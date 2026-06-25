%% test_wf6_wf7_identification_windows.m
% Tests whether WF6 low NMSE is caused by the selected 4% identification window.
% It refits the already selected GVG/CMP regressor populations on several
% candidate windows using regressorManager, no manual Phi.

clear; clc;

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

repoRoot = detectRepoRoot(scriptDir);

addpathIfExists(fullfile(repoRoot, 'modeling_benchmark'));
addpathIfExists(fullfile(repoRoot, 'modeling_benchmark', 'GVG'));

xyDir  = fullfile(repoRoot, 'results', 'ILC_8waveforms');
gvgDir = fullfile(repoRoot, 'results', 'GVG_ILC_8waveforms');
cmpDir = fullfile(repoRoot, 'results', 'composite_selection_ILC_8waveforms');

wf6Name = 'experiment20260429T192214_xy';
wf7Name = 'experiment20260429T193745_xy';

wf6XY  = fullfile(xyDir, [wf6Name '.mat']);
wf7XY  = fullfile(xyDir, [wf7Name '.mat']);
wf6GVG = findOne(gvgDir, [wf6Name '_wf06_GVG_*.mat']);
wf7GVG = findOne(gvgDir, [wf7Name '_wf07_GVG_*.mat']);
wf6CMP = findOne(cmpDir, [wf6Name '_wf06_composite_selection_*.mat']);
wf7CMP = findOne(cmpDir, [wf7Name '_wf07_composite_selection_*.mat']);

D6 = load(wf6XY); x6 = D6.x(:); y6 = D6.y(:);
D7 = load(wf7XY); x7 = D7.x(:); y7 = D7.y(:);

G6 = load(wf6GVG);
G7 = load(wf7GVG);
C6 = load(wf6CMP);
C7 = load(wf7CMP);

N = numel(x6);
L = numel(G6.nid);

fprintf('WF6 saved GVG ID NMSE: %.4f dB | nid %d:%d\n', G6.rManager.nmse, G6.nid(1), G6.nid(end));
fprintf('WF6 saved CMP ID NMSE: %.4f dB | nid %d:%d\n', C6.rManager.nmse, C6.nid(1), C6.nid(end));
fprintf('WF7 saved GVG ID NMSE: %.4f dB | nid %d:%d\n', G7.rManager.nmse, G7.nid(1), G7.nid(end));
fprintf('WF7 saved CMP ID NMSE: %.4f dB | nid %d:%d\n', C7.rManager.nmse, C7.nid(1), C7.nid(end));

% Candidate windows. All have the same length as the saved 4% nid.
starts = unique(round(linspace(1, N-L+1, 12)));
labels = strings(numel(starts), 1);
nids = cell(numel(starts), 1);

for i = 1:numel(starts)
    nids{i} = starts(i):(starts(i)+L-1);
    labels(i) = sprintf('grid_%02d_%d_%d', i, nids{i}(1), nids{i}(end));
end

% Add exact saved windows at the beginning.
labels = ["WF6_saved_nid"; "WF7_saved_nid"; labels];
nids = [{G6.nid(:).'}; {G7.nid(:).'}; nids];

models = {
    'WF6_GVG_pop', G6.rManager.regPopulation, G6.GVGconfig;
    'WF6_CMP_pop', C6.rManager.regPopulation, C6.GVGconfig;
    'WF7_GVG_pop', G7.rManager.regPopulation, G7.GVGconfig;
    'WF7_CMP_pop', C7.rManager.regPopulation, C7.GVGconfig;
};

rows = {};
fprintf('\nTesting windows. This can take some time...\n');

for w = 1:numel(labels)
    idx = nids{w};

    for m = 1:size(models,1)
        modelName = models{m,1};
        pop = models{m,2};
        cfg = models{m,3};

        try
            nmse6 = fitFixedPopulationNmse(x6(idx), y6(idx), pop, cfg, numel(pop));
        catch ME
            nmse6 = NaN;
            fprintf('WF6 failed %s %s: %s\n', labels(w), modelName, ME.message);
        end

        try
            nmse7 = fitFixedPopulationNmse(x7(idx), y7(idx), pop, cfg, numel(pop));
        catch ME
            nmse7 = NaN;
            fprintf('WF7 failed %s %s: %s\n', labels(w), modelName, ME.message);
        end

        rows(end+1,:) = {char(labels(w)), idx(1), idx(end), char(modelName), nmse6, nmse7}; %#ok<SAGROW>
        fprintf('%-18s | %-11s | WF6 %.3f dB | WF7 %.3f dB\n', labels(w), modelName, nmse6, nmse7);
    end
end

T = cell2table(rows, 'VariableNames', {'windowLabel','firstIdx','lastIdx','population','nmseWF6','nmseWF7'});

outDir = fullfile(repoRoot, 'results', 'common_composite_model_evaluation');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
outCsv = fullfile(outDir, sprintf('wf6_wf7_identification_window_test_%s.csv', datestr(now,'yyyymmddTHHMMSS')));
writetable(T, outCsv);

fprintf('\nSaved: %s\n', outCsv);

fprintf('\nQuick WF6 summary by population:\n');
pops = unique(T.population, 'stable');
for i = 1:numel(pops)
    t = T(strcmp(T.population, pops{i}), :);
    fprintf('%-11s | best %.3f dB | median %.3f dB | saved-window %.3f dB\n', ...
        pops{i}, min(t.nmseWF6), median(t.nmseWF6, 'omitnan'), t.nmseWF6(strcmp(t.windowLabel,'WF6_saved_nid')));
end

%% Local functions

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

function nmse = fitFixedPopulationNmse(xId, yId, regPopulation, baseConfig, maxPopulation)
    cfg = baseConfig;
    cfg.regPopulation = cloneRegressorPopulation(regPopulation);
    cfg.inittype = 'noinit';
    cfg.DOMPtype = 'POMP';
    cfg.alpha = 1;
    cfg.maxPopulation = maxPopulation;
    cfg.evaluationtype = 'maxPopulation';
    cfg.ngenerations = 1;
    cfg.validatengen = 1;
    cfg.validate = false;
    cfg.storePopulation = false;
    cfg.mutationrate = 0;
    cfg.crossoverrate = 0;
    cfg.showPlots = false;
    cfg.verbosity = 0;

    rm = regressorManager(xId, yId, cfg);
    rm.initialization();
    rm.evaluation();
    rm.selection();
    nmse = rm.nmse;
end

function clonedPopulation = cloneRegressorPopulation(regPopulation)
    clonedPopulation = [];
    for i = 1:numel(regPopulation)
        reg = regPopulation(i);
        clonedPopulation = [clonedPopulation Regressor(reg.X, reg.Xconj, reg.Xenv)]; %#ok<AGROW>
    end
end

function path = findOne(folder, pattern)
    files = dir(fullfile(folder, pattern));
    if isempty(files)
        error('No file found for pattern: %s', fullfile(folder, pattern));
    end
    [~, idx] = max([files.datenum]);
    files = files(idx);
    path = fullfile(files.folder, files.name);
end

function addpathIfExists(pathName)
    if exist(pathName, 'dir')
        addpath(pathName);
    end
end
