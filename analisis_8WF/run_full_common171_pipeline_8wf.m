% Master pipeline for the full analisis_8WF common171 workflow.
%
% Run from anywhere:
%   run('analisis_8WF/run_full_common171_pipeline_8wf.m')
%
% This script orchestrates the already validated scripts. It deliberately
% avoids duplicating their numerical logic. Child scripts are executed through
% a local function so their clearvars calls do not clear this master script.

clearvars;
clc;

%% ===================== USER CONFIG =====================

cfg.forceRecomputeComposite = true;    % Regenerate the composite models 
cfg.forceRecomputeCommonModel = true;  % and the common model from scratch

cfg.runSpecific300Evaluation = false;
cfg.runTutorPOMP200Evaluation = true;
cfg.createLabPackage = true;

cfg.measurementDirName = 'ILC_8waveforms_20260624';

cfg.idStart = 1;
cfg.rawIdSamples = 10100;
cfg.valStart = cfg.idStart + cfg.rawIdSamples;
cfg.valLength = 10100;

cfg.lambda = 1e-5;
cfg.diagLoad = 1e-12;
cfg.alpha = 1/(1+cfg.lambda);
cfg.Qpmax = 50;
cfg.Qnmax = 50;
cfg.commonModelName = 'common171';

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

originalDir = pwd;
cleanupDir = onCleanup(@() cd(originalDir));
cd(repoRoot);
setappdata(0, 'analisis8WF_pipeline_cfg', cfg);
cleanupPipelineCfg = onCleanup(@() clearPipelineConfigAppdata());

addRequiredPaths(repoRoot);
waveformFiles = verifyWaveformFiles(paths.inputWaveformDir);

fprintf('\n=== Full common171 8WF pipeline ===\n');
fprintf('Repo root: %s\n', repoRoot);
fprintf('Measurement set: %s\n', cfg.measurementDirName);
fprintf('Waveform input directory: %s\n', cfg.waveformInputDir);
fprintf('Waveforms found: %d\n', numel(waveformFiles));
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

if cfg.forceRecomputeCommonModel || isempty(findLatestCommon171Candidate(paths.pairwiseCommonDir))
    stageRows = runStage(stageRows, 'build_common171_from_composite', ...
        paths.buildCommonScript);
    [stableCommonCsv, commonCsvSource] = ensureStableCommonCsv(paths, cfg, runStamp);
else
    [stableCommonCsv, commonCsvSource] = ensureStableCommonCsv(paths, cfg, runStamp);
    fprintf('\n[SKIP] build_common171_from_composite: campaign common CSV already exists.\n');
    stageRows = appendStage(stageRows, 'build_common171_from_composite', ...
        'skipped', 'Campaign common CSV already exists', paths.buildCommonScript);
end

if cfg.runSpecific300Evaluation
    stageRows = runStage(stageRows, 'eval_common171_vs_specific300_all8', ...
        paths.evalSpecific300Script);
else
    fprintf('\n[SKIP] eval_common171_vs_specific300_all8: disabled by cfg.\n');
    stageRows = appendStage(stageRows, 'eval_common171_vs_specific300_all8', ...
        'skipped', 'Disabled by cfg.runSpecific300Evaluation', ...
        paths.evalSpecific300Script);
end

if cfg.runTutorPOMP200Evaluation
    assertTutorPomp200Defaults(cfg);
    stageRows = runStage(stageRows, 'eval_common171_vs_pomp200_all8', ...
        paths.evalPomp200Script);
else
    fprintf('\n[SKIP] eval_common171_vs_pomp200_all8: disabled by cfg.\n');
    stageRows = appendStage(stageRows, 'eval_common171_vs_pomp200_all8', ...
        'skipped', 'Disabled by cfg.runTutorPOMP200Evaluation', ...
        paths.evalPomp200Script);
end

finalResultsCsv = findLatestFile(paths.evaluationResultsDir, ...
    'common171_vs_pomp200_all8_*.csv');
finalResultsMat = findLatestFile(paths.evaluationResultsDir, ...
    'common171_vs_pomp200_all8_*.mat');
specific300Csv = findLatestFile(paths.evaluationResultsDir, ...
    'common171_vs_composite_vs_gvg_ID_VAL_summary_*.csv');

