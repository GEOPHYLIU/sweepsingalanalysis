% demo_matrix.m
% Functional regression matrix across all 14 registered sweep types,
% both directions and two parameter sets.  "Pass" here means:
%   * generation returns without throwing,
%   * sample count / timing / frequency / phase arrays are finite,
%   * hard generation checks B5-B12 and C1 pass where applicable.
% B1-B4 are design checks reported honestly; B1-B4 failures are documented
% known limitations for some analytic / narrow-band types (see README).

clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));

types = {'linear','dbPerOct','dbPerHz','tPower','expNeg','logSweep', ...
    'dampedRicker','targetSpectrum','analogSpectrum','customWavelet', ...
    'piecewiseLinear','pseudoRandom','coded','variSweep'};
nCase = 0; nPass = 0; nDesign = 0; tAll = tic;
fprintf('%-16s %-5s %-13s %-6s %-7s %-9s %s\n', ...
    'type', 'dir', 'case', 'N', 'gen', 'design', 'failed');
for k = 1:numel(types)
    for variant = 1:2
        for direction = {'up','down'}
            nCase = nCase + 1;
            P = vsw_defaultParams();
            P.sweep.type = types{k};
            P.sweep.lengthMs = 16000; P.sweep.dtMs = 1;
            P.taper.type = 'cosine';
            P.taper.startMs = 150; P.taper.endMs = 150;

            % --- per-type nominal parameters -------------------------
            switch lower(types{k})
                case 'dbperoct'
                    P.sweep.sweepConstant = [3.3 0.5];
                    P.sweep.sweepConstant = P.sweep.sweepConstant(variant);
                case 'dbperhz'
                    P.sweep.sweepConstant = [2 -2];
                    P.sweep.sweepConstant = P.sweep.sweepConstant(variant);
                case 'tpower'
                    P.sweep.sweepConstant = [2 0.5];
                    P.sweep.sweepConstant = P.sweep.sweepConstant(variant);
                case 'expneg'
                    P.sweep.sweepConstant = [2 -2];
                    P.sweep.sweepConstant = P.sweep.sweepConstant(variant);
                case 'logsweep'
                    P.sweep.sweepConstant = [5 0.5];
                    P.sweep.sweepConstant = P.sweep.sweepConstant(variant);
                case 'dampedricker'
                    P.wavelet.mainFreqHz = [35 30];
                    P.wavelet.mainFreqHz = P.wavelet.mainFreqHz(variant);
                    P.wavelet.dampingFactor = [2.8 1.5];
                    P.wavelet.dampingFactor = P.wavelet.dampingFactor(variant);
                case {'targetspectrum','analogspectrum'}
                    fax = linspace(2, 96, 400).';
                    A = exp(-0.5*((fax - 38)/18).^2);
                    A = A + 0.25*exp(-0.5*((fax - 70)/8).^2);
                    A(fax > 48 & fax < 52) = A(fax > 48 & fax < 52) * 0.15;
                    P.wavelet.targetFreqAxis = fax;
                    P.wavelet.targetSpectrum = A;
                case 'customwavelet'
                    P.wavelet.mainFreqHz = [30 35];
                    P.wavelet.mainFreqHz = P.wavelet.mainFreqHz(variant);
                    P.wavelet.lobeAmpRatio = [0.2 0.25];
                    P.wavelet.lobeAmpRatio = P.wavelet.lobeAmpRatio(variant);
                    P.wavelet.lobeWidthRatio = [1.0 1.0];
                    P.wavelet.lobeWidthRatio = P.wavelet.lobeWidthRatio(variant);
                case 'piecewiselinear'
                    if variant == 1
                        P.sweep.segmentFreqsHz = [2 30 60 96];
                    else
                        P.sweep.segmentFreqsHz = [20 35 55 70];
                    end
                    P.sweep.segmentLengthsMs = [4000 5000 7000];
                case 'pseudorandom'
                    P.sweep.lengthMs = 12000;
                    P.code.order = [8 10];
                    P.code.order = P.code.order(variant);
                    P.code.chipMs = [4 2];
                    P.code.chipMs = P.code.chipMs(variant);
                    P.code.carrierHz = 60;
                case 'coded'
                    P.sweep.lengthMs = 12000;
                    P.code.order = [8 7];
                    P.code.order = P.code.order(variant);
                    P.code.chipMs = [4 6];
                    P.code.chipMs = P.code.chipMs(variant);
                    P.code.carrierHz = [60 45];
                    P.code.carrierHz = P.code.carrierHz(variant);
                case 'varisweep'
                    P.sweep.variCount = [5 3];
                    P.sweep.variCount = P.sweep.variCount(variant);
                    P.sweep.variBandJitterPct = [2 5];
                    P.sweep.variBandJitterPct = P.sweep.variBandJitterPct(variant);
            end

            % --- band / direction -----------------------------------
            isWavelet = any(strcmpi(types{k}, ...
                {'dampedRicker', 'customWavelet'}));
            if variant == 1
                lo = 2; hi = 96;
            elseif isWavelet
                % Keep the target wavelet inside the band; truncating it
                % invalidates the closed-form B2 width by design.
                lo = 3; hi = 96;
                P.sweep.lengthMs = 8000;
            else
                lo = 20; hi = 70;
            end
            if strcmp(direction{1}, 'up')
                P.sweep.f1Hz = lo; P.sweep.f2Hz = hi;
            else
                P.sweep.f1Hz = hi; P.sweep.f2Hz = lo;
            end
            P.sweep.direction = direction{1};
            if strcmpi(types{k}, 'piecewiselinear')
                if strcmp(direction{1}, 'down')
                    P.sweep.segmentFreqsHz = fliplr(P.sweep.segmentFreqsHz);
                end
            end

            % --- generate -------------------------------------------
            try
                R = vsw_generate(P, struct('figure', false, 'throwOnFail', false));
            catch ME
                fprintf('%-16s %-5s %-13s ERROR %s\n', ...
                    types{k}, direction{1}, sprintf('v%d', variant), ME.identifier);
                continue;
            end

            okShape = R.D.N == round(P.sweep.lengthMs / P.sweep.dtMs) && ...
                numel(R.derived.signal) == R.D.N && ...
                all(isfinite(R.derived.signal)) && ...
                all(isfinite(R.derived.fOfTS)) && ...
                all(isfinite(R.derived.phaseRad)) && ...
                isfield(R.analysis, 'acfEnvelope') && ...
                all(isfinite(R.analysis.acfEnvelope));

            genOk = okShape && R.qc.generationPass;
            nPass = nPass + genOk;
            nDesign = nDesign + R.qc.designPass;
            fprintf('%-16s %-5s %-13s %-6d %-7s %-9s %s\n', ...
                types{k}, direction{1}, sprintf('v%d', variant), R.D.N, ...
                tf(genOk), tf(R.qc.designPass), strjoin(R.qc.failed, ','));
        end
    end
end

fprintf('\nmatrix: %d cases, generation pass %d/%d, design pass %d/%d, %.1f s\n', ...
    nCase, nPass, nCase, nDesign, nCase, toc(tAll));
assert(nPass == nCase, 'demo_matrix: some cases failed generation checks.');
fprintf('demo_matrix done.\n');

function s = tf(b)
if b, s = 'pass'; else, s = 'FAIL'; end
end
