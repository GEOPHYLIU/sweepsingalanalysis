% demo_new_types.m
% P0-1: the four extension types that complete the 14-type registry
% (03 §2.1): analogSpectrum, piecewiseLinear, coded, variSweep.

clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));

map = vsw_registry();
fprintf('registry: %d types\n', map.Count);
assert(map.Count == 14, 'Registry must expose 14 types.');
for t = {'analogSpectrum','piecewiseLinear','coded','variSweep'}
    assert(isKey(map, t{1}), ['Missing registry entry: ' t{1}]);
end

base = vsw_defaultParams();
base.sweep.lengthMs = 12000;
base.sweep.dtMs = 1;
base.sweep.f1Hz = 6; base.sweep.f2Hz = 96;

% ---- analogSpectrum is an exact alias of targetSpectrum ----------------
Q = base; Q.sweep.type = 'analogSpectrum';
Q.wavelet.targetFreqAxis = linspace(6, 96, 181).';
fax = Q.wavelet.targetFreqAxis;
Q.wavelet.targetSpectrum = exp(-0.5*((fax - 45)/18).^2);
Ra = vsw_generate(Q, struct('figure', false, 'throwOnFail', false));
Q.sweep.type = 'targetSpectrum';
Rt = vsw_generate(Q, struct('figure', false, 'throwOnFail', false));
aliasErr = max(abs(Ra.signal - Rt.signal));
assert(strcmp(Ra.G.aliasOf, 'targetSpectrum'));
assert(aliasErr == 0, 'analogSpectrum must be bit-identical to targetSpectrum.');
fprintf('analogSpectrum alias    : max|dx| = %.3g, B1 pass = %d\n', ...
    aliasErr, qcPass(Ra, 'B1'));

% ---- piecewiseLinear ---------------------------------------------------
Q = base; Q.sweep.type = 'piecewiseLinear';
Q.sweep.segmentFreqsHz  = [6 30 60 96];
Q.sweep.segmentLengthsMs = [2000 4000 6000];
R = vsw_generate(Q, struct('figure', false, 'throwOnFail', false));
assert(max(abs(R.analysis.phaseErrorRad)) < 1e-9);
fAtEndUp = R.derived.fAtT;
assert(abs(fAtEndUp - 96) < 1e-9);
fprintf('piecewiseLinear up      : phase err = %.3g rad, f(T) = %.3f Hz\n', ...
    max(abs(R.analysis.phaseErrorRad)), fAtEndUp);

Q.sweep.direction = 'down';
Q.sweep.f1Hz = 96; Q.sweep.f2Hz = 6;
Q.sweep.segmentFreqsHz  = [96 60 30 6];
R = vsw_generate(Q, struct('figure', false, 'throwOnFail', false));
assert(max(abs(R.analysis.phaseErrorRad)) < 1e-9);
assert(abs(R.derived.fAtT - 6) < 1e-9);
fprintf('piecewiseLinear down    : phase err = %.3g rad, f(T) = %.3f Hz\n', ...
    max(abs(R.analysis.phaseErrorRad)), R.derived.fAtT);

% ---- coded (Golay complementary BPSK) ---------------------------------
Q = base; Q.sweep.type = 'coded';
Q.code.order = 8; Q.code.chipMs = 4; Q.code.carrierHz = 60;
Q.code.gapMs = 50;
R = vsw_generate(Q, struct('figure', false, 'throwOnFail', false));
assert(strcmp(R.G.codePair, 'golay'));
assert(max(abs(R.analysis.phaseErrorRad)) < 1e-6);
fprintf('coded                   : order = %d, carrier = %.1f Hz, phase err = %.3g rad\n', ...
    R.G.codeOrder, R.G.carrierHz, max(abs(R.analysis.phaseErrorRad)));