pipelineSummaryCsv = fullfile(paths.evaluationResultsDir, sprintf( ...
    'full_common171_pipeline_8wf_%s_%s.csv', cfg.measurementTag, runStamp));
stageTable = cell2table(stageRows, 'VariableNames', ...
    {'stage', 'status', 'detail', 'script'});
writetable(stageTable, pipelineSummaryCsv);

labPackageDir = '';
if cfg.createLabPackage
    labPackageDir = createLabPackage(paths, cfg, runStamp, stableCommonCsv, ...
        commonCsvSource, finalResultsCsv, finalResultsMat, specific300Csv, ...
        pipelineSummaryCsv);
end

stableOutputs = publishStableFullPipelineOutputs(paths, cfg, runStamp, ...
    repoRoot, waveformFiles, stableCommonCsv, finalResultsCsv);

fprintf('\n=== Pipeline summary ===\n');
fprintf('Stable common CSV:\n  %s\n', stableCommonCsv);
if ~isempty(finalResultsCsv)
    fprintf('Final common171 vs POMP200 CSV:\n  %s\n', finalResultsCsv);
else
    fprintf('Final common171 vs POMP200 CSV: not found\n');
end
fprintf('Pipeline stage log:\n  %s\n', pipelineSummaryCsv);
if ~isempty(labPackageDir)
    fprintf('Lab package:\n  %s\n', labPackageDir);
end

fprintf('\nFULL COMMON171 PIPELINE FINISHED\n\n');
fprintf('Final common model:\n');
fprintf('%s\n\n', relativeToRepo(stableOutputs.commonCsv, repoRoot));
fprintf('Final evaluation:\n');
fprintf('%s\n\n', relativeToRepo(stableOutputs.evaluationCsv, repoRoot));
fprintf('Lab package:\n');
fprintf('%s\n\n', relativeToRepo(stableOutputs.labPackageMat, repoRoot));
fprintf('Summary:\n');
fprintf('%s\n', relativeToRepo(stableOutputs.summaryTxt, repoRoot));

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
    cfg.finalOutputDir = fullfile(repoRoot, 'results', ...
        'common171_full_pipeline', cfg.measurementDirName);
    cfg.compositeResultsDir = fullfile(repoRoot, 'results', ...
        ['composite_selection_' cfg.measurementTag]);
    cfg.evaluationResultsDir = fullfile(repoRoot, 'results', ...
        'common_composite_model_evaluation', cfg.measurementTag);
end

