% Evaluate a common composite-derived model against waveform-specific models.
% Corrected version: identification uses regressorManager.evaluation().
% Also fixes repo-root detection when the script is stored in analisis_8WF or _codex_private/scratch.

clearvars;
clc;

%% ===================== USER CONFIG =====================

commonModelCsvName = 'common171_regressors.csv';
legacyCommonModelCsvName = 'modelo_general_composite_thr095_ge6_171_regresores.csv';
lambda = 1e-5;
perc = 0.04;
nWaveforms = 8;
specificSanityToleranceDb = 0.5;

%% ===================== MAIN LOGIC =====================

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

analysisRoot = scriptDir;
repoRoot = detectRepoRoot(scriptDir);

originalDir = pwd;
cleanupDir = onCleanup(@() cd(originalDir));
cd(repoRoot);

oldFigureVisibility = get(groot, 'DefaultFigureVisible');
cleanupFigures = onCleanup(@() set(groot, 'DefaultFigureVisible', oldFigureVisibility));
set(groot, 'DefaultFigureVisible', 'off');

addpathIfExists(fullfile(repoRoot, 'modeling_benchmark'));
gvgDir = fullfile(repoRoot, 'modeling_benchmark', 'GVG');
if exist(gvgDir, 'dir')
    addpath(genpath(gvgDir));
end

inputDir = fullfile(repoRoot, 'results', 'ILC_8waveforms');
compositeDir = fullfile(repoRoot, 'results', 'composite_selection_ILC_8waveforms');
outputDir = fullfile(repoRoot, 'results', 'common_composite_model_evaluation');

commonCsvPath = findCommonModelCsv(repoRoot, compositeDir, commonModelCsvName, ...
    legacyCommonModelCsvName, analysisRoot);
commonRegressors = loadCommonRegressors(commonCsvPath);
commonRegPopulation = specsToRegressorPopulation(commonRegressors);
nCommonRegressors = numel(commonRegPopulation);

compositeModelFiles = selectLatestCompositeModelFiles(compositeDir, nWaveforms);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));

waveformIndex = (1:nWaveforms).';
waveformFile = cell(nWaveforms, 1);
nCommon = repmat(nCommonRegressors, nWaveforms, 1);
nSpecificRegressors = NaN(nWaveforms, 1);
savedSpecificIdentificationNMSE = NaN(nWaveforms, 1);
specificIdentificationDifferenceDb = NaN(nWaveforms, 1);
nmseCommonId = NaN(nWaveforms, 1);
nmseSpecificId = NaN(nWaveforms, 1);
deltaCommonMinusSpecificId = NaN(nWaveforms, 1);
nmseCommonVal = NaN(nWaveforms, 1);
nmseSpecificVal = NaN(nWaveforms, 1);
deltaCommonMinusSpecificVal = NaN(nWaveforms, 1);
nmseCommonValComplement = NaN(nWaveforms, 1);
nmseSpecificValComplement = NaN(nWaveforms, 1);
outputMatFile = cell(nWaveforms, 1);

coefRows = cell(nWaveforms, 1);
evaluationResults = cell(nWaveforms, 1);

