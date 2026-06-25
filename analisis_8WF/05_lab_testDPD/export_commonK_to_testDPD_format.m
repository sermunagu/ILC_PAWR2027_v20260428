% Export CommonK candidate signals to the *_xy_execution.mat format used by
% main_testDPD_ADRV_v2060226.m.
%
% This script does not call hardware. It only creates a dpd structure when
% yvalmod signals are explicitly provided by the user.

clearvars;
clc;

%% ===================== USER CONFIG =====================

cfg.filenamedate = '';       % Example: '20260429T190512'
cfg.commonLabel = '';        % Empty means infer from latest CommonK package.
cfg.modeltype = '';          % Empty means use cfg.commonLabel.

% Required: point to a MAT file that contains yvalmod signals or a dpd struct.
cfg.yvalmodSourceMat = '';
cfg.yvalmodVariable = 'yvalmod'; % Also accepts a source variable named dpd.

cfg.expectedNumSignals = []; % Set [] to accept all provided signals.
cfg.measurementDirName = 'ILC_8waveforms_20260624';
cfg.experimentName = '';     % Empty means use latest CommonK experiment found.
cfg.reportDir = '';          % Empty means infer CommonK latest/run folder.

% Safety: never overwrite an existing exact testDPD file unless this is true.
cfg.allowOverwriteExactXYExecution = false;

%% ===================== MAIN LOGIC =====================

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

repoRoot = detectRepoRoot(scriptDir);
cfg = resolvePipelineCfg(cfg);
reportDir = resolveReportDir(repoRoot, cfg);
if ~exist(reportDir, 'dir')
    mkdir(reportDir);
end

if isempty(cfg.filenamedate)
    error('Set cfg.filenamedate before running this exporter.');
end
if isempty(cfg.yvalmodSourceMat)
    error(['Set cfg.yvalmodSourceMat to a MAT file containing yvalmod ' ...
        'signals or a dpd struct. This exporter will not invent yvalmod.']);
end
cfg.yvalmodSourceMat = resolveInputFile(repoRoot, cfg.yvalmodSourceMat);
if ~exist(cfg.yvalmodSourceMat, 'file')
    error('cfg.yvalmodSourceMat does not exist: %s', cfg.yvalmodSourceMat);
end

if isempty(cfg.commonLabel)
    cfg.commonLabel = inferCommonLabel(reportDir);
end
if isempty(cfg.modeltype)
    cfg.modeltype = cfg.commonLabel;
end

experimentMat = fullfile(repoRoot, 'results', ...
    ['experiment' cfg.filenamedate '.mat']);
exactXYExecutionMat = fullfile(repoRoot, 'results', ...
    ['experiment' cfg.filenamedate '_xy_execution.mat']);
if ~exist(experimentMat, 'file')
    error('Required experiment MAT does not exist: %s', experimentMat);
end

dpd = buildDpdFromSource(cfg);
validateDpdForExport(dpd, cfg.expectedNumSignals);

runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
if exist(exactXYExecutionMat, 'file') && ~cfg.allowOverwriteExactXYExecution
    outputMat = fullfile(repoRoot, 'results', sprintf( ...
        'experiment%s_xy_execution_%s_%s.mat', ...
        cfg.filenamedate, makeSafeFileTag(cfg.commonLabel), runStamp));
    writeMode = 'timestamped_candidate_existing_exact_not_overwritten';
else
    outputMat = exactXYExecutionMat;
    writeMode = ternary(exist(exactXYExecutionMat, 'file') == 2, ...
        'overwrote_exact_user_enabled', 'created_exact');
end

exportMetadata = struct();
exportMetadata.createdBy = mfilename;
exportMetadata.createdAt = runStamp;
exportMetadata.filenamedate = cfg.filenamedate;
exportMetadata.commonLabel = cfg.commonLabel;
exportMetadata.modeltype = cfg.modeltype;
exportMetadata.yvalmodSourceMat = cfg.yvalmodSourceMat;
exportMetadata.yvalmodVariable = cfg.yvalmodVariable;
exportMetadata.writeMode = writeMode;
exportMetadata.outputMat = outputMat;
exportMetadata.exactXYExecutionMat = exactXYExecutionMat;
exportMetadata.note = ['Compatible dpd export for main_testDPD_ADRV_v2060226.m. ' ...
    'No hardware was executed by this exporter.'];

save(outputMat, 'dpd', 'exportMetadata', '-v7.3');

reportCsv = fullfile(reportDir, sprintf( ...
    'testDPD_export_%s_%s.csv', cfg.filenamedate, runStamp));
reportTxt = fullfile(reportDir, sprintf( ...
    'testDPD_export_%s_%s.txt', cfg.filenamedate, runStamp));
