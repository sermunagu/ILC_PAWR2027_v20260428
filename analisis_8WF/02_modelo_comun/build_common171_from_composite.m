% Deprecated wrapper kept for backwards compatibility.
% Use analisis_8WF/02_modelo_comun/build_common_structure_from_composite.m instead.

fprintf(['Deprecated wrapper: use build_common_structure_from_composite.m ' ...
    'for the dynamic CommonK pipeline.\n']);

run(fullfile(fileparts(mfilename('fullpath')), ...
    'build_common_structure_from_composite.m'));