for wf = 1:nWaveforms
    fprintf('\n=== Evaluating WF%02d ===\n', wf);

    compositeData = load(compositeModelFiles{wf});
    [specificRegressors, baseConfig, sourcePath] = unpackCompositeModel( ...
        compositeData, compositeModelFiles{wf}, inputDir);
    nSpecificRegressors(wf) = numel(specificRegressors);
    savedSpecificIdentificationNMSE(wf) = getSavedIdentificationNMSE(compositeData);

    [x, y, waveformFile{wf}] = loadWaveformXY(sourcePath);
    x = x(:) - mean(x(:));
    y = y(:) - mean(y(:));
    nid = sel_indices(x, y, perc);
    xId = x(nid);
    yId = y(nid);
    xId = xId(:);
    yId = yId(:);

    specificFit = fitWithRegressorManager(xId, yId, specificRegressors, ...
        baseConfig, lambda, numel(specificRegressors));
    nmseSpecificId(wf) = specificFit.nmseId;
    specificIdentificationDifferenceDb(wf) = abs(nmseSpecificId(wf) - ...
        savedSpecificIdentificationNMSE(wf));

    if specificIdentificationDifferenceDb(wf) > specificSanityToleranceDb
        error(['Specific-model sanity check failed for WF%02d.\n' ...
            'Saved identificationNMSE: %.4f dB\n' ...
            'Recomputed with regressorManager.evaluation(): %.4f dB\n' ...
            'Difference: %.4f dB > %.4f dB\n' ...
            'Aborting before evaluating the common model.'], ...
            wf, savedSpecificIdentificationNMSE(wf), nmseSpecificId(wf), ...
            specificIdentificationDifferenceDb(wf), specificSanityToleranceDb);
    end

    commonFit = fitWithRegressorManager(xId, yId, commonRegPopulation, ...
        baseConfig, lambda, nCommonRegressors);
    nmseCommonId(wf) = commonFit.nmseId;
    deltaCommonMinusSpecificId(wf) = nmseCommonId(wf) - nmseSpecificId(wf);

    [yhatCommonId, yCommonIdAligned] = predictIdentification(commonFit.rManager, xId, yId);
    [yhatSpecificId, ySpecificIdAligned] = predictIdentification(specificFit.rManager, xId, yId);
    [yhatCommonVal, yCommonValAligned] = predictValidation(commonFit.rManager, x, y);
    [yhatSpecificVal, ySpecificValAligned] = predictValidation(specificFit.rManager, x, y);

    nmseCommonVal(wf) = calcNmseDb(yCommonValAligned, yhatCommonVal);
    nmseSpecificVal(wf) = calcNmseDb(ySpecificValAligned, yhatSpecificVal);
    deltaCommonMinusSpecificVal(wf) = nmseCommonVal(wf) - nmseSpecificVal(wf);

    complementMask = true(numel(yCommonValAligned), 1);
    complementMask(nid) = false;
    nmseCommonValComplement(wf) = calcNmseDb(yCommonValAligned(complementMask), ...
        yhatCommonVal(complementMask));
    nmseSpecificValComplement(wf) = calcNmseDb(ySpecificValAligned(complementMask), ...
        yhatSpecificVal(complementMask));

    NMSEs = struct( ...
        'commonId', nmseCommonId(wf), ...
        'specificId', nmseSpecificId(wf), ...
        'savedSpecificIdentification', savedSpecificIdentificationNMSE(wf), ...
        'specificIdentificationDifferenceDb', specificIdentificationDifferenceDb(wf), ...
        'commonIdPredictionDiagnostic', calcNmseDb(yCommonIdAligned, yhatCommonId), ...
        'specificIdPredictionDiagnostic', calcNmseDb(ySpecificIdAligned, yhatSpecificId), ...
        'deltaCommonMinusSpecificId', deltaCommonMinusSpecificId(wf), ...
        'commonVal', nmseCommonVal(wf), ...
        'specificVal', nmseSpecificVal(wf), ...
        'deltaCommonMinusSpecificVal', deltaCommonMinusSpecificVal(wf), ...
        'commonValComplement', nmseCommonValComplement(wf), ...
        'specificValComplement', nmseSpecificValComplement(wf));

    coefCommon = commonFit.coefSelected;
    coefSpecific = specificFit.coefSelected;

    outputMatFile{wf} = fullfile(outputDir, sprintf( ...
        'common_composite_model_evaluation_wf%02d_%s.mat', wf, runStamp));

    specificRegressors = specificFit.rManager.regPopulation;
    save(outputMatFile{wf}, 'commonRegressors', 'specificRegressors', ...
        'coefCommon', 'coefSpecific', 'yhatCommonId', 'yhatSpecificId', ...
        'yhatCommonVal', 'yhatSpecificVal', 'NMSEs', 'nid', 'lambda', ...
        'sourcePath', 'commonCsvPath', '-v7.3');

    coefRows{wf} = coefficientTableForWaveform(wf, commonRegressors, ...
        commonFit.coefByInput);
    evaluationResults{wf} = struct('waveformIndex', wf, 'NMSEs', NMSEs, ...
        'outputMatFile', outputMatFile{wf});

    fprintf('Sanity OK WF%02d: saved %.3f dB, recomputed %.3f dB.\n', ...
        wf, savedSpecificIdentificationNMSE(wf), nmseSpecificId(wf));
