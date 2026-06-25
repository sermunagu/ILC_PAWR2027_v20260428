%% diagnose_wf6_vs_wf7_gvg.m
% Diagnostic script to compare WF6 and WF7 GVG/composite/modeling metadata.
% Run from anywhere; the repo root is detected from this script location.

clearvars -except repoRoot
clc

scriptFile = mfilename('fullpath');
if isempty(scriptFile)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptFile);
end

repoRoot = detectRepoRoot(scriptDir);

xyDir  = fullfile(repoRoot, 'results', 'ILC_8waveforms');
gvgDir = fullfile(repoRoot, 'results', 'GVG_ILC_8waveforms');
cmpDir = fullfile(repoRoot, 'results', 'composite_selection_ILC_8waveforms');

wf6xyName = 'experiment20260429T192214_xy';
wf7xyName = 'experiment20260429T193745_xy';

wf6XY = fullfile(xyDir, [wf6xyName '.mat']);
wf7XY = fullfile(xyDir, [wf7xyName '.mat']);

wf6GVG = findOne(gvgDir, [wf6xyName '_wf06_GVG_*.mat']);
wf7GVG = findOne(gvgDir, [wf7xyName '_wf07_GVG_*.mat']);

wf6CMP = findOne(cmpDir, [wf6xyName '_wf06_composite_selection_*.mat']);
wf7CMP = findOne(cmpDir, [wf7xyName '_wf07_composite_selection_*.mat']);

fprintf('\n===== FILES =====\n');
fprintf('WF6 XY : %s\n', wf6XY);
fprintf('WF7 XY : %s\n', wf7XY);
fprintf('WF6 GVG: %s\n', wf6GVG);
fprintf('WF7 GVG: %s\n', wf7GVG);
fprintf('WF6 CMP: %s\n', wf6CMP);
fprintf('WF7 CMP: %s\n', wf7CMP);

fprintf('\n===== XY SIGNAL STATS =====\n');
diagnoseXY('WF6', wf6XY);
diagnoseXY('WF7', wf7XY);

fprintf('\n===== GVG .MAT CONTENT =====\n');
fprintf('\nWF6 GVG variables:\n');
whos('-file', wf6GVG)
fprintf('\nWF7 GVG variables:\n');
whos('-file', wf7GVG)

fprintf('\n===== GVG OBJECTS =====\n');
G6 = load(wf6GVG);
G7 = load(wf7GVG);
diagnoseModelStruct('WF6 GVG', G6);
diagnoseModelStruct('WF7 GVG', G7);

fprintf('\n===== COMPOSITE OBJECTS =====\n');
C6 = load(wf6CMP);
C7 = load(wf7CMP);
diagnoseModelStruct('WF6 CMP', C6);
diagnoseModelStruct('WF7 CMP', C7);

fprintf('\n===== CONFIG COMPARISON QUICK =====\n');
compareConfig('GVGconfig', G6, G7);
compareConfig('GVGconfig', C6, C7);

fprintf('\nDone.\n');

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

function path = findOne(folder, pattern)
    files = dir(fullfile(folder, pattern));
    if isempty(files)
        error('No file found for pattern: %s', fullfile(folder, pattern));
    end
    if numel(files) > 1
        fprintf('Warning: multiple files for %s. Using latest by datenum.\n', pattern);
        [~, idx] = max([files.datenum]);
        files = files(idx);
    end
    path = fullfile(files(1).folder, files(1).name);
end

function diagnoseXY(label, xyPath)
    D = load(xyPath);
    x = D.x(:);
    y = D.y(:);

    rawFull = 10*log10(mean(abs(y - x).^2) / mean(abs(y).^2));

    fprintf('\n%s:\n', label);
    fprintf('  description: %s\n', D.description);
    fprintf('  BW/Foff: %.3f / %.3f MHz\n', scalarFirst(D.info_signal.BW)/1e6, scalarFirst(D.info_signal.Foff)/1e6);
    fprintf('  length: %d\n', numel(x));
    fprintf('  raw y-x full: %.3f dB\n', rawFull);
    fprintf('  mean|x| %.6g | mean|y| %.6g\n', mean(abs(x)), mean(abs(y)));
    fprintf('  max |x| %.6g | max |y| %.6g\n', max(abs(x)), max(abs(y)));
    fprintf('  std |x| %.6g | std |y| %.6g\n', std(abs(x)), std(abs(y)));
    fprintf('  PAPR x %.3f dB | PAPR y %.3f dB\n', ...
        10*log10(max(abs(x).^2)/mean(abs(x).^2)), ...
        10*log10(max(abs(y).^2)/mean(abs(y).^2)));
    fprintf('  NaN/Inf x: %d/%d | NaN/Inf y: %d/%d\n', ...
        any(isnan(x)), any(isinf(x)), any(isnan(y)), any(isinf(y)));

    a = x \ y;
    yhat = a*x;
    nmseLin = 10*log10(mean(abs(y - yhat).^2) / mean(abs(y).^2));
    fprintf('  best scalar y~=a*x: %.3f dB\n', nmseLin);
