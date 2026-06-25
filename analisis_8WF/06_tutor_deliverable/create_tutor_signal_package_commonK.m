% Create the tutor signal deliverable from the CommonK evaluation output.
%
% This script is called by run_full_commonK_pipeline_8wf.m. It does not run
% hardware and does not execute MATLAB measurements.

clearvars;
clc;

%% ===================== MAIN LOGIC =====================

cfg = getPipelineConfig();
if isempty(fieldnames(cfg))
    error('Missing analisis8WF_pipeline_cfg. Run the master CommonK pipeline.');
end

requiredFields = {'runOutputDir', 'latestOutputDir', 'finalEvaluationMat', ...
    'measurementDirName', 'measurementTag', 'experimentName', 'runStamp', ...
    'commonLabel', 'nCommon', 'commonSupportThreshold', 'commonThresholdTag', ...
    'Qpmax', 'Qnmax'};
for i = 1:numel(requiredFields)
    if ~isfield(cfg, requiredFields{i}) || isempty(cfg.(requiredFields{i}))
        error('Missing cfg.%s for tutor signal package creation.', requiredFields{i});
    end
end

if ~exist(cfg.finalEvaluationMat, 'file')
    error('CommonK evaluation MAT not found: %s', cfg.finalEvaluationMat);
end

packageDir = fullfile(cfg.runOutputDir, 'tutor_signal_package');
latestPackageDir = fullfile(cfg.latestOutputDir, 'tutor_signal_package');
ensureDir(packageDir);
ensureDir(latestPackageDir);

E = load(cfg.finalEvaluationMat, 'yhatValPOMP200', 'yhatIdPOMP200', ...
    'yhatValCommonK', 'yhatIdCommonK', 'configuration');
requireLoadedField(E, 'yhatValPOMP200', cfg.finalEvaluationMat);
requireLoadedField(E, 'yhatValCommonK', cfg.finalEvaluationMat);
if numel(E.yhatValPOMP200) ~= numel(E.yhatValCommonK)
    error(['Evaluation MAT has different numbers of POMP200 and CommonK ' ...
        'validation signals: %d vs %d.'], numel(E.yhatValPOMP200), ...
        numel(E.yhatValCommonK));
end

waveforms = 1:numel(E.yhatValCommonK);
edgeLoss = cfg.Qpmax + cfg.Qnmax;

specificSignals = buildSpecificSignals(E.yhatValPOMP200, cfg, waveforms);
commonSignals = buildCommonSignals(E.yhatValCommonK, cfg, waveforms);
signalPackageMetadata = buildMetadata(cfg, edgeLoss);
manifest = buildManifest(specificSignals, commonSignals, cfg, edgeLoss);

specificMat = fullfile(packageDir, 'signals_specific_POMP200.mat');
commonMat = fullfile(packageDir, 'signals_common_CommonK.mat');
combinedMat = fullfile(packageDir, 'signals_combined_specific_and_common.mat');
manifestCsv = fullfile(packageDir, 'tutor_signal_manifest.csv');
summaryTxt = fullfile(packageDir, 'tutor_signal_package_summary.txt');
packageReadme = fullfile(packageDir, 'README_tutor_signal_package.md');

save(specificMat, 'specificSignals', 'signalPackageMetadata', '-v7.3');
save(commonMat, 'commonSignals', 'signalPackageMetadata', '-v7.3');
save(combinedMat, 'specificSignals', 'commonSignals', ...
    'signalPackageMetadata', '-v7.3');
writetable(manifest, manifestCsv);
writePackageReadme(packageReadme, cfg);

maxZipMatBytes = getCfgField(cfg, 'tutorPackageMaxZipMatBytes', ...
    100 * 1024 * 1024);
zipReport = createPackageZip(packageDir, cfg, maxZipMatBytes, ...
    {packageReadme, manifestCsv, summaryTxt, specificMat, commonMat, combinedMat});
writeSummary(summaryTxt, cfg, packageDir, manifest, zipReport, ...
    specificMat, commonMat, combinedMat, packageReadme, manifestCsv);

% Rebuild zip after the summary has its final content.
zipReport = createPackageZip(packageDir, cfg, maxZipMatBytes, ...
    {packageReadme, manifestCsv, summaryTxt, specificMat, commonMat, combinedMat});
writeSummary(summaryTxt, cfg, packageDir, manifest, zipReport, ...
    specificMat, commonMat, combinedMat, packageReadme, manifestCsv);
% Keep the ZIP copy of the summary aligned with the final summary text.
zipReport = createPackageZip(packageDir, cfg, maxZipMatBytes, ...
    {packageReadme, manifestCsv, summaryTxt, specificMat, commonMat, combinedMat});