end

summaryTable = table(waveformIndex, waveformFile, nCommon, nSpecificRegressors, ...
    savedSpecificIdentificationNMSE, specificIdentificationDifferenceDb, ...
    nmseCommonId, nmseSpecificId, deltaCommonMinusSpecificId, ...
    nmseCommonVal, nmseSpecificVal, deltaCommonMinusSpecificVal, ...
    nmseCommonValComplement, nmseSpecificValComplement, outputMatFile, ...
    'VariableNames', {'waveformIndex', 'waveformFile', 'nCommonRegressors', ...
    'nSpecificRegressors', 'savedSpecificIdentificationNMSE', ...
    'specificIdentificationDifferenceDb', 'nmseCommonId', 'nmseSpecificId', ...
    'deltaCommonMinusSpecificId', 'nmseCommonVal', 'nmseSpecificVal', ...
    'deltaCommonMinusSpecificVal', 'nmseCommonValComplement', ...
    'nmseSpecificValComplement', 'outputMatFile'});

coefficientsTable = vertcat(coefRows{:});

summaryCsv = fullfile(outputDir, sprintf( ...
    'common_composite_model_evaluation_summary_%s.csv', runStamp));
coefficientsCsv = fullfile(outputDir, sprintf( ...
    'common_composite_model_evaluation_coefficients_%s.csv', runStamp));
globalMat = fullfile(outputDir, sprintf( ...
    'common_composite_model_evaluation_global_%s.mat', runStamp));

writetable(summaryTable, summaryCsv);
writetable(coefficientsTable, coefficientsCsv);
save(globalMat, 'summaryTable', 'coefficientsTable', 'evaluationResults', ...
    'commonRegressors', 'commonCsvPath', 'lambda', 'perc', 'runStamp', '-v7.3');

fprintf('\nWF | NMSE common ID | NMSE specific ID | delta ID | NMSE common VAL | NMSE specific VAL | delta VAL\n');
for wf = 1:nWaveforms
    fprintf('%02d | %9.3f dB | %11.3f dB | %+8.3f dB | %10.3f dB | %12.3f dB | %+9.3f dB\n', ...
        wf, nmseCommonId(wf), nmseSpecificId(wf), deltaCommonMinusSpecificId(wf), ...
        nmseCommonVal(wf), nmseSpecificVal(wf), deltaCommonMinusSpecificVal(wf));
end

fprintf('\nSaved:\n  %s\n  %s\n  %s\n', summaryCsv, coefficientsCsv, globalMat);

%% ===================== LOCAL FUNCTIONS =====================

function repoRoot = detectRepoRoot(startDir)
    % Walk upwards until finding the real project root.
    % This allows the script to live in analisis_8WF or _codex_private/scratch.
    repoRoot = startDir;

    while true
        hasResults = exist(fullfile(repoRoot, 'results'), 'dir') == 7;
        hasGVG = exist(fullfile(repoRoot, 'modeling_benchmark', 'GVG', 'Regressor.m'), 'file') == 2;

        if hasResults && hasGVG
            return;
        end

        parentDir = fileparts(repoRoot);
        if strcmp(parentDir, repoRoot) || isempty(parentDir)
            error(['Could not detect repo root from "%s". ' ...
                'Put this script inside the project or one of its subfolders.'], startDir);
        end

        repoRoot = parentDir;
    end