writeExportReports(reportCsv, reportTxt, cfg, outputMat, exactXYExecutionMat, ...
    dpd, exportMetadata);

fprintf('\n=== CommonK export to testDPD format ===\n');
fprintf('Output MAT: %s\n', outputMat);
fprintf('Write mode: %s\n', writeMode);
fprintf('dpd signals: %d\n', numel(dpd));
fprintf('Reports:\n  %s\n  %s\n', reportCsv, reportTxt);

if ~strcmp(outputMat, exactXYExecutionMat)
    fprintf(['\nNOTE: Existing exact _xy_execution.mat was not overwritten. ' ...
        'Review the timestamped candidate before copying/renaming it for lab use.\n']);
end

%% ===================== LOCAL FUNCTIONS =====================

function repoRoot = detectRepoRoot(startDir)
    repoRoot = startDir;
    while true
        hasMain = exist(fullfile(repoRoot, 'main_testDPD_ADRV_v2060226.m'), ...
            'file') == 2;
        hasAnalysis = exist(fullfile(repoRoot, 'analisis_8WF'), 'dir') == 7;
        if hasMain && hasAnalysis
            return;
        end
        parentDir = fileparts(repoRoot);
        if strcmp(parentDir, repoRoot) || isempty(parentDir)
            error('Could not detect repo root from %s.', startDir);
        end
        repoRoot = parentDir;
    end
end

function cfg = resolvePipelineCfg(cfg)
    if isappdata(0, 'analisis8WF_pipeline_cfg')
        pipelineCfg = getappdata(0, 'analisis8WF_pipeline_cfg');
        cfg.measurementDirName = getCfgField(pipelineCfg, ...
            'measurementDirName', cfg.measurementDirName);
        cfg.experimentName = getCfgField(pipelineCfg, ...
            'experimentName', cfg.experimentName);
        cfg.reportDir = getCfgField(pipelineCfg, 'latestOutputDir', cfg.reportDir);
        cfg.commonLabel = getCfgField(pipelineCfg, 'commonLabel', cfg.commonLabel);
    end
end

function value = getCfgField(cfg, fieldName, defaultValue)
    if isstruct(cfg) && isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
        value = cfg.(fieldName);
    else
        value = defaultValue;
    end
end

function reportDir = resolveReportDir(repoRoot, cfg)
    if ~isempty(cfg.reportDir)
        reportDir = cfg.reportDir;
        return;
    end

    rootDir = fullfile(repoRoot, 'results', 'common_model_experiments', ...
        cfg.measurementDirName);
    if ~isempty(cfg.experimentName)
        latestDir = fullfile(rootDir, cfg.experimentName, 'latest');
        if exist(latestDir, 'dir')
            reportDir = latestDir;
            return;
        end
    end

    candidates = dir(fullfile(rootDir, '*', 'latest'));
    candidates = candidates([candidates.isdir]);
    if ~isempty(candidates)
        [~, idx] = max([candidates.datenum]);
        reportDir = fullfile(candidates(idx).folder, candidates(idx).name);
    else
        reportDir = fullfile(rootDir, '_testDPD_export_reports');
    end
end

function filePath = resolveInputFile(repoRoot, filePath)
    if exist(filePath, 'file')
        return;
    end
    candidate = fullfile(repoRoot, filePath);
    if exist(candidate, 'file')
        filePath = candidate;
    end
end

function commonLabel = inferCommonLabel(reportDir)
    files = dir(fullfile(reportDir, 'latest_common_regressors.csv'));
    if ~isempty(files)
        T = readtable(fullfile(files(1).folder, files(1).name), ...
            'VariableNamingRule', 'preserve', 'TextType', 'char');
        commonLabel = sprintf('common%d', height(T));
        return;
    end
    error('Could not infer cfg.commonLabel. Set it manually or provide latest_common_regressors.csv.');
end

function dpd = buildDpdFromSource(cfg)
    vars = whos('-file', cfg.yvalmodSourceMat);
    names = {vars.name};

    if ismember('dpd', names) && strcmp(cfg.yvalmodVariable, 'dpd')
        S = load(cfg.yvalmodSourceMat, 'dpd');
        dpd = normalizeExistingDpd(S.dpd, cfg);
        return;
    end

    if ~ismember(cfg.yvalmodVariable, names)
        if ismember('dpd', names)
            S = load(cfg.yvalmodSourceMat, 'dpd');
            dpd = normalizeExistingDpd(S.dpd, cfg);
            return;
        end
        error('Variable "%s" not found in %s.', ...
            cfg.yvalmodVariable, cfg.yvalmodSourceMat);
    end

    S = load(cfg.yvalmodSourceMat, cfg.yvalmodVariable);
    value = S.(cfg.yvalmodVariable);
    signals = unpackSignals(value);

    dpd = repmat(struct('yvalmod', [], 'modeltype', ''), numel(signals), 1);
    for k = 1:numel(signals)
        dpd(k).yvalmod = signals{k}(:);
        dpd(k).modeltype = cfg.modeltype;
    end
