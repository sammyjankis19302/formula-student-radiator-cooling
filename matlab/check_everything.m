%CHECK_EVERYTHING  Run the model checks, then build and check the Simulink model.
%
%   In MATLAB, go to this folder and type:   check_everything
%   It takes a few minutes. It ends with a PASS line for each part.

here = fileparts(mfilename('fullpath'));
addpath(here);
fprintf('MATLAB %s\n\n', version);
fprintf('============ Part 1: model checks ============\n');
run_tests();
fprintf('\n============ Part 2: Simulink model ============\n');
check_simulink();
