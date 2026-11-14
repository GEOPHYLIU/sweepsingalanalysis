function demo_external()
%DEMO_EXTERNAL  Round-trip and negative tests for the external-signal path.
%
%   Generates a reference sweep, writes it out in every supported external
%   format, reads each back with vsw_importSignal, analyses it once with
%   vsw_analyzeExternal, compares it with the reference and renders both the
%   four-view external figure and the comparison figure.
%
%   The last cases are deliberate corruptions: a text file renamed to .wav,
%   a truncated SAC file and a truncated SEG-Y file.  They verify that the
%   importer sniffs real content and refuses structurally broken input.
%
%   Run from the matlab/ folder:  demo_external

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));

P = vsw_defaultParams();
P.sweep.type     = 'linear';
P.sweep.f1Hz     = 6;
P.sweep.f2Hz     = 96;
P.sweep.direction = 'up';
P.sweep.lengthMs = 4000;
P.sweep.dtMs     = 1;
P.output.format  = 'segy';
R = vsw_generate(P, struct('figure', false, 'saveDir', '', 'throwOnFail', false));

tmp = fullfile(tempdir, 'vsw_external_demo');
if ~exist(tmp, 'dir'), mkdir(tmp); end

t = R.D.tAxisS;
x = R.derived.signal;
dt = R.D.dtS;

fprintf('\n=== external import round-trip ===\n');
fprintf('reference : %s  (%d samples, %.4g ms)\n', ...
    R.meta.signalId, R.D.N, R.D.dtMs);

cases = {};
% label, file, opts, expectOk, warning substring ('' = none required)

% ---- 1. CSV with a time column ----------------------------------------
f1 = fullfile(tmp, 'sweep_time.csv');
writematrix([t, x], f1);
cases{end+1} = {'csv + time column', f1, struct(), true, ''};

% ---- 2. TXT single column, fallback dt --------------------------------
f2 = fullfile(tmp, 'sweep_plain.txt');
writematrix(x, f2);
cases{end+1} = {'txt + fallback dt', f2, struct('dtMs', 1), true, ''};

% ---- 3. TXT, time in ms ----------------------------------------------
f3 = fullfile(tmp, 'sweep_time_ms.txt');
writematrix([t*1e3, x], f3);
cases{end+1} = {'txt + time in ms', f3, ...
    struct('timeUnit', 'ms'), true, ''};

% ---- 4. WAV -----------------------------------------------------------
f4 = fullfile(tmp, 'sweep.wav');
audiowrite(f4, x / max(abs(x)) * 0.98, round(1/dt));
cases{end+1} = {'wav', f4, struct(), true, ''};

% ---- 5. MAT -----------------------------------------------------------
f5 = fullfile(tmp, 'sweep.mat');
fs = 1/dt;
save(f5, 'x', 'fs');
cases{end+1} = {'mat', f5, struct(), true, ''};

% ---- 6. SEG-Y ---------------------------------------------------------
f6 = fullfile(tmp, 'sweep.sgy');
vsw_writeSegy(R, f6);
cases{end+1} = {'segy', f6, struct(), true, ''};

% ---- 7. XLSX ----------------------------------------------------------
f7 = fullfile(tmp, 'sweep.xlsx');
writematrix([t, x], f7);
cases{end+1} = {'xlsx', f7, struct(), true, ''};

% ---- 8. SAC -----------------------------------------------------------
f8 = fullfile(tmp, 'sweep.sac');
writeSac(f8, x, dt, 'little');
cases{end+1} = {'sac', f8, struct(), true, ''};

% ---- 9. raw float32, little-endian -----------------------------------
f9 = fullfile(tmp, 'sweep_f32.bin');
fid = fopen(f9, 'wb');
fwrite(fid, x, 'float32');
fclose(fid);
cases{end+1} = {'raw float32 LE', f9, ...
    struct('sampleFormat', 'float32', 'byteOrder', 'little', 'dtMs', 1), ...
    true, ''};

% ---- 10. raw float32, big-endian -------------------------------------
f10 = fullfile(tmp, 'sweep_f32be.bin');
fid = fopen(f10, 'wb');
fwrite(fid, x, 'float32', 0, 'b');
fclose(fid);
cases{end+1} = {'raw float32 BE', f10, ...
    struct('sampleFormat', 'float32', 'byteOrder', 'big', 'dtMs', 1), ...
    true, ''};

