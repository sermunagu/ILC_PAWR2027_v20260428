% Pairwise common-structure analysis for compositeall-selected regressors.
% Reference/base waveform: WF8. No GVG evolution and no global clustering.

clearvars;
clc;

baseWaveformIndex = 8;
referenceWaveformIndex = 8;
thresholds = [0.98 0.97 0.96 0.95];
dominanceMargin = 0.005;
maxClearCandidates = 2;
perc = 0.04;
useReferenceSelIndices = true;

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

originalDir = pwd;
cleanupDir = onCleanup(@() cd(originalDir));
cd(repoRoot);

addpathIfExists(fullfile(repoRoot, 'modeling_benchmark'));
gvgDir = fullfile(repoRoot, 'modeling_benchmark', 'GVG');
if exist(gvgDir, 'dir')
    addpath(genpath(gvgDir));
end

%% ===================== MAIN LOGIC =====================

inputDir = getCfgField(pipelineCfg, 'waveformInputDir', ...
    fullfile(repoRoot, 'results', measurementDirName));
compositeDir = getCfgField(pipelineCfg, 'compositeResultsDir', ...
    fullfile(repoRoot, 'results', ['composite_selection_' measurementTag]));
outputDir = fullfile(compositeDir, 'pairwise_common_structure');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

modelFiles = selectLatestCompositeModelFiles(compositeDir);
models = loadCompositeModels(modelFiles, inputDir);

referenceSourcePath = models{referenceWaveformIndex}.sourcePath;
[xRefFull, yRefFull] = loadReferenceXY(referenceSourcePath);
xRefFull = xRefFull(:) - mean(xRefFull(:));
yRefFull = yRefFull(:) - mean(yRefFull(:));

if useReferenceSelIndices
    refIndices = sel_indices(xRefFull, yRefFull, perc);
    xRef = xRefFull(refIndices);
else
    refIndices = (1:numel(xRefFull)).';
    xRef = xRefFull;
end

Qpmax = models{baseWaveformIndex}.Qpmax;
Qnmax = models{baseWaveformIndex}.Qnmax;
baseInfo = makeRegressorInfo(models{baseWaveformIndex}.regPopulation);
baseMatrix = buildRegressorMatrix(models{baseWaveformIndex}.regPopulation, xRef, Qpmax, Qnmax);
baseNorms = columnNorms(baseMatrix);

compareInfos = cell(8, 1);
corrMatrices = cell(8, 1);
for wf = 1:8
    compareInfos{wf} = makeRegressorInfo(models{wf}.regPopulation);
    compareMatrix = buildRegressorMatrix(models{wf}.regPopulation, xRef, Qpmax, Qnmax);
    corrMatrices{wf} = normalizedCorrelationMatrix(baseMatrix, baseNorms, ...
        compareMatrix, columnNorms(compareMatrix));
end
clear baseMatrix compareMatrix

runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
thresholdSummary = initializeThresholdSummary(numel(thresholds));

for iThr = 1:numel(thresholds)
    threshold = thresholds(iThr);
    [commonTable, matchesLongTable] = analyzeThreshold(threshold, baseInfo, ...
        compareInfos, corrMatrices, baseWaveformIndex, dominanceMargin, ...
        maxClearCandidates);

    thresholdSummary(iThr, :) = summarizeThreshold(threshold, commonTable, matchesLongTable);

    thrTag = thresholdTag(threshold);
    commonCsv = fullfile(outputDir, sprintf( ...
        'composite_pairwise_refWF%02d_baseWF%02d_common_structure_%s_%s.csv', ...
        referenceWaveformIndex, baseWaveformIndex, thrTag, runStamp));
    matchesCsv = fullfile(outputDir, sprintf( ...
        'composite_pairwise_refWF%02d_baseWF%02d_matches_long_%s_%s.csv', ...
        referenceWaveformIndex, baseWaveformIndex, thrTag, runStamp));

    writetable(commonTable, commonCsv);
    writetable(matchesLongTable, matchesCsv);
end

summaryCsv = fullfile(outputDir, sprintf( ...
    'composite_pairwise_threshold_summary_%s.csv', runStamp));
writetable(thresholdSummary, summaryCsv);

fprintf('\nPairwise composite common-structure CSVs written to:\n  %s\n', outputDir);

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