copyfile(packageReadme, fullfile(latestPackageDir, 'README_tutor_signal_package.md'), 'f');
copyfile(manifestCsv, fullfile(latestPackageDir, 'tutor_signal_manifest.csv'), 'f');
copyfile(summaryTxt, fullfile(latestPackageDir, 'tutor_signal_package_summary.txt'), 'f');
copyfile(specificMat, fullfile(latestPackageDir, 'signals_specific_POMP200.mat'), 'f');
copyfile(commonMat, fullfile(latestPackageDir, 'signals_common_CommonK.mat'), 'f');
copyfile(combinedMat, fullfile(latestPackageDir, ...
    'signals_combined_specific_and_common.mat'), 'f');
if ~isempty(zipReport.zipFile) && exist(zipReport.zipFile, 'file')
    [~, zipName, zipExt] = fileparts(zipReport.zipFile);
    copyfile(zipReport.zipFile, fullfile(latestPackageDir, ...
        [zipName zipExt]), 'f');
end

tutorPackageInfo = struct();
tutorPackageInfo.packageDir = packageDir;
tutorPackageInfo.latestPackageDir = latestPackageDir;
tutorPackageInfo.zipFile = zipReport.zipFile;
tutorPackageInfo.manifestCsv = manifestCsv;
tutorPackageInfo.summaryTxt = summaryTxt;
tutorPackageInfo.specificMat = specificMat;
tutorPackageInfo.commonMat = commonMat;
tutorPackageInfo.combinedMat = combinedMat;
tutorPackageInfo.nSpecificSignals = numel(specificSignals);
tutorPackageInfo.nCommonSignals = numel(commonSignals);
tutorPackageInfo.nManifestRows = height(manifest);
setappdata(0, 'analisis8WF_tutor_package_info', tutorPackageInfo);

fprintf('\n=== Tutor signal package ===\n');
fprintf('Package directory: %s\n', packageDir);
fprintf('Specific signals: %d\n', tutorPackageInfo.nSpecificSignals);
fprintf('Common signals: %d\n', tutorPackageInfo.nCommonSignals);
fprintf('ZIP: %s\n', tutorPackageInfo.zipFile);

%% ===================== LOCAL FUNCTIONS =====================

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

function requireLoadedField(S, fieldName, sourceFile)
    if ~isfield(S, fieldName)
        error('Evaluation MAT lacks %s: %s', fieldName, sourceFile);
    end
end

function specificSignals = buildSpecificSignals(yhatValPOMP200, cfg, waveforms)
    specificSignals = repmat(baseSignalStruct(), numel(waveforms), 1);
    for i = 1:numel(waveforms)
        wf = waveforms(i);
        y = yhatValPOMP200{wf};
        validateSignal(y, sprintf('yhatValPOMP200{%d}', wf));
        specificSignals(i).waveformIndex = wf;
        specificSignals(i).modelFamily = 'specific_POMP200';
        specificSignals(i).modeltype = sprintf('POMP200_specific_WF%02d', wf);
        specificSignals(i).yvalmod = y(:);
        specificSignals(i).sourceVariable = 'yhatValPOMP200';
        specificSignals(i).commonLabel = '';
        specificSignals(i).nCommon = NaN;
        specificSignals(i).nSamples = numel(y);
        specificSignals(i).rmsValue = sqrt(mean(abs(y(:)).^2));
        specificSignals(i).paprDb = calcPaprDb(y);
        specificSignals(i).measurementDirName = cfg.measurementDirName;
        specificSignals(i).experimentName = cfg.experimentName;
        specificSignals(i).runStamp = cfg.runStamp;
    end
end

function commonSignals = buildCommonSignals(yhatValCommonK, cfg, waveforms)
    commonSignals = repmat(baseSignalStruct(), numel(waveforms), 1);
    for i = 1:numel(waveforms)
        wf = waveforms(i);
        y = yhatValCommonK{wf};
        validateSignal(y, sprintf('yhatValCommonK{%d}', wf));
        commonSignals(i).waveformIndex = wf;
        commonSignals(i).modelFamily = 'common_CommonK';
        commonSignals(i).modeltype = sprintf('%s_struct_ge%d_%s_WF%02d', ...
            cfg.commonLabel, cfg.commonSupportThreshold, ...
            cfg.commonThresholdTag, wf);
        commonSignals(i).yvalmod = y(:);
        commonSignals(i).sourceVariable = 'yhatValCommonK';
        commonSignals(i).commonLabel = cfg.commonLabel;
        commonSignals(i).nCommon = cfg.nCommon;
        commonSignals(i).nSamples = numel(y);
        commonSignals(i).rmsValue = sqrt(mean(abs(y(:)).^2));
        commonSignals(i).paprDb = calcPaprDb(y);
        commonSignals(i).measurementDirName = cfg.measurementDirName;
        commonSignals(i).experimentName = cfg.experimentName;
        commonSignals(i).runStamp = cfg.runStamp;
    end
