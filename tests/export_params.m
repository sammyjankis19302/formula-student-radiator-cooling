% Write the MATLAB parameters to results/params.json for the Python cross-check.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'matlab'));
p = cooling_params();
fid = fopen(fullfile(here, '..', 'results', 'params.json'), 'w');
fprintf(fid, '%s', jsonencode(p));
fclose(fid);