% ---- 11. raw int16, two interleaved traces ---------------------------
f11 = fullfile(tmp, 'sweep_i16_2tr.bin');
M = [x, 0.5*x] / max(abs(x)) * 32767;
fid = fopen(f11, 'wb');
fwrite(fid, M, 'int16');   % column-major = trace-major, one trace per column
fclose(fid);
cases{end+1} = {'raw int16 2 traces', f11, ...
    struct('sampleFormat', 'int16', 'byteOrder', 'little', ...
           'samplesPerTrace', numel(x), 'channel', 1, 'dtMs', 1), ...
    true, ''};

% ---- 12. text renamed to .wav: real format wins -----------------------
f12 = fullfile(tmp, 'renamed_csv.wav');
copyfile(f1, f12);
cases{end+1} = {'renamed text as .wav', f12, struct(), true, ...
    'does not match'};

% ---- 13. UTF-8 with BOM ----------------------------------------------
f13 = fullfile(tmp, 'sweep_bom.csv');
bytes = readAll(f1);
fid = fopen(f13, 'wb');
fwrite(fid, uint8([239 187 191]), 'uint8');
fwrite(fid, bytes, 'uint8');
fclose(fid);
cases{end+1} = {'UTF-8 BOM csv', f13, struct(), true, '', 'UTF-8-BOM'};

% ---- 14. UTF-16LE with BOM -------------------------------------------
f14 = fullfile(tmp, 'sweep_utf16.txt');
txt = fileread(f1);
u16 = unicode2native(txt, 'UTF-16LE');
fid = fopen(f14, 'wb');
fwrite(fid, uint8([255 254]), 'uint8');
fwrite(fid, u16, 'uint8');
fclose(fid);
cases{end+1} = {'UTF-16LE txt', f14, struct(), true, '', 'UTF-16LE'};

% ---- 15. GBK header + ASCII numbers ----------------------------------
f15 = fullfile(tmp, 'sweep_gbk.csv');
hdr = unicode2native(sprintf('时间,幅值\n'), 'GBK');
bytes = readAll(f1);
fid = fopen(f15, 'wb');
fwrite(fid, hdr, 'uint8');
fwrite(fid, bytes, 'uint8');
fclose(fid);
cases{end+1} = {'GBK header csv', f15, struct(), true, '', 'GBK'};

% ---- 16. Sercel .custom (2000 samples/s) -----------------------------
f16 = fullfile(tmp, 'sweep.custom');
fsCustom = 2000;
xCustom = resampleTo(x, t, fsCustom);
fid = fopen(f16, 'wb');
fprintf(fid, '#IDENTIFIER sweep.custom\r\n');
fprintf(fid, '%.9f\r\n', xCustom);
fclose(fid);
cases{end+1} = {'custom (Sercel)', f16, struct(), true, '', '', ...
    numel(xCustom), 1/fsCustom};

% ---- 17. INOVA .vsci, cosine phase ------------------------------------
f17 = fullfile(tmp, 'sweep.vsci');
fsVsci = 4000;
[xVsci, dtVsci] = writeSci(f17, x, t, fsVsci, 'cos');
cases{end+1} = {'vsci cos', f17, struct('phaseConvention', 'cos'), ...
    true, '', '', numel(xVsci), dtVsci};

% ---- 18. INOVA .vsci, sine phase --------------------------------------
f18 = fullfile(tmp, 'sweep_sin.vsci');
[xSin, dtSin] = writeSci(f18, x, t, fsVsci, 'sin');
cases{end+1} = {'vsci sin', f18, struct('phaseConvention', 'sin'), ...
    true, '', '', numel(xSin), dtSin};

% ---- 19. INOVA .fsci (2048 samples/s) ---------------------------------
f19 = fullfile(tmp, 'sweep.fsci');
fsFsci = 2048;
[xFsci, dtFsci] = writeSci(f19, x, t, fsFsci, 'cos');
cases{end+1} = {'fsci cos', f19, struct('phaseConvention', 'cos'), ...
    true, '', '', numel(xFsci), dtFsci};

