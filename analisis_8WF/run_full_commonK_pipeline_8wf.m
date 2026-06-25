% Master pipeline for the full analisis_8WF CommonK workflow.
%
% Run from anywhere:
%   run('analisis_8WF/run_full_commonK_pipeline_8wf.m')
%
% This script orchestrates the already validated scripts. It deliberately
% avoids duplicating their numerical logic. Child scripts are executed through
% a local function so their clearvars calls do not clear this master script.
%
% CommonK is built per measurement campaign from the latest pairwise
% common-structure CSV using cfg.commonSupportColumn >= cfg.commonSupportThreshold.

clearvars;
clc;

%% ===================== USER CONFIG =====================

cfg.forceRecomputeComposite = true;    % Regenerate the composite models 
cfg.forceRecomputeCommonModel = true;  % and the common model from scratch

cfg.runSpecific300Evaluation = false;
cfg.runTutorPOMP200Evaluation = true;
cfg.createLabPackage = true;
cfg.createTutorSignalPackage = true;
cfg.createTestDPDPackage = true;

cfg.measurementDirName = 'ILC_8waveforms_20260624';
cfg.experimentName = '';  % Empty means auto-name after nCommon is known.

cfg.commonCorrelationThreshold = 0.95;
cfg.commonSupportColumn = 'structuralSupportWaveformCount';
cfg.commonSupportThreshold = 6;

cfg.idStart = 1;
cfg.rawIdSamples = 10100;
cfg.valStart = cfg.idStart + cfg.rawIdSamples;
cfg.valLength = 10100;

cfg.lambda = 1e-5;
cfg.diagLoad = 1e-12;
cfg.alpha = 1/(1+cfg.lambda);
cfg.Qpmax = 50;
cfg.Qnmax = 50;

cfg.testDPDFileNameDate = '';
cfg.testDPDBaseExperimentDate = '';
cfg.testDPDBaseExperimentMat = '';
cfg.testDPDWaveformsToExport = 1:8;
cfg.testDPDSignalSource = 'yhatValCommonK';
cfg.testDPDExportMode = 'both';  % commonK_only | specific_only | both
cfg.copyTestDPDPackageToResultsRoot = true;
cfg.allowOverwriteTestDPDExactFile = false;

%% ===================== MAIN LOGIC =====================

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

repoRoot = detectRepoRoot(scriptDir);
cfg = finalizePipelineConfig(cfg, repoRoot);
paths = buildPipelinePaths(repoRoot, cfg);
runStamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
cfg.runStamp = runStamp;

originalDir = pwd;
cleanupDir = onCleanup(@() cd(originalDir));
cd(repoRoot);
setappdata(0, 'analisis8WF_pipeline_cfg', cfg);
if isappdata(0, 'analisis8WF_testDPD_info')
    rmappdata(0, 'analisis8WF_testDPD_info');
end
if isappdata(0, 'analisis8WF_tutor_package_info')
    rmappdata(0, 'analisis8WF_tutor_package_info');
end
cleanupPipelineCfg = onCleanup(@() clearPipelineConfigAppdata());

addRequiredPaths(repoRoot);
waveformFiles = verifyWaveformFiles(paths.inputWaveformDir);

fprintf('\n=== Full CommonK 8WF pipeline ===\n');
fprintf('Repo root: %s\n', repoRoot);
fprintf('Measurement set: %s\n', cfg.measurementDirName);
fprintf('Waveform input directory: %s\n', cfg.waveformInputDir);
fprintf('Waveforms found: %d\n', numel(waveformFiles));
fprintf('Common support criterion: %s >= %g\n', ...
    cfg.commonSupportColumn, cfg.commonSupportThreshold);
fprintf('Common correlation threshold: %.6g\n', ...
    cfg.commonCorrelationThreshold);
fprintf('Run stamp: %s\n', runStamp);

stageRows = cell(0, 4);

if cfg.forceRecomputeComposite || ~hasCompositeModels(paths.compositeResultsDir)
    stageRows = runStage(stageRows, 'generate_composite_8wf', ...
        paths.runCompositeScript);
else
    fprintf('\n[SKIP] generate_composite_8wf: existing composite models found.\n');
    stageRows = appendStage(stageRows, 'generate_composite_8wf', 'skipped', ...
        'Existing composite models found', paths.runCompositeScript);
end

if cfg.forceRecomputeCommonModel || isempty(findLatestCommonStructureCandidate( ...
        paths.pairwiseCommonDir, cfg.commonCorrelationThreshold))
    stageRows = runStage(stageRows, 'build_common_structure_from_composite', ...
        paths.buildCommonScript);
else
    fprintf('\n[SKIP] build_common_structure_from_composite: campaign common-structure CSV already exists.\n');
    stageRows = appendStage(stageRows, 'build_common_structure_from_composite', ...
        'skipped', 'Campaign common CSV already exists', paths.buildCommonScript);
