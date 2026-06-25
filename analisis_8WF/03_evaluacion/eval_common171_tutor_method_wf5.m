% Evaluate the fixed 171-regressor common model on WF5 using a tutor-like
% reconstructed NMSE methodology.
%
% This script does NOT extend the common model to 200 regressors. The common
% model is evaluated exactly with its 171 regressors because it comes from the
% structural commonality criterion across waveforms.
%
% Final metrics are reconstructed explicitly as:
%       20*log10(norm(y - X_original*h_desnormalized)/norm(y))
% using normalized-column ridge estimation and desnormalized coefficients.

clearvars;
clc;

%% ===================== USER CONFIG =====================

sourceFile = fullfile('results', 'ILC_8waveforms', ...
    'experiment20260429T190512_xy.mat');
commonModelCsvPrimary = fullfile('analisis_8WF', '02_modelo_comun', ...
    'common171_regressors.csv');
commonModelCsvFallback = fullfile('analisis_8WF', ...
    'modelo_general_composite_thr095_ge6_171_regresores.csv');

% Keep these windows identical to reproduce_tutor_composite_id10000_WF5.m.
% EDIT when the exact tutor id/validation windows are known.
idStart = 1;
rawIdSamples = 10100;
valStart = idStart + rawIdSamples;
valLength = 10100;  % Set [] to use from valStart to the end of the waveform.

lambda = 1e-5;
alpha = 1 / (1 + lambda); %#ok<NASGU> % Kept for reporting/method parity.
diagLoad = 1e-12;
Qpmax = 50;
Qnmax = 50;
edgeLoss = Qpmax + Qnmax;

NMSE_id_ref = -36.591918;
NMSE_val_ref = -35.887290;

%% ===================== MAIN LOGIC =====================

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

repoRoot = detectRepoRoot(scriptDir);

originalDir = pwd;
cleanupDir = onCleanup(@() cd(originalDir));
cd(repoRoot);

addpathIfExists(fullfile(repoRoot, 'modeling_benchmark'));
gvgDir = fullfile(repoRoot, 'modeling_benchmark', 'GVG');
if exist(gvgDir, 'dir')
    addpath(genpath(gvgDir));
end

outputDir = fullfile(repoRoot, 'results', 'common_composite_model_evaluation');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

data = load(fullfile(repoRoot, sourceFile), 'x', 'y');
x = data.x(:) - mean(data.x(:));
y = data.y(:) - mean(data.y(:));

[xIdRaw, yIdRaw, idxRaw] = extractRawWindow(x, y, idStart, rawIdSamples, ...
    'identification');
[xValRaw, yValRaw, idxValRaw] = extractRawWindow(x, y, valStart, valLength, ...
    'validation');

commonModelCsv = findCommonModelCsv(repoRoot, commonModelCsvPrimary, ...
    commonModelCsvFallback);
commonRegressors = loadCommonRegressors(commonModelCsv);
nCommonRegressors = numel(commonRegressors);

if nCommonRegressors ~= 171
    error('Expected exactly 171 common regressors, found %d.', nCommonRegressors);
end

GVGconfig = buildFixedPopulationConfig(Qpmax, Qnmax, nCommonRegressors, ...
    lambda, alpha);

[X_id, y_id] = buildMatrixWithRegressorManager(xIdRaw, yIdRaw, ...
    commonRegressors, GVGconfig);

if size(X_id, 1) ~= rawIdSamples - edgeLoss
    warning('ID useful samples are %d, expected rawIdSamples-edgeLoss=%d.', ...
        size(X_id, 1), rawIdSamples - edgeLoss);
end

[h, h_norm, colNorm] = fitFixedNormalizedRidge(X_id, y_id, lambda, diagLoad);
yhat_id = X_id * h;
NMSE_id_common171 = calcNmseDb(y_id, yhat_id);

[X_val, y_val] = buildMatrixWithRegressorManager(xValRaw, yValRaw, ...
    commonRegressors, GVGconfig);
