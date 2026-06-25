% Create a testDPD-compatible package from the CommonK evaluation output.
%
% This script is intended to be called by run_full_commonK_pipeline_8wf.m.
% It does not execute hardware and does not run main_testDPD_ADRV_v2060226.m.

clearvars;
clc;

%% ===================== MAIN LOGIC =====================

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

repoRoot = detectRepoRoot(scriptDir);
cfg = getPipelineConfig();

if isempty(fieldnames(cfg))
    error('Missing analisis8WF_pipeline_cfg. Run the master CommonK pipeline.');
end

requiredFields = {'runOutputDir', 'latestOutputDir', 'finalEvaluationMat', ...
    'measurementDirName', 'experimentName', 'runStamp', 'commonLabel', ...
    'nCommon', 'commonSupportThreshold', 'commonThresholdTag', ...
    'testDPDSignalSource'};
for i = 1:numel(requiredFields)
    if ~isfield(cfg, requiredFields{i}) || isempty(cfg.(requiredFields{i}))
        error('Missing cfg.%s for testDPD package creation.', requiredFields{i});
    end
end

if ~exist(cfg.finalEvaluationMat, 'file')
    error('CommonK evaluation MAT not found: %s', cfg.finalEvaluationMat);
end

baseExperimentMat = resolveBaseExperimentMat(repoRoot, cfg);
if isempty(baseExperimentMat) || ~exist(baseExperimentMat, 'file')
    error(['Cannot create directly runnable testDPD package: missing base ' ...
        'experiment .mat with meas_out and exp_config. Provide ' ...
        'cfg.testDPDBaseExperimentMat or cfg.testDPDBaseExperimentDate.']);
end

validateBaseExperimentMat(baseExperimentMat);

filenamedate = getCfgField(cfg, 'testDPDFileNameDate', '');
if isempty(filenamedate)
    filenamedate = makeSafeFileTag(sprintf('%s_%s_%s', ...
        cfg.measurementDirName, cfg.experimentName, cfg.runStamp));
end

testDPDDir = fullfile(cfg.runOutputDir, 'testDPD');
latestTestDPDDir = fullfile(cfg.latestOutputDir, 'testDPD');
ensureDir(testDPDDir);
ensureDir(latestTestDPDDir);

packageBaseMat = fullfile(testDPDDir, ['experiment' filenamedate '.mat']);
packageXYExecutionMat = fullfile(testDPDDir, ...
    ['experiment' filenamedate '_xy_execution.mat']);
launcherFile = fullfile(testDPDDir, 'run_testDPD_commonK_generated.m');
manifestCsv = fullfile(testDPDDir, 'testDPD_manifest.csv');
summaryTxt = fullfile(testDPDDir, 'testDPD_summary.txt');

baseData = load(baseExperimentMat, 'meas_out', 'exp_config');
[dpd, signalTable] = buildDpdFromEvaluation(cfg);

packageMetadata = buildPackageMetadata(cfg, filenamedate, baseExperimentMat, ...
    packageBaseMat, packageXYExecutionMat);
testDPDMetadata = packageMetadata;
testDPDMetadata.signalTable = signalTable;
testDPDMetadata.exportMode = getCfgField(cfg, 'testDPDExportMode', 'commonK_only');
testDPDMetadata.sourceMapping = ...
    'specific_POMP200 -> yhatValPOMP200{wf}; common_CommonK -> yhatValCommonK{wf}';
testDPDMetadata.candidateWarning = 'Candidate yvalmod source: CommonK validation prediction yhatValCommonK{wf}. Confirm block convention before lab injection.';

meas_out = baseData.meas_out; %#ok<NASGU>
exp_config = baseData.exp_config; %#ok<NASGU>
save(packageBaseMat, 'meas_out', 'exp_config', 'packageMetadata', '-v7.3');
save(packageXYExecutionMat, 'dpd', 'testDPDMetadata', '-v7.3');
writeLauncher(launcherFile, filenamedate);