end

[paths, cfg, commonInfo] = buildStableCommonModelFromCandidate( ...
    paths, cfg, repoRoot, runStamp);
runStamp = cfg.runStamp;
setappdata(0, 'analisis8WF_pipeline_cfg', cfg);
stageRows = appendStage(stageRows, 'build_commonK_from_candidate', 'ok', ...
    sprintf('%s with %d regressors', cfg.commonLabel, cfg.nCommon), ...
    commonInfo.sourceCsv);

if cfg.runSpecific300Evaluation
    stageRows = runStage(stageRows, 'eval_commonK_vs_specific300_all8', ...
        paths.evalSpecific300Script);
else
    fprintf('\n[SKIP] eval_commonK_vs_specific300_all8: disabled by cfg.\n');
    stageRows = appendStage(stageRows, 'eval_commonK_vs_specific300_all8', ...
        'skipped', 'Disabled by cfg.runSpecific300Evaluation', ...
        paths.evalSpecific300Script);
end

if cfg.runTutorPOMP200Evaluation
    assertTutorPomp200Defaults(cfg);
    stageRows = runStage(stageRows, 'eval_commonK_vs_pomp200_all8', ...
        paths.evalPomp200Script);
else
    fprintf('\n[SKIP] eval_commonK_vs_pomp200_all8: disabled by cfg.\n');
    stageRows = appendStage(stageRows, 'eval_commonK_vs_pomp200_all8', ...
        'skipped', 'Disabled by cfg.runTutorPOMP200Evaluation', ...
        paths.evalPomp200Script);
end

finalResultsCsv = findLatestFile(paths.runOutputDir, ...
    sprintf('%s_vs_pomp200_all8_%s_*.csv', cfg.commonLabel, cfg.measurementTag));
finalResultsMat = findLatestFile(paths.runOutputDir, ...
    sprintf('%s_vs_pomp200_all8_%s_*.mat', cfg.commonLabel, cfg.measurementTag));
specific300Csv = findLatestFile(paths.evaluationResultsDir, ...
    sprintf('%s_vs_composite_vs_gvg_ID_VAL_summary_*.csv', cfg.commonLabel));

cfg.finalResultsCsv = finalResultsCsv;
cfg.finalEvaluationMat = finalResultsMat;
setappdata(0, 'analisis8WF_pipeline_cfg', cfg);

tutorPackageInfo = struct();
if cfg.createTutorSignalPackage
    if isappdata(0, 'analisis8WF_tutor_package_info')
        rmappdata(0, 'analisis8WF_tutor_package_info');
    end
    stageRows = runStage(stageRows, 'create_tutor_signal_package_commonK', ...
        paths.createTutorPackageScript);
    if isappdata(0, 'analisis8WF_tutor_package_info')
        tutorPackageInfo = getappdata(0, 'analisis8WF_tutor_package_info');
    end
else
    fprintf('\n[SKIP] create_tutor_signal_package_commonK: disabled by cfg.\n');
    stageRows = appendStage(stageRows, 'create_tutor_signal_package_commonK', ...
        'skipped', 'Disabled by cfg.createTutorSignalPackage', ...
        paths.createTutorPackageScript);
end

testDPDInfo = struct();
if cfg.createTestDPDPackage
    if isappdata(0, 'analisis8WF_testDPD_info')
        rmappdata(0, 'analisis8WF_testDPD_info');
    end
    stageRows = runStage(stageRows, 'create_testDPD_package_from_commonK', ...
        paths.createTestDPDScript);
    if isappdata(0, 'analisis8WF_testDPD_info')
        testDPDInfo = getappdata(0, 'analisis8WF_testDPD_info');
    end
else
    fprintf('\n[SKIP] create_testDPD_package_from_commonK: disabled by cfg.\n');
    stageRows = appendStage(stageRows, 'create_testDPD_package_from_commonK', ...
        'skipped', 'Disabled by cfg.createTestDPDPackage', ...
        paths.createTestDPDScript);
end

pipelineSummaryCsv = fullfile(paths.runOutputDir, sprintf( ...
    'full_%s_pipeline_8wf_%s_%s.csv', cfg.commonLabel, ...
    cfg.measurementTag, runStamp));
stageTable = cell2table(stageRows, 'VariableNames', ...
    {'stage', 'status', 'detail', 'script'});
writetable(stageTable, pipelineSummaryCsv);

finalOutputs = publishFinalExperimentOutputs(paths, cfg, runStamp, ...
    repoRoot, waveformFiles, commonInfo, finalResultsCsv, finalResultsMat, ...
    specific300Csv, pipelineSummaryCsv, testDPDInfo, tutorPackageInfo);

