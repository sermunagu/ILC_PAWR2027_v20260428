% Compare the fixed common 171-regressor model against a tutor-method
% waveform-specific compositeall + POMP200 baseline for all 8 waveforms.
%
% This script extends the WF5 tutor-method comparison to all measured
% waveforms. It does not modify previous scripts and does not extend the
% common model to 200 regressors.
%
% Baseline per waveform:
%   compositeall pool -> POMP support selection -> nReg = 200
%   normalized-column ridge with lambda + diagLoad
%   desnormalized coefficients
%   explicit reconstructed NMSE:
%       20*log10(norm(y - X_original*h)/norm(y))
%
% Common model per waveform:
%   exactly the 171 regressors from modelo_general_composite_thr095_ge6
%   no extra regressors and no support selection
%   same normalized ridge/desnormalization/NMSE reconstruction

clearvars;
clc;

%% ===================== USER CONFIG =====================

inputPattern = '';
commonModelCsvPrimary = fullfile('analisis_8WF', '02_modelo_comun', ...
    'common171_regressors.csv');
commonModelCsvFallback = fullfile('analisis_8WF', ...
    'modelo_general_composite_thr095_ge6_171_regresores.csv');

% Same window policy for all waveforms unless edited here.
idStart = 1;
rawIdSamples = 10100;
valStart = idStart + rawIdSamples;
valLength = 10100;  % Set [] to use from valStart to the end of each waveform.

lambda = 1e-5;
alpha = 1 / (1 + lambda);
diagLoad = 1e-12;
Qpmax = 50;
Qnmax = 50;
edgeLoss = Qpmax + Qnmax;

nRegPOMP200 = 200;
nExpectedCommon = 171;
expectedCompositePoolCount = 4249;

verbosePompIterations = false;

%% ===================== MAIN LOGIC =====================

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

repoRoot = detectRepoRoot(scriptDir);
pipelineCfg = getPipelineConfig();
measurementDirName = getCfgField(pipelineCfg, 'measurementDirName', ...
    'ILC_8waveforms');
measurementTag = getCfgField(pipelineCfg, 'measurementTag', ...
    makeSafeFileTag(measurementDirName));
inputDir = getCfgField(pipelineCfg, 'waveformInputDir', ...
    fullfile(repoRoot, 'results', measurementDirName));
inputPattern = fullfile(inputDir, 'experiment*_xy.mat');
idStart = getCfgField(pipelineCfg, 'idStart', idStart);
rawIdSamples = getCfgField(pipelineCfg, 'rawIdSamples', rawIdSamples);
valStart = getCfgField(pipelineCfg, 'valStart', valStart);
valLength = getCfgField(pipelineCfg, 'valLength', valLength);
lambda = getCfgField(pipelineCfg, 'lambda', lambda);
alpha = getCfgField(pipelineCfg, 'alpha', alpha);
diagLoad = getCfgField(pipelineCfg, 'diagLoad', diagLoad);
Qpmax = getCfgField(pipelineCfg, 'Qpmax', Qpmax);
Qnmax = getCfgField(pipelineCfg, 'Qnmax', Qnmax);
edgeLoss = Qpmax + Qnmax;

originalDir = pwd;
cleanupDir = onCleanup(@() cd(originalDir));
cd(repoRoot);

addpathIfExists(fullfile(repoRoot, 'modeling_benchmark'));
gvgDir = fullfile(repoRoot, 'modeling_benchmark', 'GVG');
if exist(gvgDir, 'dir')
    addpath(genpath(gvgDir));
end

outputDir = getCfgField(pipelineCfg, 'evaluationResultsDir', ...
    fullfile(repoRoot, 'results', 'common_composite_model_evaluation', ...
    measurementTag));
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

xyFiles = dir(fullfile(inputDir, 'experiment*_xy.mat'));
[~, order] = sort({xyFiles.name});
xyFiles = xyFiles(order);

if numel(xyFiles) ~= 8
    error('Expected exactly 8 experiment*_xy.mat files in %s, found %d.', ...
        inputDir, numel(xyFiles));
end

commonModelCsv = findCommonModelCsv(repoRoot, commonModelCsvPrimary, ...
    commonModelCsvFallback);