directLaunchReady = false;
rootBaseMat = fullfile(repoRoot, 'results', ['experiment' filenamedate '.mat']);
rootXYExecutionMat = fullfile(repoRoot, 'results', ...
    ['experiment' filenamedate '_xy_execution.mat']);

if getCfgField(cfg, 'copyTestDPDPackageToResultsRoot', false)
    copyPackageToResultsRoot(packageBaseMat, packageXYExecutionMat, ...
        rootBaseMat, rootXYExecutionMat, ...
        getCfgField(cfg, 'allowOverwriteTestDPDExactFile', false));
    directLaunchReady = true;
end

manifest = validatePackageFiles(packageBaseMat, packageXYExecutionMat, ...
    filenamedate, cfg, directLaunchReady, rootBaseMat, rootXYExecutionMat);
writetable(manifest, manifestCsv);
writeSummary(summaryTxt, cfg, filenamedate, packageBaseMat, ...
    packageXYExecutionMat, rootBaseMat, rootXYExecutionMat, ...
    directLaunchReady, signalTable, testDPDMetadata.candidateWarning);

copyfile(packageBaseMat, fullfile(latestTestDPDDir, ...
    ['experiment' filenamedate '.mat']), 'f');
copyfile(packageXYExecutionMat, fullfile(latestTestDPDDir, ...
    ['experiment' filenamedate '_xy_execution.mat']), 'f');
copyfile(manifestCsv, fullfile(latestTestDPDDir, 'testDPD_manifest.csv'), 'f');
copyfile(summaryTxt, fullfile(latestTestDPDDir, 'testDPD_summary.txt'), 'f');
copyfile(launcherFile, fullfile(latestTestDPDDir, ...
    'run_testDPD_commonK_generated.m'), 'f');

testDPDInfo = struct();
testDPDInfo.filenamedate = filenamedate;
testDPDInfo.packageDir = testDPDDir;
testDPDInfo.latestPackageDir = latestTestDPDDir;
testDPDInfo.baseExperimentMat = packageBaseMat;
testDPDInfo.xyExecutionMat = packageXYExecutionMat;
testDPDInfo.rootBaseExperimentMat = rootBaseMat;
testDPDInfo.rootXYExecutionMat = rootXYExecutionMat;
testDPDInfo.directLaunchReady = directLaunchReady;
testDPDInfo.signalSource = cfg.testDPDSignalSource;
testDPDInfo.exportMode = getCfgField(cfg, 'testDPDExportMode', 'commonK_only');
testDPDInfo.nSignals = numel(dpd);
testDPDInfo.command = sprintf(['filenamedate = ''%s'';\n' ...
    'main_testDPD_ADRV_v2060226'], filenamedate);
testDPDInfo.manifestCsv = manifestCsv;
testDPDInfo.summaryTxt = summaryTxt;
testDPDInfo.launcherFile = launcherFile;
setappdata(0, 'analisis8WF_testDPD_info', testDPDInfo);

fprintf('\n=== CommonK testDPD package ===\n');
fprintf('Package directory: %s\n', testDPDDir);
fprintf('Direct testDPD launch ready: %s\n', logicalText(directLaunchReady));
fprintf('filenamedate: %s\n', filenamedate);
fprintf('Command:\nfilenamedate = ''%s'';\nmain_testDPD_ADRV_v2060226\n', ...
    filenamedate);
if ~directLaunchReady
    fprintf(['This launcher requires experiment files to be copied to ' ...
        'results root. Set cfg.copyTestDPDPackageToResultsRoot = true ' ...
        'or copy both files manually.\n']);
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

function ensureDir(pathName)
    if ~exist(pathName, 'dir')
        mkdir(pathName);
    end
end

