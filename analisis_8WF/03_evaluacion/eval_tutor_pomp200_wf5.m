% Reproduce the tutor WF5 compositeall + POMP reference experiment.
%
% This script is intentionally separate from the 171-regressor common-model
% analysis. Here nReg = 200 is used only to reproduce the tutor baseline from
% the complete compositeall candidate pool.
%
% IMPORTANT:
% - Do not use rManager.nmse as the final metric here.
% - Final NMSE is reconstructed explicitly as:
%       20*log10(norm(y - X_original*h_desnormalized)/norm(y))
% - idStart, valStart and valLength are editable because the exact tutor
%   windows are not known from the repository scripts.

clearvars;
clc;

%% ===================== USER CONFIG =====================

sourceFile = fullfile('results', 'ILC_8waveforms', ...
    'experiment20260429T190512_xy.mat');

% EDIT if the tutor used a different raw identification window.
idStart = 1;
rawIdSamples = 10100;

% EDIT if the tutor used a different validation window.
% Current default uses the next 10100 raw samples after the ID window to avoid
% building a very large validation matrix by accident.
valStart = idStart + rawIdSamples;
valLength = 10100;  % Set [] to use from valStart to the end of the waveform.

lambda = 1e-5;
alpha = 1 / (1 + lambda);
diagLoad = 1e-12;
Qpmax = 50;
Qnmax = 50;
edgeLoss = Qpmax + Qnmax;
targetNReg = 200;
expectedPoolCount = 4249;

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

GVGconfig = buildCompositeAllConfig(Qpmax, Qnmax, targetNReg, lambda, alpha);

rManager = regressorManager(xIdRaw, yIdRaw, GVGconfig);
rManager.initialization();
initialPoolCount = numel(rManager.regPopulation);
rManager.removerepeated();
poolCount = numel(rManager.regPopulation);
poolPopulation = cloneRegressorPopulation(rManager.regPopulation);

fprintf('Tutor reproduction WF5 compositeall/POMP baseline\n');
fprintf('Source file: %s\n', sourceFile);
fprintf('ID raw window: start=%d, raw samples=%d, edgeLoss=%d\n', ...
    idStart, rawIdSamples, edgeLoss);
fprintf('Validation raw window: start=%d, raw samples=%d\n', ...
    valStart, numel(idxValRaw));
fprintf('Pool before removeRepeated: %d regressors\n', initialPoolCount);
fprintf('Pool after removeRepeated:  %d regressors (expected about %d)\n', ...
    poolCount, expectedPoolCount);

if poolCount < targetNReg
    error('Composite pool has %d regressors, fewer than targetNReg=%d.', ...
        poolCount, targetNReg);
end

if abs(poolCount - expectedPoolCount) > 25
    warning(['Composite pool count differs from the expected reference. ' ...
        'Check model configuration and local GVG code version.']);
end

rManager.buildX();
X_id = rManager.X;
y_id = rManager.yX;
rManager.clearRegressors();

if size(X_id, 1) ~= rawIdSamples - edgeLoss
    warning('ID useful samples are %d, expected rawIdSamples-edgeLoss=%d.', ...
        size(X_id, 1), rawIdSamples - edgeLoss);
end

pomp = runPompTutorReference(X_id, y_id, targetNReg, alpha, lambda, diagLoad);
S = pomp.support;
h = pomp.h;
h_norm = pomp.hNorm;
colNorm = pomp.colNorm;

yhat_id = X_id(:, S) * h;
NMSE_id = calcNmseDb(y_id, yhat_id);

selectedPopulation = cloneRegressorPopulation(poolPopulation(S));
[X_val, y_val] = buildMatrixWithRegressorManager(xValRaw, yValRaw, ...
    selectedPopulation, GVGconfig);
yhat_val = X_val * h;
NMSE_val = calcNmseDb(y_val, yhat_val);

delta_id = NMSE_id - NMSE_id_ref;
delta_val = NMSE_val - NMSE_val_ref;

fprintf('\nReference-compatible reconstructed metrics\n');
fprintf('nReg: %d\n', targetNReg);
fprintf('ID useful samples:  %d\n', numel(y_id));
fprintf('VAL useful samples: %d\n', numel(y_val));
fprintf('NMSE_id:  %.6f dB (ref %.6f, delta %.6f)\n', ...
    NMSE_id, NMSE_id_ref, delta_id);
fprintf('NMSE_val: %.6f dB (ref %.6f, delta %.6f)\n', ...
    NMSE_val, NMSE_val_ref, delta_val);

runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
outputCsv = fullfile(outputDir, sprintf( ...
    'reproduce_tutor_composite_id10000_WF5_%s.csv', runStamp));
outputMat = strrep(outputCsv, '.csv', '.mat');

summary = table({sourceFile}, idStart, rawIdSamples, numel(y_id), ...
    valStart, numel(idxValRaw), numel(y_val), Qpmax, Qnmax, edgeLoss, ...
    lambda, alpha, diagLoad, initialPoolCount, poolCount, ...
    expectedPoolCount, targetNReg, NMSE_id, NMSE_val, NMSE_id_ref, ...
    NMSE_val_ref, delta_id, delta_val, {outputMat}, ...
    'VariableNames', {'sourceFile', 'idStart', 'rawIdSamples', ...
    'idUsefulSamples', 'valStart', 'valRawSamples', 'valUsefulSamples', ...
    'Qpmax', 'Qnmax', 'edgeLoss', 'lambda', 'alpha', 'diagLoad', ...
    'initialPoolCount', 'poolCountAfterRemoveRepeated', ...
    'expectedPoolCount', 'nReg', 'NMSE_id', 'NMSE_val', 'NMSE_id_ref', ...
    'NMSE_val_ref', 'delta_id', 'delta_val', 'outputMatFile'});

writetable(summary, outputCsv);

metrics = struct('NMSE_id', NMSE_id, 'NMSE_val', NMSE_val, ...
    'NMSE_id_ref', NMSE_id_ref, 'NMSE_val_ref', NMSE_val_ref, ...
    'delta_id', delta_id, 'delta_val', delta_val);
windows = struct('idStart', idStart, 'rawIdSamples', rawIdSamples, ...
    'idxRaw', idxRaw, 'valStart', valStart, 'valLength', valLength, ...
    'idxValRaw', idxValRaw);

save(outputMat, 'S', 'h', 'h_norm', 'colNorm', 'poolPopulation', ...
    'selectedPopulation', 'GVGconfig', 'metrics', 'windows', ...
    'pomp', 'summary', '-v7.3');

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
            'regressorManager.m'), 'file') == 2;
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

function GVGconfig = buildCompositeAllConfig(Qpmax, Qnmax, maxPopulation, lambda, alpha)
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
    GVGconfig.inittype = 'compositeall';

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

function clonedPopulation = cloneRegressorPopulation(regPopulation)
    clonedPopulation = [];
    for i = 1:numel(regPopulation)
        reg = regPopulation(i);
        cloned = Regressor(reg.X, reg.Xconj, reg.Xenv);
        cloned.score = reg.score;
        clonedPopulation = [clonedPopulation cloned]; %#ok<AGROW>
    end
end

function result = runPompTutorReference(X, y, nReg, alpha, lambda, diagLoad)
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

        fprintf('%d | selected %d | reconstructed NMSE %.6f dB\n', ...
            k, selected, nmseByRank(k));
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

function value = calcNmseDb(y, yhat)
    value = 20 * log10(norm(y(:) - yhat(:), 2) / norm(y(:), 2));
end