commonRegressors = loadCommonRegressors(commonModelCsv);
if numel(commonRegressors) ~= nExpectedCommon
    error('Expected exactly %d common regressors, found %d.', ...
        nExpectedCommon, numel(commonRegressors));
end

compositeConfig = buildCompositeAllConfig(Qpmax, Qnmax, nRegPOMP200, ...
    lambda, alpha);
commonConfig = buildFixedPopulationConfig(Qpmax, Qnmax, nExpectedCommon, ...
    lambda, alpha);

nWaveforms = numel(xyFiles);
waveformIndex = (1:nWaveforms).';
waveformFile = cell(nWaveforms, 1);

idStartUsed = repmat(idStart, nWaveforms, 1);
rawIdSamplesUsed = repmat(rawIdSamples, nWaveforms, 1);
idUsefulSamples = NaN(nWaveforms, 1);
valStartUsed = repmat(valStart, nWaveforms, 1);
valRawSamples = NaN(nWaveforms, 1);
valUsefulSamples = NaN(nWaveforms, 1);

initialPoolCount = NaN(nWaveforms, 1);
poolCountAfterRemoveRepeated = NaN(nWaveforms, 1);

NMSE_id_POMP200 = NaN(nWaveforms, 1);
NMSE_val_POMP200 = NaN(nWaveforms, 1);
NMSE_id_common171 = NaN(nWaveforms, 1);
NMSE_val_common171 = NaN(nWaveforms, 1);
delta_id = NaN(nWaveforms, 1);
delta_val = NaN(nWaveforms, 1);

supportPOMP200 = cell(nWaveforms, 1);
coefficientsPOMP200 = cell(nWaveforms, 1);
coefficientsPOMP200Norm = cell(nWaveforms, 1);
colNormPOMP200Pool = cell(nWaveforms, 1);
selectedRegressorsPOMP200 = cell(nWaveforms, 1);
nmsePOMP200ByRank = cell(nWaveforms, 1);

coefficientsCommon171 = cell(nWaveforms, 1);
coefficientsCommon171Norm = cell(nWaveforms, 1);
colNormCommon171 = cell(nWaveforms, 1);

idIndices = cell(nWaveforms, 1);
valIndices = cell(nWaveforms, 1);

for wf = 1:nWaveforms
    sourcePath = fullfile(xyFiles(wf).folder, xyFiles(wf).name);
    waveformFile{wf} = xyFiles(wf).name;

    fprintf('\n=== WF%02d: %s ===\n', wf, xyFiles(wf).name);
    [x, y] = loadCenteredXY(sourcePath);

    [xIdRaw, yIdRaw, idxRaw] = extractRawWindow(x, y, idStart, ...
        rawIdSamples, 'identification');
    [xValRaw, yValRaw, idxValRaw] = extractRawWindow(x, y, valStart, ...
        valLength, 'validation');

    idIndices{wf} = idxRaw;
    valIndices{wf} = idxValRaw;
    valRawSamples(wf) = numel(idxValRaw);

    baseline = fitCompositeAllPomp200(xIdRaw, yIdRaw, xValRaw, yValRaw, ...
        compositeConfig, nRegPOMP200, alpha, lambda, diagLoad, ...
        verbosePompIterations);

    common171 = fitFixedCommon171(xIdRaw, yIdRaw, xValRaw, yValRaw, ...
        commonRegressors, commonConfig, lambda, diagLoad);

    initialPoolCount(wf) = baseline.initialPoolCount;
    poolCountAfterRemoveRepeated(wf) = baseline.poolCount;

    idUsefulSamples(wf) = baseline.idUsefulSamples;
    valUsefulSamples(wf) = baseline.valUsefulSamples;

    NMSE_id_POMP200(wf) = baseline.NMSE_id;
    NMSE_val_POMP200(wf) = baseline.NMSE_val;
    NMSE_id_common171(wf) = common171.NMSE_id;
    NMSE_val_common171(wf) = common171.NMSE_val;

    delta_id(wf) = NMSE_id_common171(wf) - NMSE_id_POMP200(wf);
    delta_val(wf) = NMSE_val_common171(wf) - NMSE_val_POMP200(wf);

    supportPOMP200{wf} = baseline.support;
    coefficientsPOMP200{wf} = baseline.h;
    coefficientsPOMP200Norm{wf} = baseline.hNorm;
    colNormPOMP200Pool{wf} = baseline.colNorm;
    selectedRegressorsPOMP200{wf} = baseline.selectedPopulation;
    nmsePOMP200ByRank{wf} = baseline.nmseByRank;

    coefficientsCommon171{wf} = common171.h;
    coefficientsCommon171Norm{wf} = common171.hNorm;
    colNormCommon171{wf} = common171.colNorm;

    fprintf('Pool compositeall: %d before, %d after removeRepeated\n', ...
        initialPoolCount(wf), poolCountAfterRemoveRepeated(wf));
    fprintf('POMP200   ID %.6f dB | VAL %.6f dB\n', ...
        NMSE_id_POMP200(wf), NMSE_val_POMP200(wf));
    fprintf('Common171 ID %.6f dB | VAL %.6f dB\n', ...
        NMSE_id_common171(wf), NMSE_val_common171(wf));
    fprintf('Delta common-baseline ID %.6f dB | VAL %.6f dB\n', ...
        delta_id(wf), delta_val(wf));