function baseExperimentMat = resolveBaseExperimentMat(repoRoot, cfg)
    baseExperimentMat = getCfgField(cfg, 'testDPDBaseExperimentMat', '');
    if ~isempty(baseExperimentMat)
        baseExperimentMat = resolveInputFile(repoRoot, baseExperimentMat);
        return;
    end

    baseDate = getCfgField(cfg, 'testDPDBaseExperimentDate', '');
    if ~isempty(baseDate)
        baseExperimentMat = fullfile(repoRoot, 'results', ...
            ['experiment' baseDate '.mat']);
        return;
    end

    baseExperimentMat = inferBaseExperimentMatFromMeasurementDir(repoRoot, cfg);
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

function baseExperimentMat = inferBaseExperimentMatFromMeasurementDir(repoRoot, cfg)
    baseExperimentMat = '';
    measurementDir = fullfile(repoRoot, 'results', cfg.measurementDirName);
    files = dir(fullfile(measurementDir, 'experiment*.mat'));
    files = files(~contains({files.name}, '_xy'));
    files = files(~contains({files.name}, '_DPD'));
    [~, order] = sort({files.name});
    files = files(order);

    for iFile = 1:numel(files)
        candidate = fullfile(files(iFile).folder, files(iFile).name);
        vars = whos('-file', candidate);
        names = {vars.name};
        if ismember('meas_out', names) && ismember('exp_config', names)
            baseExperimentMat = candidate;
            fprintf(['\n[INFO] Inferred testDPD base experiment MAT from ' ...
                'measurement campaign:\n  %s\n'], baseExperimentMat);
            return;
        end
    end
end

function validateBaseExperimentMat(baseExperimentMat)
    vars = whos('-file', baseExperimentMat);
    names = {vars.name};
    if ~ismember('meas_out', names) || ~ismember('exp_config', names)
        error('Base experiment MAT must contain meas_out and exp_config: %s', ...
            baseExperimentMat);
    end
    S = load(baseExperimentMat, 'meas_out', 'exp_config');
    if isempty(S.meas_out)
        error('Base experiment meas_out is empty: %s', baseExperimentMat);
    end
    if ~hasMember(S.meas_out(1), 'u')
        error('Base experiment lacks meas_out(1).u: %s', baseExperimentMat);
    end
    u = getMember(S.meas_out(1), 'u');
    if ~(isnumeric(u) && isvector(u) && all(isfinite(u(:))))
        error('meas_out(1).u must be a finite numeric vector.');
    end
    if ~hasMember(S.exp_config, 'captureTime')
        error('Base experiment lacks exp_config.captureTime: %s', ...
            baseExperimentMat);
    end
end