function modelFiles = selectLatestCompositeModelFiles(compositeDir)
    files = dir(fullfile(compositeDir, 'experiment*_wf*_composite_selection_*.mat'));
    modelFiles = cell(8, 1);

    for wf = 1:8
        wfTag = sprintf('_wf%02d_', wf);
        isThisWaveform = false(numel(files), 1);
        for iFile = 1:numel(files)
            isThisWaveform(iFile) = ~isempty(strfind(files(iFile).name, wfTag)); %#ok<STREMP>
        end

        candidates = files(isThisWaveform);
        if isempty(candidates)
            error('No composite .mat file found for WF%02d in %s.', wf, compositeDir);
        end

        [~, latestIndex] = max([candidates.datenum]);
        modelFiles{wf} = fullfile(candidates(latestIndex).folder, candidates(latestIndex).name);
    end
end

function models = loadCompositeModels(modelFiles, inputDir)
    models = cell(8, 1);

    for wf = 1:8
        S = load(modelFiles{wf}, 'rManager', 'GVGconfig', 'sourcePath');

        if isfield(S, 'rManager')
            regPopulation = S.rManager.regPopulation;
            Qpmax = S.rManager.Qpmax;
            Qnmax = S.rManager.Qnmax;
        elseif isfield(S, 'regPopulation')
            regPopulation = S.regPopulation;
            Qpmax = S.GVGconfig.Qpmax;
            Qnmax = S.GVGconfig.Qnmax;
        else
            error('Composite file lacks rManager/regPopulation: %s.', modelFiles{wf});
        end

        if isfield(S, 'sourcePath') && exist(S.sourcePath, 'file')
            sourcePath = S.sourcePath;
        else
            sourcePath = inferSourcePathFromModelFile(modelFiles{wf}, inputDir);
        end

        models{wf} = struct('file', modelFiles{wf}, ...
            'regPopulation', regPopulation, ...
            'Qpmax', Qpmax, ...
            'Qnmax', Qnmax, ...
            'sourcePath', sourcePath);
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

function [x, y] = loadReferenceXY(sourcePath)
    if ~exist(sourcePath, 'file')
        error('Reference source file not found: %s.', sourcePath);
    end
    S = load(sourcePath, 'x', 'y');
    x = S.x;
    y = S.y;
end