end

function addpathIfExists(pathName)
    if ~isempty(pathName) && exist(pathName, 'dir')
        addpath(pathName);
    end
end

function csvPath = findCommonModelCsv(repoRoot, compositeDir, csvName, legacyCsvName, analysisRoot)
    analysisDir = fullfile(repoRoot, 'analisis_8WF');
    candidates = { ...
        fullfile(analysisDir, '02_modelo_comun', csvName), ...
        fullfile(analysisDir, '02_modelo_comun', legacyCsvName), ...
        fullfile(analysisRoot, csvName), ...
        fullfile(analysisRoot, legacyCsvName), ...
        fullfile(analysisDir, legacyCsvName), ...
        fullfile(repoRoot, csvName), ...
        fullfile(repoRoot, legacyCsvName), ...
        fullfile(compositeDir, 'pairwise_common_structure', csvName), ...
        fullfile(compositeDir, 'pairwise_common_structure', legacyCsvName)};

    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            csvPath = candidates{i};
            return;
        end
    end

    error('Common model CSV not found. Checked primary and legacy paths.');
end

function commonRegressors = loadCommonRegressors(csvPath)
    T = readCsvTable(csvPath);
    nRows = height(T);
    commonRegressors = repmat(emptyRegressorSpec(), nRows, 1);

    keyCol = firstExistingColumn(T, {'regressorKey', 'baseRegressorKey'});
    textCol = firstExistingColumn(T, {'regressorText', 'baseRegressorText', 'regressorString'});
    rankCol = firstExistingColumn(T, {'regressorRankCommon', 'baseRank', 'regressorRank'});
    xCol = firstExistingColumn(T, {'X'});
    xconjCol = firstExistingColumn(T, {'Xconj'});
    xenvCol = firstExistingColumn(T, {'Xenv'});

    for i = 1:nRows
        if ~isempty(xCol) && ~isempty(xconjCol) && ~isempty(xenvCol)
            X = parseVector(tableValue(T, xCol, i));
            Xconj = parseVector(tableValue(T, xconjCol, i));
            Xenv = parseVector(tableValue(T, xenvCol, i));
            key = makeRegressorKey(X, Xconj, Xenv);
        elseif ~isempty(keyCol)
            key = char(tableValue(T, keyCol, i));
            [X, Xconj, Xenv] = parseRegressorKey(key);
        else
            error('Common model CSV must contain X/Xconj/Xenv or regressorKey/baseRegressorKey.');
        end

        if ~isempty(textCol)
            text = char(tableValue(T, textCol, i));
        else
            text = regressorText(X, Xconj, Xenv);
        end

        if ~isempty(rankCol)
            rank = tableValue(T, rankCol, i);
            if ~isnumeric(rank)
                rank = str2double(char(rank));
            end
        else
            rank = i;
        end

        commonRegressors(i).rank = rank;
        commonRegressors(i).X = X;
        commonRegressors(i).Xconj = Xconj;
        commonRegressors(i).Xenv = Xenv;
        commonRegressors(i).key = key;
        commonRegressors(i).text = text;
    end
end

function regPopulation = specsToRegressorPopulation(specs)
    regPopulation = [];
    for i = 1:numel(specs)
        reg = Regressor(specs(i).X, specs(i).Xconj, specs(i).Xenv);
        reg.sortindexes();
        regPopulation = [regPopulation reg]; %#ok<AGROW>
    end
end