function [dpd, signalTable] = buildDpdFromEvaluation(cfg)
    exportMode = getCfgField(cfg, 'testDPDExportMode', 'commonK_only');
    validModes = {'commonK_only', 'specific_only', 'both'};
    if ~ismember(exportMode, validModes)
        error('Unsupported cfg.testDPDExportMode: %s.', exportMode);
    end

    E = load(cfg.finalEvaluationMat, 'yhatValPOMP200', 'yhatValCommonK', ...
        'configuration');
    if ~isfield(E, 'yhatValPOMP200')
        error('Evaluation MAT lacks required signal source: yhatValPOMP200.');
    end
    if ~isfield(E, 'yhatValCommonK')
        error('Evaluation MAT lacks required signal source: yhatValCommonK.');
    end
    if ~iscell(E.yhatValPOMP200) || ~iscell(E.yhatValCommonK)
        error('yhatValPOMP200 and yhatValCommonK must be cell arrays.');
    end

    waveformsToExport = getCfgField(cfg, 'testDPDWaveformsToExport', ...
        1:numel(E.yhatValCommonK));
    waveformsToExport = waveformsToExport(:).';
    if isempty(waveformsToExport)
        error('cfg.testDPDWaveformsToExport is empty.');
    end
    maxWaveform = min(numel(E.yhatValPOMP200), numel(E.yhatValCommonK));
    if any(waveformsToExport < 1) || any(waveformsToExport > maxWaveform) ...
            || any(waveformsToExport ~= floor(waveformsToExport))
        error('cfg.testDPDWaveformsToExport contains invalid waveform indices.');
    end

    families = {};
    if strcmp(exportMode, 'specific_only') || strcmp(exportMode, 'both')
        families{end + 1} = 'specific_POMP200'; %#ok<AGROW>
    end
    if strcmp(exportMode, 'commonK_only') || strcmp(exportMode, 'both')
        families{end + 1} = 'common_CommonK'; %#ok<AGROW>
    end

    nSignals = numel(waveformsToExport) * numel(families);
    dpd = repmat(struct('yvalmod', [], 'modeltype', '', ...
        'modelFamily', '', 'sourceVariable', '', ...
        'commonLabel', '', 'nCommon', NaN, 'waveformIndex', NaN, ...
        'measurementDirName', '', 'experimentName', '', 'runStamp', '', ...
        'signalSource', '', 'exportMode', '', 'createdBy', ''), nSignals, 1);

    signalIndex = (1:nSignals).';
    waveformIndex = NaN(nSignals, 1);
    modelFamily = cell(nSignals, 1);
    modeltype = cell(nSignals, 1);
    sourceVariable = cell(nSignals, 1);
    nSamples = NaN(nSignals, 1);
    rmsValue = NaN(nSignals, 1);
    paprDb = NaN(nSignals, 1);
    edgeLoss = repmat(cfg.Qpmax + cfg.Qnmax, nSignals, 1);

    row = 0;
    for iFamily = 1:numel(families)
        family = families{iFamily};
        for iWaveform = 1:numel(waveformsToExport)
            wf = waveformsToExport(iWaveform);
            row = row + 1;

            if strcmp(family, 'specific_POMP200')
                sourceName = 'yhatValPOMP200';
                yvalmod = E.yhatValPOMP200{wf};
                thisModelType = sprintf('POMP200_specific_WF%02d', wf);
                thisCommonLabel = '';
                thisNCommon = NaN;
            else
                sourceName = 'yhatValCommonK';
                yvalmod = E.yhatValCommonK{wf};
                thisModelType = sprintf('%s_struct_ge%d_%s_WF%02d', ...
                    cfg.commonLabel, cfg.commonSupportThreshold, ...
                    cfg.commonThresholdTag, wf);
                thisCommonLabel = cfg.commonLabel;
                thisNCommon = cfg.nCommon;
            end

            if ~(isnumeric(yvalmod) && isvector(yvalmod) && all(isfinite(yvalmod(:))))
                error('%s{%d} must be a finite numeric vector.', sourceName, wf);
            end
            yvalmod = yvalmod(:);

            dpd(row).yvalmod = yvalmod;
            dpd(row).modeltype = thisModelType;
            dpd(row).modelFamily = family;
            dpd(row).sourceVariable = sourceName;
            dpd(row).commonLabel = thisCommonLabel;
            dpd(row).nCommon = thisNCommon;
            dpd(row).waveformIndex = wf;
            dpd(row).measurementDirName = cfg.measurementDirName;
            dpd(row).experimentName = cfg.experimentName;
            dpd(row).runStamp = cfg.runStamp;
            dpd(row).signalSource = sourceName;
            dpd(row).exportMode = exportMode;
            dpd(row).createdBy = mfilename;

            waveformIndex(row) = wf;
            modelFamily{row} = family;
            modeltype{row} = thisModelType;
            sourceVariable{row} = sourceName;
            nSamples(row) = numel(yvalmod);
            powerValue = mean(abs(yvalmod).^2);
            rmsValue(row) = sqrt(powerValue);
            paprDb(row) = 10 * log10(max(abs(yvalmod).^2) / powerValue);
        end
    end

    signalTable = table(signalIndex, waveformIndex, modelFamily, modeltype, ...
        sourceVariable, nSamples, rmsValue, paprDb, edgeLoss);
