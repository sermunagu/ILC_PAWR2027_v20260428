% Compare common 171-regressor model against composite and GVG specific models.
% Offline only: no hardware, no GVGgenerateModel, no mutation/crossover.

clearvars;
clc;

%% ===================== USER CONFIG =====================

commonModelCsvName = 'common171_regressors.csv';
legacyCommonModelCsvName = 'modelo_general_composite_thr095_ge6_171_regresores.csv';
lambda = 1e-5;
perc = 0.04;
nWaveforms = 8;
sanityToleranceDb = 0.5;

%% ===================== MAIN LOGIC =====================

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

analysisRoot = scriptDir;
repoRoot = detectRepoRoot(scriptDir);
pipelineCfg = getPipelineConfig();
measurementDirName = getCfgField(pipelineCfg, 'measurementDirName', ...
    'ILC_8waveforms');
measurementTag = getCfgField(pipelineCfg, 'measurementTag', ...
    makeSafeFileTag(measurementDirName));

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

inputDir = getCfgField(pipelineCfg, 'waveformInputDir', ...
    fullfile(repoRoot, 'results', measurementDirName));
compositeDir = getCfgField(pipelineCfg, 'compositeResultsDir', ...
    fullfile(repoRoot, 'results', ['composite_selection_' measurementTag]));
gvgResultsDir = fullfile(repoRoot, 'results', 'GVG_ILC_8waveforms');
outputDir = getCfgField(pipelineCfg, 'evaluationResultsDir', ...
    fullfile(repoRoot, 'results', 'common_composite_model_evaluation', ...
    measurementTag));
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

commonCsvPath = findCommonModelCsv(repoRoot, compositeDir, commonModelCsvName, ...
    legacyCommonModelCsvName, analysisRoot);
commonRegressors = loadCommonRegressors(commonCsvPath);
commonRegPopulation = specsToRegressorPopulation(commonRegressors);
nCommonRegressors = numel(commonRegPopulation);

xyFiles = selectWaveformXYFiles(inputDir, nWaveforms);
compositeFiles = selectLatestFilesByWaveform(compositeDir, '*_composite_selection_*.mat', nWaveforms);
gvgFiles = selectLatestFilesByWaveform(gvgResultsDir, '*_GVG_*.mat', nWaveforms);

waveformIndex = (1:nWaveforms).';
waveformLabel = cell(nWaveforms, 1);
nmseCommonId = NaN(nWaveforms, 1);
nmseCompositeSpecificId = NaN(nWaveforms, 1);
deltaCommonMinusCompositeId = NaN(nWaveforms, 1);
nmseGVGSpecificId = NaN(nWaveforms, 1);
deltaCommonMinusGVGId = NaN(nWaveforms, 1);

% Validation NMSEs computed consistently on the full waveform using
% buildUcustomX and the fitted/loaded coefficients.
nmseCommonVal = NaN(nWaveforms, 1);
nmseCompositeSpecificVal = NaN(nWaveforms, 1);
deltaCommonMinusCompositeVal = NaN(nWaveforms, 1);
nmseGVGSpecificVal = NaN(nWaveforms, 1);
deltaCommonMinusGVGVal = NaN(nWaveforms, 1);

% Diagnostic only: saved GVG validation values, when present.
nmseGVGSpecificSavedValMean = NaN(nWaveforms, 1);
nmseGVGSpecificSavedValMin = NaN(nWaveforms, 1);