fprintf('\n=== Pipeline summary ===\n');
fprintf('Common label: %s\n', cfg.commonLabel);
fprintf('N_common: %d\n', cfg.nCommon);
fprintf('Common CSV:\n  %s\n', commonInfo.filteredCsv);
if ~isempty(finalResultsCsv)
    fprintf('Final %s vs POMP200 CSV:\n  %s\n', cfg.commonLabel, finalResultsCsv);
else
    fprintf('Final %s vs POMP200 CSV: not found\n', cfg.commonLabel);
end
fprintf('Pipeline stage log:\n  %s\n', pipelineSummaryCsv);
if ~isempty(fieldnames(tutorPackageInfo))
    fprintf('Tutor signal package:\n  %s\n', tutorPackageInfo.packageDir);
    fprintf('Tutor signal ZIP:\n  %s\n', tutorPackageInfo.zipFile);
end
if ~isempty(fieldnames(testDPDInfo))
    fprintf('testDPD package:\n  %s\n', testDPDInfo.packageDir);
    fprintf('Direct testDPD launch ready: %s\n', ...
        logicalText(testDPDInfo.directLaunchReady));
    fprintf('testDPD export mode: %s (%d signals)\n', ...
        testDPDInfo.exportMode, testDPDInfo.nSignals);
    fprintf('testDPD command:\nfilenamedate = ''%s'';\nmain_testDPD_ADRV_v2060226\n', ...
        testDPDInfo.filenamedate);
end

fprintf('\nFULL COMMONK PIPELINE FINISHED\n\n');
fprintf('Final common model:\n');
fprintf('%s\n\n', relativeToRepo(finalOutputs.commonCsv, repoRoot));
fprintf('Final evaluation:\n');
fprintf('%s\n\n', relativeToRepo(finalOutputs.evaluationCsv, repoRoot));
fprintf('Lab package:\n');
fprintf('%s\n\n', relativeToRepo(finalOutputs.labPackageMat, repoRoot));
fprintf('Summary:\n');
fprintf('%s\n', relativeToRepo(finalOutputs.summaryTxt, repoRoot));

%% ===================== LOCAL FUNCTIONS =====================

function repoRoot = detectRepoRoot(startDir)
    repoRoot = startDir;
    while true
        hasGVG = exist(fullfile(repoRoot, 'modeling_benchmark', 'GVG', ...
            'Regressor.m'), 'file') == 2;
        hasResults = exist(fullfile(repoRoot, 'results'), 'dir') == 7;
        hasAnalysis = exist(fullfile(repoRoot, 'analisis_8WF'), 'dir') == 7;
        if hasGVG && hasResults && hasAnalysis
            return;
        end

        parentDir = fileparts(repoRoot);
        if strcmp(parentDir, repoRoot) || isempty(parentDir)
            error('Could not detect repo root from %s.', startDir);
        end
        repoRoot = parentDir;
    end
end

function cfg = finalizePipelineConfig(cfg, repoRoot)
    cfg.measurementTag = makeSafeFileTag(cfg.measurementDirName);
    cfg.waveformInputDir = fullfile(repoRoot, 'results', cfg.measurementDirName);
    cfg.compositeResultsDir = fullfile(repoRoot, 'results', ...
        ['composite_selection_' cfg.measurementTag]);
    cfg.commonThresholdTag = thresholdTag(cfg.commonCorrelationThreshold);
end