end

function metadata = buildPackageMetadata(cfg, filenamedate, baseExperimentMat, ...
    packageBaseMat, packageXYExecutionMat)
    metadata = struct();
    metadata.createdBy = mfilename;
    metadata.createdAt = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
    metadata.filenamedate = filenamedate;
    metadata.baseExperimentMat = baseExperimentMat;
    metadata.packageBaseMat = packageBaseMat;
    metadata.packageXYExecutionMat = packageXYExecutionMat;
    metadata.commonLabel = cfg.commonLabel;
    metadata.nCommon = cfg.nCommon;
    metadata.measurementDirName = cfg.measurementDirName;
    metadata.experimentName = cfg.experimentName;
    metadata.runStamp = cfg.runStamp;
    metadata.signalSource = cfg.testDPDSignalSource;
    metadata.exportMode = getCfgField(cfg, 'testDPDExportMode', 'commonK_only');
    metadata.note = ['main_testDPD_ADRV_v2060226.m will apply CFR internally ' ...
        'with xCFR = CFR_hard(x, 15).'];
end

function writeLauncher(launcherFile, filenamedate)
    fid = fopen(launcherFile, 'w');
    if fid < 0
        error('Could not create launcher: %s', launcherFile);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%% Generated launcher for CommonK testDPD package.\\n');
    fprintf(fid, '%% This script does not prepare files; it only runs testDPD.\\n\\n');
    fprintf(fid, 'filenamedate = ''%s'';\\n', filenamedate);
    fprintf(fid, 'main_testDPD_ADRV_v2060226;\\n');
    clear cleaner
end

function copyPackageToResultsRoot(packageBaseMat, packageXYExecutionMat, ...
    rootBaseMat, rootXYExecutionMat, allowOverwrite)
    if ~allowOverwrite
        if exist(rootBaseMat, 'file')
            error('Refusing to overwrite existing root base MAT: %s', rootBaseMat);
        end
        if exist(rootXYExecutionMat, 'file')
            error('Refusing to overwrite existing root xy execution MAT: %s', ...
                rootXYExecutionMat);
        end
    end
    copyfile(packageBaseMat, rootBaseMat, 'f');
    copyfile(packageXYExecutionMat, rootXYExecutionMat, 'f');
end

