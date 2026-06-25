%% analyze_GVG_pairwise_common_structure_REF_WF_v2.m
% Pairwise common-structure analysis for GVG selected regressors.
%
% This version is intentionally simpler and more explicit than the previous
% script. The scientific logic is marked in the block:
%
%   ===================== MAIN LOGIC =====================
%
% Objective:
%   Use WF8 (100 MHz) as the base model and compare each WF8 regressor
%   against the selected regressors of every waveform, one waveform at a time.
%
% Method:
%   1) Exact match first.
%   2) If there is no exact match, evaluate all regressors on the SAME
%      reference realization x_ref, usually WF8.
%   3) Compute normalized complex correlation.
%   4) Classify the match as:
%        base              : same waveform as the base model
%        exact             : same mathematical regressor exists in target WF
%        correlated_clear  : few candidates above threshold; clean match
%        correlated_best   : many candidates, but one candidate clearly wins
%        redundant_support : several candidates above threshold; structure is
%                            covered, but there is no clean one-to-one match
%        no_match          : no candidate above threshold
%
% Important interpretation:
%   redundant_support COUNTS as structural support, but not as a clean
%   one-to-one equivalent. This avoids throwing away information just because
%   the regressor library is redundant.
%
% Outputs:
%   1) common_structure CSV: one row per WF8/base regressor.
%   2) matches_long CSV: one row per base regressor and target waveform.

clearvars;
clc;

%% ===================== USER SETTINGS =====================

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

repoRoot = detectRepoRoot(scriptDir);
runStamp = '20260615T182750';

baseWaveformIndex = 8;       % WF8 = base model, usually 100 MHz
referenceWaveformIndex = 8;  % WF8 = reference realization x_ref

% 0.99 = conservative; 0.98 = useful sensitivity analysis.
correlationThreshold = 0.95;

% If candidateCount <= maxClearCandidates, the correlated match is clean.
maxClearCandidates = 2;

% If there are many candidates, accept a clean best match only if the best
% correlation is sufficiently above the second best.
dominanceMargin = 0.005;

maxSamplesForReference = 20000;
rngSeed = 1004;

inputModelDir = fullfile(repoRoot, 'results', 'GVG_ILC_8waveforms');
inputXYDir    = fullfile(repoRoot, 'results', 'ILC_8waveforms');
outputDir     = fullfile(inputModelDir, sprintf( ...
    'pairwise_common_structure_v2_refWF%02d_baseWF%02d_thr%03d', ...
    referenceWaveformIndex, baseWaveformIndex, round(correlationThreshold * 1000)));

%% ===================== PATHS =====================

addpathIfExists(fullfile(repoRoot, 'toolbox'));
addpathIfExists(fullfile(repoRoot, 'toolbox_signalgen'));
addpathIfExists(fullfile(repoRoot, 'confset'));
addpathIfExists(fullfile(repoRoot, 'modeling_benchmark'));
if exist(fullfile(repoRoot, 'modeling_benchmark', 'GVG'), 'dir')
    addpath(genpath(fullfile(repoRoot, 'modeling_benchmark', 'GVG')));
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
rng(rngSeed);

%% ===================== LOAD SELECTED REGRESSORS =====================

modelFiles = dir(fullfile(inputModelDir, sprintf('experiment*_wf*_GVG_%s.mat', runStamp)));
[~, order] = sort({modelFiles.name});
modelFiles = modelFiles(order);

if isempty(modelFiles)
    error('No model files found in %s for runStamp %s.', inputModelDir, runStamp);
end

uniqueMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
uniqueRegs = struct('key', {}, 'text', {}, 'X', {}, 'Xconj', {}, 'Xenv', {}, ...
                    'totalOrder', {}, 'maxMemoryTap', {});
selectionRows = table();
modelInfo = struct('waveformIndex', {}, 'modelFile', {}, 'modelPath', {}, 'sourcePath', {});

fprintf('Reading selected GVG regressors...\n');

