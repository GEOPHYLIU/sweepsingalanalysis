% demo_m3_targets.m
% M3: three design routes side by side.
%   route A: damped Ricker target spectrum (analytic A)
%   route B: arbitrary user target spectrum (reflection spectrum + notch)
%   route C: customer-shaped wavelet -> |W| -> A allocation
% Same f0 = 35 Hz family, but the correlation wavelets differ, which is the
% whole point of exposing the three routes.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));

base = vsw_defaultParams();
base.sweep.lengthMs = 16000;
base.sweep.f1Hz = 2; base.sweep.f2Hz = 96;
base.taper.type = 'cosine'; base.taper.startMs = 150; base.taper.endMs = 150;
base.wavelet.mainFreqHz = 35;

% --- A: damped Ricker ---------------------------------------------------
PA = base;
PA.sweep.type = 'dampedRicker';
PA.wavelet.dampingFactor = 2.8;

% --- B: arbitrary target spectrum --------------------------------------
PB = base;
PB.sweep.type = 'targetSpectrum';
fax = linspace(2, 96, 400).';
A = exp(-0.5*((fax - 38)/18).^2);          % main reflection band
A = A + 0.25*exp(-0.5*((fax - 70)/8).^2);  % secondary band
A(fax > 48 & fax < 52) = A(fax > 48 & fax < 52) * 0.15;  % 50 Hz notch
PB.wavelet.targetFreqAxis = fax;
PB.wavelet.targetSpectrum = A;

% --- C: customer wavelet ----------------------------------------------
PC = base;
PC.sweep.type = 'customWavelet';
PC.wavelet.mainFreqHz = 30;
PC.wavelet.lobeAmpRatio = 0.2;
PC.wavelet.lobeWidthRatio = 1.0;

R = cell(1,3); names = {'A dampedRicker','B targetSpectrum','C customWavelet'};
R{1} = vsw_generate(PA, struct('figure', false, 'saveDir', ''));
R{2} = vsw_generate(PB, struct('figure', false, 'saveDir', ''));
R{3} = vsw_generate(PC, struct('figure', false, 'saveDir', ''));
for k = 1:3
    vsw_printQc(R{k});
end

figure('Color','w','Position',[60 60 1250 800]);
tiledlayout(2,2,'TileSpacing','compact');
nexttile; hold on; grid on;
for k=1:3
    Aa = R{k}.analysis;
    plot(Aa.freqAxisHz, Aa.ampSpectrumDB, 'LineWidth',1.0);
end
xlim([0 120]); ylim([-80 5]); legend(names,'Location','southwest');
xlabel('Hz'); ylabel('dB'); title('(2) spectra of the three routes');

nexttile; hold on; grid on;
for k=1:3
    Aa = R{k}.analysis;
    sel = abs(Aa.acfLagS) <= 0.25;
    plot(Aa.acfLagS(sel), Aa.acfNormalized(sel), 'LineWidth',1.1);
end
legend(names,'Location','southeast'); xlabel('lag (s)'); ylabel('norm. ACF');
title('(3) correlation wavelets');

nexttile; hold on; grid on;
for k=1:3
    plot(R{k}.derived.tAxisS, R{k}.derived.fOfTS, 'LineWidth',1.0);
end
xlabel('time (s)'); ylabel('f(t) Hz'); title('instantaneous frequency');
legend(names,'Location','southeast');

nexttile; hold on; grid on;
for k=1:3
    Aa = R{k}.analysis;
    plot(Aa.freqAxisHz, Aa.ampSpectrum.^2 / max(Aa.ampSpectrum.^2), 'LineWidth',1.0);
end
xlim([0 120]); xlabel('Hz'); ylabel('normalized |S|^2');
title('|S|^2  (= correlation-wavelet spectrum)');

fprintf('\nroute summary:  A zc=%.4f s  B zc=%.4f s  C zc=%.4f s\n', ...
    R{1}.analysis.zeroCrossS, R{2}.analysis.zeroCrossS, R{3}.analysis.zeroCrossS);
fprintf('demo_m3 done.\n');
