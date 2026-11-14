% demo_m1_linear.m
% M1: linear sweep, full chain generation -> analysis -> four views -> QC.
% Acceptance: one signal produces every view and every applicable check.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));

P = vsw_defaultParams();
P.sweep.type          = 'linear';
P.sweep.f1Hz          = 6;
P.sweep.f2Hz          = 96;
P.sweep.lengthMs      = 16000;
P.sweep.dtMs          = 1;
P.sweep.direction     = 'up';
P.sweep.initialPhaseDeg = 0;
P.taper.type          = 'cosine';
P.taper.startMs       = 500;
P.taper.endMs         = 500;
P.drive.amplitudeFraction = 0.7;
P.output.writeExtendedStanza = false;
P.meta.project  = 'M1 demo';
P.meta.operator = 'vsw-matlab';

opts = struct('figure', true, 'saveDir', fullfile(here, 'out'), ...
              'showFreqOnTime', true, ...
              'exportBase', fullfile(here, 'out', 'fig_m1_linear'));

% E1 performance is defined on the compute chain only (03 §4): generation,
% analysis and QC, without four-view rendering or file I/O.
tic;
R = vsw_generate(P, struct('figure', false, 'saveDir', ''));
elapsed = toc;

vsw_printQc(R);
fprintf('\ncore generation + analysis + QC: %.3f s (target <= 0.3 s)\n', elapsed);

% Rendering and writing are timed separately; they are not part of E1.
vsw_plotFourViews(R, opts);
R.saved = vsw_save(R, opts.saveDir);

% Analytic spot checks that do not depend on the QC layer.
t = R.derived.tAxisS;
fExpect = P.sweep.f1Hz + (P.sweep.f2Hz - P.sweep.f1Hz) * t / R.D.T;
fprintf('max |f(t)-analytic| = %.3g Hz\n', max(abs(R.derived.fOfTS - fExpect)));
phaseExpect = 2*pi*(P.sweep.f1Hz*t + 0.5*(P.sweep.f2Hz-P.sweep.f1Hz)/R.D.T*t.^2);
phaseExpect = phaseExpect + P.sweep.initialPhaseDeg*pi/180;
fprintf('max |phase-analytic| = %.3g rad (target 1e-6)\n', ...
    max(abs(R.derived.phaseRad - phaseExpect)));

fprintf('SEG-Y written: %s\n', R.saved.sgy);
fprintf('verification pass: %d\n', R.saved.verify.pass);
