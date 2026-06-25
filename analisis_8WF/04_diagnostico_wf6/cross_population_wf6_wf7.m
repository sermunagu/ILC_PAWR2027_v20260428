% Lightweight WF6/WF7 cross-population comparison for selected GVG populations.
% No hardware, no GVGgenerateModel, no mutation/crossover.

clearvars;
clc;

%% User paths
wf6.xy = fullfile('results', 'ILC_8waveforms', 'experiment20260429T192214_xy.mat');
wf7.xy = fullfile('results', 'ILC_8waveforms', 'experiment20260429T193745_xy.mat');
wf6.gvg = fullfile('results', 'GVG_ILC_8waveforms', ...
    'experiment20260429T192214_xy_wf06_GVG_20260615T182750.mat');
wf7.gvg = fullfile('results', 'GVG_ILC_8waveforms', ...
    'experiment20260429T193745_xy_wf07_GVG_20260615T182750.mat');

%% Setup
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

outputDir = fullfile(repoRoot, 'results', 'GVG_ILC_8waveforms', 'cross_population_compare');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% Load data
[wf6.x, wf6.y] = loadCenteredXY(wf6.xy);
[wf7.x, wf7.y] = loadCenteredXY(wf7.xy);
G6 = load(wf6.gvg);
G7 = load(wf7.gvg);

wf6.nid = G6.nid(:);
wf7.nid = G7.nid(:);
wf6.regPopulation = getSelectedPopulation(G6);
wf7.regPopulation = getSelectedPopulation(G7);
wf6.config = getBaseConfig(G6, numel(wf6.regPopulation));
wf7.config = getBaseConfig(G7, numel(wf7.regPopulation));

%% Compare 2x2
cases = {
    6, 6, wf6, wf6
    6, 7, wf6, wf7
    7, 6, wf7, wf6
    7, 7, wf7, wf7
};

nCases = size(cases, 1);
signalWaveform = NaN(nCases, 1);
populationWaveform = NaN(nCases, 1);
nIdSamples = NaN(nCases, 1);
nInputRegressors = NaN(nCases, 1);
nSelectedRegressors = NaN(nCases, 1);
nopt = NaN(nCases, 1);
nmseIdDb = NaN(nCases, 1);

for iCase = 1:nCases
    signalWaveform(iCase) = cases{iCase, 1};
    populationWaveform(iCase) = cases{iCase, 2};
    signalData = cases{iCase, 3};
    populationData = cases{iCase, 4};

    result = fitFixedPopulation(signalData.x, signalData.y, signalData.nid, ...
        populationData.regPopulation, populationData.config);

    nIdSamples(iCase) = numel(signalData.nid);
    nInputRegressors(iCase) = numel(populationData.regPopulation);
    nSelectedRegressors(iCase) = numel(result.rManager.regPopulation);
    nopt(iCase) = result.nopt;
    nmseIdDb(iCase) = result.nmseIdDb;
end

summaryTable = table(signalWaveform, populationWaveform, nIdSamples, ...
    nInputRegressors, nSelectedRegressors, nopt, nmseIdDb);

runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
csvFile = fullfile(outputDir, sprintf('WF6_WF7_GVG_cross_population_NMSE_%s.csv', runStamp));
writetable(summaryTable, csvFile);

fprintf('\nSignal WF | Population WF | NMSE ID (dB)\n');
for iCase = 1:nCases
    fprintf('WF%02d      | WF%02d          | %9.4f\n', ...
        signalWaveform(iCase), populationWaveform(iCase), nmseIdDb(iCase));
end
fprintf('\nSaved CSV:\n  %s\n', csvFile);

%% Local functions
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

function [x, y] = loadCenteredXY(fileName)
    if ~exist(fileName, 'file')
        error('Missing xy file: %s', fileName);
    end
    S = load(fileName, 'x', 'y');
    x = S.x(:);
    y = S.y(:);
    x = x - mean(x);
    y = y - mean(y);
end

function regPopulation = getSelectedPopulation(G)
    if isfield(G, 'rManager') && isprop(G.rManager, 'regPopulation') && ...
            ~isempty(G.rManager.regPopulation)
        regPopulation = G.rManager.regPopulation;
    elseif isfield(G, 'regPopulation') && ~isempty(G.regPopulation)
        regPopulation = G.regPopulation;
    else
        error('GVG .mat does not contain a usable selected regPopulation.');
    end
end

function GVGconfig = getBaseConfig(G, nRegs)
    if isfield(G, 'GVGconfig')
        GVGconfig = G.GVGconfig;
    elseif isfield(G, 'rManager')
        GVGconfig = configFromRManager(G.rManager);
    else
        error('GVG .mat does not contain GVGconfig or rManager.');
    end

    GVGconfig.inittype = 'noinit';
    GVGconfig.regPopulation = [];
    GVGconfig.maxPopulation = nRegs;
    GVGconfig.evaluationtype = 'maxPopulation';
    GVGconfig.DOMPtype = 'POMP';
    GVGconfig.lambda = 1e-5;
    GVGconfig.alpha = 1;
    GVGconfig.ngenerations = 1;
    GVGconfig.validatengen = 1;
    GVGconfig.validate = false;
    GVGconfig.storePopulation = false;
    GVGconfig.mutationrate = 0;
    GVGconfig.crossoverrate = 0;
    GVGconfig.showPlots = false;
    GVGconfig.verbosity = 0;
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

function result = fitFixedPopulation(x, y, nid, regPopulation, baseConfig)
    xId = x(nid);
    yId = y(nid);
    xId = xId(:);
    yId = yId(:);

    GVGconfig = baseConfig;
    GVGconfig.regPopulation = cloneRegressorPopulation(regPopulation);
    GVGconfig.maxPopulation = numel(regPopulation);

    rManager = regressorManager(xId, yId, GVGconfig);
    rManager.initialization();
    evalc('rManager.evaluation();');
    rManager.selection();

    result.rManager = rManager;
    result.nmseIdDb = rManager.nmse;
    result.nopt = scalarOrLast(rManager.nopt);
end

function clonedPopulation = cloneRegressorPopulation(regPopulation)
    clonedPopulation = [];
    for iReg = 1:numel(regPopulation)
        reg = regPopulation(iReg);
        clonedPopulation = [clonedPopulation Regressor(reg.X, reg.Xconj, reg.Xenv)]; %#ok<AGROW>
    end
end

function value = scalarOrLast(x)
    value = NaN;
    if isnumeric(x) && ~isempty(x)
        x = x(:);
        value = x(end);
    end
end
