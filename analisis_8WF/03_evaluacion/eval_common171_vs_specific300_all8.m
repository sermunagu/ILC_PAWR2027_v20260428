% Deprecated wrapper kept for backwards compatibility.
% This is not part of the CommonK master pipeline.

fprintf(['Deprecated wrapper: eval_common171_vs_specific300_all8.m is a ' ...
    'legacy Common171 comparison. Use the CommonK pipeline for current work.\n']);

run(fullfile(fileparts(mfilename('fullpath')), '..', ...
    '_archive_no_definitivo', 'eval_common171_vs_specific300_all8_legacy.m'));
