%% export_GVG_ILC_8waveforms_regressors_csv.m
% Export selected GVG regressors to CSV files.
%
% Purpose
% -------
% This script reads the final GVG result .mat files generated for the
% ILC 8-waveform campaign and exports the selected regressors in a format
% that is easier to inspect in Excel/LibreOffice/MATLAB.
%
% Expected input folder:
%   results/GVG_ILC_8waveforms/
%
% Expected input files:
%   experiment*_wfXX_GVG_YYYYMMDDTHHMMSS.mat
%
% Generated outputs:
%   results/GVG_ILC_8waveforms/regressor_csv/
%       GVG_selected_regressors_long_<stamp>.csv
%       GVG_selected_regressors_presence_<stamp>.csv
%       GVG_selected_regressors_summary_<stamp>.csv
%       GVG_selected_regressors_export_<stamp>.mat
%
% Notes
% -----
% - This script does NOT run GVG again.
% - This script does NOT modify the original measurements.
% - It only reads saved rManager objects and exports their selected
%   regPopulation regressors.

clearvars;
clc;

%% User settings

% Leave empty to automatically use the most complete/latest GVG run.
% For your final run, this should automatically select: 20260615T182750
runStamp = '';

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

repoRoot = detectRepoRoot(scriptDir);
inputDir = fullfile(repoRoot, 'results', 'GVG_ILC_8waveforms');
outputDir = fullfile(inputDir, 'regressor_csv');

% Optional: add project paths so MATLAB can load the saved class objects.
addpathIfExists(fullfile(repoRoot, 'modeling_benchmark'));
addpathIfExists(fullfile(repoRoot, 'modeling_benchmark', 'GVG'));
if exist(fullfile(repoRoot, 'modeling_benchmark', 'GVG'), 'dir')
    addpath(genpath(fullfile(repoRoot, 'modeling_benchmark', 'GVG')));
end

if ~exist(inputDir, 'dir')
    error('Input folder not found: %s', inputDir);
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% Locate model files

allModelFiles = dir(fullfile(inputDir, 'experiment*_wf*_GVG_*.mat'));

if isempty(allModelFiles)
    error('No GVG model files found in: %s', inputDir);
end

if isempty(runStamp)
    runStamp = chooseBestRunStamp(allModelFiles);
    fprintf('Auto-selected runStamp: %s\n', runStamp);
else
    fprintf('Using user-selected runStamp: %s\n', runStamp);
end

modelFiles = dir(fullfile(inputDir, sprintf('experiment*_wf*_GVG_%s.mat', runStamp)));
[~, order] = sort({modelFiles.name});
modelFiles = modelFiles(order);

if isempty(modelFiles)
    error('No GVG model files found for runStamp %s in %s', runStamp, inputDir);
end

fprintf('Found %d model files for runStamp %s.\n', numel(modelFiles), runStamp);

%% Extract selected regressors from each model

longRows = table();

