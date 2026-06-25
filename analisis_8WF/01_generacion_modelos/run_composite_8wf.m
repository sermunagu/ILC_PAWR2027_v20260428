% Offline composite-initialization selection for the 8 saved ILC waveforms.
% Parallel experiment: no hardware, no official script changes, no GVG evolution.

clearvars;
clc;

filesToRun = 1:8;

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

oldFigureVisibility = get(groot, 'DefaultFigureVisible');
cleanupFigures = onCleanup(@() set(groot, 'DefaultFigureVisible', oldFigureVisibility));
set(groot, 'DefaultFigureVisible', 'off');

addpathIfExists(fullfile(repoRoot, 'toolbox'));
addpathIfExists(fullfile(repoRoot, 'toolbox_signalgen'));
addpathIfExists(fullfile(repoRoot, 'confset'));
addpathIfExists(fullfile(repoRoot, 'modeling_benchmark'));
gvgDir = fullfile(repoRoot, 'modeling_benchmark', 'GVG');
if exist(gvgDir, 'dir')
    addpath(genpath(gvgDir));
end

seed = 1004;
rng(seed);

%% ===================== MAIN LOGIC =====================

inputDir = getCfgField(pipelineCfg, 'waveformInputDir', ...
    fullfile(repoRoot, 'results', measurementDirName));
outputDir = getCfgField(pipelineCfg, 'compositeResultsDir', ...
    fullfile(repoRoot, 'results', ['composite_selection_' measurementTag]));
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

xyFiles = dir(fullfile(inputDir, 'experiment*_xy.mat'));
[~, order] = sort({xyFiles.name});
xyFiles = xyFiles(order);

if isempty(xyFiles)
    error('No experiment*_xy.mat files found in %s.', inputDir);
end

selectedWaveformIndex = filesToRun(:);
if any(selectedWaveformIndex < 1) || any(selectedWaveformIndex > numel(xyFiles)) || ...
        any(selectedWaveformIndex ~= floor(selectedWaveformIndex))
    error('filesToRun must contain integer indices between 1 and %d.', numel(xyFiles));
end
xyFiles = xyFiles(selectedWaveformIndex);

perc = 0.04;
runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
allLongTables = cell(numel(xyFiles), 1);

for k = 1:numel(xyFiles)
    waveformIndex = selectedWaveformIndex(k);
    sourcePath = fullfile(xyFiles(k).folder, xyFiles(k).name);
    fprintf('\n=== Composite initial selection wf%02d: %s ===\n', waveformIndex, xyFiles(k).name);

    data = load(sourcePath, 'x', 'y', 'fs', 'info_signal', 'description');
    x = data.x(:);
    y = data.y(:);
    x = x - mean(x);
    y = y - mean(y);

    nid = sel_indices(x, y, perc);
    GVGconfig = buildCompositeConfig();

    rManager = regressorManager(x(nid), y(nid), GVGconfig);
    rManager.initialization();
    initialPopulationCount = length(rManager.regPopulation);
    rManager.removerepeated();
    candidatePopulationCount = length(rManager.regPopulation);
    rManager.evaluation();
    rManager.selection();
    rManager.printModel();

    [~, sourceStem] = fileparts(xyFiles(k).name);
    outputMatName = sprintf('%s_wf%02d_composite_selection_%s.mat', ...
        sourceStem, waveformIndex, runStamp);
    outputMatFile = fullfile(outputDir, outputMatName);

    selectedRegressors = selectedRegressorTable(rManager, waveformIndex, ...
        xyFiles(k).name, outputMatFile);
    allLongTables{k} = selectedRegressors;

    sourceMetadata = rmfieldIfPresent(data, {'x', 'y'});
    selectedCount = height(selectedRegressors);
    identificationNMSE = rManager.nmse;
    nCoefficients = scalarOrLast(rManager.nopt);

    if isobject(rManager) && ismethod(rManager, 'prepareForSave')
        rManager.prepareForSave();
    end

    save(outputMatFile, 'rManager', 'GVGconfig', 'sourcePath', ...
        'sourceMetadata', 'perc', 'nid', 'seed', 'initialPopulationCount', ...
        'candidatePopulationCount', 'selectedCount', 'identificationNMSE', ...
        'nCoefficients', 'selectedRegressors', '-v7.3');

    fprintf('Saved %s\n', outputMatFile);
