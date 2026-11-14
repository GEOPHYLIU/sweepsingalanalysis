% demo_output.m
% Output layer: SEG-Y rev2.1 + IBM float32, write-read-back acceptance,
% format matrix, numTraces, rev1/rev0 fallback and sample formats.

clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));

P = vsw_defaultParams();
P.sweep.type = 'dbPerOct';
P.sweep.f1Hz = 6; P.sweep.f2Hz = 96;
P.sweep.lengthMs = 12000; P.sweep.dtMs = 1;
P.sweep.sweepConstant = 3.3;
P.output.writeExtendedStanza = true;
P.meta.project = 'output acceptance';

R = vsw_generate(P, struct('figure', false));
res = vsw_save(R, fullfile(here, 'out'));
V = res.verify;
disp(V);
assert(V.pass, 'SEG-Y write-read-back verification failed.');

S = vsw_readSegy(res.sgy);
fprintf('\n--- read-back header ---\n');
fprintf('text line 1 : %s\n', S.textHeader(1:80));
fprintf('text line 39: %s\n', strtrim(S.textHeader(38*80+1:39*80)));
fprintf('sample format=%d  dt=%d us  N=%d  trid=%d  traces=%d\n', ...
    S.sampleFormat, S.sampleIntervalUs, S.nSamples, S.traceIdCode, S.nTraces);
fprintf('sweep %d-%d Hz, length %d ms, type %d, taper %d/%d type %d\n', ...
    S.sweepStartHz, S.sweepEndHz, S.sweepLengthMs, S.sweepTypeCode, ...
    S.startTaperMs, S.endTaperMs, S.taperTypeCode);
fprintf('rev %d.%d  byteOrder=0x%08X  firstTrace=%d  ext=%d\n', ...
    S.revMajor, S.revMinor, S.byteOrder, S.firstTraceOffset, S.nExtText);
fprintf('file size=%d  expected=%d\n', dir(res.sgy).bytes, res.segyInfo.expectedSize);
if ~isempty(S.extText)
    fprintf('stanza head: %s\n', strtrim(S.extText(1:60)));
end

% IBM round-trip, independent of the file.
x = [-1; -0.0; 0; 1e-12; 1e-4; 0.1; 0.7; 1234.5];
y = vsw_ibmDecode(vsw_ibmEncode(x));
fprintf('IBM round-trip max rel err (nonzero) = %.3g\n', ...
    max(abs(y(x~=0)-x(x~=0))./abs(x(x~=0))));

% ---- format matrix ----------------------------------------------------
fprintf('\n--- format matrix ---\n');
tmp = fullfile(here, 'out', '_format_matrix');
for f = {'segy','custom','vsci','txt','csv','mat','wav','all'}
    Q = P; Q.output.format = f{1};
    Rq = vsw_generate(Q, struct('figure', false, 'throwOnFail', false));
    s = vsw_save(Rq, fullfile(tmp, f{1}));
    assert(exist(s.json, 'file') == 2 && exist(s.txt, 'file') == 2);
    switch f{1}
        case 'segy', assert(exist(s.sgy, 'file') == 2 && s.verify.pass);
        case 'custom'
            assert(exist(s.custom, 'file') == 2);
            assert(s.customInfo.sampleRate == 2000);
            assert(s.customInfo.nSamples == round(Rq.D.N * Rq.D.dtS * 2000));
        case 'vsci'
            assert(exist(s.vsci, 'file') == 2);
            assert(s.vsciInfo.sampleRate == 4000);
            assert(s.vsciInfo.nSamples == round(Rq.D.N * Rq.D.dtS * 4000));
            assert(s.vsciInfo.sequenceStart == 0);
        case 'csv',  assert(exist(s.csv, 'file') == 2);
        case 'mat',  assert(exist(s.mat, 'file') == 2);
        case 'wav',  assert(exist(s.wav, 'file') == 2);
        case 'all'
            assert(exist(s.sgy, 'file') == 2 && s.verify.pass);
            assert(exist(s.csv, 'file') == 2 && exist(s.mat, 'file') == 2);
            assert(exist(s.wav, 'file') == 2);
    end
    fprintf('%-4s  json/txt=1', f{1});
    if ~isempty(s.sgy), fprintf('  sgy(verify=%d)', s.verify.pass); end
    if ~isempty(s.custom), fprintf('  custom'); end
    if ~isempty(s.vsci), fprintf('  vsci'); end
    if ~isempty(s.csv), fprintf('  csv'); end
    if ~isempty(s.mat), fprintf('  mat'); end
    if ~isempty(s.wav), fprintf('  wav'); end
    fprintf('\n');
end