function fit = fitWithRegressorManager(xId, yId, regPopulation, baseConfig, lambda, maxPopulation)
    GVGconfig = baseConfig;
    GVGconfig.regPopulation = cloneRegressorPopulation(regPopulation);
    GVGconfig.inittype = 'noinit';
    GVGconfig.DOMPtype = 'POMP';
    GVGconfig.lambda = lambda;
    GVGconfig.alpha = 1;
    GVGconfig.maxPopulation = maxPopulation;
    GVGconfig.evaluationtype = 'maxPopulation';
    GVGconfig.ngenerations = 1;
    GVGconfig.validatengen = 1;
    GVGconfig.validate = false;
    GVGconfig.storePopulation = false;
    GVGconfig.mutationrate = 0;
    GVGconfig.crossoverrate = 0;
    GVGconfig.showPlots = false;
    GVGconfig.verbosity = 0;

    rManager = regressorManager(xId, yId, GVGconfig);
    rManager.initialization();
    rManager.evaluation();
    rManager.selection();

    fit = struct();
    fit.rManager = rManager;
    fit.nmseId = rManager.nmse;
    [fit.coefSelected, fit.coefByInput] = extractCoefficients(rManager, numel(regPopulation));
end

function clonedPopulation = cloneRegressorPopulation(regPopulation)
    clonedPopulation = [];
    for i = 1:numel(regPopulation)
        reg = regPopulation(i);
        clonedPopulation = [clonedPopulation Regressor(reg.X, reg.Xconj, reg.Xenv)]; %#ok<AGROW>
    end
end

function [coefSelected, coefByInput] = extractCoefficients(rManager, nInputRegressors)
    nopt = scalarOrLast(rManager.nopt);
    support = rManager.s(:);
    coefSelected = rManager.h(support, nopt);

    coefByInput = NaN(nInputRegressors, 1) + 1i * NaN(nInputRegressors, 1);
    valid = support >= 1 & support <= nInputRegressors;
    coefByInput(support(valid)) = coefSelected(valid);
end

function [yhat, yAligned] = predictIdentification(rManager, xId, yId)
    N = numel(xId);
    n = (1:N).';
    rManager.clearRegressors();
    [U, yAligned] = rManager.buildUcustomX(xId, yId, n);
    coefSelected = selectedCoefficientsForCurrentPopulation(rManager);
    yhat = U * coefSelected;
    rManager.clearRegressors();
end

function [yhat, yAligned] = predictValidation(rManager, x, y)
    N = numel(x);
    n = [N-rManager.Qpmax+1:N, 1:N, 1:rManager.Qnmax].';
    rManager.clearRegressors();
    [U, yAligned] = rManager.buildUcustomX(x, y, n);
    coefSelected = selectedCoefficientsForCurrentPopulation(rManager);
    yhat = U * coefSelected;
    rManager.clearRegressors();
end

function coefSelected = selectedCoefficientsForCurrentPopulation(rManager)
    nopt = scalarOrLast(rManager.nopt);
    coefSelected = rManager.h(rManager.s(:), nopt);
end

function modelFiles = selectLatestCompositeModelFiles(compositeDir, nWaveforms)
    files = dir(fullfile(compositeDir, 'experiment*_wf*_composite_selection_*.mat'));
    modelFiles = cell(nWaveforms, 1);

    for wf = 1:nWaveforms
        wfTag = sprintf('_wf%02d_', wf);
        isThisWaveform = false(numel(files), 1);
        for iFile = 1:numel(files)
            isThisWaveform(iFile) = ~isempty(strfind(files(iFile).name, wfTag)); %#ok<STREMP>
        end

        candidates = files(isThisWaveform);
        if isempty(candidates)
            error('No composite selection .mat found for WF%02d in %s.', wf, compositeDir);
        end

        [~, latestIndex] = max([candidates.datenum]);
        modelFiles{wf} = fullfile(candidates(latestIndex).folder, candidates(latestIndex).name);
    end
end

