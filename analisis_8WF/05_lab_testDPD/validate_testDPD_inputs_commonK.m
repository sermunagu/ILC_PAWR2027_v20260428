% Offline validation of files expected by main_testDPD_ADRV_v2060226.m.
%
% This script does not call hardware and does not modify measurement files.

clearvars;
clc;

%% ===================== USER CONFIG =====================

cfg.filenamedate = '';      % Example: '20260429T190512'
cfg.expectedNumSignals = []; % Set [] to accept any non-empty dpd array.
cfg.measurementDirName = 'ILC_8waveforms_20260624';
cfg.experimentName = '';    % Empty means use latest CommonK experiment found.
cfg.reportDir = '';         % Empty means infer CommonK latest/run folder.

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
    error('Set cfg.filenamedate before running this validator.');
end

experimentMat = fullfile(repoRoot, 'results', ...
    ['experiment' cfg.filenamedate '.mat']);
xyExecutionMat = fullfile(repoRoot, 'results', ...
    ['experiment' cfg.filenamedate '_xy_execution.mat']);

checks = initializeChecks();
checks = checkFileExists(checks, 'experiment_mat_exists', experimentMat);
checks = checkFileExists(checks, 'xy_execution_mat_exists', xyExecutionMat);

if exist(experimentMat, 'file')
    checks = validateExperimentMat(checks, experimentMat);
end
if exist(xyExecutionMat, 'file')
    checks = validateXYExecutionMat(checks, xyExecutionMat, cfg.expectedNumSignals);
end

status = checks.status;
isOk = all(strcmp(status, 'ok') | strcmp(status, 'warning'));

runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
reportCsv = fullfile(reportDir, sprintf( ...
    'testDPD_validation_%s_%s.csv', cfg.filenamedate, runStamp));
reportTxt = fullfile(reportDir, sprintf( ...
    'testDPD_validation_%s_%s.txt', cfg.filenamedate, runStamp));

writetable(checks, reportCsv);
writeTextReport(reportTxt, cfg, experimentMat, xyExecutionMat, checks, isOk);

fprintf('\n=== testDPD input validation ===\n');
fprintf('experiment MAT: %s\n', experimentMat);
fprintf('xy execution MAT: %s\n', xyExecutionMat);
fprintf('Overall status: %s\n', ternary(isOk, 'OK', 'FAILED'));
fprintf('Reports:\n  %s\n  %s\n', reportCsv, reportTxt);

if ~isOk
    error('testDPD input validation failed. See report: %s', reportTxt);
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
        reportDir = fullfile(rootDir, '_testDPD_validation_reports');
    end
end

function checks = initializeChecks()
    checks = table(cell(0, 1), cell(0, 1), cell(0, 1), cell(0, 1), ...
        'VariableNames', {'check', 'status', 'detail', 'value'});
end

function checks = addCheck(checks, name, status, detail, value)
    if nargin < 5
        value = '';
    end
    checks(end + 1, :) = {name, status, detail, char(string(value))}; %#ok<AGROW>
end

function checks = checkFileExists(checks, name, filePath)
    if exist(filePath, 'file')
        info = dir(filePath);
        checks = addCheck(checks, name, 'ok', filePath, ...
            sprintf('%.3f MB', info.bytes / 1024 / 1024));
    else
        checks = addCheck(checks, name, 'error', 'File not found', filePath);
    end
end

function checks = validateExperimentMat(checks, experimentMat)
    vars = whos('-file', experimentMat);
    names = {vars.name};
    checks = requireVariable(checks, names, 'meas_out', experimentMat);
    checks = requireVariable(checks, names, 'exp_config', experimentMat);

    if ~ismember('meas_out', names) || ~ismember('exp_config', names)
        return;
    end

    S = load(experimentMat, 'meas_out', 'exp_config');
    meas_out = S.meas_out;
    exp_config = S.exp_config;

    checks = addCheck(checks, 'meas_out_nonempty', ...
        statusFrom(~isempty(meas_out)), 'meas_out must be non-empty', numel(meas_out));
    if isempty(meas_out)
        return;
    end

    hasU = hasMember(meas_out(1), 'u');
    checks = addCheck(checks, 'meas_out_1_u_exists', statusFrom(hasU), ...
        'main_testDPD uses meas_out(1).u', hasU);
    if hasU
        u = getMember(meas_out(1), 'u');
        checks = validateSignal(checks, 'meas_out_1_u', u, true);
    end

    hasCaptureTime = hasMember(exp_config, 'captureTime');
    checks = addCheck(checks, 'exp_config_captureTime_exists', ...
        statusFrom(hasCaptureTime), ...
        'main_testDPD passes exp_config.captureTime to measureADRV', ...
        hasCaptureTime);
    if hasCaptureTime
        captureTime = getMember(exp_config, 'captureTime');
        checks = addCheck(checks, 'exp_config_captureTime_numeric', ...
            statusFrom(isnumeric(captureTime) && isscalar(captureTime) && ...
            isfinite(captureTime) && captureTime > 0), ...
            'captureTime should be a positive finite scalar', captureTime);
    end
end