for k = 1:numel(modelFiles)
    modelPath = fullfile(modelFiles(k).folder, modelFiles(k).name);
    fprintf('Reading %s\n', modelFiles(k).name);

    S = load(modelPath, 'rManager', 'GVGconfig', 'sourcePath', ...
        'sourceMetadata', 'nmseid', 'nmsevalv', 'genval', 'perc');

    if ~isfield(S, 'rManager')
        warning('Skipping %s because it does not contain rManager.', modelFiles(k).name);
        continue;
    end

    rManager = S.rManager;
    waveformIndex = parseWaveformIndex(modelFiles(k).name);

    if isfield(S, 'sourcePath')
        sourcePath = string(S.sourcePath);
    else
        sourcePath = "";
    end

    if isfield(S, 'perc')
        percUsed = S.perc;
    else
        percUsed = NaN;
    end

    identificationNMSE = getLastValueFromStruct(S, 'nmseid');
    officialValidationNMSE = getLastValueFromStruct(S, 'nmsevalv');

    if isfield(S, 'nmsevalv') && ~isempty(S.nmsevalv)
        [bestValidationNMSE, bestIdx] = min(S.nmsevalv(:));
        if isfield(S, 'genval') && ~isempty(S.genval) && numel(S.genval) >= bestIdx
            bestValidationGeneration = S.genval(bestIdx);
        else
            bestValidationGeneration = NaN;
        end
    else
        bestValidationNMSE = NaN;
        bestValidationGeneration = NaN;
    end

    regs = rManager.regPopulation;
    nRegs = numel(regs);

    coeffSelected = extractSelectedCoefficients(rManager, nRegs);

    for ir = 1:nRegs
        reg = regs(ir);

        X = reg.X;
        Xconj = reg.Xconj;
        Xenv = reg.Xenv;

        regressorText = string(strtrim(safeRegressorPrint(reg)));
        regressorKey = string(makeRegressorKey(X, Xconj, Xenv));

        h = coeffSelected(ir);

        oneRow = table( ...
            waveformIndex, ...
            string(modelFiles(k).name), ...
            sourcePath, ...
            ir, ...
            regressorText, ...
            regressorKey, ...
            string(vectorToText(X)), ...
            string(vectorToText(Xconj)), ...
            string(vectorToText(Xenv)), ...
            numel(X), ...
            numel(Xconj), ...
            numel(Xenv), ...
            numel(X) + numel(Xconj) + numel(Xenv), ...
            maxMemoryTap(X, Xconj, Xenv), ...
            real(h), ...
            imag(h), ...
            abs(h), ...
            angle(h), ...
            percUsed, ...
            identificationNMSE, ...
            officialValidationNMSE, ...
            bestValidationNMSE, ...
            bestValidationGeneration, ...
            'VariableNames', { ...
                'waveformIndex', ...
                'modelFile', ...
                'sourcePath', ...
                'selectedRank', ...
                'regressorText', ...
                'regressorKey', ...
                'X', ...
                'Xconj', ...
                'Xenv', ...
                'nX', ...
                'nXconj', ...
                'nXenv', ...
                'totalOrder', ...
                'maxMemoryTap', ...
                'coefReal', ...
                'coefImag', ...
                'coefAbs', ...
                'coefPhaseRad', ...
                'perc', ...
                'identificationNMSE', ...
                'officialValidationNMSE', ...
                'bestValidationNMSE', ...
                'bestValidationGeneration' ...
            });

        longRows = [longRows; oneRow]; %#ok<AGROW>
    end
end

if isempty(longRows)
    error('No regressors were exported. Check the input files and rManager objects.');
end

%% CSV 1: long format, one row per selected regressor per waveform

longCsv = fullfile(outputDir, sprintf('GVG_selected_regressors_long_%s.csv', runStamp));
writetable(longRows, longCsv);

%% CSV 2: presence/rank/coef matrix by waveform

uniqueKeys = unique(longRows.regressorKey, 'stable');
nUnique = numel(uniqueKeys);

presenceTable = table();
presenceTable.regressorKey = uniqueKeys;

regressorText = strings(nUnique, 1);
totalOrderCol = NaN(nUnique, 1);
maxMemoryTapCol = NaN(nUnique, 1);
XCol = strings(nUnique, 1);
XconjCol = strings(nUnique, 1);
XenvCol = strings(nUnique, 1);

for i = 1:nUnique
    idx = find(longRows.regressorKey == uniqueKeys(i), 1, 'first');
    regressorText(i) = longRows.regressorText(idx);
    totalOrderCol(i) = longRows.totalOrder(idx);
    maxMemoryTapCol(i) = longRows.maxMemoryTap(idx);
    XCol(i) = longRows.X(idx);
    XconjCol(i) = longRows.Xconj(idx);
    XenvCol(i) = longRows.Xenv(idx);
end

presenceTable.regressorText = regressorText;
presenceTable.X = XCol;
presenceTable.Xconj = XconjCol;
presenceTable.Xenv = XenvCol;
presenceTable.totalOrder = totalOrderCol;
presenceTable.maxMemoryTap = maxMemoryTapCol;

waveformList = unique(longRows.waveformIndex).';

waveformCount = zeros(nUnique, 1);
waveformListText = strings(nUnique, 1);

for i = 1:nUnique
    wfPresent = unique(longRows.waveformIndex(longRows.regressorKey == uniqueKeys(i))).';
    waveformCount(i) = numel(wfPresent);
    waveformListText(i) = string(vectorToText(wfPresent));
end

presenceTable.waveformCount = waveformCount;
presenceTable.waveformList = waveformListText;
presenceTable.isCommonToAllWaveforms = waveformCount == numel(waveformList);
presenceTable.isUniqueToOneWaveform = waveformCount == 1;