for k = 1:numel(modelFiles)
    modelPath = fullfile(modelFiles(k).folder, modelFiles(k).name);
    wfIndex = parseWaveformIndex(modelFiles(k).name);

    S = load(modelPath, 'rManager', 'sourcePath');
    sourcePath = resolveSourcePath(S, modelFiles(k).name, inputXYDir);

    modelInfo(k).waveformIndex = wfIndex;
    modelInfo(k).modelFile = string(modelFiles(k).name);
    modelInfo(k).modelPath = string(modelPath);
    modelInfo(k).sourcePath = string(sourcePath);

    regs = S.rManager.regPopulation;

    for ir = 1:numel(regs)
        regStruct = regressorToStruct(regs(ir));

        if ~isKey(uniqueMap, regStruct.key)
            uniqueMap(regStruct.key) = numel(uniqueRegs) + 1;
            uniqueRegs(end + 1) = regStruct; %#ok<SAGROW>
        end

        uniqueIndex = uniqueMap(regStruct.key);

        selectionRows = [selectionRows; table( ... 
            wfIndex, string(modelFiles(k).name), ir, uniqueIndex, ...
            string(regStruct.text), string(regStruct.key), ...
            regStruct.totalOrder, regStruct.maxMemoryTap, ...
            'VariableNames', {'waveformIndex','modelFile','selectedRank', ...
            'uniqueIndex','regressorText','regressorKey','totalOrder','maxMemoryTap'})]; %#ok<AGROW>
    end
end

waveformListAll = sort([modelInfo.waveformIndex]);
nWaveforms = numel(waveformListAll);
nUnique = numel(uniqueRegs);

fprintf('  Total selected regressors: %d\n', height(selectionRows));
fprintf('  Unique exact regressors:   %d\n', nUnique);

baseRows = selectionRows(selectionRows.waveformIndex == baseWaveformIndex, :);
baseRows = sortrows(baseRows, 'selectedRank', 'ascend');
refModelIdx = find([modelInfo.waveformIndex] == referenceWaveformIndex, 1);

if isempty(baseRows)
    error('Base waveform WF%02d was not found.', baseWaveformIndex);
end
if isempty(refModelIdx)
    error('Reference waveform WF%02d was not found.', referenceWaveformIndex);
end

%% ===================== BUILD CORRELATION ON ONE REFERENCE SIGNAL =====================

% This is the methodological correction: all regressors are evaluated on the
% same realization x_ref before computing correlations.

fprintf('\nBuilding regressor columns on WF%02d reference realization...\n', referenceWaveformIndex);

xData = load(char(modelInfo(refModelIdx).sourcePath), 'x');
xRef = xData.x(:);
xRef = xRef - mean(xRef);

[minTap, maxTap] = globalTapBounds(uniqueRegs);
validN = (1 + max(0, maxTap)):(numel(xRef) + min(0, minTap));

if numel(validN) > maxSamplesForReference
    n = sort(validN(randperm(numel(validN), maxSamplesForReference))).';
else
    n = validN(:);
end

Phi = complex(zeros(numel(n), nUnique, 'single'));

for iu = 1:nUnique
    col = evaluateRegressor(uniqueRegs(iu), xRef, n);
    Phi(:, iu) = single(col ./ norm(col));
end