% .custom must read back at its fixed 2000 samples/s.
Q = P; Q.output.format = 'custom';
Rq = vsw_generate(Q, struct('figure', false));
s = vsw_save(Rq, fullfile(tmp, 'custom_roundtrip'));
Ec = vsw_importSignal(s.custom);
Cc = vsw_compareExternal(Ec, Rq);
assert(abs(Ec.dtS - 0.5e-3) < 1e-12 && Ec.N == 2*Rq.D.N);
assert(abs(Cc.peakCorr) > 0.999, 'Custom round-trip correlation failed.');
fprintf('round-trip CUSTOM  N=%d dt=%.3g ms |rho| = %.4f @ %.3f s\n', ...
    Ec.N, Ec.dtS*1e3, abs(Cc.peakCorr), Cc.peakLagS);

% .vsci must read back at its fixed 4000 samples/s (sin convention default).
Q = P; Q.output.format = 'vsci';
Rq = vsw_generate(Q, struct('figure', false));
s = vsw_save(Rq, fullfile(tmp, 'vsci_roundtrip'));
Ev = vsw_importSignal(s.vsci);
Cv = vsw_compareExternal(Ev, Rq);
assert(abs(Ev.dtS - 0.25e-3) < 1e-12 && Ev.N == 4*Rq.D.N);
assert(strcmp(Ev.phaseConvention, 'sin'));
assert(abs(Cv.peakCorr) > 0.999, 'VSCI round-trip correlation failed.');
fprintf('round-trip VSCI    N=%d dt=%.3g ms |rho| = %.4f @ %.3f s\n', ...
    Ev.N, Ev.dtS*1e3, abs(Cv.peakCorr), Cv.peakLagS);

% Non-SEG-Y formats must survive a round-trip through the importer.
Q = P; Q.output.format = 'all';
Rq = vsw_generate(Q, struct('figure', false));
s = vsw_save(Rq, fullfile(tmp, 'roundtrip'));
for f = {s.csv, s.mat, s.wav}
    E = vsw_importSignal(f{1});
    C = vsw_compareExternal(E, R);
    assert(abs(C.peakCorr) > 0.999, 'Round-trip correlation failed.');
    fprintf('round-trip %-3s  |rho| = %.4f @ %.3f s\n', ...
        upper(f{1}(end-2:end)), abs(C.peakCorr), C.peakLagS);
end

% ---- numTraces --------------------------------------------------------
fprintf('\n--- numTraces ---\n');
Q = P; Q.output.numTraces = 4;
Rq = vsw_generate(Q, struct('figure', false));
s = vsw_save(Rq, fullfile(tmp, 'multi'));
assert(s.verify.pass, 'Multi-trace verification failed.');
S4 = vsw_readSegy(s.sgy, 4);
assert(S4.nTraces == 4 && S4.traceSequence == 4);
fprintf('numTraces=4 -> %d traces, binary 3213=%d, last trace seq=%d\n', ...
    S4.nTraces, S4.tracesInFile, S4.traceSequence);

% ---- revision fallback ------------------------------------------------
fprintf('\n--- revision fallback ---\n');
for rev = {'rev1','rev0'}
    Q = P; Q.output.segyRevision = rev{1};
    Rq = vsw_generate(Q, struct('figure', false));
    s = vsw_save(Rq, fullfile(tmp, rev{1}));
    assert(s.verify.pass, ['Verification failed for ' rev{1}]);
    S = vsw_readSegy(s.sgy);
    fprintf('%-4s -> rev %d.%d, 3297=%d, %s\n', rev{1}, ...
        S.revMajor, S.revMinor, S.byteOrder, ...
        strtrim(S.textHeader(38*80+1:39*80)));
end

% ---- sample formats ---------------------------------------------------
fprintf('\n--- sample formats ---\n');
for fm = {'int16','ieeeFloat32','int32'}
    Q = P; Q.output.sampleFormat = fm{1};
    Rq = vsw_generate(Q, struct('figure', false));
    s = vsw_save(Rq, fullfile(tmp, fm{1}));
    assert(s.verify.pass, ['Verification failed for ' fm{1}]);
    fprintf('%-12s max rel err = %.3g\n', fm{1}, s.verify.sampleMaxRelErr);
end

% ---- t0 and byte-order guard -----------------------------------------
Q = P; Q.output.t0Ms = 12;
Rq = vsw_generate(Q, struct('figure', false));
s = vsw_save(Rq, fullfile(tmp, 't0'));
assert(s.verify.pass && vsw_readSegy(s.sgy).traceDelayMs == 12);
fprintf('\nt0Ms=12 -> trace header delay = %d ms\n', ...
    vsw_readSegy(s.sgy).traceDelayMs);

Q = P; Q.output.byteOrder = 'little';
Rq = vsw_generate(Q, struct('figure', false));
try
    vsw_writeSegy(Rq, fullfile(tmp, 'little.sgy'));
    error('Little-endian write should have been rejected.');
catch ME
    assert(strcmp(ME.identifier, 'vsw:segy:byteOrder'));
    fprintf('byteOrder=little -> rejected (%s)\n', ME.identifier);
end

fprintf('\ndemo_output done: %s\n', res.sgy);