yhat_val = X_val * h;
NMSE_val_common171 = calcNmseDb(y_val, yhat_val);

delta_id = NMSE_id_common171 - NMSE_id_ref;
delta_val = NMSE_val_common171 - NMSE_val_ref;

fprintf('Common 171 WF5 tutor-method evaluation\n');
fprintf('Source file: %s\n', sourceFile);
fprintf('Common model CSV: %s\n', commonModelCsv);
fprintf('ID raw window: start=%d, raw samples=%d, edgeLoss=%d\n', ...
    idStart, rawIdSamples, edgeLoss);
fprintf('Validation raw window: start=%d, raw samples=%d\n', ...
    valStart, numel(idxValRaw));
fprintf('nReg common model: %d\n', nCommonRegressors);
fprintf('ID useful samples:  %d\n', numel(y_id));
fprintf('VAL useful samples: %d\n', numel(y_val));
fprintf('\nTutor/compositeall POMP 200 reference:\n');
fprintf('  NMSE_id_ref:  %.6f dB\n', NMSE_id_ref);
fprintf('  NMSE_val_ref: %.6f dB\n', NMSE_val_ref);
fprintf('Common 171 reconstructed metrics:\n');
fprintf('  NMSE_id_common171:  %.6f dB (delta %.6f)\n', ...
    NMSE_id_common171, delta_id);
fprintf('  NMSE_val_common171: %.6f dB (delta %.6f)\n', ...
    NMSE_val_common171, delta_val);

runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
outputCsv = fullfile(outputDir, sprintf( ...
    'common171_tutor_method_WF5_%s.csv', runStamp));
outputMat = strrep(outputCsv, '.csv', '.mat');

summary = table({sourceFile}, {commonModelCsv}, idStart, rawIdSamples, ...
    numel(y_id), valStart, numel(idxValRaw), numel(y_val), Qpmax, Qnmax, ...
    edgeLoss, lambda, alpha, diagLoad, nCommonRegressors, ...
    NMSE_id_common171, NMSE_val_common171, NMSE_id_ref, NMSE_val_ref, ...
    delta_id, delta_val, {outputMat}, ...
    'VariableNames', {'sourceFile', 'commonModelCsv', 'idStart', ...
    'rawIdSamples', 'idUsefulSamples', 'valStart', 'valRawSamples', ...
    'valUsefulSamples', 'Qpmax', 'Qnmax', 'edgeLoss', 'lambda', ...
    'alpha', 'diagLoad', 'nRegCommon', 'NMSE_id_common171', ...
    'NMSE_val_common171', 'NMSE_id_ref', 'NMSE_val_ref', ...
    'delta_id', 'delta_val', 'outputMatFile'});

writetable(summary, outputCsv);

metrics = struct('NMSE_id_common171', NMSE_id_common171, ...
    'NMSE_val_common171', NMSE_val_common171, ...
    'NMSE_id_ref', NMSE_id_ref, 'NMSE_val_ref', NMSE_val_ref, ...
    'delta_id', delta_id, 'delta_val', delta_val);
windows = struct('idStart', idStart, 'rawIdSamples', rawIdSamples, ...
    'idxRaw', idxRaw, 'valStart', valStart, 'valLength', valLength, ...
    'idxValRaw', idxValRaw);

save(outputMat, 'h', 'h_norm', 'colNorm', 'commonRegressors', ...
    'GVGconfig', 'metrics', 'windows', 'summary', '-v7.3');

fprintf('\nSaved:\n  %s\n  %s\n', outputCsv, outputMat);

%% ===================== LOCAL FUNCTIONS =====================

function addpathIfExists(pathName)
    if ~isempty(pathName) && exist(pathName, 'dir')
        addpath(pathName);
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

function GVGconfig = buildFixedPopulationConfig(Qpmax, Qnmax, maxPopulation, lambda, alpha)
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
    GVGconfig.inittype = 'noinit';

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

function [Xmat, yAligned] = buildMatrixWithRegressorManager(xRaw, yRaw, regPopulation, baseConfig)
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
