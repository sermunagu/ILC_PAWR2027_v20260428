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

inputDir = fullfile(repoRoot, 'results', 'ILC_8waveforms');
outputDir = fullfile(repoRoot, 'results', 'GVG_ILC_8waveforms');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

xyFiles = dir(fullfile(inputDir, 'experiment*_xy.mat'));
[~, order] = sort({xyFiles.name});
xyFiles = xyFiles(order);

if isempty(xyFiles)
    error('No experiment*_xy.mat files found in %s.', inputDir);
end

if numel(xyFiles) ~= 8
    warning('Expected 8 _xy.mat files, found %d. Continuing with available files.', numel(xyFiles));
end

availableFileCount = numel(xyFiles);
selectedWaveformIndex = filesToRun(:);
if isempty(selectedWaveformIndex)
    error('filesToRun must contain at least one waveform index.');
end
if any(selectedWaveformIndex < 1) || any(selectedWaveformIndex > availableFileCount) || ...
        any(selectedWaveformIndex ~= floor(selectedWaveformIndex))
    error('filesToRun must contain integer indices between 1 and %d.', availableFileCount);
end
xyFiles = xyFiles(selectedWaveformIndex);

perc = 0.04;
runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
nFiles = numel(xyFiles);

waveformIndex = selectedWaveformIndex;
waveformFile = cell(nFiles, 1);
sourceMode = cell(nFiles, 1);
nSamples = NaN(nFiles, 1);
nIdSamples = NaN(nFiles, 1);
nCoefficients = NaN(nFiles, 1);
identificationNMSE = NaN(nFiles, 1);
officialValidationNMSE = NaN(nFiles, 1);
bestValidationNMSE = NaN(nFiles, 1);
bestValidationGeneration = NaN(nFiles, 1);
status = repmat({'pending'}, nFiles, 1);
outputFile = cell(nFiles, 1);
errorMessage = repmat({''}, nFiles, 1);

for k = 1:nFiles
    sourcePath = fullfile(xyFiles(k).folder, xyFiles(k).name);
    waveformFile{k} = xyFiles(k).name;
    fprintf('\n=== Offline GVG waveform %02d/%02d: %s ===\n', k, nFiles, xyFiles(k).name);

    try
        [x, y, sourceMetadata, sourceMode{k}] = loadXYForGVG(sourcePath);
        x = x(:);
        y = y(:);

        if ~isnumeric(x) || ~isnumeric(y)
            error('Loaded x/y must be numeric.');
        end

        if numel(x) ~= numel(y)
            error('Loaded x/y length mismatch: x=%d, y=%d.', numel(x), numel(y));
        end

        nSamples(k) = numel(x);
        x = x - mean(x);
        y = y - mean(y);

        nid = sel_indices(x, y, perc);
        nIdSamples(k) = numel(nid);

        GVGconfig = buildGVGConfig();
        fprintf('Identification samples: %d. Validation samples: %d.\n', numel(nid), numel(x));

        [rManager, regPopulation, nmseid, genval, nmsevalv, rManagerv, yvalmod] = ...
            GVGgenerateModel(x(nid), y(nid), x, y, GVGconfig);

        if isobject(rManager) && ismethod(rManager, 'printModel')
            rManager.printModel();
        else
            warning('Returned rManager does not expose printModel().');
        end

        nCoefficients(k) = extractNcoeff(rManager);
        identificationNMSE(k) = lastNumericValue(nmseid);
        if isnan(identificationNMSE(k)) && isobject(rManager) && isprop(rManager, 'nmse')
            identificationNMSE(k) = lastNumericValue(rManager.nmse);
        end
        officialValidationNMSE(k) = finalValidationValue(nmsevalv);
        [bestValidationNMSE(k), bestValidationGeneration(k)] = ...
            diagnosticBestValidation(nmsevalv, genval);

        if isobject(rManager) && ismethod(rManager, 'prepareForSave')
            rManager.prepareForSave();
        end

        [~, sourceStem] = fileparts(xyFiles(k).name);
        outputName = sprintf('%s_wf%02d_GVG_%s.mat', sourceStem, waveformIndex(k), runStamp);
        outputPath = uniqueFilePath(outputDir, outputName);

        save(outputPath, ...
            'rManager', 'regPopulation', 'nmseid', 'genval', 'nmsevalv', ...
            'rManagerv', 'yvalmod', 'GVGconfig', 'sourcePath', ...
            'sourceMetadata', 'perc', 'nid', 'seed', '-v7.3');

        outputFile{k} = outputPath;
        status{k} = 'ok';
        fprintf('Saved %s\n', outputPath);
    catch ME
        status{k} = 'failed';
        errorMessage{k} = ME.message;
        warning('Failed waveform %s: %s', xyFiles(k).name, ME.message);
    end
end