% ---- 20. malformed SCIO: negative envelope ---------------------------
f20 = fullfile(tmp, 'bad.vsci');
fid = fopen(f20, 'wb');
fprintf(fid, '%7d%7d%7d\r\n', 0, -1, 0);
fprintf(fid, '%7d%7d%7d\r\n', 1, 100, 100);
fclose(fid);
cases{end+1} = {'SCI negative envelope', f20, struct(), false, ''};

% ---- 21. truncated SAC: must be refused ------------------------------
f21 = fullfile(tmp, 'truncated.sac');
bytes = readAll(f8);
fid = fopen(f21, 'wb');
fwrite(fid, bytes(1:end-100), 'uint8');
fclose(fid);
cases{end+1} = {'truncated SAC', f21, struct(), false, ''};

% ---- 22. truncated SEG-Y: must be refused ----------------------------
f22 = fullfile(tmp, 'truncated.sgy');
bytes = readAll(f6);
fid = fopen(f22, 'wb');
fwrite(fid, bytes(1:end-1000), 'uint8');
fclose(fid);
cases{end+1} = {'truncated SEG-Y', f22, struct(), false, ''};

nPass = 0;
for ii = 1:numel(cases)
    label  = cases{ii}{1};
    file   = cases{ii}{2};
    opts   = cases{ii}{3};
    expectOk = cases{ii}{4};
    needWarn = cases{ii}{5};
    encExpect = '';
    if numel(cases{ii}) >= 6, encExpect = cases{ii}{6}; end
    expN = R.D.N;
    if numel(cases{ii}) >= 7 && ~isempty(cases{ii}{7})
        expN = cases{ii}{7};
    end
    expDt = R.D.dtS;
    if numel(cases{ii}) >= 8 && ~isempty(cases{ii}{8})
        expDt = cases{ii}{8};
    end
    try
        E = vsw_importSignal(file, opts);
        if ~expectOk
            fprintf('%-24s FAILED: expected an error, import succeeded\n', label);
            close all force;
            continue;
        end
        A = vsw_analyzeExternal(E);
        C = vsw_compareExternal(E, R);
        hasWarn = isempty(needWarn) || ...
            any(~cellfun(@isempty, strfind(E.warnings, needWarn)));
        encOk = isempty(encExpect) || strcmp(E.encoding, encExpect);
        dtOk = abs(E.dtS - expDt) <= 1e-9 * max(1, expDt);
        ok = hasWarn && encOk && dtOk && E.N == expN && abs(C.peakCorr) > 0.999;
        fprintf('%-24s N=%5d dt=%6.3g ms fdom=%7.4g Hz rho=%+.4f @ %+7.3g s  %s\n', ...
            label, E.N, E.dtS*1e3, A.dominantFreqHz, C.peakCorr, ...
            C.peakLagS, tern(ok, 'PASS', 'FAIL'));
        if ok
            nPass = nPass + 1;
        else
            fprintf('    warnings: %s\n', strjoin(E.warnings, ' | '));
        end
        if ii == 1
            h = vsw_plotExternal(E, A);
            saveas(h, fullfile(tmp, 'external_fourviews.png'));
            h2 = vsw_plotCompare(E, A, R, C);
            saveas(h2, fullfile(tmp, 'external_compare.png'));
        end
        close all force;
    catch ME
        if ~expectOk
            fprintf('%-24s rejected as expected: %s\n', label, ME.message);
            nPass = nPass + 1;
        else
            fprintf('%-24s FAILED: %s\n', label, ME.message);
        end
        close all force;
    end
end

% ---- optional: real Sercel samples shipped in the repo root ----------
% They have a second TRUE/FALSE flag column and a different sweep than the
% synthetic reference, so check .custom against its paired .txt instead.
root = fileparts(fileparts(mfilename('fullpath')));
pairs = {'S1.custom', 'S1.txt'; 'S2.custom', 'S2.txt'};
nReal = 0;
nRealPass = 0;
for ii = 1:size(pairs, 1)
    fc = fullfile(root, pairs{ii, 1});
    ft = fullfile(root, pairs{ii, 2});
    if ~(exist(fc, 'file') && exist(ft, 'file'))
        continue;
    end
    nReal = nReal + 1;
    try
        Ec = vsw_importSignal(fc);
        Et = vsw_importSignal(ft);
        Cc = vsw_compareExternal(Ec, Et.x, struct('refDtS', Et.dtS));
        ok = abs(Cc.peakCorr) > 0.999 && abs(Cc.peakLagS) < 1e-9 && ...
            Ec.N == 2 * Et.N;
        fprintf('%-24s N=%5d dt=%6.3g ms rho=%+.4f @ %+7.3g s  %s\n', ...
            ['real ' pairs{ii, 1}], Ec.N, Ec.dtS*1e3, Cc.peakCorr, ...
            Cc.peakLagS, tern(ok, 'PASS', 'FAIL'));
        if ok, nRealPass = nRealPass + 1; end
    catch ME
        fprintf('%-24s FAILED: %s\n', ['real ' pairs{ii, 1}], ME.message);
    end