end

longTable = vertcat(allLongTables{:});
presenceTable = buildPresenceTable(longTable, selectedWaveformIndex);
summaryTable = buildSummaryTable(longTable, presenceTable, selectedWaveformIndex);

longCsv = fullfile(outputDir, sprintf('composite_selected_regressors_long_%s.csv', runStamp));
presenceCsv = fullfile(outputDir, sprintf('composite_selected_regressors_presence_%s.csv', runStamp));
summaryCsv = fullfile(outputDir, sprintf('composite_selected_regressors_summary_%s.csv', runStamp));

writetable(longTable, longCsv);
writetable(presenceTable, presenceCsv);
writetable(summaryTable, summaryCsv);

fprintf('\nComposite selection CSVs written:\n  %s\n  %s\n  %s\n', ...
    longCsv, presenceCsv, summaryCsv);

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

function GVGconfig = buildCompositeConfig()
    GVGconfig.Qpmax = 50;
    GVGconfig.Qnmax = 50;
    GVGconfig.Pmax = 13;
    GVGconfig.ngenerations = 1;
    GVGconfig.maxPopulation = 300;
    GVGconfig.evaluationtype = 'maxPopulation';
    GVGconfig.mutationrate = 0;
    GVGconfig.crossoverrate = 0;
    GVGconfig.verbosity = 3;
    GVGconfig.showPlots = false;
    GVGconfig.validate = false;
    GVGconfig.validatengen = 1;
    GVGconfig.storePopulation = false;
    GVGconfig.regPopulation = [];

    GVGconfig.DOMPtype = 'POMP';
    GVGconfig.lambda = 1e-5;
    GVGconfig.alpha = 1;
    % The implemented composite option in this codebase is "compositeall".
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

function T = selectedRegressorTable(rManager, waveformIndex, waveformFile, outputMatFile)
    nRegs = length(rManager.regPopulation);
    waveformIndexColumn = repmat(waveformIndex, nRegs, 1);
    waveformFileColumn = repmat({waveformFile}, nRegs, 1);
    outputMatFileColumn = repmat({outputMatFile}, nRegs, 1);
    regressorRank = (1:nRegs).';

    supportIndex = NaN(nRegs, 1);
    if isnumeric(rManager.s) && ~isempty(rManager.s)
        supportIndex(1:min(nRegs, numel(rManager.s))) = rManager.s(1:min(nRegs, numel(rManager.s)));
    end

    coefficient = NaN(nRegs, 1);
    finalN = scalarOrLast(rManager.nopt);
    if isnumeric(rManager.h) && ~isempty(rManager.h) && ~isnan(finalN)
        finalH = rManager.h(:, finalN);
        for iReg = 1:nRegs
            if ~isnan(supportIndex(iReg)) && supportIndex(iReg) <= numel(finalH)
                coefficient(iReg) = finalH(supportIndex(iReg));
            end
        end
    end

    nmseAtRank = NaN(nRegs, 1);
    if isnumeric(rManager.nmsev) && ~isempty(rManager.nmsev)
        n = min(nRegs, numel(rManager.nmsev));
        nmseAtRank(1:n) = rManager.nmsev(1:n);
    end

    score = NaN(nRegs, 1);
    regressorKey = cell(nRegs, 1);
    regressorString = cell(nRegs, 1);
    X = cell(nRegs, 1);
    Xconj = cell(nRegs, 1);
    Xenv = cell(nRegs, 1);

    for iReg = 1:nRegs
        reg = rManager.regPopulation(iReg);
        score(iReg) = reg.score;
        regressorKey{iReg} = makeRegressorKey(reg);
        regressorString{iReg} = strtrim(reg.print());
        X{iReg} = mat2str(reg.X);
        Xconj{iReg} = mat2str(reg.Xconj);
        Xenv{iReg} = mat2str(reg.Xenv);
    end

    T = table(waveformIndexColumn, waveformFileColumn, regressorRank, ...
        supportIndex, coefficient, nmseAtRank, score, regressorKey, ...
        regressorString, X, Xconj, Xenv, outputMatFileColumn, ...
        'VariableNames', {'waveformIndex', 'waveformFile', 'regressorRank', ...
        'supportIndex', 'coefficient', 'nmseAtRank', 'score', 'regressorKey', ...
        'regressorString', 'X', 'Xconj', 'Xenv', 'outputMatFile'});