end

function diagnoseModelStruct(label, S)
    fprintf('\n%s:\n', label);

    if isfield(S, 'sourcePath')
        fprintf('  sourcePath: %s\n', S.sourcePath);
    end
    if isfield(S, 'sourceMetadata')
        try
            fprintf('  sourceMetadata.sourcePath: %s\n', S.sourceMetadata.sourcePath);
        catch
        end
    end

    if isfield(S, 'rManager')
        rm = S.rManager;
        try
            fprintf('  rManager.nmse: %.6f dB\n', rm.nmse);
        catch ME
            fprintf('  could not read rManager.nmse: %s\n', ME.message);
        end

        props = properties(rm);
        fprintf('  rManager properties:\n');
        for i = 1:numel(props)
            fprintf('    %s\n', props{i});
        end

        pop = [];
        popName = '';
        candidateProps = {'regPopulation','regressorPopulation','population','RegPopulation'};
        for i = 1:numel(candidateProps)
            if isprop(rm, candidateProps{i})
                try
                    pop = rm.(candidateProps{i});
                    popName = candidateProps{i};
                    break;
                catch
                end
            end
        end

        if ~isempty(popName)
            fprintf('  selected population property: %s\n', popName);
            fprintf('  numel population: %d\n', numel(pop));
            fprintf('  first 10 regressors:\n');
            for k = 1:min(10, numel(pop))
                disp(pop(k))
            end
        else
            fprintf('  no accessible population property found in rManager.\n');
        end
    else
        fprintf('  no rManager field found.\n');
    end

    if isfield(S, 'regPopulation')
        fprintf('  top-level regPopulation numel: %d\n', numel(S.regPopulation));
    end
    if isfield(S, 'nmseid')
        fprintf('  nmseid final/min: %.6f / %.6f dB\n', S.nmseid(end), min(S.nmseid));
    end
    if isfield(S, 'nmsevalv')
        fprintf('  nmsevalv: ');
        fprintf('%.3f ', S.nmsevalv);
        fprintf('\n');
    end
    if isfield(S, 'perc')
        fprintf('  perc: %.6g\n', S.perc);
    end
    if isfield(S, 'nid')
        fprintf('  nid length: %d | first/last: %d/%d\n', numel(S.nid), S.nid(1), S.nid(end));
    end
end

function compareConfig(fieldName, A, B)
    if ~isfield(A, fieldName) || ~isfield(B, fieldName)
        fprintf('%s not present in both structs.\n', fieldName);
        return
    end

    fprintf('\nComparing %s fields present in both:\n', fieldName);
    ca = A.(fieldName);
    cb = B.(fieldName);
    fa = fieldnames(ca);
    fb = fieldnames(cb);
    f = intersect(fa, fb);

    for i = 1:numel(f)
        va = ca.(f{i});
        vb = cb.(f{i});
        same = isequaln(va, vb);
        if ~same
            fprintf('  DIFF %s: ', f{i});
            printCompact(va);
            fprintf(' vs ');
            printCompact(vb);
            fprintf('\n');
        end
    end
end

function printCompact(v)
    if isnumeric(v) || islogical(v)
        if isscalar(v)
            fprintf('%g', v);
        else
            sz = size(v);
            fprintf('[%s %s]', strjoin(string(sz),'x'), class(v));
        end
    elseif ischar(v)
        fprintf('''%s''', v);
    elseif isstring(v)
        fprintf('"%s"', v);
    else
        fprintf('<%s>', class(v));
    end
end

function v = scalarFirst(x)
    if isempty(x)
        v = NaN;
    else
        v = x(1);
    end
end