for iw = 1:numel(waveformList)
    wf = waveformList(iw);

    presentCol = false(nUnique, 1);
    rankCol = NaN(nUnique, 1);
    coefAbsCol = NaN(nUnique, 1);
    coefRealCol = NaN(nUnique, 1);
    coefImagCol = NaN(nUnique, 1);

    for i = 1:nUnique
        idx = find(longRows.waveformIndex == wf & longRows.regressorKey == uniqueKeys(i), 1, 'first');
        if ~isempty(idx)
            presentCol(i) = true;
            rankCol(i) = longRows.selectedRank(idx);
            coefAbsCol(i) = longRows.coefAbs(idx);
            coefRealCol(i) = longRows.coefReal(idx);
            coefImagCol(i) = longRows.coefImag(idx);
        end
    end

    presenceTable.(sprintf('WF%02d_present', wf)) = presentCol;
    presenceTable.(sprintf('WF%02d_rank', wf)) = rankCol;
    presenceTable.(sprintf('WF%02d_coefAbs', wf)) = coefAbsCol;
    presenceTable.(sprintf('WF%02d_coefReal', wf)) = coefRealCol;
    presenceTable.(sprintf('WF%02d_coefImag', wf)) = coefImagCol;
end

% Sort by how common the regressor is, then by order and memory.
presenceTable = sortrows(presenceTable, ...
    {'waveformCount', 'totalOrder', 'maxMemoryTap'}, ...
    {'descend', 'ascend', 'ascend'});

presenceCsv = fullfile(outputDir, sprintf('GVG_selected_regressors_presence_%s.csv', runStamp));
writetable(presenceTable, presenceCsv);

%% CSV 3: compact summary of common/different regressors

summaryTable = table();
summaryTable.metric = [ ...
    "numberOfWaveforms"; ...
    "selectedRegressorsPerWaveform"; ...
    "uniqueRegressorsAcrossAllWaveforms"; ...
    "regressorsCommonToAllWaveforms"; ...
    "regressorsUniqueToOneWaveform" ...
    ];

nRegsPerWaveform = NaN;
if ~isempty(waveformList)
    counts = arrayfun(@(wf) sum(longRows.waveformIndex == wf), waveformList);
    if numel(unique(counts)) == 1
        nRegsPerWaveform = counts(1);
    end
end

summaryTable.value = [ ...
    numel(waveformList); ...
    nRegsPerWaveform; ...
    height(presenceTable); ...
    sum(presenceTable.isCommonToAllWaveforms); ...
    sum(presenceTable.isUniqueToOneWaveform) ...
    ];

summaryCsv = fullfile(outputDir, sprintf('GVG_selected_regressors_summary_%s.csv', runStamp));
writetable(summaryTable, summaryCsv);

%% Save MATLAB copy

matOut = fullfile(outputDir, sprintf('GVG_selected_regressors_export_%s.mat', runStamp));
save(matOut, 'longRows', 'presenceTable', 'summaryTable', 'runStamp', ...
    'inputDir', 'outputDir', 'modelFiles');

%% Print final status

fprintf('\nExport complete.\n');
fprintf('Long CSV:\n  %s\n', longCsv);
fprintf('Presence CSV:\n  %s\n', presenceCsv);
fprintf('Summary CSV:\n  %s\n', summaryCsv);
fprintf('MAT copy:\n  %s\n', matOut);

fprintf('\nSummary:\n');
disp(summaryTable);

fprintf('\nMost common regressors, first 20 rows:\n');
disp(presenceTable(1:min(20, height(presenceTable)), ...
    {'regressorText', 'waveformCount', 'waveformList', 'totalOrder', 'maxMemoryTap'}));

%% Local helper functions

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

function runStamp = chooseBestRunStamp(files)
    stamps = strings(numel(files), 1);

    for i = 1:numel(files)
        tokens = regexp(files(i).name, '_GVG_(\d{8}T\d{6})\.mat$', 'tokens', 'once');
        if ~isempty(tokens)
            stamps(i) = string(tokens{1});
        end
    end

    stamps = stamps(stamps ~= "");

    if isempty(stamps)
        error('Could not parse any run timestamp from GVG model filenames.');
    end

    uniqueStamps = unique(stamps);
    counts = zeros(size(uniqueStamps));

    for i = 1:numel(uniqueStamps)
        counts(i) = sum(stamps == uniqueStamps(i));
    end

    maxCount = max(counts);
    candidateStamps = uniqueStamps(counts == maxCount);

    % ISO-like timestamp strings sort chronologically.
    candidateStamps = sort(candidateStamps);
    runStamp = char(candidateStamps(end));