end

summaryTable = table(waveformIndex, waveformFile, idStartUsed, ...
    rawIdSamplesUsed, idUsefulSamples, valStartUsed, valRawSamples, ...
    valUsefulSamples, initialPoolCount, poolCountAfterRemoveRepeated, ...
    NMSE_id_POMP200, NMSE_val_POMP200, NMSE_id_common171, ...
    NMSE_val_common171, delta_id, delta_val);

notWF6 = waveformIndex ~= 6;
summaryMeans = struct();
summaryMeans.mean_delta_id_including_WF6 = mean(delta_id, 'omitnan');
summaryMeans.mean_delta_id_excluding_WF6 = mean(delta_id(notWF6), 'omitnan');
summaryMeans.mean_delta_val_including_WF6 = mean(delta_val, 'omitnan');
summaryMeans.mean_delta_val_excluding_WF6 = mean(delta_val(notWF6), 'omitnan');

runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
outputCsv = fullfile(outputDir, sprintf( ...
    'common171_vs_pomp200_all8_%s_%s.csv', measurementTag, runStamp));
outputMat = strrep(outputCsv, '.csv', '.mat');

writetable(summaryTable, outputCsv);

configuration = struct();
configuration.inputPattern = inputPattern;
configuration.measurementDirName = measurementDirName;
configuration.measurementTag = measurementTag;
configuration.inputDir = inputDir;
configuration.commonModelCsv = commonModelCsv;
configuration.idStart = idStart;
configuration.rawIdSamples = rawIdSamples;
configuration.valStart = valStart;
configuration.valLength = valLength;
configuration.lambda = lambda;
configuration.alpha = alpha;
configuration.diagLoad = diagLoad;
configuration.Qpmax = Qpmax;
configuration.Qnmax = Qnmax;
configuration.edgeLoss = edgeLoss;
configuration.nRegPOMP200 = nRegPOMP200;
configuration.nExpectedCommon = nExpectedCommon;
configuration.expectedCompositePoolCount = expectedCompositePoolCount;
configuration.verbosePompIterations = verbosePompIterations;

windowsUsed = table(waveformIndex, waveformFile, idStartUsed, ...
    rawIdSamplesUsed, idUsefulSamples, valStartUsed, valRawSamples, ...
    valUsefulSamples);

save(outputMat, 'configuration', 'summaryTable', 'summaryMeans', ...
    'windowsUsed', 'idIndices', 'valIndices', 'supportPOMP200', ...
    'coefficientsPOMP200', 'coefficientsPOMP200Norm', ...
    'colNormPOMP200Pool', 'selectedRegressorsPOMP200', ...
    'nmsePOMP200ByRank', 'coefficientsCommon171', ...
    'coefficientsCommon171Norm', 'colNormCommon171', ...
    'commonRegressors', 'compositeConfig', 'commonConfig', '-v7.3');

fprintf('\n=== Final summary ===\n');
fprintf('Mean delta_id including WF6: %.6f dB\n', ...
    summaryMeans.mean_delta_id_including_WF6);
fprintf('Mean delta_id excluding WF6: %.6f dB\n', ...
    summaryMeans.mean_delta_id_excluding_WF6);
fprintf('Mean delta_val including WF6: %.6f dB\n', ...
    summaryMeans.mean_delta_val_including_WF6);