for wf = 1:nWaveforms
    fprintf('\n=== WF%02d common171 vs composite vs GVG ===\n', wf);

    compositeData = load(compositeFiles{wf});
    gvgData = load(gvgFiles{wf});

    [specificCompositeRegressors, baseConfig, sourcePath] = unpackCompositeModel( ...
        compositeData, compositeFiles{wf}, xyFiles{wf});

    if isempty(sourcePath)
        sourcePath = xyFiles{wf};
    end

    [x, y, waveformFile] = loadCenteredXY(sourcePath);
    waveformLabel{wf} = sprintf('WF%02d_%s', wf, waveformFile);
    nid = getCompositeNidOrCompute(compositeData, x, y, perc);
    xId = x(nid);
    yId = y(nid);
    xId = xId(:);
    yId = yId(:);

    nmseCompositeSpecificId(wf) = getSavedCompositeIdentificationNMSE(compositeData);
    recomputedComposite = fitWithRegressorManager(xId, yId, ...
        specificCompositeRegressors, baseConfig, lambda, numel(specificCompositeRegressors));

    if abs(recomputedComposite.nmseId - nmseCompositeSpecificId(wf)) > sanityToleranceDb
        error(['Composite sanity failed for WF%02d.\n' ...
            'Saved composite NMSE: %.4f dB\n' ...
            'Recomputed composite NMSE: %.4f dB\n' ...
            'Tolerance: %.4f dB\n' ...
            'Aborting before comparing common/GVG.'], ...
            wf, nmseCompositeSpecificId(wf), recomputedComposite.nmseId, sanityToleranceDb);
    end

    commonFit = fitWithRegressorManager(xId, yId, commonRegPopulation, ...
        baseConfig, lambda, nCommonRegressors);
    nmseCommonId(wf) = commonFit.nmseId;

    nmseGVGSpecificId(wf) = getSavedGVGIdentificationNMSE(gvgData);
    deltaCommonMinusCompositeId(wf) = nmseCommonId(wf) - nmseCompositeSpecificId(wf);
    deltaCommonMinusGVGId(wf) = nmseCommonId(wf) - nmseGVGSpecificId(wf);

    % Validation on full waveform, using the same prediction mechanism for
    % common, composite-specific and GVG-specific models.
    [yhatCommonVal, yCommonValAligned] = predictValidation(commonFit.rManager, x, y);
    [yhatCompositeVal, yCompositeValAligned] = predictValidation(recomputedComposite.rManager, x, y);
    [yhatGVGVal, yGVGValAligned] = predictValidation(gvgData.rManager, x, y);

    nmseCommonVal(wf) = calcNmseDb(yCommonValAligned, yhatCommonVal);
    nmseCompositeSpecificVal(wf) = calcNmseDb(yCompositeValAligned, yhatCompositeVal);
    nmseGVGSpecificVal(wf) = calcNmseDb(yGVGValAligned, yhatGVGVal);

    deltaCommonMinusCompositeVal(wf) = nmseCommonVal(wf) - nmseCompositeSpecificVal(wf);
    deltaCommonMinusGVGVal(wf) = nmseCommonVal(wf) - nmseGVGSpecificVal(wf);

    [nmseGVGSpecificSavedValMean(wf), nmseGVGSpecificSavedValMin(wf)] = ...
        getSavedGVGValidationSummary(gvgData);

    fprintf('ID  | Common %.3f dB | Composite %.3f dB | GVG %.3f dB\n', ...
        nmseCommonId(wf), nmseCompositeSpecificId(wf), nmseGVGSpecificId(wf));
    fprintf('VAL | Common %.3f dB | Composite %.3f dB | GVG %.3f dB\n', ...
        nmseCommonVal(wf), nmseCompositeSpecificVal(wf), nmseGVGSpecificVal(wf));
end

summaryTable = table(waveformIndex, waveformLabel, ...
    nmseCommonId, nmseCompositeSpecificId, deltaCommonMinusCompositeId, ...
    nmseGVGSpecificId, deltaCommonMinusGVGId, ...
    nmseCommonVal, nmseCompositeSpecificVal, deltaCommonMinusCompositeVal, ...
    nmseGVGSpecificVal, deltaCommonMinusGVGVal, ...
    nmseGVGSpecificSavedValMean, nmseGVGSpecificSavedValMin);

summaryRows = makeMeanRows(summaryTable);
outputTable = [summaryTable; summaryRows];

runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
outputCsv = fullfile(outputDir, sprintf( ...
    'common171_vs_composite_vs_gvg_ID_VAL_summary_%s_%s.csv', ...
    measurementTag, runStamp));
writetable(outputTable, outputCsv);

fprintf('\nSummary means, ID:\n');
fprintf('mean delta common-composite ID including WF6: %.4f dB\n', ...
    mean(summaryTable.deltaCommonMinusCompositeId, 'omitnan'));
fprintf('mean delta common-composite ID excluding WF6: %.4f dB\n', ...
    mean(summaryTable.deltaCommonMinusCompositeId(summaryTable.waveformIndex ~= 6), 'omitnan'));
fprintf('mean delta common-GVG ID including WF6: %.4f dB\n', ...
    mean(summaryTable.deltaCommonMinusGVGId, 'omitnan'));
fprintf('mean delta common-GVG ID excluding WF6: %.4f dB\n', ...
    mean(summaryTable.deltaCommonMinusGVGId(summaryTable.waveformIndex ~= 6), 'omitnan'));

fprintf('\nSummary means, VAL full waveform:\n');
fprintf('mean delta common-composite VAL including WF6: %.4f dB\n', ...
    mean(summaryTable.deltaCommonMinusCompositeVal, 'omitnan'));