function [regPopulation, baseConfig, sourcePath] = unpackCompositeModel(S, modelFile, inputDir)
    if isfield(S, 'rManager')
        regPopulation = S.rManager.regPopulation;
        baseConfig = configFromRManager(S.rManager);
    elseif isfield(S, 'regPopulation') && isfield(S, 'GVGconfig')
        regPopulation = S.regPopulation;
        baseConfig = S.GVGconfig;
    else
        error('Composite file lacks rManager/regPopulation: %s.', modelFile);
    end

    if isfield(S, 'GVGconfig')
        baseConfig = fillMissingConfigFields(baseConfig, S.GVGconfig);
    end

    if isfield(S, 'sourcePath') && exist(S.sourcePath, 'file')
        sourcePath = S.sourcePath;
    else
        sourcePath = inferSourcePathFromModelFile(modelFile, inputDir);
    end
end

function GVGconfig = configFromRManager(rManager)
    GVGconfig.Qpmax = rManager.Qpmax;
    GVGconfig.Qnmax = rManager.Qnmax;
    GVGconfig.Pmax = rManager.Pmax;
    GVGconfig.maxPopulation = rManager.maxPopulation;
    GVGconfig.evaluationtype = rManager.evaluationtype;
    GVGconfig.DOMPtype = rManager.DOMPtype;
    GVGconfig.lambda = rManager.lambda;
    GVGconfig.alpha = rManager.alpha;
    GVGconfig.verbosity = rManager.verbosity;
    GVGconfig.showPlots = false;
    GVGconfig.crossoverrate = rManager.crossoverrate;
    GVGconfig.mutationrate = rManager.mutationrate;
    GVGconfig.inittype = rManager.inittype;
    GVGconfig.regPopulation = [];
    GVGconfig.ngenerations = 1;
    GVGconfig.validatengen = 1;
    GVGconfig.validate = false;
    GVGconfig.storePopulation = false;

    GVGconfig.Pfv = rManager.Pfv;
    GVGconfig.Mfv = rManager.Mfv;
    GVGconfig.Pcvs = rManager.Pcvs;
    GVGconfig.Mcvs = rManager.Mcvs;
    GVGconfig.Pmp = rManager.Pmp;
    GVGconfig.Mmp = rManager.Mmp;
    GVGconfig.Pddr = rManager.Pddr;
    GVGconfig.Mddr = rManager.Mddr;
    GVGconfig.Ka = rManager.Ka;
    GVGconfig.La = rManager.La;
    GVGconfig.Kb = rManager.Kb;
    GVGconfig.Lb = rManager.Lb;
    GVGconfig.Mb = rManager.Mb;
    GVGconfig.Kc = rManager.Kc;
    GVGconfig.Lc = rManager.Lc;
    GVGconfig.Mc = rManager.Mc;
end

function GVGconfig = fillMissingConfigFields(GVGconfig, savedConfig)
    names = fieldnames(savedConfig);
    for i = 1:numel(names)
        if ~isfield(GVGconfig, names{i})
            GVGconfig.(names{i}) = savedConfig.(names{i});
        end
    end
end

function value = getSavedIdentificationNMSE(S)
    if isfield(S, 'identificationNMSE')
        value = scalarOrLast(S.identificationNMSE);
    elseif isfield(S, 'NMSEs') && isfield(S.NMSEs, 'specificId')
        value = scalarOrLast(S.NMSEs.specificId);
    elseif isfield(S, 'rManager') && isprop(S.rManager, 'nmse')
        value = scalarOrLast(S.rManager.nmse);
    else
        error('Composite .mat does not contain identificationNMSE or rManager.nmse.');
    end
end

function sourcePath = inferSourcePathFromModelFile(modelFile, inputDir)
    [~, stem] = fileparts(modelFile);
    token = regexp(stem, '^(experiment\d+T\d+_xy)_wf\d+_', 'tokens', 'once');
    if isempty(token)
        error('Cannot infer source *_xy.mat from %s.', modelFile);
    end
    sourcePath = fullfile(inputDir, [token{1} '.mat']);