fprintf('Mean delta_val excluding WF6: %.6f dB\n', ...
    summaryMeans.mean_delta_val_excluding_WF6);
fprintf('\nSaved:\n  %s\n  %s\n', outputCsv, outputMat);

%% ===================== LOCAL FUNCTIONS =====================

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

function repoRoot = detectRepoRoot(startDir)
    repoRoot = startDir;
    while true
        hasGVG = exist(fullfile(repoRoot, 'modeling_benchmark', 'GVG', ...
            'Regressor.m'), 'file') == 2;
        hasResults = exist(fullfile(repoRoot, 'results'), 'dir') == 7;
        if hasGVG && hasResults
            return;
        end

        parentDir = fileparts(repoRoot);
        if strcmp(parentDir, repoRoot) || isempty(parentDir)
            error('Could not detect repo root from %s.', startDir);
        end
        repoRoot = parentDir;
    end
end

function csvPath = findCommonModelCsv(repoRoot, primaryRelativePath, fallbackRelativePath)
    candidates = { ...
        fullfile(repoRoot, primaryRelativePath), ...
        fullfile(repoRoot, fallbackRelativePath)};

    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            csvPath = candidates{i};
            return;
        end
    end

    error('Common model CSV not found. Checked:\n  %s\n  %s', ...
        candidates{1}, candidates{2});
end

function [x, y] = loadCenteredXY(sourcePath)
    data = load(sourcePath, 'x', 'y');
    x = data.x(:) - mean(data.x(:));
    y = data.y(:) - mean(data.y(:));
end

function GVGconfig = buildCompositeAllConfig(Qpmax, Qnmax, maxPopulation, lambda, alpha)
    GVGconfig = baseGVGConfig(Qpmax, Qnmax, maxPopulation, lambda, alpha);
    GVGconfig.inittype = 'compositeall';
end

function GVGconfig = buildFixedPopulationConfig(Qpmax, Qnmax, maxPopulation, lambda, alpha)
    GVGconfig = baseGVGConfig(Qpmax, Qnmax, maxPopulation, lambda, alpha);
    GVGconfig.inittype = 'noinit';
end

function GVGconfig = baseGVGConfig(Qpmax, Qnmax, maxPopulation, lambda, alpha)
    GVGconfig.Qpmax = Qpmax;
    GVGconfig.Qnmax = Qnmax;
    GVGconfig.Pmax = 13;
    GVGconfig.ngenerations = 1;
    GVGconfig.maxPopulation = maxPopulation;
    GVGconfig.evaluationtype = 'maxPopulation';
    GVGconfig.mutationrate = 0;
    GVGconfig.crossoverrate = 0;
    GVGconfig.verbosity = 0;
    GVGconfig.showPlots = false;
    GVGconfig.validate = false;
    GVGconfig.validatengen = 1;
    GVGconfig.storePopulation = false;
    GVGconfig.regPopulation = [];

    GVGconfig.DOMPtype = 'POMP';
    GVGconfig.lambda = lambda;
    GVGconfig.alpha = alpha;

    GVGconfig.Pmp = 13;
    GVGconfig.Mmp = 5;
    GVGconfig.Pfv = 13;
    GVGconfig.Mfv = 5;
    GVGconfig.Pcvs = 13;
    GVGconfig.Mcvs = 3;
    GVGconfig.Pddr = 13;
    GVGconfig.Mddr = 10;

    Pgmp = 13;
    Lgmp = 10;
    Mgmp = 2;
    GVGconfig.Ka = 0:(Pgmp - 1);
    GVGconfig.La = Lgmp * ones(size(GVGconfig.Ka));
    GVGconfig.Kb = 1:(Pgmp - 1);
    GVGconfig.Lb = Lgmp * ones(size(GVGconfig.Kb));
    GVGconfig.Mb = Mgmp * ones(size(GVGconfig.Kb));
    GVGconfig.Kc = 1:(Pgmp - 1);
    GVGconfig.Lc = Lgmp * ones(size(GVGconfig.Kc));
    GVGconfig.Mc = Mgmp * ones(size(GVGconfig.Kc));
end