function tag = makeSafeFileTag(value)
    tag = regexprep(char(value), '[^\w.-]', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');
    if isempty(tag)
        tag = 'measurement_set';
    end
end

function tag = thresholdTag(threshold)
    tag = sprintf('thr%03d', round(threshold * 100));
end

function clearPipelineConfigAppdata()
    if isappdata(0, 'analisis8WF_pipeline_cfg')
        rmappdata(0, 'analisis8WF_pipeline_cfg');
    end
end

function paths = buildPipelinePaths(repoRoot, cfg)
    analysisDir = fullfile(repoRoot, 'analisis_8WF');
    paths.repoRoot = repoRoot;
    paths.analysisDir = analysisDir;
    paths.inputWaveformDir = cfg.waveformInputDir;
    paths.compositeResultsDir = cfg.compositeResultsDir;
    paths.commonExperimentsRoot = fullfile(repoRoot, 'results', ...
        'common_model_experiments', cfg.measurementDirName);
    paths.evaluationResultsDir = '';
    paths.experimentDir = '';
    paths.runOutputDir = '';
    paths.latestOutputDir = '';
    paths.pairwiseCommonDir = fullfile(paths.compositeResultsDir, ...
        'pairwise_common_structure');

    paths.runCompositeScript = fullfile(analysisDir, ...
        '01_generacion_modelos', 'run_composite_8wf.m');
    paths.runGvgScript = fullfile(analysisDir, ...
        '01_generacion_modelos', 'run_gvg_8wf.m');
    paths.buildCommonScript = fullfile(analysisDir, ...
        '02_modelo_comun', 'build_common_structure_from_composite.m');
    paths.evalSpecific300Script = fullfile(analysisDir, ...
        '03_evaluacion', 'eval_commonK_vs_specific300_all8.m');
    paths.evalPomp200Script = fullfile(analysisDir, ...
        '03_evaluacion', 'eval_commonK_vs_pomp200_all8.m');
    paths.createTutorPackageScript = fullfile(analysisDir, ...
        '06_tutor_deliverable', 'create_tutor_signal_package_commonK.m');
    paths.createTestDPDScript = fullfile(analysisDir, ...
        '05_lab_testDPD', 'create_testDPD_package_from_commonK.m');
    paths.readme = fullfile(analysisDir, 'README_ANALISIS_8WF.md');
    paths.masterScript = fullfile(analysisDir, 'run_full_commonK_pipeline_8wf.m');
end

function addRequiredPaths(repoRoot)
    addpathIfExists(fullfile(repoRoot, 'toolbox'));
    addpathIfExists(fullfile(repoRoot, 'toolbox_signalgen'));
    addpathIfExists(fullfile(repoRoot, 'confset'));
    addpathIfExists(fullfile(repoRoot, 'modeling_benchmark'));

    gvgDir = fullfile(repoRoot, 'modeling_benchmark', 'GVG');
    if exist(gvgDir, 'dir')
        addpath(genpath(gvgDir));
    end
end

function addpathIfExists(pathName)
    if exist(pathName, 'dir')
        addpath(pathName);
    end
end

function waveformFiles = verifyWaveformFiles(inputWaveformDir)
    if ~exist(inputWaveformDir, 'dir')
        error('Waveform input directory does not exist: %s', inputWaveformDir);
    end

    files = dir(fullfile(inputWaveformDir, 'experiment*_xy.mat'));
    [~, order] = sort({files.name});
    files = files(order);

    if numel(files) ~= 8
        error('Expected exactly 8 experiment*_xy.mat files in %s, found %d.', ...
            inputWaveformDir, numel(files));
    end

    waveformFiles = cell(numel(files), 1);
    for i = 1:numel(files)
        waveformFiles{i} = fullfile(files(i).folder, files(i).name);
        vars = whos('-file', waveformFiles{i});
        names = {vars.name};
        if ~any(strcmp(names, 'x')) || ~any(strcmp(names, 'y'))
            error('Waveform file lacks x/y variables: %s', waveformFiles{i});
        end
    end
end

function tf = hasCompositeModels(compositeResultsDir)
    files = dir(fullfile(compositeResultsDir, ...
        'experiment*_wf*_composite_selection_*.mat'));
    tf = numel(files) >= 8;
end

function stageRows = runStage(stageRows, stageName, scriptPath)
    fprintf('\n[RUN] %s\n  %s\n', stageName, scriptPath);
    if ~exist(scriptPath, 'file')
        error('Missing script for stage %s: %s', stageName, scriptPath);
    end

    try
        runChildScript(scriptPath);
        stageRows = appendStage(stageRows, stageName, 'ok', 'Completed', scriptPath);
    catch ME
        stageRows = appendStage(stageRows, stageName, 'failed', ME.message, scriptPath);
        rethrow(ME);
    end
end

function runChildScript(scriptPath)
    run(scriptPath);
end

function stageRows = appendStage(stageRows, stageName, status, detail, scriptPath)
    stageRows(end + 1, :) = {stageName, status, detail, scriptPath}; %#ok<AGROW>
end

function [paths, cfg, commonInfo] = buildStableCommonModelFromCandidate( ...
    paths, cfg, repoRoot, requestedRunStamp)

    sourceCsv = findLatestCommonStructureCandidate(paths.pairwiseCommonDir, ...
        cfg.commonCorrelationThreshold);
    if isempty(sourceCsv)
        error('No common-structure CSV found in %s for threshold %.6g.', ...
            paths.pairwiseCommonDir, cfg.commonCorrelationThreshold);
    end

    T = readtable(sourceCsv, 'VariableNamingRule', 'preserve', ...
        'TextType', 'char');
    supportColumn = resolveTableColumn(T, cfg.commonSupportColumn);
    supportValues = T.(supportColumn);
    if ~isnumeric(supportValues)
        supportValues = str2double(string(supportValues));
    end

    keepRows = supportValues >= cfg.commonSupportThreshold;
    Tfiltered = T(keepRows, :);
    nCommon = height(Tfiltered);
    if nCommon <= 0
        error('Common support filter produced zero regressors: %s >= %g in %s.', ...
            supportColumn, cfg.commonSupportThreshold, sourceCsv);
    end

    commonLabel = sprintf('common%d', nCommon);
    cfg.nCommon = nCommon;
    cfg.commonLabel = commonLabel;
    cfg.commonModelName = commonLabel;

    if ~isfield(cfg, 'experimentName') || isempty(cfg.experimentName)
        cfg.experimentName = sprintf('%s_struct_ge%d_%s', ...
            commonLabel, cfg.commonSupportThreshold, cfg.commonThresholdTag);
    else
        cfg.experimentName = makeSafeFileTag(cfg.experimentName);
    end

    [paths, cfg] = finalizeExperimentPaths(paths, cfg, repoRoot, ...
        requestedRunStamp);

    commonCsvName = sprintf('%s_ge%d_%s_regressors.csv', commonLabel, ...
        cfg.commonSupportThreshold, cfg.commonThresholdTag);
    filteredCsv = fullfile(paths.runOutputDir, commonCsvName);
    writetable(Tfiltered, filteredCsv);

    metadata = struct();
    metadata.nCommon = nCommon;
    metadata.commonLabel = commonLabel;
    metadata.commonSupportColumn = supportColumn;
    metadata.commonSupportThreshold = cfg.commonSupportThreshold;
    metadata.commonCorrelationThreshold = cfg.commonCorrelationThreshold;
    metadata.commonThresholdTag = cfg.commonThresholdTag;
    metadata.measurementDirName = cfg.measurementDirName;
    metadata.measurementTag = cfg.measurementTag;
    metadata.experimentName = cfg.experimentName;
    metadata.sourceCsv = sourceCsv;
    metadata.filteredCsv = filteredCsv;
    metadata.runStamp = cfg.runStamp;

    metadataMat = fullfile(paths.runOutputDir, sprintf( ...
        '%s_common_model_metadata_%s.mat', commonLabel, cfg.runStamp));
    save(metadataMat, 'metadata');

    cfg.commonModelCsv = filteredCsv;
    cfg.commonMetadataMat = metadataMat;
    cfg.finalOutputDir = paths.runOutputDir;
    cfg.evaluationResultsDir = paths.runOutputDir;

    commonInfo = metadata;
    commonInfo.table = Tfiltered;
    commonInfo.metadataMat = metadataMat;

    fprintf('\nCommon model built from campaign candidate:\n');
    fprintf('  source: %s\n', sourceCsv);
    fprintf('  filter: %s >= %g\n', supportColumn, cfg.commonSupportThreshold);
    fprintf('  label: %s\n', commonLabel);
    fprintf('  nCommon: %d\n', nCommon);
    fprintf('  output: %s\n', filteredCsv);
end

function [paths, cfg] = finalizeExperimentPaths(paths, cfg, repoRoot, ...
    requestedRunStamp)

    paths.experimentDir = fullfile(paths.commonExperimentsRoot, ...
        cfg.experimentName);
    if ~exist(paths.experimentDir, 'dir')
        mkdir(paths.experimentDir);
    end

    runStamp = requestedRunStamp;
    runDir = fullfile(paths.experimentDir, runStamp);
    suffix = 2;
    while exist(runDir, 'dir')
        runStamp = sprintf('%s_%02d', requestedRunStamp, suffix);
        runDir = fullfile(paths.experimentDir, runStamp);
        suffix = suffix + 1;
    end

    mkdir(runDir);
    paths.runOutputDir = runDir;
    paths.evaluationResultsDir = runDir;
    paths.latestOutputDir = fullfile(paths.experimentDir, 'latest');
    if ~exist(paths.latestOutputDir, 'dir')
        mkdir(paths.latestOutputDir);
    end

    cfg.runStamp = runStamp;
    cfg.experimentDir = paths.experimentDir;
    cfg.runOutputDir = paths.runOutputDir;
    cfg.latestOutputDir = paths.latestOutputDir;
    cfg.finalOutputDir = paths.runOutputDir;
    cfg.evaluationResultsDir = paths.runOutputDir;
end

function csvPath = findLatestCommonStructureCandidate(pairwiseCommonDir, threshold)
    csvPath = '';
    thrTag = thresholdTag(threshold);
    files = dir(fullfile(pairwiseCommonDir, ...
        ['*common_structure_' thrTag '_*.csv']));
    if isempty(files)
        return;
    end

    [~, order] = sort([files.datenum], 'descend');
    files = files(order);
    csvPath = fullfile(files(1).folder, files(1).name);
end

function name = resolveTableColumn(T, requestedName)
    names = T.Properties.VariableNames;
    exact = strcmp(names, requestedName);
    if any(exact)
        name = names{find(exact, 1, 'first')};
        return;
    end

    insensitive = strcmpi(names, requestedName);
    if any(insensitive)
        name = names{find(insensitive, 1, 'first')};
        return;
    end

    error('Required column "%s" not found. Available columns: %s', ...
        requestedName, strjoin(names, ', '));
end

function assertTutorPomp200Defaults(cfg)
    % The validated evaluation script currently owns its numeric settings.
    % This guard prevents silently running it with master cfg values that do
    % not match the child script defaults.
    expected.idStart = 1;
    expected.rawIdSamples = 10100;
    expected.valStart = expected.idStart + expected.rawIdSamples;
    expected.valLength = 10100;
    expected.lambda = 1e-5;
    expected.diagLoad = 1e-12;
    expected.alpha = 1/(1+expected.lambda);
    expected.Qpmax = 50;
    expected.Qnmax = 50;

    fields = fieldnames(expected);
    for i = 1:numel(fields)
        name = fields{i};
        if ~isequal(cfg.(name), expected.(name))
            error(['cfg.%s differs from the validated child script default. ' ...
                'Update eval_commonK_vs_pomp200_all8.m to accept overrides ' ...
                'before changing this value in the master pipeline.'], name);
        end
    end
end

function latestPath = findLatestFile(folderName, pattern)
    latestPath = '';
    files = dir(fullfile(folderName, pattern));
    if isempty(files)
        return;
    end
    [~, idx] = max([files.datenum]);
    latestPath = fullfile(files(idx).folder, files(idx).name);
end

function finalOutputs = publishFinalExperimentOutputs(paths, cfg, runStamp, ...
    repoRoot, waveformFiles, commonInfo, finalResultsCsv, finalResultsMat, ...
    specific300Csv, pipelineSummaryCsv, testDPDInfo, tutorPackageInfo)

    if cfg.runTutorPOMP200Evaluation && ...
            (isempty(finalResultsCsv) || ~exist(finalResultsCsv, 'file'))
        error('Final POMP200 evaluation CSV not found for %s in %s.', ...
            cfg.commonLabel, paths.runOutputDir);
    end
    if ~exist(commonInfo.filteredCsv, 'file')
        error('Common regressors CSV not found: %s', commonInfo.filteredCsv);
    end

    finalOutputs = struct();
    finalOutputs.commonCsv = commonInfo.filteredCsv;
    finalOutputs.evaluationCsv = finalResultsCsv;
    finalOutputs.evaluationMat = finalResultsMat;
    finalOutputs.summaryTxt = fullfile(paths.runOutputDir, sprintf( ...
        '%s_summary_%s_%s.txt', cfg.commonLabel, cfg.measurementTag, runStamp));
    finalOutputs.manifestCsv = fullfile(paths.runOutputDir, sprintf( ...
        '%s_manifest_%s_%s.csv', cfg.commonLabel, cfg.measurementTag, runStamp));
    finalOutputs.labPackageMat = fullfile(paths.runOutputDir, sprintf( ...
        '%s_lab_package_%s_%s.mat', cfg.commonLabel, ...
        cfg.measurementTag, runStamp));

    commonRegressors = readtable(commonInfo.filteredCsv, ...
        'VariableNamingRule', 'preserve', 'TextType', 'char');
    if height(commonRegressors) ~= cfg.nCommon
        error('Common CSV row count mismatch for %s: cfg.nCommon=%d, rows=%d.', ...
            cfg.commonLabel, cfg.nCommon, height(commonRegressors));
    end

    if isempty(finalResultsCsv)
        resultsTable = table();
        metrics = struct();
    else
        resultsTable = readtable(finalResultsCsv, ...
            'VariableNamingRule', 'preserve', 'TextType', 'char');
        metrics = computeDeltaMetrics(resultsTable);
    end

    conceptualNote = sprintf(['%s fija una estructura común de %d regresores. ' ...
        'Los coeficientes deben estimarse para cada waveform/dataset de laboratorio usando esta estructura.'], ...
        cfg.commonLabel, cfg.nCommon);

    commonCsvPath = commonInfo.filteredCsv;
    commonMetadata = rmfieldIfPresent(commonInfo, {'table'});
    save(finalOutputs.labPackageMat, 'cfg', 'runStamp', 'repoRoot', ...
        'waveformFiles', 'commonCsvPath', 'finalResultsCsv', 'resultsTable', ...
        'commonRegressors', 'commonMetadata', 'conceptualNote', 'metrics', ...
        'testDPDInfo', 'tutorPackageInfo', '-v7.3');

    writeExperimentSummary(finalOutputs.summaryTxt, cfg, runStamp, ...
        commonCsvPath, finalResultsCsv, commonRegressors, resultsTable, ...
        metrics, conceptualNote, testDPDInfo, tutorPackageInfo);

    manifestRows = {
        'common_model_csv', commonInfo.filteredCsv;
        'common_metadata_mat', commonInfo.metadataMat;
        'evaluation_csv', finalResultsCsv;
        'evaluation_mat', finalResultsMat;
        'specific300_csv', specific300Csv;
        'pipeline_stage_log_csv', pipelineSummaryCsv;
        'lab_package_mat', finalOutputs.labPackageMat;
        'summary_txt', finalOutputs.summaryTxt;
        };
    manifestRows = manifestRows(~cellfun(@isempty, manifestRows(:, 2)), :);
    manifest = cell2table(manifestRows, 'VariableNames', ...
        {'artifact', 'path'});
    writetable(manifest, finalOutputs.manifestCsv);

    publishLatestAliases(paths, cfg, finalOutputs);
end

function metrics = computeDeltaMetrics(resultsTable)
    requiredNames = {'waveformIndex', 'delta_id', 'delta_val'};
    for i = 1:numel(requiredNames)
        if ~ismember(requiredNames{i}, resultsTable.Properties.VariableNames)
            error('Evaluation table lacks required column: %s', requiredNames{i});
        end
    end

    wf = resultsTable.waveformIndex;
    keepDataRows = ~isnan(wf);
    wf = wf(keepDataRows);
    deltaId = resultsTable.delta_id(keepDataRows);
    deltaVal = resultsTable.delta_val(keepDataRows);
    notWF6 = wf ~= 6;

    metrics = struct();
    metrics.mean_delta_id_including_WF6 = mean(deltaId, 'omitnan');
    metrics.mean_delta_id_excluding_WF6 = mean(deltaId(notWF6), 'omitnan');
    metrics.mean_delta_val_including_WF6 = mean(deltaVal, 'omitnan');
    metrics.mean_delta_val_excluding_WF6 = mean(deltaVal(notWF6), 'omitnan');
end

function writeExperimentSummary(summaryTxt, cfg, runStamp, commonCsvPath, finalResultsCsv, ...
    commonRegressors, resultsTable, metrics, conceptualNote, testDPDInfo, ...
    tutorPackageInfo)

    fid = fopen(summaryTxt, 'w');
    if fid < 0
        error('Could not create summary file: %s', summaryTxt);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'FULL COMMONK PIPELINE SUMMARY\n');
    fprintf(fid, 'Timestamp: %s\n\n', runStamp);
    fprintf(fid, 'Measurement set:\n%s\n\n', cfg.measurementDirName);
    fprintf(fid, 'Experiment:\n%s\n\n', cfg.experimentName);
    fprintf(fid, 'Input waveform directory:\n%s\n\n', cfg.waveformInputDir);
    fprintf(fid, 'Output directory:\n%s\n\n', cfg.finalOutputDir);
    fprintf(fid, 'Common label: %s\n', cfg.commonLabel);
    fprintf(fid, 'N_common: %d\n', cfg.nCommon);
    fprintf(fid, 'Common criterion: %s >= %g\n', ...
        cfg.commonSupportColumn, cfg.commonSupportThreshold);
    fprintf(fid, 'Correlation threshold: %.6g\n', ...
        cfg.commonCorrelationThreshold);
    fprintf(fid, 'Baseline: POMP200 específico por waveform\n\n');
    fprintf(fid, 'Common regressors CSV:\n%s\n\n', commonCsvPath);
    fprintf(fid, 'Evaluation CSV:\n%s\n\n', finalResultsCsv);
    fprintf(fid, 'Number of common regressors: %d\n\n', height(commonRegressors));
    fprintf(fid, 'Conceptual note:\n%s\n\n', conceptualNote);

    if ~isempty(fieldnames(tutorPackageInfo))
        fprintf(fid, 'Tutor signal package:\n');
        fprintf(fid, 'Package directory: %s\n', tutorPackageInfo.packageDir);
        fprintf(fid, 'ZIP file: %s\n', tutorPackageInfo.zipFile);
        fprintf(fid, 'Specific signals: %d\n', tutorPackageInfo.nSpecificSignals);
        fprintf(fid, 'Common signals: %d\n\n', tutorPackageInfo.nCommonSignals);
    end

    if ~isempty(fieldnames(testDPDInfo))
        fprintf(fid, 'testDPD package:\n');
        fprintf(fid, 'Direct testDPD launch ready: %s\n', ...
            logicalText(testDPDInfo.directLaunchReady));
        fprintf(fid, 'filenamedate: %s\n', testDPDInfo.filenamedate);
        fprintf(fid, 'Package directory: %s\n', testDPDInfo.packageDir);
        fprintf(fid, 'Base experiment file: %s\n', testDPDInfo.baseExperimentMat);
        fprintf(fid, 'XY execution file: %s\n', testDPDInfo.xyExecutionMat);
        fprintf(fid, 'Signal source: %s\n', testDPDInfo.signalSource);
        fprintf(fid, 'Export mode: %s\n', testDPDInfo.exportMode);
        fprintf(fid, 'Number of dpd signals: %d\n', testDPDInfo.nSignals);
        fprintf(fid, 'Command:\n');
        fprintf(fid, 'filenamedate = ''%s'';\n', testDPDInfo.filenamedate);
        fprintf(fid, 'main_testDPD_ADRV_v2060226\n\n');
        if ~testDPDInfo.directLaunchReady
            fprintf(fid, ['This launcher requires experiment files to be ' ...
                'copied to results root.\n']);
            fprintf(fid, ['Set cfg.copyTestDPDPackageToResultsRoot = true ' ...
                'or copy both files manually.\n\n']);
        end
    end

    fprintf(fid, 'Results table:\n');
    fprintf(fid, '%s\n', evalc('disp(resultsTable)'));

    fprintf(fid, '\nDelta summary:\n');
    fprintf(fid, 'mean delta_id including WF6: %.6f dB\n', ...
        metrics.mean_delta_id_including_WF6);
    fprintf(fid, 'mean delta_id excluding WF6: %.6f dB\n', ...
        metrics.mean_delta_id_excluding_WF6);
    fprintf(fid, 'mean delta_val including WF6: %.6f dB\n', ...
        metrics.mean_delta_val_including_WF6);
    fprintf(fid, 'mean delta_val excluding WF6: %.6f dB\n\n', ...
        metrics.mean_delta_val_excluding_WF6);

    fprintf(fid, 'Interpretation:\n');
    fprintf(fid, 'delta = %s - POMP200\n', cfg.commonLabel);
    fprintf(fid, 'delta > 0 implica que %s es peor\n', cfg.commonLabel);
    fprintf(fid, 'delta < 0 implica que %s es mejor\n', cfg.commonLabel);

    clear cleaner