summary = table(waveformIndex, waveformFile, sourceMode, nSamples, nIdSamples, ...
    nCoefficients, identificationNMSE, officialValidationNMSE, ...
    bestValidationNMSE, bestValidationGeneration, status, outputFile, errorMessage);

summaryCsv = uniqueFilePath(outputDir, sprintf('GVG_ILC_8waveforms_summary_%s.csv', runStamp));
writetable(summary, summaryCsv);

summaryMat = strrep(summaryCsv, '.csv', '.mat');
save(summaryMat, 'summary', 'perc', 'seed', 'runStamp', 'inputDir', 'outputDir');

fprintf('\nOffline GVG summary written to:\n  %s\n  %s\n', summaryCsv, summaryMat);
disp(summary);

function addpathIfExists(pathName)
    if ~isempty(pathName) && exist(pathName, 'dir')
        addpath(pathName);
    end
end

function repoRoot = detectRepoRoot(startDir)
    repoRoot = startDir;
    while true
        hasGVG = exist(fullfile(repoRoot, 'modeling_benchmark', 'GVG', ...
            'GVGgenerateModel.m'), 'file') == 2;
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

function [x, y, metadata, mode] = loadXYForGVG(filePath)
    vars = whos('-file', filePath);
    names = {vars.name};

    if any(strcmp(names, 'x')) && any(strcmp(names, 'y'))
        loadArgs = {'x', 'y'};
        optionalNames = {'fs', 'info_signal', 'description'};
        for ii = 1:numel(optionalNames)
            if any(strcmp(names, optionalNames{ii}))
                loadArgs{end + 1} = optionalNames{ii};
            end
        end
        data = load(filePath, loadArgs{:});
        x = data.x;
        y = data.y;
        metadata = rmfieldIfPresent(data, {'x', 'y'});
        mode = 'direct x/y';
        return;
    end

    if any(strcmp(names, 'meas_out'))
        data = load(filePath, 'meas_out');
        meas = data.meas_out(end);

        if isfield(meas, 'u') && isfield(meas, 'x')
            x = meas.u;
            y = meas.x;
            mode = 'meas_out(end).u / meas_out(end).x';
        elseif isfield(meas, 'x') && isfield(meas, 'y')
            x = meas.x;
            y = meas.y;
            mode = 'meas_out(end).x / meas_out(end).y';
        else
            error('meas_out fallback found no supported x/y fields.');
        end

        metadata = struct('meas_out_fields', {fieldnames(meas)});
        return;
    end

    error('No direct x/y variables and no meas_out fallback found in %s.', filePath);
end

function GVGconfig = buildGVGConfig()
    GVGconfig.Qpmax = 50;
    GVGconfig.Qnmax = 50;
    GVGconfig.Pmax = 13;
    GVGconfig.ngenerations = 50;
    GVGconfig.maxPopulation = 300;
    GVGconfig.evaluationtype = 'maxPopulation';
    GVGconfig.mutationrate = 0.7;
    GVGconfig.crossoverrate = 0.5;
    GVGconfig.verbosity = 3;
    GVGconfig.showPlots = false;
    GVGconfig.validate = true;
    GVGconfig.validatengen = 10;
    GVGconfig.storePopulation = false;
    GVGconfig.regPopulation = [];

    GVGconfig.DOMPtype = 'POMP';
    GVGconfig.lambda = 1e-5;
    GVGconfig.alpha = 1;
    GVGconfig.inittype = 'GMP';

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

function value = extractNcoeff(rManager)
    value = NaN;
    if isobject(rManager) && isprop(rManager, 'nopt')
        value = lastNumericValue(rManager.nopt);
    end
    if isnan(value) && isobject(rManager) && isprop(rManager, 's')
        value = numel(rManager.s);
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

function value = finalValidationValue(nmsevalv)
    value = NaN;
    if isnumeric(nmsevalv) && ~isempty(nmsevalv)
        value = nmsevalv(end);
    end
end

function [bestValue, bestGeneration] = diagnosticBestValidation(nmsevalv, genval)
    bestValue = NaN;
    bestGeneration = NaN;

    if ~isnumeric(nmsevalv) || isempty(nmsevalv)
        return;
    end

    values = nmsevalv(:);
    validPositions = find(~isnan(values));
    if isempty(validPositions)
        return;
    end

    [bestValue, localIndex] = min(values(validPositions));
    bestPosition = validPositions(localIndex);

    if isnumeric(genval) && numel(genval) >= bestPosition
        genval = genval(:);
        bestGeneration = genval(bestPosition);
    else
        bestGeneration = bestPosition;
    end
end

function outPath = uniqueFilePath(folderName, fileName)
    outPath = fullfile(folderName, fileName);
    if ~exist(outPath, 'file')
        return;
    end

    [~, stem, ext] = fileparts(fileName);
    counter = 1;
    while exist(outPath, 'file')
        outPath = fullfile(folderName, sprintf('%s_%02d%s', stem, counter, ext));
        counter = counter + 1;
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