function manifest = validatePackageFiles(packageBaseMat, packageXYExecutionMat, ...
    filenamedate, cfg, directLaunchReady, rootBaseMat, rootXYExecutionMat)
    manifest = table(cell(0, 1), cell(0, 1), cell(0, 1), cell(0, 1), ...
        'VariableNames', {'item', 'status', 'detail', 'value'});

    manifest = addManifestRow(manifest, 'filenamedate', 'ok', ...
        'Generated testDPD file identifier', filenamedate);
    manifest = addManifestRow(manifest, 'direct_testDPD_launch_ready', 'ok', ...
        'True only when files were copied to results root', ...
        logicalText(directLaunchReady));
    exportMode = getCfgField(cfg, 'testDPDExportMode', 'commonK_only');
    manifest = addManifestRow(manifest, 'signal_source', 'ok', ...
        'Default/CommonK candidate signal. See per-dpd source_variable rows.', ...
        cfg.testDPDSignalSource);
    manifest = addManifestRow(manifest, 'testDPD_export_mode', 'ok', ...
        'Signal families exported into dpd', exportMode);
    manifest = addManifestRow(manifest, 'candidate_yvalmod_sources', 'ok', ...
        'Source mapping for exported dpd(k).yvalmod entries', ...
        'specific_POMP200 -> yhatValPOMP200{wf}; common_CommonK -> yhatValCommonK{wf}');
    manifest = addManifestRow(manifest, 'candidate_yvalmod_source', 'ok', ...
        'Explicit MATLAB source for dpd(k).yvalmod', 'yhatValCommonK{wf}');
    manifest = addManifestRow(manifest, 'candidate_yvalmod_warning', 'warning', ...
        'Lab convention warning', ...
        'Candidate yvalmod source: CommonK validation prediction yhatValCommonK{wf}. Confirm block convention before lab injection.');

    manifest = addFileCheck(manifest, 'package_base_experiment_mat', packageBaseMat);
    manifest = addFileCheck(manifest, 'package_xy_execution_mat', packageXYExecutionMat);
    if directLaunchReady
        manifest = addFileCheck(manifest, 'root_base_experiment_mat', rootBaseMat);
        manifest = addFileCheck(manifest, 'root_xy_execution_mat', rootXYExecutionMat);
    end

    B = load(packageBaseMat, 'meas_out', 'exp_config');
    manifest = addManifestRow(manifest, 'meas_out_nonempty', ...
        statusFrom(~isempty(B.meas_out)), 'meas_out must be non-empty', ...
        numel(B.meas_out));
    manifest = addManifestRow(manifest, 'meas_out_1_u_exists', ...
        statusFrom(hasMember(B.meas_out(1), 'u')), ...
        'main_testDPD uses meas_out(1).u', '');
    u = getMember(B.meas_out(1), 'u');
    manifest = addSignalChecks(manifest, 'meas_out_1_u', u);
    manifest = addManifestRow(manifest, 'exp_config_captureTime_exists', ...
        statusFrom(hasMember(B.exp_config, 'captureTime')), ...
        'main_testDPD uses exp_config.captureTime', '');

    X = load(packageXYExecutionMat, 'dpd');
    dpd = X.dpd;
    manifest = addManifestRow(manifest, 'dpd_nonempty', ...
        statusFrom(~isempty(dpd)), 'dpd must be non-empty', numel(dpd));
    for k = 1:numel(dpd)
        prefix = sprintf('dpd_%02d', k);
        manifest = addManifestRow(manifest, [prefix '_modeltype_exists'], ...
            statusFrom(hasMember(dpd(k), 'modeltype')), ...
            'main_testDPD uses dpd(k).modeltype', '');
        if hasMember(dpd(k), 'modelFamily')
            manifest = addManifestRow(manifest, [prefix '_model_family'], ...
                'ok', 'Exported signal family', getMember(dpd(k), 'modelFamily'));
        end
        if hasMember(dpd(k), 'sourceVariable')
            manifest = addManifestRow(manifest, [prefix '_source_variable'], ...
                'ok', 'Evaluation variable used for yvalmod', ...
                getMember(dpd(k), 'sourceVariable'));
        end
        manifest = addManifestRow(manifest, [prefix '_yvalmod_exists'], ...
            statusFrom(hasMember(dpd(k), 'yvalmod')), ...
            'main_testDPD uses dpd(k).yvalmod', '');
        if hasMember(dpd(k), 'yvalmod')
            manifest = addSignalChecks(manifest, [prefix '_yvalmod'], ...
                getMember(dpd(k), 'yvalmod'));
        end
    end

    if any(strcmp(manifest.status, 'error'))
        error('Generated testDPD package failed validation: %s', packageXYExecutionMat);
    end
end

function manifest = addFileCheck(manifest, item, filePath)
    if exist(filePath, 'file')
        info = dir(filePath);
        manifest = addManifestRow(manifest, item, 'ok', filePath, ...
            sprintf('%.3f MB', info.bytes / 1024 / 1024));
    else
        manifest = addManifestRow(manifest, item, 'error', 'File not found', filePath);
    end
end

