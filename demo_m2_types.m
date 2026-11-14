% demo_m2_types.m
% M2: analytic route coverage — linear, dB/Oct, dB/Hz, t-Power, neg-exp, log.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));

types   = {'linear','dbPerOct','dbPerHz','tPower','expNeg','logSweep'};
consts  = [0, 3.3, 0.04, 2.0, 3.0, 3.0];
labels  = {'linear','dB/Oct n=3.3','dB/Hz n=0.04','t-Power p=2', ...
           'neg-exp k=3','log k=3'};

Rall = cell(1, numel(types));
for k = 1:numel(types)
    P = vsw_defaultParams();
    P.sweep.type          = types{k};
    P.sweep.f1Hz          = 6;
    P.sweep.f2Hz          = 96;
    P.sweep.lengthMs      = 16000;
    P.sweep.dtMs          = 1;
    P.sweep.direction     = 'up';
    P.sweep.sweepConstant = consts(k);
    P.taper.type          = 'cosine';
    P.taper.startMs       = 500;
    P.taper.endMs         = 500;
    P.output.writeExtendedStanza = true;
    Rall{k} = vsw_generate(P, struct('figure', false, 'saveDir', ''));
    vsw_printQc(Rall{k});
end

figure('Color','w','Position',[60 60 1200 760]);
tiledlayout(2,1,'TileSpacing','compact');
nexttile; hold on; grid on;
for k = 1:numel(types)
    plot(Rall{k}.derived.tAxisS, Rall{k}.derived.fOfTS, 'LineWidth', 1.2);
end
legend(labels, 'Location','southeast'); xlabel('time (s)'); ylabel('f(t) Hz');
title('M2 analytic sweep laws');
nexttile; hold on; grid on;
for k = 1:numel(types)
    A = Rall{k}.analysis;
    plot(A.freqAxisHz, A.ampSpectrumDB, 'LineWidth', 1.0);
end
xlim([0 120]); ylim([-80 5]);
legend(labels, 'Location','southwest');
xlabel('frequency (Hz)'); ylabel('dB'); title('Single-sided amplitude spectra');

% Add the two extension types to the registry demo (down-sweep sanity).
P = vsw_defaultParams();
P.sweep.type='linear'; P.sweep.f1Hz=96; P.sweep.f2Hz=6; P.sweep.direction='down';
P.sweep.lengthMs=16000;
Rdown = vsw_generate(P, struct('figure', false, 'saveDir', ''));
fprintf('\ndown sweep: f(0)=%.3f Hz, f(T)=%.3f Hz, monotonic decreasing = %d\n', ...
    Rdown.derived.fOfTS(1), Rdown.derived.fAtT, all(diff(Rdown.derived.fOfTS) <= 1e-6));
fprintf('demo_m2 done.\n');