R = double(abs(Phi' * Phi));
R(1:nUnique+1:end) = 1;

clear Phi xRef xData

fprintf('  Correlation matrix ready: %d unique regressors, %d samples.\n', nUnique, numel(n));

%% ===================== MAIN LOGIC =====================
% For each WF8/base regressor:
%   for each target waveform:
%       exact match first;
%       otherwise find correlated candidates on R;
%       classify as clean, best, redundant or missing;
%   summarize how many waveforms support that base regressor.

matchRows = table();
summaryRows = table();

for ib = 1:height(baseRows)
    baseUniqueIdx = baseRows.uniqueIndex(ib);
    baseReg = uniqueRegs(baseUniqueIdx);

    supportWfs = [];
    strongSupportWfs = [];
    exactWfs = [];
    correlatedClearWfs = [];
    correlatedBestWfs = [];
    redundantSupportWfs = [];
    missingWfs = [];
    corrAccepted = [];
    perWfSummary = strings(0, 1);

    for targetWf = waveformListAll
        targetRows = selectionRows(selectionRows.waveformIndex == targetWf, :);
        targetRows = sortrows(targetRows, 'selectedRank', 'ascend');

        if targetWf == baseWaveformIndex
            result = makeBaseResult(baseReg, baseRows.selectedRank(ib), baseUniqueIdx);
        else
            result = matchOneBaseRegressor(baseUniqueIdx, baseReg, targetRows, uniqueRegs, R, ...
                correlationThreshold, maxClearCandidates, dominanceMargin);
        end

        if result.structuralSupport
            supportWfs(end + 1) = targetWf; %#ok<SAGROW>
        else
            missingWfs(end + 1) = targetWf; %#ok<SAGROW>
        end

        if result.oneToOneSupport
            strongSupportWfs(end + 1) = targetWf; %#ok<SAGROW>
        end

        switch result.matchType
            case {"base", "exact"}
                exactWfs(end + 1) = targetWf; %#ok<SAGROW>
            case "correlated_clear"
                correlatedClearWfs(end + 1) = targetWf; %#ok<SAGROW>
                corrAccepted(end + 1) = result.bestCorr; %#ok<SAGROW>
            case "correlated_best"
                correlatedBestWfs(end + 1) = targetWf; %#ok<SAGROW>
                corrAccepted(end + 1) = result.bestCorr; %#ok<SAGROW>
            case "redundant_support"
                redundantSupportWfs(end + 1) = targetWf; %#ok<SAGROW>
                corrAccepted(end + 1) = result.bestCorr; %#ok<SAGROW>
        end

        perWfSummary(end + 1) = sprintf('WF%02d:%s best=%.4f cand=%d -> %s', ...
            targetWf, result.matchType, result.bestCorr, result.candidateCount, char(result.matchedText)); %#ok<SAGROW>

        matchRows = [matchRows; table( ... 
            baseWaveformIndex, referenceWaveformIndex, correlationThreshold, ...
            baseRows.selectedRank(ib), baseUniqueIdx, string(baseReg.text), string(baseReg.key), ...
            baseReg.totalOrder, baseReg.maxMemoryTap, ...
            targetWf, string(result.matchType), result.structuralSupport, result.oneToOneSupport, ...
            result.bestCorr, result.secondBestCorr, result.bestMinusSecond, result.candidateCount, ...
            result.matchedRank, result.matchedUniqueIdx, string(result.matchedText), ...
            string(result.topCandidateRegressors), string(result.topCandidateCorrelations), ...
            'VariableNames', {'baseWaveformIndex','referenceWaveformIndex','correlationThreshold', ...
            'baseSelectedRank','baseUniqueIndex','baseRegressor','baseRegressorKey', ...
            'baseTotalOrder','baseMaxMemoryTap','targetWaveformIndex','matchType', ...
            'structuralSupport','oneToOneSupport','bestCorrelationOnReference', ...
            'secondBestCorrelationOnReference','bestMinusSecondCorrelation', ...
            'candidateCountAboveThreshold','matchedTargetRank','matchedTargetUniqueIndex', ...
            'matchedTargetRegressor','topCandidateRegressors','topCandidateCorrelations'})]; %#ok<AGROW>
    end

    supportWfs = unique(supportWfs);
    strongSupportWfs = unique(strongSupportWfs);
    exactWfs = unique(exactWfs);
    correlatedClearWfs = unique(correlatedClearWfs);
    correlatedBestWfs = unique(correlatedBestWfs);
    redundantSupportWfs = unique(redundantSupportWfs);
    missingWfs = unique(missingWfs);

    if isempty(corrAccepted)
        minCorr = NaN; meanCorr = NaN; maxCorr = NaN;
    else
        minCorr = min(corrAccepted);
        meanCorr = mean(corrAccepted);
        maxCorr = max(corrAccepted);
    end

    summaryRows = [summaryRows; table( ... 
        baseWaveformIndex, referenceWaveformIndex, correlationThreshold, ...
        baseRows.selectedRank(ib), baseUniqueIdx, string(baseReg.text), string(baseReg.key), ...
        baseReg.totalOrder, baseReg.maxMemoryTap, ...
        numel(supportWfs), 100 * numel(supportWfs) / nWaveforms, ...
        numel(strongSupportWfs), 100 * numel(strongSupportWfs) / nWaveforms, ...
        numel(exactWfs), numel(correlatedClearWfs), numel(correlatedBestWfs), ...
        numel(redundantSupportWfs), numel(missingWfs), ...
        string(vectorToText(supportWfs)), string(vectorToText(strongSupportWfs)), ...
        string(vectorToText(exactWfs)), string(vectorToText(correlatedClearWfs)), ...
        string(vectorToText(correlatedBestWfs)), string(vectorToText(redundantSupportWfs)), ...
        string(vectorToText(missingWfs)), minCorr, meanCorr, maxCorr, ...
        string(strjoin(perWfSummary, ' | ')), ...
        'VariableNames', {'baseWaveformIndex','referenceWaveformIndex','correlationThreshold', ...
        'baseSelectedRank','baseUniqueIndex','baseRegressor','baseRegressorKey', ...
        'baseTotalOrder','baseMaxMemoryTap','structuralSupportWaveformCount', ...
        'structuralSupportPercent','oneToOneSupportWaveformCount','oneToOneSupportPercent', ...
        'exactWaveformCount','correlatedClearWaveformCount','correlatedBestWaveformCount', ...
        'redundantSupportWaveformCount','missingWaveformCount','structuralSupportWaveformList', ...
        'oneToOneSupportWaveformList','exactWaveformList','correlatedClearWaveformList', ...
        'correlatedBestWaveformList','redundantSupportWaveformList','missingWaveformList', ...
        'minAcceptedCorrelation','meanAcceptedCorrelation','maxAcceptedCorrelation', ...
        'perWaveformMatchSummary'})]; %#ok<AGROW>
end

summaryRows = sortrows(summaryRows, ...
    {'structuralSupportWaveformCount','oneToOneSupportWaveformCount','exactWaveformCount','baseSelectedRank'}, ...
    {'descend','descend','descend','ascend'});

%% ===================== EXPORT =====================

thresholdTag = sprintf('thr%03d', round(correlationThreshold * 1000));

summaryCsv = fullfile(outputDir, sprintf( ...
    'GVG_pairwise_v2_refWF%02d_baseWF%02d_common_structure_%s_%s.csv', ...
    referenceWaveformIndex, baseWaveformIndex, thresholdTag, runStamp));

matchesCsv = fullfile(outputDir, sprintf( ...
    'GVG_pairwise_v2_refWF%02d_baseWF%02d_matches_long_%s_%s.csv', ...
    referenceWaveformIndex, baseWaveformIndex, thresholdTag, runStamp));

writetable(summaryRows, summaryCsv);
writetable(matchRows, matchesCsv);

fprintf('\nDone. Written:\n');
fprintf('  %s\n', summaryCsv);
fprintf('  %s\n', matchesCsv);

%% ===================== LOCAL FUNCTIONS =====================

function result = makeBaseResult(baseReg, rank, uniqueIdx)
    result.matchType = "base";
    result.structuralSupport = true;
    result.oneToOneSupport = true;
    result.bestCorr = 1;
    result.secondBestCorr = NaN;
    result.bestMinusSecond = NaN;
    result.candidateCount = 1;
    result.matchedRank = rank;
    result.matchedUniqueIdx = uniqueIdx;
    result.matchedText = string(baseReg.text);
    result.topCandidateRegressors = string(baseReg.text);
    result.topCandidateCorrelations = "1";
end

function result = matchOneBaseRegressor(baseUniqueIdx, baseReg, targetRows, uniqueRegs, R, threshold, maxClearCandidates, dominanceMargin)
    exactRows = find(targetRows.uniqueIndex == baseUniqueIdx);

    if ~isempty(exactRows)
        result.matchType = "exact";
        result.structuralSupport = true;
        result.oneToOneSupport = true;
        result.bestCorr = 1;
        result.secondBestCorr = NaN;
        result.bestMinusSecond = NaN;
        result.candidateCount = numel(exactRows);
        result.matchedRank = targetRows.selectedRank(exactRows(1));
        result.matchedUniqueIdx = baseUniqueIdx;
        result.matchedText = string(baseReg.text);
        result.topCandidateRegressors = string(baseReg.text);
        result.topCandidateCorrelations = "1";
        return;
    end

    targetUnique = targetRows.uniqueIndex;
    corrVals = R(baseUniqueIdx, targetUnique).';
    [sortedCorrs, order] = sort(corrVals, 'descend');
    sortedUnique = targetUnique(order);
    sortedRanks = targetRows.selectedRank(order);

    candidateCount = sum(sortedCorrs >= threshold);
    bestCorr = sortedCorrs(1);
    if numel(sortedCorrs) >= 2
        secondBest = sortedCorrs(2);
        bestMinusSecond = bestCorr - secondBest;
    else
        secondBest = NaN;
        bestMinusSecond = NaN;
    end

    nTop = min(5, numel(sortedCorrs));
    topTexts = strings(nTop, 1);
    topCorrs = strings(nTop, 1);
    for i = 1:nTop
        topTexts(i) = string(uniqueRegs(sortedUnique(i)).text);
        topCorrs(i) = sprintf('%.6f', sortedCorrs(i));
    end

    result.bestCorr = bestCorr;
    result.secondBestCorr = secondBest;
    result.bestMinusSecond = bestMinusSecond;
    result.candidateCount = candidateCount;
    result.matchedRank = sortedRanks(1);
    result.matchedUniqueIdx = sortedUnique(1);
    result.matchedText = string(uniqueRegs(sortedUnique(1)).text);
    result.topCandidateRegressors = strjoin(topTexts, ' ; ');
    result.topCandidateCorrelations = strjoin(topCorrs, ' ; ');

    if candidateCount == 0
        result.matchType = "no_match";
        result.structuralSupport = false;
        result.oneToOneSupport = false;
    elseif candidateCount <= maxClearCandidates
        result.matchType = "correlated_clear";
        result.structuralSupport = true;
        result.oneToOneSupport = true;
    elseif bestMinusSecond >= dominanceMargin
        result.matchType = "correlated_best";
        result.structuralSupport = true;
        result.oneToOneSupport = true;
    else
        result.matchType = "redundant_support";
        result.structuralSupport = true;
        result.oneToOneSupport = false;
    end
end

function addpathIfExists(pathName)
    if exist(pathName, 'dir')
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

function wfIndex = parseWaveformIndex(fileName)
    tokens = regexp(fileName, '_wf(\d+)_', 'tokens', 'once');
    wfIndex = str2double(tokens{1});
end

function sourcePath = resolveSourcePath(S, modelFileName, inputXYDir)
    if isfield(S, 'sourcePath') && exist(char(S.sourcePath), 'file')
        sourcePath = char(S.sourcePath);
    else
        sourceName = regexprep(modelFileName, '_wf\d+_GVG_\d{8}T\d{6}\.mat$', '.mat');
        sourcePath = fullfile(inputXYDir, sourceName);
    end
end

function regStruct = regressorToStruct(reg)
    X = sort(reg.X(:).');
    Xconj = sort(reg.Xconj(:).');
    Xenv = sort(reg.Xenv(:).');

    key = sprintf('X:%s|Xconj:%s|Xenv:%s', vectorToText(X), vectorToText(Xconj), vectorToText(Xenv));

    try
        text = strtrim(reg.print());
    catch
        text = key;
    end

    regStruct.key = key;
    regStruct.text = text;
    regStruct.X = X;
    regStruct.Xconj = Xconj;
    regStruct.Xenv = Xenv;
    regStruct.totalOrder = numel(X) + numel(Xconj) + numel(Xenv);
    regStruct.maxMemoryTap = max(abs([X(:); Xconj(:); Xenv(:); 0]));
end

function [minTap, maxTap] = globalTapBounds(uniqueRegs)
    taps = [];
    for i = 1:numel(uniqueRegs)
        taps = [taps; uniqueRegs(i).X(:); uniqueRegs(i).Xconj(:); uniqueRegs(i).Xenv(:)]; %#ok<AGROW>
    end
    minTap = min([taps; 0]);
    maxTap = max([taps; 0]);
end

function col = evaluateRegressor(regStruct, x, n)
    n = n(:);
    col = ones(numel(n), 1);

    for i = 1:numel(regStruct.X)
        col = col .* x(n - regStruct.X(i));
    end
    for i = 1:numel(regStruct.Xconj)
        col = col .* conj(x(n - regStruct.Xconj(i)));
    end
    for i = 1:numel(regStruct.Xenv)
        col = col .* abs(x(n - regStruct.Xenv(i)));
    end
end

function txt = vectorToText(v)
    if isempty(v)
        txt = '[]';
        return;
    end
    v = v(:).';
    parts = strings(1, numel(v));
    for i = 1:numel(v)
        parts(i) = sprintf('%g', v(i));
    end
    txt = ['[', char(strjoin(parts, ' ')), ']'];
end