end

function dpd = normalizeExistingDpd(dpd, cfg)
    if isempty(dpd)
        error('Source dpd is empty.');
    end
    for k = 1:numel(dpd)
        if ~hasMember(dpd(k), 'yvalmod')
            error('Source dpd(%d) lacks yvalmod.', k);
        end
        if ~hasMember(dpd(k), 'modeltype') || isempty(getMember(dpd(k), 'modeltype'))
            dpd(k).modeltype = cfg.modeltype;
        end
    end
end

function signals = unpackSignals(value)
    if isnumeric(value)
        if isvector(value)
            signals = {value(:)};
        else
            signals = cell(1, size(value, 2));
            for k = 1:size(value, 2)
                signals{k} = value(:, k);
            end
        end
    elseif iscell(value)
        signals = value(:).';
    elseif isstruct(value) && isfield(value, 'yvalmod')
        signals = cell(1, numel(value));
        for k = 1:numel(value)
            signals{k} = value(k).yvalmod;
        end
    else
        error('Unsupported yvalmod source type: %s.', class(value));
    end
end

function validateDpdForExport(dpd, expectedNumSignals)
    if isempty(dpd)
        error('dpd is empty.');
    end
    if ~isempty(expectedNumSignals) && numel(dpd) ~= expectedNumSignals
        error('Expected %d dpd signals, found %d.', ...
            expectedNumSignals, numel(dpd));
    end
    for k = 1:numel(dpd)
        if ~hasMember(dpd(k), 'yvalmod')
            error('dpd(%d).yvalmod is missing.', k);
        end
        yvalmod = getMember(dpd(k), 'yvalmod');
        if ~(isnumeric(yvalmod) && isvector(yvalmod) && all(isfinite(yvalmod(:))))
            error('dpd(%d).yvalmod must be a finite numeric vector.', k);
        end
        if numel(yvalmod) <= 100
            error('dpd(%d).yvalmod is too short: %d samples.', ...
                k, numel(yvalmod));
        end
        if ~hasMember(dpd(k), 'modeltype')
            error('dpd(%d).modeltype is missing.', k);
        end
    end
end

function writeExportReports(reportCsv, reportTxt, cfg, outputMat, ...
    exactXYExecutionMat, dpd, exportMetadata)
    signalIndex = (1:numel(dpd)).';
    modeltype = cell(numel(dpd), 1);
    nSamples = NaN(numel(dpd), 1);
    rmsValue = NaN(numel(dpd), 1);
    paprDb = NaN(numel(dpd), 1);
    for k = 1:numel(dpd)
        x = dpd(k).yvalmod(:);
        modeltype{k} = char(string(dpd(k).modeltype));
        nSamples(k) = numel(x);
        rmsValue(k) = sqrt(mean(abs(x).^2));
        paprDb(k) = 10 * log10(max(abs(x).^2) / mean(abs(x).^2));
    end
    T = table(signalIndex, modeltype, nSamples, rmsValue, paprDb);
    writetable(T, reportCsv);

    fid = fopen(reportTxt, 'w');
    if fid < 0
        error('Could not create report: %s', reportTxt);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, 'CommonK to testDPD export report\n');
    fprintf(fid, 'filenamedate: %s\n', cfg.filenamedate);
    fprintf(fid, 'commonLabel: %s\n', cfg.commonLabel);
    fprintf(fid, 'modeltype: %s\n', cfg.modeltype);
    fprintf(fid, 'source MAT: %s\n', cfg.yvalmodSourceMat);
    fprintf(fid, 'output MAT: %s\n', outputMat);
    fprintf(fid, 'exact xy execution MAT: %s\n', exactXYExecutionMat);
    fprintf(fid, 'write mode: %s\n\n', exportMetadata.writeMode);
    fprintf(fid, '%s\n', evalc('disp(T)'));
    clear cleaner
end

function tf = hasMember(value, name)
    if isstruct(value)
        tf = isfield(value, name);
    elseif isobject(value)
        tf = isprop(value, name);
    else
        tf = false;
    end
end

function out = getMember(value, name)
    out = value.(name);
end

function out = ternary(condition, a, b)
    if condition
        out = a;
    else
        out = b;
    end
end

function tag = makeSafeFileTag(value)
    tag = regexprep(char(value), '[^\w.-]', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');
    if isempty(tag)
        tag = 'commonK';
    end
end