end

function waveformIndex = parseWaveformIndex(fileName)
    tokens = regexp(fileName, '_wf(\d+)_GVG_', 'tokens', 'once');
    if isempty(tokens)
        waveformIndex = NaN;
    else
        waveformIndex = str2double(tokens{1});
    end
end

function value = getLastValueFromStruct(S, fieldName)
    value = NaN;
    if isfield(S, fieldName)
        x = S.(fieldName);
        if isnumeric(x) && ~isempty(x)
            x = x(:);
            idx = find(~isnan(x), 1, 'last');
            if ~isempty(idx)
                value = x(idx);
            end
        end
    end
end

function coeffSelected = extractSelectedCoefficients(rManager, nRegs)
    coeffSelected = complex(NaN(nRegs, 1), NaN(nRegs, 1));

    if ~isprop(rManager, 'h') || isempty(rManager.h)
        return;
    end

    h = rManager.h;

    if ~isnumeric(h)
        return;
    end

    if isprop(rManager, 'nopt') && ~isempty(rManager.nopt)
        noptVal = lastNumericValue(rManager.nopt);
    else
        noptVal = NaN;
    end

    if isprop(rManager, 's') && ~isempty(rManager.s)
        s = rManager.s(:);
    else
        s = [];
    end

    % Most likely case in this GVG code:
    % h is a coefficient matrix and selected coefficients are h(s, nopt).
    if ~isempty(s) && ~isnan(noptVal) && ismatrix(h) && ...
            size(h, 1) >= max(s(1:min(end, nRegs))) && size(h, 2) >= noptVal
        idx = s(1:min(nRegs, numel(s)));
        coeffSelected(1:numel(idx)) = h(idx, noptVal);
        return;
    end

    % Fallback: h is already a selected coefficient vector.
    if isvector(h)
        hvec = h(:);
        n = min(nRegs, numel(hvec));
        coeffSelected(1:n) = hvec(1:n);
        return;
    end

    % Fallback: take column nopt if possible and map directly.
    if ~isnan(noptVal) && ismatrix(h) && size(h, 2) >= noptVal
        hcol = h(:, noptVal);
        n = min(nRegs, numel(hcol));
        coeffSelected(1:n) = hcol(1:n);
    end
end

function value = lastNumericValue(x)
    value = NaN;
    if isnumeric(x) && ~isempty(x)
        x = x(:);
        idx = find(~isnan(x), 1, 'last');
        if ~isempty(idx)
            value = x(idx);
        end
    end
end

function txt = safeRegressorPrint(reg)
    try
        txt = reg.print();
        if isempty(txt)
            txt = '<constant_or_empty>';
        end
    catch
        txt = sprintf('X=%s; Xconj=%s; Xenv=%s', ...
            vectorToText(reg.X), vectorToText(reg.Xconj), vectorToText(reg.Xenv));
    end
end

function key = makeRegressorKey(X, Xconj, Xenv)
    key = sprintf('X:%s|Xconj:%s|Xenv:%s', ...
        vectorToText(sortVector(X)), ...
        vectorToText(sortVector(Xconj)), ...
        vectorToText(sortVector(Xenv)));
end

function y = sortVector(x)
    if isempty(x)
        y = [];
    else
        y = sort(x(:).');
    end
end

function txt = vectorToText(x)
    if isempty(x)
        txt = '[]';
        return;
    end

    x = x(:).';
    parts = strings(1, numel(x));
    for i = 1:numel(x)
        if abs(x(i) - round(x(i))) < 1e-12
            parts(i) = sprintf('%d', round(x(i)));
        else
            parts(i) = sprintf('%.12g', x(i));
        end
    end
    txt = ['[', char(strjoin(parts, ' ')), ']'];
end

function m = maxMemoryTap(X, Xconj, Xenv)
    allTaps = [X(:); Xconj(:); Xenv(:)];
    if isempty(allTaps)
        m = NaN;
    else
        m = max(abs(allTaps));
    end
end