function checks = validateXYExecutionMat(checks, xyExecutionMat, expectedNumSignals)
    vars = whos('-file', xyExecutionMat);
    names = {vars.name};
    checks = requireVariable(checks, names, 'dpd', xyExecutionMat);
    if ~ismember('dpd', names)
        return;
    end

    S = load(xyExecutionMat, 'dpd');
    dpd = S.dpd;
    checks = addCheck(checks, 'dpd_nonempty', statusFrom(~isempty(dpd)), ...
        'dpd must be non-empty', numel(dpd));
    if isempty(dpd)
        return;
    end

    if ~isempty(expectedNumSignals)
        checks = addCheck(checks, 'dpd_expected_count', ...
            statusFrom(numel(dpd) == expectedNumSignals), ...
            'numel(dpd) must match cfg.expectedNumSignals', ...
            sprintf('%d expected, %d found', expectedNumSignals, numel(dpd)));
    end

    lengths = NaN(numel(dpd), 1);
    for k = 1:numel(dpd)
        prefix = sprintf('dpd_%02d', k);
        hasY = hasMember(dpd(k), 'yvalmod');
        checks = addCheck(checks, [prefix '_yvalmod_exists'], ...
            statusFrom(hasY), 'main_testDPD uses dpd(k).yvalmod', hasY);
        if hasY
            yvalmod = getMember(dpd(k), 'yvalmod');
            checks = validateSignal(checks, [prefix '_yvalmod'], yvalmod, true);
            if isnumeric(yvalmod)
                lengths(k) = numel(yvalmod);
                checks = validatePowerMetrics(checks, [prefix '_yvalmod'], yvalmod);
            end
        end

        hasModelType = hasMember(dpd(k), 'modeltype');
        checks = addCheck(checks, [prefix '_modeltype_exists'], ...
            statusFrom(hasModelType), 'main_testDPD uses dpd(k).modeltype', ...
            hasModelType);
        if hasModelType
            modeltype = getMember(dpd(k), 'modeltype');
            checks = addCheck(checks, [prefix '_modeltype_text'], ...
                statusFrom(ischar(modeltype) || isstring(modeltype)), ...
                'modeltype should be text', modeltype);
        end
    end

    validLengths = lengths(isfinite(lengths));
    if ~isempty(validLengths)
        checks = addCheck(checks, 'dpd_lengths_reasonable', ...
            statusFrom(all(validLengths > 100)), ...
            'Each yvalmod should have more than 100 samples', ...
            sprintf('min=%d max=%d', min(validLengths), max(validLengths)));
        checks = addCheck(checks, 'dpd_lengths_consistent_warning', ...
            ternary(numel(unique(validLengths)) == 1, 'ok', 'warning'), ...
            'Different yvalmod lengths may be valid but should be intentional', ...
            sprintf('%s', mat2str(validLengths(:).')));
    end
end

function checks = requireVariable(checks, names, variableName, filePath)
    checks = addCheck(checks, [variableName '_exists'], ...
        statusFrom(ismember(variableName, names)), ...
        sprintf('Required variable in %s', filePath), variableName);
end

function checks = validateSignal(checks, name, x, allowComplex)
    isNumericVector = isnumeric(x) && isvector(x);
    checks = addCheck(checks, [name '_numeric_vector'], ...
        statusFrom(isNumericVector), 'Signal must be a numeric vector', ...
        class(x));
    if ~isNumericVector
        return;
    end

    finiteValues = all(isfinite(x(:)));
    checks = addCheck(checks, [name '_finite'], statusFrom(finiteValues), ...
        'Signal must not contain NaN or Inf', numel(x));

    if ~allowComplex
        checks = addCheck(checks, [name '_real'], statusFrom(isreal(x)), ...
            'Signal must be real', isreal(x));
    else
        checks = addCheck(checks, [name '_complex_allowed'], 'ok', ...
            'Complex or real vector accepted', ternary(isreal(x), 'real', 'complex'));
    end
end

function checks = validatePowerMetrics(checks, name, x)
    x = x(:);
    power = mean(abs(x).^2);
    peak = max(abs(x).^2);
    rmsValue = sqrt(power);
    paprDb = 10 * log10(peak / power);
    checks = addCheck(checks, [name '_power_finite'], ...
        statusFrom(isfinite(power) && power > 0 && isfinite(rmsValue)), ...
        'Power/RMS must be finite and positive', power);
    checks = addCheck(checks, [name '_papr_finite'], ...
        statusFrom(isfinite(paprDb)), 'PAPR must be finite', ...
        sprintf('%.6f dB', paprDb));
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

function status = statusFrom(condition)
    status = ternary(condition, 'ok', 'error');
end

function out = ternary(condition, a, b)
    if condition
        out = a;
    else
        out = b;
    end
end

function writeTextReport(reportTxt, cfg, experimentMat, xyExecutionMat, checks, isOk)
    fid = fopen(reportTxt, 'w');
    if fid < 0
        error('Could not create report: %s', reportTxt);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'testDPD validation report\n');
    fprintf(fid, 'filenamedate: %s\n', cfg.filenamedate);
    fprintf(fid, 'measurementDirName: %s\n', cfg.measurementDirName);
    fprintf(fid, 'experimentName: %s\n', cfg.experimentName);
    fprintf(fid, 'experiment MAT: %s\n', experimentMat);
    fprintf(fid, 'xy execution MAT: %s\n', xyExecutionMat);
    fprintf(fid, 'overall status: %s\n\n', ternary(isOk, 'OK', 'FAILED'));
    fprintf(fid, '%s\n', evalc('disp(checks)'));

    clear cleaner
end