function [xWin, yWin, idx] = extractRawWindow(x, y, startIndex, rawLength, label)
    if isempty(rawLength)
        rawLength = numel(x) - startIndex + 1;
    end

    if isempty(startIndex) || startIndex < 1 || startIndex ~= floor(startIndex)
        error('%s start index must be a positive integer.', label);
    end
    if rawLength <= 0 || rawLength ~= floor(rawLength)
        error('%s raw length must be a positive integer or [].', label);
    end

    idx = startIndex:(startIndex + rawLength - 1);
    if idx(end) > numel(x)
        error('%s window exceeds waveform length: last index %d > %d.', ...
            label, idx(end), numel(x));
    end

    xWin = x(idx);
    yWin = y(idx);
end

function baseline = fitCompositeAllPomp200(xIdRaw, yIdRaw, xValRaw, yValRaw, ...
    GVGconfig, nReg, alpha, lambda, diagLoad, verboseIterations)

    rManager = regressorManager(xIdRaw, yIdRaw, GVGconfig);
    rManager.initialization();
    baseline.initialPoolCount = numel(rManager.regPopulation);
    rManager.removerepeated();
    baseline.poolCount = numel(rManager.regPopulation);
    poolPopulation = cloneRegressorPopulation(rManager.regPopulation);

    if baseline.poolCount < nReg
        error('Composite pool has %d regressors, fewer than nReg=%d.', ...
            baseline.poolCount, nReg);
    end

    rManager.buildX();
    X_id = rManager.X;
    y_id = rManager.yX;
    rManager.clearRegressors();

    pomp = runPompTutorReference(X_id, y_id, nReg, alpha, lambda, ...
        diagLoad, verboseIterations);

    selectedPopulation = cloneRegressorPopulation(poolPopulation(pomp.support));
    [X_val, y_val] = buildMatrixWithRegressorManager(xValRaw, yValRaw, ...
        selectedPopulation, GVGconfig);

    yhat_id = X_id(:, pomp.support) * pomp.h;
    yhat_val = X_val * pomp.h;

    baseline.NMSE_id = calcNmseDb(y_id, yhat_id);
    baseline.NMSE_val = calcNmseDb(y_val, yhat_val);
    baseline.idUsefulSamples = numel(y_id);
    baseline.valUsefulSamples = numel(y_val);
    baseline.support = pomp.support;
    baseline.h = pomp.h;
    baseline.hNorm = pomp.hNorm;
    baseline.colNorm = pomp.colNorm;
    baseline.nmseByRank = pomp.nmseByRank;
    baseline.selectedPopulation = selectedPopulation;
end

function common171 = fitFixedCommon171(xIdRaw, yIdRaw, xValRaw, yValRaw, ...
    commonRegressors, GVGconfig, lambda, diagLoad)

    [X_id, y_id] = buildMatrixWithRegressorManager(xIdRaw, yIdRaw, ...
        commonRegressors, GVGconfig);
    [h, hNorm, colNorm] = fitFixedNormalizedRidge(X_id, y_id, ...
        lambda, diagLoad);

    [X_val, y_val] = buildMatrixWithRegressorManager(xValRaw, yValRaw, ...
        commonRegressors, GVGconfig);

    yhat_id = X_id * h;
    yhat_val = X_val * h;

    common171.NMSE_id = calcNmseDb(y_id, yhat_id);
    common171.NMSE_val = calcNmseDb(y_val, yhat_val);
    common171.idUsefulSamples = numel(y_id);
    common171.valUsefulSamples = numel(y_val);
    common171.h = h;
    common171.hNorm = hNorm;
    common171.colNorm = colNorm;
end