end

function S = baseSignalStruct()
    S = struct('waveformIndex', NaN, ...
        'modelFamily', '', ...
        'modeltype', '', ...
        'yvalmod', [], ...
        'sourceVariable', '', ...
        'commonLabel', '', ...
        'nCommon', NaN, ...
        'nSamples', NaN, ...
        'rmsValue', NaN, ...
        'paprDb', NaN, ...
        'measurementDirName', '', ...
        'experimentName', '', ...
        'runStamp', '');
end

function metadata = buildMetadata(cfg, edgeLoss)
    metadata = struct();
    metadata.createdBy = mfilename;
    metadata.createdAt = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
    metadata.measurementDirName = cfg.measurementDirName;
    metadata.measurementTag = cfg.measurementTag;
    metadata.experimentName = cfg.experimentName;
    metadata.runStamp = cfg.runStamp;
    metadata.commonLabel = cfg.commonLabel;
    metadata.nCommon = cfg.nCommon;
    metadata.edgeLoss = edgeLoss;
    metadata.specificSourceVariable = 'yhatValPOMP200';
    metadata.commonSourceVariable = 'yhatValCommonK';
    metadata.warning = ['Signals are validation predictions reconstructed by ' ...
        'the models. Confirm block convention before lab injection.'];
end

function manifest = buildManifest(specificSignals, commonSignals, cfg, edgeLoss)
    allSignals = [specificSignals(:); commonSignals(:)];
    nRows = numel(allSignals);
    waveformIndex = NaN(nRows, 1);
    modelFamily = cell(nRows, 1);
    modeltype = cell(nRows, 1);
    sourceVariable = cell(nRows, 1);
    nSamples = NaN(nRows, 1);
    rmsValue = NaN(nRows, 1);
    paprDb = NaN(nRows, 1);
    edgeLoss = repmat(edgeLoss, nRows, 1);
    measurementDirName = repmat({cfg.measurementDirName}, nRows, 1);
    experimentName = repmat({cfg.experimentName}, nRows, 1);
    runStamp = repmat({cfg.runStamp}, nRows, 1);
    commonLabel = cell(nRows, 1);
    nCommon = NaN(nRows, 1);

    for i = 1:nRows
        signal = allSignals(i);
        waveformIndex(i) = signal.waveformIndex;
        modelFamily{i} = signal.modelFamily;
        modeltype{i} = signal.modeltype;
        sourceVariable{i} = signal.sourceVariable;
        nSamples(i) = signal.nSamples;
        rmsValue(i) = signal.rmsValue;
        paprDb(i) = signal.paprDb;
        commonLabel{i} = signal.commonLabel;
        nCommon(i) = signal.nCommon;
    end

    manifest = table(waveformIndex, modelFamily, modeltype, sourceVariable, ...
        nSamples, rmsValue, paprDb, edgeLoss, measurementDirName, ...
        experimentName, runStamp, commonLabel, nCommon);
end

function validateSignal(y, label)
    if ~(isnumeric(y) && isvector(y) && all(isfinite(y(:))))
        error('%s must be a finite numeric vector.', label);
    end
    if isempty(y)
        error('%s is empty.', label);
    end
end

function paprDb = calcPaprDb(y)
    y = y(:);
    powerValue = mean(abs(y).^2);
    paprDb = 10 * log10(max(abs(y).^2) / powerValue);
end

function zipReport = createPackageZip(packageDir, cfg, maxZipMatBytes, files)
    zipFile = fullfile(packageDir, sprintf( ...
        'tutor_signal_package_%s_%s_%s.zip', cfg.measurementTag, ...
        makeSafeFileTag(cfg.experimentName), cfg.runStamp));
    filesForZip = {};
    skippedFiles = {};
    skippedReasons = {};

    for i = 1:numel(files)
        filePath = files{i};
        if isempty(filePath) || exist(filePath, 'file') ~= 2
            continue;
        end
        [~, ~, ext] = fileparts(filePath);
        info = dir(filePath);
        if strcmpi(ext, '.mat') && info.bytes > maxZipMatBytes
            skippedFiles{end + 1, 1} = filePath; %#ok<AGROW>
            skippedReasons{end + 1, 1} = sprintf( ...
                'MAT larger than %.1f MB', maxZipMatBytes / 1024 / 1024); %#ok<AGROW>
        else
            [~, name, fileExt] = fileparts(filePath);
            filesForZip{end + 1, 1} = [name fileExt]; %#ok<AGROW>
        end
    end

    if ~isempty(filesForZip)
        zip(zipFile, filesForZip, packageDir);
    else
        zipFile = '';
    end

    zipReport = struct();
    zipReport.zipFile = zipFile;
    zipReport.filesIncluded = filesForZip;
    zipReport.skippedFiles = skippedFiles;
    zipReport.skippedReasons = skippedReasons;
    zipReport.maxZipMatBytes = maxZipMatBytes;
