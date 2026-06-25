% Deprecated wrapper kept for backwards compatibility.
% Use analisis_8WF/run_full_commonK_pipeline_8wf.m instead.

fprintf(['Deprecated wrapper: use run_full_commonK_pipeline_8wf.m ' ...
    'for the dynamic CommonK pipeline.\n']);

run(fullfile(fileparts(mfilename('fullpath')), ...
    'run_full_commonK_pipeline_8wf.m'));
