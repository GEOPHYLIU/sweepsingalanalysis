% run_all.m  —  run every milestone demo in sequence.
clear; clc; close all;
here = fileparts(mfilename('fullpath'));

fprintf('\n########## M1 ##########\n');
run(fullfile(here, 'demo_m1_linear.m'));
close all;

fprintf('\n########## M2 ##########\n');
run(fullfile(here, 'demo_m2_types.m'));
close all;

fprintf('\n########## M3 ##########\n');
run(fullfile(here, 'demo_m3_targets.m'));
close all;

fprintf('\n########## M5 ##########\n');
run(fullfile(here, 'demo_m5_distortion.m'));
close all;

fprintf('\n########## NEW TYPES ##########\n');
run(fullfile(here, 'demo_new_types.m'));
close all;

fprintf('\n########## TYPE MATRIX ##########\n');
run(fullfile(here, 'demo_matrix.m'));
close all;

fprintf('\n########## OUTPUT ##########\n');
run(fullfile(here, 'demo_output.m'));
close all;

fprintf('\n########## EXTERNAL SIGNAL ##########\n');
run(fullfile(here, 'demo_external.m'));
close all;

fprintf('\nall demos finished.\n');