end

fprintf('\nexternal import: %d/%d cases pass\n', nPass, numel(cases));
if nReal > 0
    fprintf('real Sercel samples: %d/%d pass\n', nRealPass, nReal);
end
fprintf('artefacts written under %s\n', tmp);
if nPass ~= numel(cases) || nRealPass ~= nReal
    error('demo_external:fail', '%d external import case(s) failed.', ...
        numel(cases) - nPass + nReal - nRealPass);
end
end

% =======================================================================
function [xr, dt] = writeSci(file, x, t, fs, conv)
xr = resampleTo(x, t, fs);
[env, ph] = analyticSignal(xr);
if max(env) > 0, env = env / max(env); end
phaseDeg = ph * 180/pi;
% The analytic signal has x = env*cos(phase).  For a sine-convention box
% file, add 90 deg so that env*sin(phase+90) reconstructs the same wave.
if strcmp(conv, 'sin'), phaseDeg = phaseDeg + 90; end
envCode = round(env * 32676);
code = round(phaseDeg * 65536 / 360);
code = mod(code + 32768, 65536) - 32768;
n = numel(xr);
fid = fopen(file, 'wb');
fprintf(fid, '%7d%7d%7d\r\n', [0:n-1; envCode.'; code.']);
fclose(fid);
dt = 1 / fs;
end

function xr = resampleTo(x, t, fs)
T = numel(x) * median(diff(t));
n = round(T * fs);
tv = (0:n-1).' / fs;
xr = interp1(t, x, tv, 'linear', 0);
end

function [env, ph] = analyticSignal(x)
x = x(:);
n = numel(x);
X = fft(x);
h = zeros(n, 1);
if mod(n, 2) == 0
    h(1) = 1; h(n/2 + 1) = 1; h(2:n/2) = 2;
else
    h(1) = 1; h(2:(n+1)/2) = 2;
end
z = ifft(X .* h);
env = abs(z);
ph = unwrap(angle(z));
end

% =======================================================================
function writeSac(file, x, dt, order)
% Minimal SAC writer for the demo: 70 float words, 40 int words, 192 chars.
h = zeros(1, 632, 'uint8');
h = putF32(h, 1, dt, order);            % delta
h = putF32(h, 2, min(x), order);        % depmin
h = putF32(h, 3, max(x), order);        % depmax
h = putF32(h, 6, 0, order);             % b
h = putF32(h, 7, (numel(x)-1)*dt, order); % e
h = putF32(h, 8, 0, order);             % o
h = putI32(h, 10, numel(x), order);     % npts
h = putI32(h, 14, 1, order);            % iftype = time series
fid = fopen(file, 'wb');
fwrite(fid, h, 'uint8');
if strcmp(order, 'big')
    fwrite(fid, x, 'float32', 0, 'b');
else
    fwrite(fid, x, 'float32');
end
fclose(fid);
end

function h = putF32(h, word, value, order)
b = typecast(single(value), 'uint8');
if strcmp(order, 'big'), b = b(end:-1:1); end
h((word-1)*4 + (1:4)) = b;
end

function h = putI32(h, word, value, order)
b = typecast(int32(value), 'uint8');
if strcmp(order, 'big'), b = b(end:-1:1); end
h(280 + (word-1)*4 + (1:4)) = b;
end

function b = readAll(file)
fid = fopen(file, 'rb');
b = fread(fid, Inf, 'uint8=>uint8');
fclose(fid);
end

function out = tern(cond, a, b)
if cond, out = a; else, out = b; end
end