end

function [x, y, waveformFile] = loadWaveformXY(sourcePath)
    if ~exist(sourcePath, 'file')
        error('Waveform source file not found: %s.', sourcePath);
    end
    S = load(sourcePath, 'x', 'y');
    x = S.x;
    y = S.y;
    [~, name, ext] = fileparts(sourcePath);
    waveformFile = [name ext];
end

function T = coefficientTableForWaveform(wf, commonRegressors, coefByInput)
    nRegs = numel(commonRegressors);
    waveformIndex = repmat(wf, nRegs, 1);
    regressorRankCommon = NaN(nRegs, 1);
    regressorText = cell(nRegs, 1);
    regressorKey = cell(nRegs, 1);
    coefReal = real(coefByInput(:));
    coefImag = imag(coefByInput(:));
    coefAbs = abs(coefByInput(:));
    coefPhaseRad = angle(coefByInput(:));

    for iReg = 1:nRegs
        regressorRankCommon(iReg) = commonRegressors(iReg).rank;
        regressorText{iReg} = commonRegressors(iReg).text;
        regressorKey{iReg} = commonRegressors(iReg).key;
    end

    T = table(waveformIndex, regressorRankCommon, regressorText, regressorKey, ...
        coefReal, coefImag, coefAbs, coefPhaseRad);
end

function value = calcNmseDb(y, yhat)
    value = 10 * log10(sum(abs(y - yhat).^2) / sum(abs(y).^2));
end

function T = readCsvTable(csvPath)
    try
        T = readtable(csvPath, 'VariableNamingRule', 'preserve', 'TextType', 'char');
    catch
        try
            T = readtable(csvPath, 'TextType', 'char');
        catch
            T = readtable(csvPath);
        end
    end
end

function spec = emptyRegressorSpec()
    spec = struct('rank', NaN, 'X', [], 'Xconj', [], 'Xenv', [], 'key', '', 'text', '');
end

function name = firstExistingColumn(T, candidates)
    name = '';
    names = T.Properties.VariableNames;

    for i = 1:numel(candidates)
        match = strcmp(names, candidates{i});
        if any(match)
            name = names{find(match, 1, 'first')};
            return;
        end
    end
end

function value = tableValue(T, columnName, rowIndex)
    column = T.(columnName);
    if iscell(column)
        value = column{rowIndex};
    elseif isstring(column)
        value = char(column(rowIndex));
    else
        value = column(rowIndex, :);
    end
end

function [X, Xconj, Xenv] = parseRegressorKey(key)
    key = strtrim(char(key));
    tokens = regexp(key, 'X=([^;]*);Xconj=([^;]*);Xenv=(.*)$', 'tokens', 'once');
    if isempty(tokens)
        error('Cannot parse regressorKey: %s', key);
    end
    X = parseVector(tokens{1});
    Xconj = parseVector(tokens{2});
    Xenv = parseVector(tokens{3});
end

function v = parseVector(value)
    if iscell(value)
        value = value{1};
    end
    if isnumeric(value)
        v = value(:).';
        v(isnan(v)) = [];
        return;
    end

    s = strtrim(char(value));
    if isempty(s) || strcmp(s, '[]')
        v = [];
    else
        v = str2num(s); %#ok<ST2NM>
        v = v(:).';
    end
end

function key = makeRegressorKey(X, Xconj, Xenv)
    key = sprintf('X=%s;Xconj=%s;Xenv=%s', mat2str(X(:).'), ...
        mat2str(Xconj(:).'), mat2str(Xenv(:).'));
end

function text = regressorText(X, Xconj, Xenv)
    reg = Regressor(X, Xconj, Xenv);
    text = strtrim(reg.print());
end

function value = scalarOrLast(x)
    value = NaN;
    if isnumeric(x) && ~isempty(x)
        x = x(:);
        value = x(end);
    end
end