end

function presenceTable = buildPresenceTable(longTable, selectedWaveformIndex)
    uniqueKeys = unique(longTable.regressorKey, 'stable');
    nUnique = numel(uniqueKeys);
    nWaveforms = numel(selectedWaveformIndex);

    regressorString = cell(nUnique, 1);
    waveformCount = zeros(nUnique, 1);
    presence = false(nUnique, nWaveforms);
    bestRank = NaN(nUnique, nWaveforms);

    for iKey = 1:nUnique
        keyRows = strcmp(longTable.regressorKey, uniqueKeys{iKey});
        firstRow = find(keyRows, 1, 'first');
        regressorString{iKey} = longTable.regressorString{firstRow};

        for iWave = 1:nWaveforms
            waveRows = keyRows & longTable.waveformIndex == selectedWaveformIndex(iWave);
            presence(iKey, iWave) = any(waveRows);
            if any(waveRows)
                bestRank(iKey, iWave) = min(longTable.regressorRank(waveRows));
            end
        end
        waveformCount(iKey) = sum(presence(iKey, :));
    end

    presenceTable = table(uniqueKeys, regressorString, waveformCount, ...
        'VariableNames', {'regressorKey', 'regressorString', 'waveformCount'});

    for iWave = 1:nWaveforms
        idx = selectedWaveformIndex(iWave);
        presenceTable.(sprintf('presence_wf%02d', idx)) = presence(:, iWave);
    end
    for iWave = 1:nWaveforms
        idx = selectedWaveformIndex(iWave);
        presenceTable.(sprintf('rank_wf%02d', idx)) = bestRank(:, iWave);
    end
end

function summaryTable = buildSummaryTable(longTable, presenceTable, selectedWaveformIndex)
    metric = {};
    value = [];
    note = {};

    for iWave = 1:numel(selectedWaveformIndex)
        idx = selectedWaveformIndex(iWave);
        metric{end + 1, 1} = sprintf('selected_regressors_wf%02d', idx); %#ok<AGROW>
        value(end + 1, 1) = sum(longTable.waveformIndex == idx); %#ok<AGROW>
        note{end + 1, 1} = 'Selected composite regressors for this waveform'; %#ok<AGROW>
    end

    metric{end + 1, 1} = 'unique_global_regressors';
    value(end + 1, 1) = height(presenceTable);
    note{end + 1, 1} = 'Unique exact regressor keys across selected waveforms';

    nWaveforms = numel(selectedWaveformIndex);
    for count = nWaveforms:-1:1
        metric{end + 1, 1} = sprintf('regressors_present_in_%d_of_%d_waveforms', count, nWaveforms); %#ok<AGROW>
        value(end + 1, 1) = sum(presenceTable.waveformCount == count); %#ok<AGROW>
        note{end + 1, 1} = 'Use these rows to find common/general model candidates'; %#ok<AGROW>
    end

    summaryTable = table(metric, value, note);
end

function key = makeRegressorKey(reg)
    key = sprintf('X=%s;Xconj=%s;Xenv=%s', ...
        mat2str(reg.X), mat2str(reg.Xconj), mat2str(reg.Xenv));
end

function value = scalarOrLast(x)
    value = NaN;
    if isnumeric(x) && ~isempty(x)
        x = x(:);
        value = x(end);
    end
end

function out = rmfieldIfPresent(in, fieldsToRemove)
    out = in;
    for ii = 1:numel(fieldsToRemove)
        if isfield(out, fieldsToRemove{ii})
            out = rmfield(out, fieldsToRemove{ii});
        end
    end
end