fprintf('mean delta common-composite VAL excluding WF6: %.4f dB\n', ...
    mean(summaryTable.deltaCommonMinusCompositeVal(summaryTable.waveformIndex ~= 6), 'omitnan'));
fprintf('mean delta common-GVG VAL including WF6: %.4f dB\n', ...
    mean(summaryTable.deltaCommonMinusGVGVal, 'omitnan'));
fprintf('mean delta common-GVG VAL excluding WF6: %.4f dB\n', ...
    mean(summaryTable.deltaCommonMinusGVGVal(summaryTable.waveformIndex ~= 6), 'omitnan'));
fprintf('\nSaved CSV:\n  %s\n', outputCsv);

%% ===================== LOCAL FUNCTIONS =====================

function repoRoot = detectRepoRoot(startDir)
    % Walk upwards until finding the real project root.
    % This lets the script live in analisis_8WF, _codex_private/scratch,
    % or any other subfolder of the repository.
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

function cfg = getPipelineConfig()
    if isappdata(0, 'analisis8WF_pipeline_cfg')
        cfg = getappdata(0, 'analisis8WF_pipeline_cfg');
    else
        cfg = struct();
    end
end

function value = getCfgField(cfg, fieldName, defaultValue)
    if isstruct(cfg) && isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
        value = cfg.(fieldName);
    else
        value = defaultValue;
    end
end