end

function publishLatestAliases(paths, cfg, finalOutputs)
    if ~exist(paths.latestOutputDir, 'dir')
        mkdir(paths.latestOutputDir);
    end

    copyfile(finalOutputs.commonCsv, fullfile(paths.latestOutputDir, ...
        sprintf('latest_%s_regressors.csv', cfg.commonLabel)), 'f');
    copyfile(finalOutputs.commonCsv, fullfile(paths.latestOutputDir, ...
        'latest_common_regressors.csv'), 'f');

    if ~isempty(finalOutputs.evaluationCsv) && exist(finalOutputs.evaluationCsv, 'file')
        copyfile(finalOutputs.evaluationCsv, fullfile(paths.latestOutputDir, ...
            sprintf('latest_%s_vs_pomp200_all8.csv', cfg.commonLabel)), 'f');
        copyfile(finalOutputs.evaluationCsv, fullfile(paths.latestOutputDir, ...
            'latest_common_vs_pomp200_all8.csv'), 'f');
    end

    if ~isempty(finalOutputs.evaluationMat) && exist(finalOutputs.evaluationMat, 'file')
        copyfile(finalOutputs.evaluationMat, fullfile(paths.latestOutputDir, ...
            sprintf('latest_%s_vs_pomp200_all8.mat', cfg.commonLabel)), 'f');
    end

    copyfile(finalOutputs.labPackageMat, fullfile(paths.latestOutputDir, ...
        'latest_lab_package.mat'), 'f');
    copyfile(finalOutputs.summaryTxt, fullfile(paths.latestOutputDir, ...
        'latest_summary.txt'), 'f');
    copyfile(finalOutputs.manifestCsv, fullfile(paths.latestOutputDir, ...
        'latest_manifest.csv'), 'f');
end

function text = logicalText(value)
    if value
        text = 'true';
    else
        text = 'false';
    end
end

function S = rmfieldIfPresent(S, fieldsToRemove)
    for i = 1:numel(fieldsToRemove)
        if isfield(S, fieldsToRemove{i})
            S = rmfield(S, fieldsToRemove{i});
        end
    end
end

function relPath = relativeToRepo(absPath, repoRoot)
    prefix = [repoRoot filesep];
    if startsWith(absPath, prefix)
        relPath = strrep(absPath, prefix, '');
    else
        relPath = absPath;
    end
end

function copied = copyIfExists(copied, sourcePath, destinationDir)
    if isempty(sourcePath) || ~exist(sourcePath, 'file')
        return;
    end

    [~, name, ext] = fileparts(sourcePath);
    destinationPath = fullfile(destinationDir, [name ext]);
    copyfile(sourcePath, destinationPath);
    copied(end + 1, :) = {sourcePath, destinationPath}; %#ok<AGROW>
end