function info = makeRegressorInfo(regPopulation)
    nRegs = numel(regPopulation);
    info.rank = (1:nRegs).';
    info.key = cell(nRegs, 1);
    info.text = cell(nRegs, 1);
    info.totalOrder = zeros(nRegs, 1);
    info.maxMemoryTap = zeros(nRegs, 1);

    for iReg = 1:nRegs
        reg = regPopulation(iReg);
        taps = [reg.X(:).' reg.Xconj(:).' reg.Xenv(:).'];
        info.key{iReg} = makeRegressorKey(reg);
        info.text{iReg} = strtrim(reg.print());
        info.totalOrder(iReg) = numel(reg.X) + numel(reg.Xconj) + numel(reg.Xenv);
        if isempty(taps)
            info.maxMemoryTap(iReg) = 0;
        else
            info.maxMemoryTap(iReg) = max(abs(taps));
        end
    end
end

function U = buildRegressorMatrix(regPopulation, x, Qpmax, Qnmax)
    nRegs = numel(regPopulation);
    N = numel(x);
    n = [N-Qpmax+1:N, 1:N, 1:Qnmax].';
    U = complex(zeros(N, nRegs));

    for iReg = 1:nRegs
        U(:, iReg) = evaluateRegressorOnX(regPopulation(iReg), x, n, Qpmax, Qnmax);
    end
end

function u = evaluateRegressorOnX(reg, x, n, Qpmax, Qnmax)
    u = ones(size(n(1+Qpmax:end-Qnmax)));

    for i = 1:numel(reg.X)
        tap = reg.X(i);
        u = u .* x(n(1+Qpmax-tap:end-Qnmax-tap));
    end

    for i = 1:numel(reg.Xconj)
        tap = reg.Xconj(i);
        u = u .* conj(x(n(1+Qpmax-tap:end-Qnmax-tap)));
    end

    for i = 1:numel(reg.Xenv)
        tap = reg.Xenv(i);
        u = u .* abs(x(n(1+Qpmax-tap:end-Qnmax-tap)));
    end
end

function norms = columnNorms(U)
    norms = sqrt(sum(abs(U).^2, 1));
    norms(norms == 0) = NaN;
end

function C = normalizedCorrelationMatrix(baseMatrix, baseNorms, compareMatrix, compareNorms)
    denom = baseNorms(:) * compareNorms(:).';
    C = abs(baseMatrix' * compareMatrix) ./ denom;
    C(~isfinite(C)) = 0;
    C(C > 1) = 1;
end

function [commonTable, matchesLongTable] = analyzeThreshold(threshold, baseInfo, ...
    compareInfos, corrMatrices, baseWaveformIndex, dominanceMargin, maxClearCandidates)

    nBase = numel(baseInfo.rank);
    nWaveforms = numel(compareInfos);
    nRows = nBase * nWaveforms;

    baseRank = NaN(nRows, 1);
    baseRegressorText = cell(nRows, 1);
    compareWaveformIndex = NaN(nRows, 1);
    matchType = cell(nRows, 1);
    matchedRegressorText = cell(nRows, 1);
    matchedRank = NaN(nRows, 1);
    bestCorrelation = NaN(nRows, 1);
    secondBestCorrelation = NaN(nRows, 1);
    nCandidatesAboveThreshold = NaN(nRows, 1);
    candidateRegressorsShort = cell(nRows, 1);

    row = 0;
    for iBase = 1:nBase
        for wf = 1:nWaveforms
            row = row + 1;
            result = classifyPair(iBase, wf, threshold, baseInfo, compareInfos{wf}, ...
                corrMatrices{wf}, baseWaveformIndex, dominanceMargin, maxClearCandidates);

            baseRank(row) = baseInfo.rank(iBase);
            baseRegressorText{row} = baseInfo.text{iBase};
            compareWaveformIndex(row) = wf;
            matchType{row} = result.matchType;
            matchedRegressorText{row} = result.matchedRegressorText;
            matchedRank(row) = result.matchedRank;
            bestCorrelation(row) = result.bestCorrelation;
            secondBestCorrelation(row) = result.secondBestCorrelation;
            nCandidatesAboveThreshold(row) = result.nCandidatesAboveThreshold;
            candidateRegressorsShort{row} = result.candidateRegressorsShort;
        end
    end

    matchesLongTable = table(baseRank, baseRegressorText, compareWaveformIndex, ...
        matchType, matchedRegressorText, matchedRank, bestCorrelation, ...
        secondBestCorrelation, nCandidatesAboveThreshold, candidateRegressorsShort);

    commonTable = buildCommonTable(matchesLongTable, baseInfo);
end

function result = classifyPair(iBase, wf, threshold, baseInfo, compareInfo, ...
    corrMatrix, baseWaveformIndex, dominanceMargin, maxClearCandidates)

    result = struct('matchType', '', ...
        'matchedRegressorText', '', ...
        'matchedRank', NaN, ...
        'bestCorrelation', NaN, ...
        'secondBestCorrelation', NaN, ...
        'nCandidatesAboveThreshold', NaN, ...
        'candidateRegressorsShort', '');

    if wf == baseWaveformIndex
        result.matchType = 'base';
        result.matchedRegressorText = baseInfo.text{iBase};
        result.matchedRank = baseInfo.rank(iBase);
        result.bestCorrelation = 1;
        result.nCandidatesAboveThreshold = 1;
        result.candidateRegressorsShort = sprintf('#%d %.4f %s', ...
            baseInfo.rank(iBase), 1, shortenText(baseInfo.text{iBase}, 100));
        return;
    end

    exactIdx = find(strcmp(compareInfo.key, baseInfo.key{iBase}), 1, 'first');
    if ~isempty(exactIdx)
        result.matchType = 'exact';
        result.matchedRegressorText = compareInfo.text{exactIdx};
        result.matchedRank = compareInfo.rank(exactIdx);
        result.bestCorrelation = 1;
        result.nCandidatesAboveThreshold = 1;
        result.candidateRegressorsShort = sprintf('#%d exact %s', ...
            compareInfo.rank(exactIdx), shortenText(compareInfo.text{exactIdx}, 100));
        return;
    end

    correlations = corrMatrix(iBase, :);
    [sortedCorr, sortedIdx] = sort(correlations, 'descend');
    highIdx = find(correlations >= threshold);

    result.bestCorrelation = sortedCorr(1);
    if numel(sortedCorr) >= 2
        result.secondBestCorrelation = sortedCorr(2);
    end
    result.nCandidatesAboveThreshold = numel(highIdx);

    if isempty(highIdx)
        result.matchType = 'no_match';
        result.candidateRegressorsShort = candidateSummary(compareInfo, sortedIdx, sortedCorr, 3);
        return;
    end

    bestIdx = sortedIdx(1);
    result.matchedRegressorText = compareInfo.text{bestIdx};
    result.matchedRank = compareInfo.rank(bestIdx);
    result.candidateRegressorsShort = candidateSummary(compareInfo, sortedIdx(1:numel(highIdx)), ...
        sortedCorr(1:numel(highIdx)), 5);

    if numel(highIdx) <= maxClearCandidates
        result.matchType = 'correlated_clear';
    elseif sortedCorr(1) - sortedCorr(2) >= dominanceMargin
        result.matchType = 'correlated_best';
    else
        result.matchType = 'redundant_support';
    end
end

function commonTable = buildCommonTable(matchesLongTable, baseInfo)
    nBase = numel(baseInfo.rank);

    baseRank = baseInfo.rank;
    baseRegressorText = baseInfo.text;
    baseRegressorKey = baseInfo.key;
    baseTotalOrder = baseInfo.totalOrder;
    baseMaxMemoryTap = baseInfo.maxMemoryTap;
    structuralSupportWaveformCount = zeros(nBase, 1);
    structuralSupportFraction = zeros(nBase, 1);
    oneToOneSupportWaveformCount = zeros(nBase, 1);
    oneToOneSupportFraction = zeros(nBase, 1);
    exactCount = zeros(nBase, 1);
    correlatedClearCount = zeros(nBase, 1);
    correlatedBestCount = zeros(nBase, 1);
    redundantSupportCount = zeros(nBase, 1);
    noMatchCount = zeros(nBase, 1);
    supportWaveformList = cell(nBase, 1);
    oneToOneWaveformList = cell(nBase, 1);

    structuralTypes = {'base', 'exact', 'correlated_clear', 'correlated_best', 'redundant_support'};
    oneToOneTypes = {'base', 'exact', 'correlated_clear', 'correlated_best'};
    nWaveforms = numel(unique(matchesLongTable.compareWaveformIndex));

    for iBase = 1:nBase
        rows = matchesLongTable.baseRank == baseRank(iBase);
        types = matchesLongTable.matchType(rows);
        waveforms = matchesLongTable.compareWaveformIndex(rows);

        structuralMask = ismember(types, structuralTypes);
        oneToOneMask = ismember(types, oneToOneTypes);

        structuralSupportWaveformCount(iBase) = sum(structuralMask);
        oneToOneSupportWaveformCount(iBase) = sum(oneToOneMask);
        structuralSupportFraction(iBase) = structuralSupportWaveformCount(iBase) / nWaveforms;
        oneToOneSupportFraction(iBase) = oneToOneSupportWaveformCount(iBase) / nWaveforms;

        exactCount(iBase) = sum(strcmp(types, 'exact'));
        correlatedClearCount(iBase) = sum(strcmp(types, 'correlated_clear'));
        correlatedBestCount(iBase) = sum(strcmp(types, 'correlated_best'));
        redundantSupportCount(iBase) = sum(strcmp(types, 'redundant_support'));
        noMatchCount(iBase) = sum(strcmp(types, 'no_match'));

        supportWaveformList{iBase} = waveformList(waveforms(structuralMask));
        oneToOneWaveformList{iBase} = waveformList(waveforms(oneToOneMask));
    end

    commonTable = table(baseRank, baseRegressorText, baseRegressorKey, ...
        baseTotalOrder, baseMaxMemoryTap, structuralSupportWaveformCount, ...
        structuralSupportFraction, oneToOneSupportWaveformCount, ...
        oneToOneSupportFraction, exactCount, correlatedClearCount, ...
        correlatedBestCount, redundantSupportCount, noMatchCount, ...
        supportWaveformList, oneToOneWaveformList);

    commonTable = sortrows(commonTable, ...
        {'structuralSupportWaveformCount', 'oneToOneSupportWaveformCount', ...
        'baseTotalOrder', 'baseMaxMemoryTap', 'baseRank'}, ...
        {'descend', 'descend', 'ascend', 'ascend', 'ascend'});
end

function thresholdSummary = initializeThresholdSummary(nThresholds)
    thresholdSummary = table(NaN(nThresholds, 1), NaN(nThresholds, 1), ...
        NaN(nThresholds, 1), NaN(nThresholds, 1), NaN(nThresholds, 1), ...
        NaN(nThresholds, 1), NaN(nThresholds, 1), NaN(nThresholds, 1), ...
        NaN(nThresholds, 1), NaN(nThresholds, 1), NaN(nThresholds, 1), ...
        NaN(nThresholds, 1), NaN(nThresholds, 1), NaN(nThresholds, 1), ...
        NaN(nThresholds, 1), NaN(nThresholds, 1), ...
        'VariableNames', {'threshold', 'nBaseRegressors', 'support_ge_8', ...
        'support_ge_7', 'support_ge_6', 'support_ge_5', 'support_ge_4', ...
        'support_ge_3', 'oneToOne_ge_8', 'oneToOne_ge_7', ...
        'oneToOne_ge_6', 'exactTotal', 'correlatedClearTotal', ...
        'correlatedBestTotal', 'redundantSupportTotal', 'noMatchTotal'});
end

function row = summarizeThreshold(threshold, commonTable, matchesLongTable)
    row = initializeThresholdSummary(1);
    row.threshold = threshold;
    row.nBaseRegressors = height(commonTable);
    row.support_ge_8 = sum(commonTable.structuralSupportWaveformCount >= 8);
    row.support_ge_7 = sum(commonTable.structuralSupportWaveformCount >= 7);
    row.support_ge_6 = sum(commonTable.structuralSupportWaveformCount >= 6);
    row.support_ge_5 = sum(commonTable.structuralSupportWaveformCount >= 5);
    row.support_ge_4 = sum(commonTable.structuralSupportWaveformCount >= 4);
    row.support_ge_3 = sum(commonTable.structuralSupportWaveformCount >= 3);
    row.oneToOne_ge_8 = sum(commonTable.oneToOneSupportWaveformCount >= 8);
    row.oneToOne_ge_7 = sum(commonTable.oneToOneSupportWaveformCount >= 7);
    row.oneToOne_ge_6 = sum(commonTable.oneToOneSupportWaveformCount >= 6);
    row.exactTotal = sum(strcmp(matchesLongTable.matchType, 'exact'));
    row.correlatedClearTotal = sum(strcmp(matchesLongTable.matchType, 'correlated_clear'));
    row.correlatedBestTotal = sum(strcmp(matchesLongTable.matchType, 'correlated_best'));
    row.redundantSupportTotal = sum(strcmp(matchesLongTable.matchType, 'redundant_support'));
    row.noMatchTotal = sum(strcmp(matchesLongTable.matchType, 'no_match'));
end

function list = waveformList(waveforms)
    waveforms = sort(unique(waveforms(:).'));
    parts = cell(1, numel(waveforms));
    for i = 1:numel(waveforms)
        parts{i} = sprintf('WF%02d', waveforms(i));
    end
    list = strjoin(parts, ';');
end

function text = candidateSummary(compareInfo, sortedIdx, sortedCorr, maxItems)
    nItems = min([numel(sortedIdx), numel(sortedCorr), maxItems]);
    parts = cell(1, nItems);
    for i = 1:nItems
        idx = sortedIdx(i);
        parts{i} = sprintf('#%d %.4f %s', compareInfo.rank(idx), sortedCorr(i), ...
            shortenText(compareInfo.text{idx}, 100));
    end
    text = strjoin(parts, '; ');
end

function text = shortenText(text, maxLength)
    if numel(text) > maxLength
        text = [text(1:maxLength-3) '...'];
    end
end

function key = makeRegressorKey(reg)
    key = sprintf('X=%s;Xconj=%s;Xenv=%s', ...
        mat2str(reg.X(:).'), mat2str(reg.Xconj(:).'), mat2str(reg.Xenv(:).'));
end

function tag = thresholdTag(threshold)
    tag = sprintf('thr%03d', round(threshold * 100));
end