function tag = makeSafeFileTag(value)
    tag = regexprep(char(value), '[^\w.-]', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');
    if isempty(tag)
        tag = 'measurement_set';
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

function xyFiles = selectWaveformXYFiles(inputDir, nWaveforms)
    files = dir(fullfile(inputDir, 'experiment*_xy.mat'));
    [~, order] = sort({files.name});
    files = files(order);
    if numel(files) < nWaveforms
        error('Expected at least %d *_xy.mat files in %s.', nWaveforms, inputDir);
    end

    xyFiles = cell(nWaveforms, 1);
    for wf = 1:nWaveforms
        xyFiles{wf} = fullfile(files(wf).folder, files(wf).name);
    end
end

function modelFiles = selectLatestFilesByWaveform(folderName, pattern, nWaveforms)
    files = dir(fullfile(folderName, pattern));
    modelFiles = cell(nWaveforms, 1);

    for wf = 1:nWaveforms
        wfTag = sprintf('_wf%02d_', wf);
        isWaveform = false(numel(files), 1);
        for iFile = 1:numel(files)
            isWaveform(iFile) = ~isempty(strfind(files(iFile).name, wfTag)); %#ok<STREMP>
        end

        candidates = files(isWaveform);
        if isempty(candidates)
            error('No file matching WF%02d pattern "%s" in %s.', wf, pattern, folderName);
        end

        [~, latestIndex] = max([candidates.datenum]);
        modelFiles{wf} = fullfile(candidates(latestIndex).folder, candidates(latestIndex).name);
    end
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

function [regPopulation, baseConfig, sourcePath] = unpackCompositeModel(S, modelFile, fallbackSourcePath)
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
        sourcePath = fallbackSourcePath;
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
    evalc('rManager.evaluation();');
    rManager.selection();

    fit = struct('rManager', rManager, 'nmseId', rManager.nmse);
end

function clonedPopulation = cloneRegressorPopulation(regPopulation)
    clonedPopulation = [];
    for i = 1:numel(regPopulation)
        reg = regPopulation(i);
        clonedPopulation = [clonedPopulation Regressor(reg.X, reg.Xconj, reg.Xenv)]; %#ok<AGROW>
    end
end

function nmse = getSavedCompositeIdentificationNMSE(S)
    if isfield(S, 'identificationNMSE')
        nmse = scalarOrLast(S.identificationNMSE);
    elseif isfield(S, 'rManager') && isprop(S.rManager, 'nmse')
        nmse = scalarOrLast(S.rManager.nmse);
    else
        error('Composite .mat does not contain identificationNMSE or rManager.nmse.');
    end
end

function nmse = getSavedGVGIdentificationNMSE(S)
    if isfield(S, 'rManager') && isprop(S.rManager, 'nmse')
        nmse = scalarOrLast(S.rManager.nmse);
    else
        error('GVG .mat does not contain rManager.nmse.');
    end
end

function nid = getCompositeNidOrCompute(S, x, y, perc)
    if isfield(S, 'nid') && ~isempty(S.nid)
        nid = S.nid(:);
    else
        nid = sel_indices(x, y, perc);
        nid = nid(:);
    end
end

function [x, y, waveformFile] = loadCenteredXY(sourcePath)
    if ~exist(sourcePath, 'file')
        error('Missing waveform xy file: %s', sourcePath);
    end
    S = load(sourcePath, 'x', 'y');
    x = S.x(:);
    y = S.y(:);
    x = x - mean(x);
    y = y - mean(y);
    [~, name, ext] = fileparts(sourcePath);
    waveformFile = [name ext];
end

function rows = makeMeanRows(summaryTable)
    labels = { ...
        'mean_delta_common_minus_composite_ID_including_WF6'
        'mean_delta_common_minus_composite_ID_excluding_WF6'
        'mean_delta_common_minus_GVG_ID_including_WF6'
        'mean_delta_common_minus_GVG_ID_excluding_WF6'
        'mean_delta_common_minus_composite_VAL_including_WF6'
        'mean_delta_common_minus_composite_VAL_excluding_WF6'
        'mean_delta_common_minus_GVG_VAL_including_WF6'
        'mean_delta_common_minus_GVG_VAL_excluding_WF6'};

    n = numel(labels);
    waveformIndex = NaN(n, 1);
    waveformLabel = labels;

    nmseCommonId = NaN(n, 1);
    nmseCompositeSpecificId = NaN(n, 1);
    deltaCommonMinusCompositeId = NaN(n, 1);
    nmseGVGSpecificId = NaN(n, 1);
    deltaCommonMinusGVGId = NaN(n, 1);

    nmseCommonVal = NaN(n, 1);
    nmseCompositeSpecificVal = NaN(n, 1);
    deltaCommonMinusCompositeVal = NaN(n, 1);
    nmseGVGSpecificVal = NaN(n, 1);
    deltaCommonMinusGVGVal = NaN(n, 1);

    nmseGVGSpecificSavedValMean = NaN(n, 1);
    nmseGVGSpecificSavedValMin = NaN(n, 1);

    keepNotWF6 = summaryTable.waveformIndex ~= 6;

    deltaCommonMinusCompositeId(1) = mean(summaryTable.deltaCommonMinusCompositeId, 'omitnan');
    deltaCommonMinusCompositeId(2) = mean(summaryTable.deltaCommonMinusCompositeId(keepNotWF6), 'omitnan');
    deltaCommonMinusGVGId(3) = mean(summaryTable.deltaCommonMinusGVGId, 'omitnan');
    deltaCommonMinusGVGId(4) = mean(summaryTable.deltaCommonMinusGVGId(keepNotWF6), 'omitnan');

    deltaCommonMinusCompositeVal(5) = mean(summaryTable.deltaCommonMinusCompositeVal, 'omitnan');
    deltaCommonMinusCompositeVal(6) = mean(summaryTable.deltaCommonMinusCompositeVal(keepNotWF6), 'omitnan');
    deltaCommonMinusGVGVal(7) = mean(summaryTable.deltaCommonMinusGVGVal, 'omitnan');
    deltaCommonMinusGVGVal(8) = mean(summaryTable.deltaCommonMinusGVGVal(keepNotWF6), 'omitnan');

    rows = table(waveformIndex, waveformLabel, ...
        nmseCommonId, nmseCompositeSpecificId, deltaCommonMinusCompositeId, ...
        nmseGVGSpecificId, deltaCommonMinusGVGId, ...
        nmseCommonVal, nmseCompositeSpecificVal, deltaCommonMinusCompositeVal, ...
        nmseGVGSpecificVal, deltaCommonMinusGVGVal, ...
        nmseGVGSpecificSavedValMean, nmseGVGSpecificSavedValMin);
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

function value = calcNmseDb(y, yhat)
    value = 10 * log10(sum(abs(y - yhat).^2) / sum(abs(y).^2));
end

function [meanVal, minVal] = getSavedGVGValidationSummary(S)
    meanVal = NaN;
    minVal = NaN;
    if isfield(S, 'nmsevalv') && isnumeric(S.nmsevalv) && ~isempty(S.nmsevalv)
        vals = S.nmsevalv(:);
        meanVal = mean(vals, 'omitnan');
        minVal = min(vals);
    elseif isfield(S, 'rManager') && isprop(S.rManager, 'nmsev') && ~isempty(S.rManager.nmsev)
        vals = S.rManager.nmsev(:);
        meanVal = mean(vals, 'omitnan');
        minVal = min(vals);
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
    GVGconfig.verbosity = 0;
    GVGconfig.showPlots = false;
    GVGconfig.crossoverrate = 0;
    GVGconfig.mutationrate = 0;
    GVGconfig.inittype = 'noinit';
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