function manifest = addSignalChecks(manifest, prefix, x)
    isNumericVector = isnumeric(x) && isvector(x);
    manifest = addManifestRow(manifest, [prefix '_numeric_vector'], ...
        statusFrom(isNumericVector), 'Signal must be a numeric vector', class(x));
    if ~isNumericVector
        return;
    end

    x = x(:);
    finiteValues = all(isfinite(x));
    powerValue = mean(abs(x).^2);
    rmsValue = sqrt(powerValue);
    paprDb = 10 * log10(max(abs(x).^2) / powerValue);
    manifest = addManifestRow(manifest, [prefix '_finite'], ...
        statusFrom(finiteValues), 'Signal must not contain NaN or Inf', numel(x));
    manifest = addManifestRow(manifest, [prefix '_length'], 'ok', ...
        'Signal length after regressor edge loss if applicable', numel(x));
    manifest = addManifestRow(manifest, [prefix '_rms'], ...
        statusFrom(isfinite(rmsValue) && rmsValue > 0), ...
        'RMS must be finite and positive', sprintf('%.12g', rmsValue));
    manifest = addManifestRow(manifest, [prefix '_papr_db'], ...
        statusFrom(isfinite(paprDb)), 'PAPR in dB', sprintf('%.6f', paprDb));
end

function manifest = addManifestRow(manifest, item, status, detail, value)
    if nargin < 5
        value = '';
    end
    manifest(end + 1, :) = {char(string(item)), char(string(status)), ...
        char(string(detail)), char(string(value))}; %#ok<AGROW>
end

function writeSummary(summaryTxt, cfg, filenamedate, packageBaseMat, ...
    packageXYExecutionMat, rootBaseMat, rootXYExecutionMat, directLaunchReady, ...
    signalTable, candidateWarning)
    fid = fopen(summaryTxt, 'w');
    if fid < 0
        error('Could not create summary: %s', summaryTxt);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'CommonK testDPD package summary\n');
    fprintf(fid, 'Direct testDPD launch ready: %s\n', logicalText(directLaunchReady));
    fprintf(fid, 'filenamedate: %s\n', filenamedate);
    fprintf(fid, 'Common label: %s\n', cfg.commonLabel);
    fprintf(fid, 'N_common: %d\n', cfg.nCommon);
    fprintf(fid, 'Measurement: %s\n', cfg.measurementDirName);
    fprintf(fid, 'Experiment: %s\n', cfg.experimentName);
    fprintf(fid, 'Signal source: %s\n', cfg.testDPDSignalSource);
    fprintf(fid, 'Export mode: %s\n', ...
        getCfgField(cfg, 'testDPDExportMode', 'commonK_only'));
    fprintf(fid, 'Candidate warning: %s\n\n', candidateWarning);
    fprintf(fid, 'Base experiment file: %s\n', packageBaseMat);
    fprintf(fid, 'XY execution file: %s\n', packageXYExecutionMat);
    fprintf(fid, 'Results-root base file: %s\n', rootBaseMat);
    fprintf(fid, 'Results-root xy execution file: %s\n\n', rootXYExecutionMat);
    fprintf(fid, 'Command:\n');
    fprintf(fid, 'filenamedate = ''%s'';\n', filenamedate);
    fprintf(fid, 'main_testDPD_ADRV_v2060226\n\n');

    if ~directLaunchReady
        fprintf(fid, ['This launcher requires experiment files to be copied ' ...
            'to results root.\n']);
        fprintf(fid, ['Set cfg.copyTestDPDPackageToResultsRoot = true or ' ...
            'copy both files manually.\n\n']);
    end

    fprintf(fid, 'main_testDPD_ADRV_v2060226.m will apply CFR internally:\n');
    fprintf(fid, 'xCFR = CFR_hard(x, 15);\n\n');
    fprintf(fid, 'Signals:\n%s\n', evalc('disp(signalTable)'));

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

function status = statusFrom(condition)
    if condition
        status = 'ok';
    else
        status = 'error';
    end
end

function text = logicalText(value)
    if value
        text = 'true';
    else
        text = 'false';
    end
end

function tag = makeSafeFileTag(value)
    tag = regexprep(char(value), '[^\w.-]', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');
    if isempty(tag)
        tag = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
    end
end