% ---- variSweep ---------------------------------------------------------
Q = base; Q.sweep.type = 'variSweep';
Q.sweep.variCount = 5; Q.sweep.variBandJitterPct = 2;
R = vsw_generate(Q, struct('figure', false, 'throwOnFail', false));
assert(R.G.variCount == 5);
assert(max(abs(R.analysis.phaseErrorRad)) < 1e-6);
fprintf('variSweep               : %d chirps, jitter %.1f%%, phase err = %.3g rad\n', ...
    R.G.variCount, R.G.variBandJitterPct, max(abs(R.analysis.phaseErrorRad)));

% ---- Yu wavelet route (waveletType = 'yu') ----------------------------
Q = base; Q.sweep.type = 'dampedRicker';
Q.wavelet.waveletType = 'yu';
Q.wavelet.yuFreqLowerHz = 20; Q.wavelet.yuFreqUpperHz = 80;
R = vsw_generate(Q, struct('figure', false, 'throwOnFail', false));
assert(strcmp(R.G.pathLabel, 'targetSpectrum'));
assert(R.G.yuFreqLowerHz == 20 && R.G.yuFreqUpperHz == 80);
assert(qcPass(R, 'B1'));
assert(~qcApplicable(R, 'B2'));
fprintf('yu wavelet              : p/q = %g/%g Hz, B1 err = %.3f dB, B2 n/a\n', ...
    R.G.yuFreqLowerHz, R.G.yuFreqUpperHz, ...
    qcValue(R, 'B1'));

Q.wavelet.waveletType = 'dampedRicker';
R2 = vsw_generate(Q, struct('figure', false, 'throwOnFail', false));
assert(strcmp(R2.G.waveletType, 'dampedRicker'));
assert(qcPass(R2, 'B1'));
fprintf('dampedRicker default    : B1 pass, path unchanged\n');

% ---- source model and control curve fields ---------------------------
Q = base;
Q.drive.sourceModel = struct('name', 'AHV-IV', 'massKg', 3200);
Q.drive.sourceControlCurve = [10 0.35; 25 0.70; 60 0.95; 96 1.00];
vsw_validate(Q);
fprintf('drive source fields     : struct + 4-point control curve accepted\n');

% ---- negative parameter checks ----------------------------------------
expectError(base, 'piecewiseLinear', ...
    struct('segmentFreqsHz', [6 30 60 96], 'segmentLengthsMs', [2000 4000 2000]), ...
    'vsw:validate:piecewiseLength');
expectError(base, 'piecewiseLinear', ...
    struct('segmentFreqsHz', [6 30 60 50], 'segmentLengthsMs', [2000 4000 6000]), ...
    'vsw:validate:piecewiseMonotonic');
expectError(base, 'variSweep', struct('variCount', 0), 'vsw:validate:variCount');
Q = base; Q.sweep.type = 'coded'; Q.code.gapMs = -1;
try
    vsw_validate(Q);
    error('coded gapMs < 0 should have been rejected.');
catch ME
    assert(strcmp(ME.identifier, 'vsw:validate:codedGap'));
end
fprintf('negative checks         : all four rejected as expected\n');

fprintf('demo_new_types done.\n');

% -----------------------------------------------------------------------
function p = qcPass(R, id)
it = R.qc.items(strcmp({R.qc.items.id}, id));
p = it.pass;
end

function a = qcApplicable(R, id)
it = R.qc.items(strcmp({R.qc.items.id}, id));
a = it.applicable;
end

function v = qcValue(R, id)
it = R.qc.items(strcmp({R.qc.items.id}, id));
v = it.value;
end

function expectError(P0, typ, s, id)
Q = P0; Q.sweep.type = typ;
fn = fieldnames(s);
for ii = 1:numel(fn), Q.sweep.(fn{ii}) = s.(fn{ii}); end
try
    vsw_validate(Q);
    error('Expected %s but validation passed.', id);
catch ME
    assert(strcmp(ME.identifier, id), ...
        sprintf('Expected %s, got %s.', id, ME.identifier));
end
end