function tag = makeSafeFileTag(value)
    tag = regexprep(char(value), '[^\w.-]', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');
    if isempty(tag)
        tag = 'measurement_set';
    end
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
    paths.evaluationResultsDir = cfg.evaluationResultsDir;
    paths.fullPipelineDir = cfg.finalOutputDir;
    paths.pairwiseCommonDir = fullfile(paths.compositeResultsDir, ...
        'pairwise_common_structure');

    paths.runCompositeScript = fullfile(analysisDir, ...
        '01_generacion_modelos', 'run_composite_8wf.m');
    paths.runGvgScript = fullfile(analysisDir, ...
        '01_generacion_modelos', 'run_gvg_8wf.m');
    paths.buildCommonScript = fullfile(analysisDir, ...
        '02_modelo_comun', 'build_common171_from_composite.m');
    paths.stableCommonCsv = fullfile(analysisDir, ...
        '02_modelo_comun', [cfg.commonModelName '_regressors.csv']);
    paths.evalSpecific300Script = fullfile(analysisDir, ...
        '03_evaluacion', 'eval_common171_vs_specific300_all8.m');
    paths.evalTutorWf5Script = fullfile(analysisDir, ...
        '03_evaluacion', 'eval_tutor_pomp200_wf5.m');
    paths.evalCommonTutorWf5Script = fullfile(analysisDir, ...
        '03_evaluacion', 'eval_common171_tutor_method_wf5.m');
    paths.evalPomp200Script = fullfile(analysisDir, ...
        '03_evaluacion', 'eval_common171_vs_pomp200_all8.m');
    paths.readme = fullfile(analysisDir, 'README_ANALISIS_8WF.md');
    paths.masterScript = fullfile(analysisDir, 'run_full_common171_pipeline_8wf.m');

    if ~exist(paths.evaluationResultsDir, 'dir')
        mkdir(paths.evaluationResultsDir);
    end
    if ~exist(paths.fullPipelineDir, 'dir')
        mkdir(paths.fullPipelineDir);
    end
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

function [stableCommonCsv, sourceCsv] = ensureStableCommonCsv(paths, cfg, runStamp)
    stableCommonCsv = paths.stableCommonCsv;
    sourceCsv = findLatestCommon171Candidate(paths.pairwiseCommonDir);

    if isempty(sourceCsv)
        if exist(stableCommonCsv, 'file')
            warning('No new common171 candidate found. Keeping stable CSV: %s', ...
                stableCommonCsv);
            sourceCsv = stableCommonCsv;
            return;
        end
        error('No common171 candidate found and stable CSV is missing: %s', ...
            stableCommonCsv);
    end

    if exist(stableCommonCsv, 'file')
        backupCsv = strrep(stableCommonCsv, '.csv', ...
            sprintf('_backup_%s.csv', runStamp));
        copyfile(stableCommonCsv, backupCsv);
    end

    copyfile(sourceCsv, stableCommonCsv, 'f');
    fprintf('\nStable %s CSV updated:\n  source: %s\n  target: %s\n', ...
        cfg.commonModelName, sourceCsv, stableCommonCsv);
end

function csvPath = findLatestCommon171Candidate(pairwiseCommonDir)
    csvPath = '';
    files = dir(fullfile(pairwiseCommonDir, ...
        '*common_structure_thr095_*.csv'));
    if isempty(files)
        return;
    end

    [~, order] = sort([files.datenum], 'descend');
    files = files(order);

    for i = 1:numel(files)
        candidate = fullfile(files(i).folder, files(i).name);
        try
            T = readtable(candidate);
            if height(T) == 171
                csvPath = candidate;
                return;
            end
        catch
            % Keep looking for another candidate.
        end
    end
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
                'Update eval_common171_vs_pomp200_all8.m to accept overrides ' ...
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

function labPackageDir = createLabPackage(paths, cfg, runStamp, stableCommonCsv, ...
    commonCsvSource, finalResultsCsv, finalResultsMat, specific300Csv, ...
    pipelineSummaryCsv)

    labPackageDir = fullfile(paths.evaluationResultsDir, sprintf( ...
        'lab_package_%s_%s_%s', cfg.commonModelName, ...
        cfg.measurementTag, runStamp));
    if ~exist(labPackageDir, 'dir')
        mkdir(labPackageDir);
    end

    copied = cell(0, 2);
    copied = copyIfExists(copied, stableCommonCsv, labPackageDir);
    copied = copyIfExists(copied, commonCsvSource, labPackageDir);
    copied = copyIfExists(copied, finalResultsCsv, labPackageDir);
    copied = copyIfExists(copied, finalResultsMat, labPackageDir);
    copied = copyIfExists(copied, specific300Csv, labPackageDir);
    copied = copyIfExists(copied, pipelineSummaryCsv, labPackageDir);
    copied = copyIfExists(copied, paths.readme, labPackageDir);
    copied = copyIfExists(copied, paths.masterScript, labPackageDir);

    manifestCsv = fullfile(labPackageDir, 'lab_package_manifest.csv');
    manifest = cell2table(copied, 'VariableNames', {'sourceFile', 'packageFile'});
    writetable(manifest, manifestCsv);

    readmePath = fullfile(labPackageDir, 'README_LAB_PACKAGE.txt');
    fid = fopen(readmePath, 'w');
    if fid < 0
        error('Could not create lab package README: %s', readmePath);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, 'Lab package for %s 8WF pipeline\n', cfg.commonModelName);
    fprintf(fid, 'Generated: %s\n\n', runStamp);
    fprintf(fid, 'Measurement set:\n%s\n\n', cfg.measurementDirName);
    fprintf(fid, 'Stable common CSV source:\n%s\n\n', stableCommonCsv);
    fprintf(fid, 'Final evaluation CSV:\n%s\n\n', finalResultsCsv);
    fprintf(fid, 'Pipeline summary CSV:\n%s\n', pipelineSummaryCsv);
    clear cleaner
