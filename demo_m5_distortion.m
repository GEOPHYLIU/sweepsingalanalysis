% demo_m5_distortion.m
% M5: phenomenon-level harmonic distortion and ghost-position QC.
% B11 compares the measured ghost lag with the stationary-phase position,
% separately for the 2nd and 3rd harmonic.  B12 is a record-only number.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));

P = vsw_defaultParams();
P.sweep.type = 'linear';
P.sweep.f1Hz = 6; P.sweep.f2Hz = 96;
P.sweep.lengthMs = 16000; P.sweep.dtMs = 1;
P.distortion.enable = true;
P.distortion.order2Amp = 0.15;
P.distortion.order3Amp = 0.08;
P.distortion.phase2Rad = -0.5;
P.distortion.phase3Rad = 0.5;

R = vsw_generate(P, struct('figure', true, 'saveDir', ''));
vsw_printQc(R);

A = R.analysis;
fprintf('\nghost theory  [s]: %.4f  %.4f\n', A.ghostTheoryTime);
fprintf('ghost measured[s]: %.4f  %.4f\n', A.ghostMeasuredTime);
fprintf('B12 low-frequency harmonic ratio (record only): %.2f dB / %.2f dB\n', ...
    A.lowFreqHarmonicDB(1), A.lowFreqHarmonicDB(2));

figure('Color','w','Position',[80 80 1000 420]);
plot(A.corrLagS, A.corrProfile / max(abs(A.corrProfile)), 'k'); hold on; grid on;
yl = ylim;
for k=1:2
    plot([1 1]*A.ghostTheoryTime(k), yl, 'r--');
    plot(A.ghostMeasuredTime(k), 0.85*sign(A.corrProfile(find(A.corrLagS>=A.ghostMeasuredTime(k),1))), 'bo');
end
xlim([-8 2]); xlabel('lag (s)'); ylabel('normalized cross-correlation');
title('distorted signal vs pilot (ghost side)');
legend({'correlation','theory','measured'}, 'Location','best');

% --- direction check: a down-sweep must put the ghost on positive lag ----
Pd = P;
Pd.sweep.direction = 'down';
Pd.sweep.f1Hz = 96; Pd.sweep.f2Hz = 6;
Rd = vsw_generate(Pd, struct('figure', false, 'saveDir', ''));
Ad = Rd.analysis;
q = Rd.qc; get = @(id) q.items(strcmp({q.items.id}, id));
fprintf('\ndown-sweep ghost theory/measured [s]: %.4f/%.4f  %.4f/%.4f\n', ...
    Ad.ghostTheoryTime(1), Ad.ghostMeasuredTime(1), ...
    Ad.ghostTheoryTime(2), Ad.ghostMeasuredTime(2));
fprintf('down-sweep B11: %s\n', get('B11').detail);

fprintf('demo_m5 done.\n');