function result = runPompTutorReference(X, y, nReg, alpha, lambda, diagLoad, ...
    verboseIterations)

    y = y(:);
    [~, nCandidates] = size(X);
    nSelect = min(nReg, nCandidates);

    colNorm = vecnorm(X, 2, 1);
    badNorm = ~isfinite(colNorm) | colNorm == 0;
    if any(badNorm)
        error('Cannot normalize X: %d columns have zero or invalid norm.', ...
            nnz(badNorm));
    end

    Xn = bsxfun(@rdivide, X, colNorm);
    Zn = Xn;
    residual = y;
    support = zeros(1, nSelect);
    nmseByRank = NaN(nSelect, 1);

    for k = 1:nSelect
        corrScore = abs(Zn' * residual);
        if k > 1
            corrScore(support(1:k-1)) = 0;
        end
        [~, selected] = max(corrScore);
        support(k) = selected;

        Scur = support(1:k);
        hNormCur = ridgeOnNormalizedMatrix(Xn(:, Scur), y, lambda, diagLoad);
        hCur = hNormCur ./ colNorm(Scur).';
        yhatCur = X(:, Scur) * hCur;
        nmseByRank(k) = calcNmseDb(y, yhatCur);

        zSelected = Zn(:, selected);
        residual = residual - alpha * (zSelected * (zSelected' * residual));
        projection = Zn.' * conj(zSelected);
        Zn = Zn - alpha * (zSelected * projection.');

        znNorm = vecnorm(Zn, 2, 1);
        badZn = ~isfinite(znNorm) | znNorm == 0;
        znNorm(badZn) = 1;
        Zn = bsxfun(@rdivide, Zn, znNorm);

        if verboseIterations
            fprintf('%d | selected %d | reconstructed NMSE %.6f dB\n', ...
                k, selected, nmseByRank(k));
        end
    end

    hNorm = ridgeOnNormalizedMatrix(Xn(:, support), y, lambda, diagLoad);
    h = hNorm ./ colNorm(support).';

    result = struct();
    result.support = support;
    result.h = h;
    result.hNorm = hNorm;
    result.colNorm = colNorm;
    result.nmseByRank = nmseByRank;
end

function hNorm = ridgeOnNormalizedMatrix(XnSelected, y, lambda, diagLoad)
    nReg = size(XnSelected, 2);
    hNorm = (XnSelected' * XnSelected + ...
        (lambda + diagLoad) * eye(nReg)) \ (XnSelected' * y);
end

function [h, hNorm, colNorm] = fitFixedNormalizedRidge(X, y, lambda, diagLoad)
    y = y(:);
    colNorm = vecnorm(X, 2, 1);
    badNorm = ~isfinite(colNorm) | colNorm == 0;
    if any(badNorm)
        error('Cannot normalize X: %d columns have zero or invalid norm.', ...
            nnz(badNorm));
    end

    Xn = bsxfun(@rdivide, X, colNorm);
    nReg = size(Xn, 2);
    hNorm = (Xn' * Xn + (lambda + diagLoad) * eye(nReg)) \ (Xn' * y);
    h = hNorm ./ colNorm.';
end

function [Xmat, yAligned] = buildMatrixWithRegressorManager(xRaw, yRaw, ...
    regPopulation, baseConfig)

    GVGconfig = baseConfig;
    GVGconfig.regPopulation = cloneRegressorPopulation(regPopulation);
    GVGconfig.inittype = 'noinit';
    GVGconfig.maxPopulation = numel(regPopulation);
    GVGconfig.verbosity = 0;
    GVGconfig.showPlots = false;

    rManager = regressorManager(xRaw, yRaw, GVGconfig);
    rManager.initialization();
    rManager.buildX();
    Xmat = rManager.X;
    yAligned = rManager.yX;
    rManager.clearRegressors();
end

function clonedPopulation = cloneRegressorPopulation(regPopulation)
    clonedPopulation = [];
    for i = 1:numel(regPopulation)
        reg = regPopulation(i);
        cloned = Regressor(reg.X, reg.Xconj, reg.Xenv);
        cloned.score = reg.score;
        clonedPopulation = [clonedPopulation cloned]; %#ok<AGROW>
    end
end

function regPopulation = loadCommonRegressors(csvPath)
    T = readCsvTable(csvPath);
    keyColumn = firstExistingColumn(T, {'baseRegressorKey', 'regressorKey'});
    if isempty(keyColumn)
        error('CSV does not contain baseRegressorKey or regressorKey: %s', csvPath);
    end

    regPopulation = [];
    for i = 1:height(T)
        key = tableValue(T, keyColumn, i);
        [X, Xconj, Xenv] = parseRegressorKey(key);
        reg = Regressor(X, Xconj, Xenv);
        reg.sortindexes();
        regPopulation = [regPopulation reg]; %#ok<AGROW>
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
    tokens = regexp(key, 'X=([^;]*);Xconj=([^;]*);Xenv=(.*)$', ...
        'tokens', 'once');
    if isempty(tokens)
        error('Cannot parse regressor key: %s', key);
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

function value = calcNmseDb(y, yhat)
    value = 20 * log10(norm(y(:) - yhat(:), 2) / norm(y(:), 2));
end