end

function stableOutputs = publishStableFullPipelineOutputs(paths, cfg, runStamp, ...
    repoRoot, waveformFiles, stableCommonCsv, finalResultsCsv)

    if isempty(finalResultsCsv) || ~exist(finalResultsCsv, 'file')
        error('Final POMP200 evaluation CSV not found. Expected latest file from eval_common171_vs_pomp200_all8.m.');
    end
    if ~exist(stableCommonCsv, 'file')
        error('Stable common regressors CSV not found: %s', stableCommonCsv);
    end

    stableOutputs = struct();
    stableOutputs.commonCsv = fullfile(paths.fullPipelineDir, ...
        'latest_common171_regressors.csv');
    stableOutputs.evaluationCsv = fullfile(paths.fullPipelineDir, ...
        'latest_common171_vs_pomp200_all8.csv');
    stableOutputs.labPackageMat = fullfile(paths.fullPipelineDir, ...
        'latest_common171_lab_package.mat');
    stableOutputs.summaryTxt = fullfile(paths.fullPipelineDir, ...
        'latest_summary.txt');

    copyfile(stableCommonCsv, stableOutputs.commonCsv, 'f');
    copyfile(finalResultsCsv, stableOutputs.evaluationCsv, 'f');

    if ~exist(stableOutputs.evaluationCsv, 'file')
        error('Stable evaluation CSV was not created: %s', stableOutputs.evaluationCsv);
    end

    commonRegressors = readtable(stableOutputs.commonCsv, ...
        'VariableNamingRule', 'preserve', 'TextType', 'char');
    if height(commonRegressors) ~= 171
        error('latest_common171_regressors.csv must contain exactly 171 rows; found %d.', ...
            height(commonRegressors));
    end

    resultsTable = readtable(stableOutputs.evaluationCsv, ...
        'VariableNamingRule', 'preserve', 'TextType', 'char');
    metrics = computeDeltaMetrics(resultsTable);

    conceptualNote = ['Common171 fija una estructura común de 171 regresores. ' ...
        'Los coeficientes deben estimarse para cada waveform/dataset de laboratorio usando esta estructura.'];

    commonCsvPath = stableOutputs.commonCsv;
    finalResultsCsv = stableOutputs.evaluationCsv; %#ok<NASGU>
    save(stableOutputs.labPackageMat, 'cfg', 'runStamp', 'repoRoot', ...
        'waveformFiles', 'commonCsvPath', 'finalResultsCsv', 'resultsTable', ...
        'commonRegressors', 'conceptualNote', 'metrics', '-v7.3');

    writeStableSummary(stableOutputs.summaryTxt, cfg, runStamp, commonCsvPath, ...
        finalResultsCsv, commonRegressors, resultsTable, metrics, conceptualNote);
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

function writeStableSummary(summaryTxt, cfg, runStamp, commonCsvPath, finalResultsCsv, ...
    commonRegressors, resultsTable, metrics, conceptualNote)

    fid = fopen(summaryTxt, 'w');
    if fid < 0
        error('Could not create summary file: %s', summaryTxt);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'FULL COMMON171 PIPELINE SUMMARY\n');
    fprintf(fid, 'Timestamp: %s\n\n', runStamp);
    fprintf(fid, 'Measurement set:\n%s\n\n', cfg.measurementDirName);
    fprintf(fid, 'Input waveform directory:\n%s\n\n', cfg.waveformInputDir);
    fprintf(fid, 'Output directory:\n%s\n\n', cfg.finalOutputDir);
    fprintf(fid, 'Common regressors CSV:\n%s\n\n', commonCsvPath);
    fprintf(fid, 'Evaluation CSV:\n%s\n\n', finalResultsCsv);
    fprintf(fid, 'Number of common regressors: %d\n\n', height(commonRegressors));
    fprintf(fid, 'Conceptual note:\n%s\n\n', conceptualNote);

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
    fprintf(fid, 'delta = Common171 - POMP200\n');
    fprintf(fid, 'delta > 0 implica que Common171 es peor\n');
    fprintf(fid, 'delta < 0 implica que Common171 es mejor\n');

    clear cleaner
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