end

function writeSummary(summaryTxt, cfg, packageDir, manifest, zipReport, ...
    specificMat, commonMat, combinedMat, packageReadme, manifestCsv)
    fid = fopen(summaryTxt, 'w');
    if fid < 0
        error('Could not create summary: %s', summaryTxt);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'Tutor signal package summary\n');
    fprintf(fid, 'Measurement: %s\n', cfg.measurementDirName);
    fprintf(fid, 'Experiment: %s\n', cfg.experimentName);
    fprintf(fid, 'Run stamp: %s\n', cfg.runStamp);
    fprintf(fid, 'Common label: %s\n', cfg.commonLabel);
    fprintf(fid, 'N_common: %d\n', cfg.nCommon);
    fprintf(fid, 'Package directory: %s\n', packageDir);
    fprintf(fid, 'Specific signals: %d\n', ...
        sum(strcmp(manifest.modelFamily, 'specific_POMP200')));
    fprintf(fid, 'Common signals: %d\n', ...
        sum(strcmp(manifest.modelFamily, 'common_CommonK')));
    fprintf(fid, 'Total manifest rows: %d\n\n', height(manifest));
    fprintf(fid, 'Files:\n');
    fprintf(fid, 'README: %s\n', packageReadme);
    fprintf(fid, 'Manifest: %s\n', manifestCsv);
    fprintf(fid, 'Specific MAT: %s\n', specificMat);
    fprintf(fid, 'Common MAT: %s\n', commonMat);
    fprintf(fid, 'Combined MAT: %s\n', combinedMat);
    fprintf(fid, 'ZIP: %s\n\n', zipReport.zipFile);
    fprintf(fid, 'ZIP included files:\n');
    for i = 1:numel(zipReport.filesIncluded)
        fprintf(fid, '- %s\n', zipReport.filesIncluded{i});
    end
    if ~isempty(zipReport.skippedFiles)
        fprintf(fid, '\nFiles skipped from ZIP due to size:\n');
        for i = 1:numel(zipReport.skippedFiles)
            fprintf(fid, '- %s (%s)\n', zipReport.skippedFiles{i}, ...
                zipReport.skippedReasons{i});
        end
    end
    fprintf(fid, ['\nWarning: signals are validation predictions ' ...
        'reconstructed by the models. Confirm block convention before ' ...
        'lab injection.\n']);

    clear cleaner
end

function writePackageReadme(readmePath, cfg)
    fid = fopen(readmePath, 'w');
    if fid < 0
        error('Could not create README: %s', readmePath);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '# Tutor Signal Package\n\n');
    fprintf(fid, 'Generated by the CommonK pipeline.\n\n');
    fprintf(fid, '- Measurement: `%s`\n', cfg.measurementDirName);
    fprintf(fid, '- Experiment: `%s`\n', cfg.experimentName);
    fprintf(fid, '- Common model: `%s` (`nCommon = %d`)\n', ...
        cfg.commonLabel, cfg.nCommon);
    fprintf(fid, '- Specific model family: `specific_POMP200`\n');
    fprintf(fid, '- Common model family: `common_CommonK`\n\n');
    fprintf(fid, '## Signal Sources\n\n');
    fprintf(fid, '- Specific signals use `yhatValPOMP200{wf}`.\n');
    fprintf(fid, '- Common signals use `yhatValCommonK{wf}`.\n\n');
    fprintf(fid, ['These are validation predictions reconstructed by the ' ...
        'models. Confirm block convention before final lab injection.\n\n']);
    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `signals_specific_POMP200.mat` contains `specificSignals`.\n');
    fprintf(fid, '- `signals_common_CommonK.mat` contains `commonSignals`.\n');
    fprintf(fid, ['- `signals_combined_specific_and_common.mat` contains ' ...
        '`specificSignals`, `commonSignals`, and `signalPackageMetadata`.\n']);
    fprintf(fid, '- `tutor_signal_manifest.csv` has one row per signal.\n');
    fprintf(fid, '- `tutor_signal_package_summary.txt` summarizes the package.\n');

    clear cleaner
end

function tag = makeSafeFileTag(value)
    tag = regexprep(char(value), '[^\w.-]', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');
    if isempty(tag)
        tag = 'experiment';
    end
end
