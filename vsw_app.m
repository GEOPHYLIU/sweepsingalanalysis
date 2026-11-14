function app = vsw_app()
%VSW_APP  Vibroseis sweep studio - programmatic uifigure GUI.
%
%   app = vsw_app() builds the GUI and runs one default generation.  The
%   returned struct carries the figure/axes/table handles so callers (and a
%   smoke test) can inspect it.  All actual signal work is delegated to the
%   vsw_* core; this file only collects parameters, invokes vsw_generate /
%   vsw_save and renders the already-computed analysis result.
%
%   For a standalone Windows executable use vsw_launch.m as the entry point
%   and run build_exe.m (requires MATLAB Compiler).

if ~isdeployed
    here = fileparts(mfilename('fullpath'));
    srcDir = fullfile(here, 'src');
    if exist(srcDir, 'dir'), addpath(srcDir); end
end

% ---- shared state ------------------------------------------------------
R          = [];          % last result
targetFreq = [];          % optional targetSpectrum axis
targetAmp  = [];          % optional targetSpectrum amplitude
E          = [];          % last imported external signal
EA         = [];          % its display analysis
C          = [];          % last external-vs-reference comparison
viewMode   = 'generated'; % 'generated' | 'external'
f          = struct();    % component handles
D0         = vsw_defaultParams();

% =======================================================================
% Figure and top-level layout
% =======================================================================
fig = uifigure('Name', 'Vibroseis Sweep Studio', ...
    'Position', [80 60 800 600], 'Color', [1 1 1]);
iconF = localIconPath();
if exist(iconF, 'file')
    fig.Icon = iconF;
end

main = uigridlayout(fig, [1 2]);
main.ColumnWidth = {'2x', '3x'};
main.RowHeight   = {'1x'};
main.Padding     = [8 8 8 8];
main.ColumnSpacing = 8;

left = uipanel(main, 'BorderType', 'none');
left.Layout.Column = 1;
lg = uigridlayout(left, [2 1]);
lg.RowHeight = {'1x', 'fit'};
lg.Padding = [0 0 0 0];
lg.RowSpacing = 6;

tg = uitabgroup(lg);
tg.Layout.Row = 1;

% =======================================================================
% Tab 1 - sweep
% =======================================================================
t1 = uitab(tg, 'Title', 'Sweep');
g1 = uigridlayout(t1, [12 2]);
g1.RowHeight   = repmat({26}, 1, 12);
g1.ColumnWidth = {165, '1x'};
g1.Padding     = [8 8 8 8];
g1.RowSpacing  = 4;

f.type = dropField(g1, 1, 'sweep type', ...
    {'linear','dbPerOct','dbPerHz','tPower','expNeg','logSweep', ...
     'dampedRicker','targetSpectrum','analogSpectrum','customWavelet', ...
     'piecewiseLinear','pseudoRandom','coded','variSweep'}, ...
    D0.sweep.type);
f.direction = dropField(g1, 2, 'direction', {'up','down'}, D0.sweep.direction);
f.f1     = numField(g1, 3,  'f1 (Hz)',      D0.sweep.f1Hz,      [0.01 1e6]);
f.f2     = numField(g1, 4,  'f2 (Hz)',      D0.sweep.f2Hz,      [0.01 1e6]);
f.len    = numField(g1, 5,  'length (ms)',  D0.sweep.lengthMs,  [1 1e7]);
f.dt     = numField(g1, 6,  'dt (ms)',      D0.sweep.dtMs,      [0.001 1000]);
f.phi0   = numField(g1, 7,  'initial phase (deg)', D0.sweep.initialPhaseDeg, []);
f.sconst = numField(g1, 8,  'sweep constant', D0.sweep.sweepConstant, []);
f.seqLen = numField(g1, 9,  'sequence length', D0.sweep.sequenceLength, [1 1e6]);
f.codeOrder = numField(g1, 10, 'code order (5..12)', D0.code.order, [5 12]);
f.codeChip  = numField(g1, 11, 'chip (ms)',          D0.code.chipMs, [0.01 1e6]);
f.codeCarrier = numField(g1, 12, 'carrier (Hz)',     D0.code.carrierHz, [0.01 1e6]);

f.type.ValueChangedFcn      = @(s,e) onTypeChanged();
f.direction.ValueChangedFcn = @(s,e) onDirectionChanged();

% =======================================================================
% Tab 2 - wavelet / target spectrum
% =======================================================================
t2 = uitab(tg, 'Title', 'Wavelet');
g2 = uigridlayout(t2, [10 2]);
g2.RowHeight   = {26, 26, 26, 26, 26, 26, 26, 32, 26, '1x'};
g2.ColumnWidth = {165, '1x'};
g2.Padding     = [8 8 8 8];
g2.RowSpacing  = 4;

f.waveletType = dropField(g2, 1, 'wavelet type', ...
    {'dampedRicker','yu','custom'}, D0.wavelet.waveletType);
f.f0     = numField(g2, 2, 'main freq f0 (Hz)', D0.wavelet.mainFreqHz, [0.01 1e6]);
f.damp   = numField(g2, 3, 'damping factor B',  D0.wavelet.dampingFactor, [1 100]);
f.yuP    = numField(g2, 4, 'Yu lower p (Hz)',   D0.wavelet.yuFreqLowerHz, [0.01 1e6]);
f.yuQ    = numField(g2, 5, 'Yu upper q (Hz)',   D0.wavelet.yuFreqUpperHz, [0.01 1e6]);
f.lobeA  = numField(g2, 6, 'lobe amp ratio',    D0.wavelet.lobeAmpRatio, [0 1]);
f.lobeW  = numField(g2, 7, 'lobe width ratio',  D0.wavelet.lobeWidthRatio, [1 100]);

f.loadTarget = uibutton(g2, 'Text', 'Load target spectrum CSV / TXT...', ...
    'ButtonPushedFcn', @(s,e) doLoadTarget());
f.loadTarget.Layout.Row = 8; f.loadTarget.Layout.Column = [1 2];

f.targetInfo = uilabel(g2, 'Text', 'no target spectrum loaded', ...
    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
f.targetInfo.Layout.Row = 9; f.targetInfo.Layout.Column = [1 2];

note2 = uilabel(g2, 'Text', ...
    ['CSV format: two columns, frequency (Hz) then amplitude >= 0. ' ...
     'Used by the targetSpectrum type. dampedRicker uses f0 and B; ' ...
     'waveletType=yu uses p and q instead.'], 'WordWrap', 'on');
note2.Layout.Row = 10; note2.Layout.Column = [1 2];

f.waveletType.ValueChangedFcn = @(s,e) onWaveletTypeChanged();

% =======================================================================
% Tab 3 - drive and taper
% =======================================================================
t3 = uitab(tg, 'Title', 'Drive');
g3 = uigridlayout(t3, [6 2]);
g3.RowHeight   = {26, 26, 26, 26, 26, '1x'};
g3.ColumnWidth = {165, '1x'};
g3.Padding     = [8 8 8 8];
g3.RowSpacing  = 4;

f.ampFrac = numField(g3, 1, 'amplitude fraction', D0.drive.amplitudeFraction, [0.001 1]);
f.lowBoost = checkField(g3, 2, 'low-frequency boost', D0.drive.lowFreqBoost);
f.taperType = dropField(g3, 3, 'taper', ...
    {'cosine','linear','sine','gauss38','gauss20','blackman','none'}, D0.taper.type);
f.taperStart = numField(g3, 4, 'start taper (ms)', D0.taper.startMs, [0 1e7]);
f.taperEnd   = numField(g3, 5, 'end taper (ms)',   D0.taper.endMs,   [0 1e7]);
note3 = uilabel(g3, 'Text', ...
    'A4: start + end taper must not exceed half the sweep length.', ...
    'WordWrap', 'on');
note3.Layout.Row = 6; note3.Layout.Column = [1 2];

% =======================================================================
% Tab 4 - harmonic distortion (M5)
% =======================================================================
t4 = uitab(tg, 'Title', 'Distortion');
g4 = uigridlayout(t4, [8 2]);
g4.RowHeight   = repmat({26}, 1, 8);
g4.ColumnWidth = {165, '1x'};
g4.Padding     = [8 8 8 8];
g4.RowSpacing  = 4;

f.distOn = checkField(g4, 1, 'enable harmonic distortion', D0.distortion.enable);
f.d2amp  = numField(g4, 2, '2nd-order amplitude', D0.distortion.order2Amp, [0 1]);
f.d3amp  = numField(g4, 3, '3rd-order amplitude', D0.distortion.order3Amp, [0 1]);
f.d2pha  = numField(g4, 4, '2nd-order phase (rad)', D0.distortion.phase2Rad, []);
f.d3pha  = numField(g4, 5, '3rd-order phase (rad)', D0.distortion.phase3Rad, []);
f.lowF   = numField(g4, 6, 'low-freq partition (Hz)', D0.distortion.lowFreqHz, [0 1e6]);
f.decay  = numField(g4, 7, 'decay (Hz)', D0.distortion.decayHz, [0.001 1e6]);
f.pilotMode = dropField(g4, 8, 'pilot mode', {'single','perSource'}, D0.distortion.pilotMode);

% =======================================================================
% Tab 5 - extension-type parameters
% =======================================================================
tExtType = uitab(tg, 'Title', 'Extend');
gx = uigridlayout(tExtType, [6 2]);
gx.RowHeight   = {26, 26, 26, 26, 26, '1x'};
gx.ColumnWidth = {165, '1x'};
gx.Padding     = [8 8 8 8];
gx.RowSpacing  = 4;

f.segFreq  = textField(gx, 1, 'segment freqs (Hz)', '6 30 60 96');
f.segLen   = textField(gx, 2, 'segment lengths (ms)', '2000 4000 6000');
f.variCount = numField(gx, 3, 'vari count', D0.sweep.variCount, [1 1000]);
f.variJitter = numField(gx, 4, 'vari jitter (%)', D0.sweep.variBandJitterPct, [0 99]);
f.codeGap  = numField(gx, 5, 'coded gap (ms)', D0.code.gapMs, [0 1e7]);
noteX = uilabel(gx, 'Text', ...
    ['piecewiseLinear: node count = segment count + 1; segment lengths ' ...
     'must sum to the sweep length. coded: Golay pair with optional gap. ' ...
     'variSweep: superposed detuned chirps.'], 'WordWrap', 'on');
noteX.Layout.Row = 6; noteX.Layout.Column = [1 2];

% =======================================================================
% Tab 6 - external signal import / display
% =======================================================================
tExt = uitab(tg, 'Title', 'External');
g6 = uigridlayout(tExt, [15 2]);
g6.RowHeight   = {22, 22, 22, 22, 22, 22, 22, 24, 24, 28, 64, 26, 26, 26, '1x'};
g6.ColumnWidth = {165, '1x'};
g6.Padding     = [6 6 6 6];
g6.RowSpacing  = 3;

f.extDt = numField(g6, 1, 'fallback dt (ms)', D0.sweep.dtMs, [0.001 1000]);
f.extTimeMode = dropField(g6, 2, 'time column', {'auto','yes','no'}, 'auto');
f.extTimeUnit = dropField(g6, 3, 'time unit', {'auto','s','ms'}, 'auto');
f.extChannel  = numField(g6, 4, 'channel / column', 1, [1 1e5]);
f.extTrace    = numField(g6, 5, 'SEG-Y trace', 1, [1 1e6]);
f.extDetrend  = dropField(g6, 6, 'detrend', {'mean','none','linear'}, 'mean');
f.extNorm     = checkField(g6, 7, 'peak-normalise to 1', false);

sub6 = uigridlayout(g6, [1 4]);
sub6.Layout.Row = 8; sub6.Layout.Column = [1 2];
sub6.ColumnWidth = {'fit', '1x', 'fit', '1x'};
sub6.RowHeight = {'1x'};
sub6.Padding = [0 0 0 0];
sub6.ColumnSpacing = 4;
uilabel(sub6, 'Text', 'raw fmt', 'VerticalAlignment', 'center');
f.extRawFmt = uidropdown(sub6, ...
    'Items', {'auto','int16','int32','float32','float64','ibmFloat32'}, ...
    'Value', 'auto');
uilabel(sub6, 'Text', 'order', 'VerticalAlignment', 'center');
f.extByteOrder = uidropdown(sub6, ...
    'Items', {'auto','little','big'}, 'Value', 'auto');

f.extPhase = dropField(g6, 9, 'polar phase', {'auto','sin','cos'}, 'auto');

f.extLoad = uibutton(g6, 'Text', 'Load external signal...', ...
    'ButtonPushedFcn', @(s,e) doLoadExternal());
f.extLoad.Layout.Row = 10; f.extLoad.Layout.Column = [1 2];
f.extLoad.Tooltip = ['Text, Excel, WAV, MAT, SEG-Y, SAC, box sweeps ' ...
    '(.custom/.vsci/.fsci), raw binary. Content sniffing decides the real ' ...
    'format; raw needs sample format/byte order; SCIO needs polar phase.'];

f.extInfo = uilabel(g6, 'Text', 'no external signal loaded', ...
    'FontAngle', 'italic', 'WordWrap', 'on');
f.extInfo.Layout.Row = 11; f.extInfo.Layout.Column = [1 2];

f.extShow = uibutton(g6, 'Text', 'Show in preview', ...
    'ButtonPushedFcn', @(s,e) doShowExternal());
f.extShow.Layout.Row = 12; f.extShow.Layout.Column = 1;

f.extBack = uibutton(g6, 'Text', 'Generated view', ...
    'ButtonPushedFcn', @(s,e) doShowGenerated());
f.extBack.Layout.Row = 12; f.extBack.Layout.Column = 2;

f.extOpen = uibutton(g6, 'Text', 'Open external 4-view figure', ...
    'ButtonPushedFcn', @(s,e) doOpenExternalFigure());
f.extOpen.Layout.Row = 13; f.extOpen.Layout.Column = [1 2];

f.extCmp = uibutton(g6, 'Text', 'Compare with generated reference', ...
    'ButtonPushedFcn', @(s,e) doCompareExternal());
f.extCmp.Layout.Row = 14; f.extCmp.Layout.Column = [1 2];

% =======================================================================
% Tab 6 - QC and output
% =======================================================================
t5 = uitab(tg, 'Title', 'QC');
g5 = uigridlayout(t5, [12 2]);
g5.RowHeight   = repmat({26}, 1, 12);
g5.ColumnWidth = {165, '1x'};
g5.Padding     = [8 8 8 8];
g5.RowSpacing  = 4;

f.specTol  = numField(g5, 1,  'B1 spec tol (dB)', D0.qc.specTolDB, [0 100]);
f.lobeTol  = numField(g5, 2,  'B2 main-lobe tol (%)', D0.qc.mainLobeTolPct, [0 100]);
f.sideMarg = numField(g5, 3,  'B3 side-lobe margin (dB)', D0.qc.sideLobeMarginDB, [0 100]);
f.edgePct  = numField(g5, 4,  'edge band (%)', D0.qc.edgeBandPct, [0 50]);
f.failMode = dropField(g5, 5, 'fail mode', {'error','warn'}, D0.qc.failMode);
f.format   = dropField(g5, 6, 'output format', ...
    {'segy','custom','vsci','all','txt','csv','mat','wav'}, D0.output.format);
f.nTraces  = numField(g5, 7,  'num traces', D0.output.numTraces, [1 100000]);
f.sweepTr  = numField(g5, 8,  'sweep trace no.', D0.output.sweepTraceNumber, [1 100000]);
f.traceId  = numField(g5, 9,  'trace id code', D0.output.traceIdCode, [1 1000]);
f.t0       = numField(g5, 10, 't0 (ms)', D0.output.t0Ms, [0 1e7]);
f.project  = textField(g5, 11, 'project', D0.meta.project);
f.operator = textField(g5, 12, 'operator', D0.meta.operator);

% =======================================================================
% Action buttons
% =======================================================================
bg = uigridlayout(lg, [3 3]);
bg.RowHeight = {36, 32, 32};
bg.ColumnWidth = {'1x','1x','1x'};
bg.Padding = [0 0 0 0];
bg.RowSpacing = 5;
bg.ColumnSpacing = 5;
bg.Layout.Row = 2;

bGen = uibutton(bg, 'Text', 'Generate', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(s,e) doGenerate());
bGen.Layout.Row = 1; bGen.Layout.Column = [1 3];

bSave = uibutton(bg, 'Text', 'Save output...', ...
    'ButtonPushedFcn', @(s,e) doSave());
bSave.Layout.Row = 2; bSave.Layout.Column = 1;

bViews = uibutton(bg, 'Text', 'Open 4 views', ...
    'ButtonPushedFcn', @(s,e) doOpenViews());
bViews.Layout.Row = 2; bViews.Layout.Column = 2;

bReset = uibutton(bg, 'Text', 'Reset', ...
    'ButtonPushedFcn', @(s,e) doReset());
bReset.Layout.Row = 2; bReset.Layout.Column = 3;

bSavePre = uibutton(bg, 'Text', 'Save preset', ...
    'ButtonPushedFcn', @(s,e) doSavePreset());
bSavePre.Layout.Row = 3; bSavePre.Layout.Column = 1;

bLoadPre = uibutton(bg, 'Text', 'Load preset', ...
    'ButtonPushedFcn', @(s,e) doLoadPreset());
bLoadPre.Layout.Row = 3; bLoadPre.Layout.Column = 2;

bQc = uibutton(bg, 'Text', 'QC table CSV', ...
    'ButtonPushedFcn', @(s,e) doExportQc());
bQc.Layout.Row = 3; bQc.Layout.Column = 3;

% =======================================================================
% Right side - four preview axes + QC table
% =======================================================================
right = uipanel(main, 'BorderType', 'none');
right.Layout.Column = 2;
rg = uigridlayout(right, [2 1]);
rg.RowHeight = {'1x', 180};
rg.Padding = [0 0 0 0];
rg.RowSpacing = 6;

ag = uigridlayout(rg, [2 2]);
ag.RowHeight = {'1x','1x'};
ag.ColumnWidth = {'1x','1x'};
ag.Padding = [0 0 0 0];
ag.RowSpacing = 6;
ag.ColumnSpacing = 6;

ax1 = uiaxes(ag); ax2 = uiaxes(ag); ax3 = uiaxes(ag); ax4 = uiaxes(ag);
ax1.Box = 'on'; ax2.Box = 'on'; ax3.Box = 'on'; ax4.Box = 'on';

qg = uigridlayout(rg, [2 1]);
qg.RowHeight = {26, '1x'};
qg.Padding = [0 0 0 0];
qg.RowSpacing = 4;

status = uilabel(qg, 'Text', 'Ready.', 'FontWeight', 'bold');
status.Layout.Row = 1;

tbl = uitable(qg, ...
    'ColumnName', {'ID','Check','Status','Value','Limit','Detail'}, ...
    'ColumnWidth', {34, 120, 46, 62, 62, 140}, ...
    'RowName', [], 'Data', cell(0,6));
tbl.Layout.Row = 2;

% =======================================================================
% Initial state
% =======================================================================
onTypeChanged();
doGenerate();

if nargout > 0
    app = struct('figure', fig, 'axes', [ax1 ax2 ax3 ax4], ...
                 'table', tbl, 'status', status, ...
                 'fields', f, 'generate', @doGenerate, ...
                 'importExternal', @importExternal, ...
                 'compareExternal', @doCompareExternal, ...
                 'showGenerated', @doShowGenerated);
end

% =======================================================================
% Callbacks / helpers
% =======================================================================
    function doGenerate()
        try
            P = collectParams();
            lastwarn('');
            t0 = tic;
            R = vsw_generate(P, struct('figure', false, 'saveDir', '', ...
                'throwOnFail', false));
            elapsed = toc(t0);
            [wmsg, wid] = lastwarn;
            viewMode = 'generated';
            drawPreview();
            updateTable();
            q = R.qc;
            if q.pass
                setStatus(sprintf('PASS  %s   (%.2f s)', R.meta.signalId, elapsed), ...
                    [0.08 0.45 0.10]);
            elseif q.generationPass
                setStatus(sprintf('DESIGN FAIL  %s   (%.2f s)   %s', ...
                    R.meta.signalId, elapsed, strjoin(q.failed, ', ')), ...
                    [0.75 0.40 0.05]);
            else
                setStatus(sprintf('FAIL  %s   (%.2f s)   %s', ...
                    R.meta.signalId, elapsed, strjoin(q.failed, ', ')), ...
                    [0.70 0.08 0.08]);
            end
            if ~isempty(wmsg) && ~strcmp(wid, '')
                status.Tooltip = wmsg;
            else
                status.Tooltip = '';
            end
        catch ME
            if strcmpi(viewMode, 'external') && ~isempty(E) && ~isempty(EA)
                % Keep the imported signal on screen; only the new generation
                % failed, and the previous reference R is still usable.
                drawPreview();
                updateTable();
            else
                R = [];
                clearPlots();
                tbl.ColumnName = {'ID','Check','Status','Value','Limit','Detail'};
                tbl.ColumnWidth = {42, 190, 62, 90, 90, 340};
                tbl.Data = cell(0,6);
            end
            setStatus(['ERROR: ' ME.message], [0.70 0.08 0.08]);
            uialert(fig, ME.message, 'Generation failed');
        end
    end

    function P = collectParams()
        P = struct();
        P.sweep = struct( ...
            'type', f.type.Value, 'direction', f.direction.Value, ...
            'f1Hz', f.f1.Value, 'f2Hz', f.f2.Value, ...
            'lengthMs', f.len.Value, 'dtMs', f.dt.Value, ...
            'initialPhaseDeg', f.phi0.Value, 'sweepConstant', f.sconst.Value, ...
            'sequenceLength', f.seqLen.Value, ...
            'segmentFreqsHz', parseNumList(f.segFreq.Value), ...
            'segmentLengthsMs', parseNumList(f.segLen.Value), ...
            'variCount', f.variCount.Value, ...
            'variBandJitterPct', f.variJitter.Value);
        P.code = struct('order', f.codeOrder.Value, 'chipMs', f.codeChip.Value, ...
            'carrierHz', f.codeCarrier.Value, 'gapMs', f.codeGap.Value);
        P.wavelet = struct('mainFreqHz', f.f0.Value, ...
            'dampingFactor', f.damp.Value, 'lobeAmpRatio', f.lobeA.Value, ...
            'lobeWidthRatio', f.lobeW.Value, ...
            'waveletType', f.waveletType.Value, ...
            'yuFreqLowerHz', f.yuP.Value, 'yuFreqUpperHz', f.yuQ.Value);
        if ~isempty(targetFreq)
            P.wavelet.targetFreqAxis = targetFreq;
            P.wavelet.targetSpectrum = targetAmp;
        end
        P.drive = struct('amplitudeFraction', f.ampFrac.Value, ...
            'lowFreqBoost', f.lowBoost.Value);
        P.taper = struct('type', f.taperType.Value, ...
            'startMs', f.taperStart.Value, 'endMs', f.taperEnd.Value);
        P.distortion = struct('enable', f.distOn.Value, ...
            'order2Amp', f.d2amp.Value, 'order3Amp', f.d3amp.Value, ...
            'phase2Rad', f.d2pha.Value, 'phase3Rad', f.d3pha.Value, ...
            'lowFreqHz', f.lowF.Value, 'decayHz', f.decay.Value, ...
            'pilotMode', f.pilotMode.Value);
        P.qc = struct('specTolDB', f.specTol.Value, ...
            'mainLobeTolPct', f.lobeTol.Value, ...
            'sideLobeMarginDB', f.sideMarg.Value, ...
            'edgeBandPct', f.edgePct.Value, 'failMode', f.failMode.Value);
        P.output = struct('format', f.format.Value, ...
            'numTraces', f.nTraces.Value, ...
            'sweepTraceNumber', f.sweepTr.Value, ...
            'traceIdCode', f.traceId.Value, 't0Ms', f.t0.Value);
        P.meta = struct('project', f.project.Value, 'operator', f.operator.Value);
    end

    function applyParams(P)
        P = vsw_mergeParams(P);
        f.type.Value = P.sweep.type;
        f.direction.Value = P.sweep.direction;
        f.f1.Value = P.sweep.f1Hz;
        f.f2.Value = P.sweep.f2Hz;
        f.len.Value = P.sweep.lengthMs;
        f.dt.Value = P.sweep.dtMs;
        f.phi0.Value = P.sweep.initialPhaseDeg;
        f.sconst.Value = P.sweep.sweepConstant;
        f.seqLen.Value = P.sweep.sequenceLength;
        f.codeOrder.Value = P.code.order;
        f.codeChip.Value = P.code.chipMs;
        f.codeCarrier.Value = P.code.carrierHz;
        f.codeGap.Value = P.code.gapMs;
        f.variCount.Value = P.sweep.variCount;
        f.variJitter.Value = P.sweep.variBandJitterPct;
        if ~isempty(P.sweep.segmentFreqsHz)
            f.segFreq.Value = num2str(P.sweep.segmentFreqsHz(:).', '%.6g ');
        end
        if ~isempty(P.sweep.segmentLengthsMs)
            f.segLen.Value = num2str(P.sweep.segmentLengthsMs(:).', '%.6g ');
        end
        f.f0.Value = P.wavelet.mainFreqHz;
        f.damp.Value = P.wavelet.dampingFactor;
        f.waveletType.Value = P.wavelet.waveletType;
        f.yuP.Value = P.wavelet.yuFreqLowerHz;
        f.yuQ.Value = P.wavelet.yuFreqUpperHz;
        f.lobeA.Value = P.wavelet.lobeAmpRatio;
        f.lobeW.Value = P.wavelet.lobeWidthRatio;
        if ~isempty(P.wavelet.targetFreqAxis)
            targetFreq = P.wavelet.targetFreqAxis(:);
            targetAmp  = P.wavelet.targetSpectrum(:);
            f.targetInfo.Text = sprintf('loaded %d points, %.2f-%.2f Hz', ...
                numel(targetFreq), min(targetFreq), max(targetFreq));
        end
        f.ampFrac.Value = P.drive.amplitudeFraction;
        f.lowBoost.Value = P.drive.lowFreqBoost;
        f.taperType.Value = P.taper.type;
        f.taperStart.Value = P.taper.startMs;
        f.taperEnd.Value = P.taper.endMs;
        f.distOn.Value = P.distortion.enable;
        f.d2amp.Value = P.distortion.order2Amp;
        f.d3amp.Value = P.distortion.order3Amp;
        f.d2pha.Value = P.distortion.phase2Rad;
        f.d3pha.Value = P.distortion.phase3Rad;
        f.lowF.Value = P.distortion.lowFreqHz;
        f.decay.Value = P.distortion.decayHz;
        f.pilotMode.Value = P.distortion.pilotMode;
        f.specTol.Value = P.qc.specTolDB;
        f.lobeTol.Value = P.qc.mainLobeTolPct;
        f.sideMarg.Value = P.qc.sideLobeMarginDB;
        f.edgePct.Value = P.qc.edgeBandPct;
        f.failMode.Value = P.qc.failMode;
        f.format.Value = P.output.format;
        f.nTraces.Value = P.output.numTraces;
        f.sweepTr.Value = P.output.sweepTraceNumber;
        f.traceId.Value = P.output.traceIdCode;
        f.t0.Value = P.output.t0Ms;
        f.project.Value = P.meta.project;
        f.operator.Value = P.meta.operator;
        onTypeChanged();
    end

    function onTypeChanged()
        typ = lower(f.type.Value);
        usesWavelet = any(strcmp(typ, {'dampedricker','customwavelet','targetspectrum'}));
        if strcmp(typ, 'customwavelet')
            f.waveletType.Value = 'custom';
        end
        wt = lower(f.waveletType.Value);
        isTarget = strcmp(typ, 'targetspectrum');
        isYu = usesWavelet && strcmp(wt, 'yu');
        isCustomShape = usesWavelet && strcmp(wt, 'custom');
        setEnable(f.waveletType, ~isTarget && ~strcmp(typ, 'customwavelet'));
        setEnable(f.f0, usesWavelet && ~isTarget && ~isYu);
        setEnable(f.damp, usesWavelet && ~isTarget && ~isYu && ~isCustomShape);
        setEnable(f.yuP, isYu);
        setEnable(f.yuQ, isYu);
        setEnable(f.lobeA, isCustomShape);
        setEnable(f.lobeW, isCustomShape);
        setEnable(f.loadTarget, isTarget);
    end

    function onWaveletTypeChanged()
        typ = f.type.Value;
        if ~any(strcmpi(typ, {'dampedRicker','customWavelet','targetSpectrum'}))
            f.type.Value = 'dampedRicker';
        end
        onTypeChanged();
    end

    function onDirectionChanged()
        if strcmpi(f.direction.Value, 'down') && f.f1.Value < f.f2.Value
            v = f.f1.Value; f.f1.Value = f.f2.Value; f.f2.Value = v;
        elseif strcmpi(f.direction.Value, 'up') && f.f1.Value > f.f2.Value
            v = f.f1.Value; f.f1.Value = f.f2.Value; f.f2.Value = v;
        end
    end

    function doSave()
        if isempty(R)
            uialert(fig, 'Generate a signal first.', 'Nothing to save');
            return;
        end
        outRoot = uigetdir(pwd, 'Select output folder');
        if isequal(outRoot, 0), return; end
        try
            saved = vsw_save(R, outRoot);
            if isfield(saved, 'verify')
                msg = sprintf('Saved: %s   |   SEG-Y verify: %s', ...
                    saved.dir, tf(saved.verify.pass));
            else
                msg = sprintf('Saved: %s   |   format: %s', ...
                    saved.dir, saved.format);
            end
            setStatus(msg, [0.08 0.45 0.10]);
        catch ME
            setStatus(['SAVE ERROR: ' ME.message], [0.70 0.08 0.08]);
            uialert(fig, ME.message, 'Save failed');
        end
    end

    function doOpenViews()
        if isempty(R)
            uialert(fig, 'Generate a signal first.', 'Nothing to plot');
            return;
        end
        vsw_plotFourViews(R, struct('showFreqOnTime', true));
    end

    function doReset()
        applyParams(vsw_defaultParams());
        targetFreq = []; targetAmp = [];
        f.targetInfo.Text = 'no target spectrum loaded';
        setStatus('Reset to defaults.', [0.20 0.20 0.20]);
    end

    function doLoadTarget()
        [fn, pth] = uigetfile( ...
            {'*.csv;*.txt;*.dat','Spectrum files (*.csv,*.txt,*.dat)'; ...
             '*.*','All files'}, 'Load target spectrum');
        if isequal(fn, 0), return; end
        try
            M = readmatrix(fullfile(pth, fn));
            M = M(all(isfinite(M), 2), :);
            if size(M, 2) < 2
                error('Need at least two columns: frequency, amplitude.');
            end
            targetFreq = M(:,1); targetAmp = max(M(:,2), 0);
            [targetFreq, idx] = sort(targetFreq);
            targetAmp = targetAmp(idx);
            if numel(unique(targetFreq)) < 3
                error('Need at least three distinct frequency points.');
            end
            f.targetInfo.Text = sprintf('loaded %d points, %.2f-%.2f Hz', ...
                numel(targetFreq), min(targetFreq), max(targetFreq));
            f.type.Value = 'targetSpectrum';
            onTypeChanged();
            setStatus('Target spectrum loaded.', [0.10 0.40 0.10]);
        catch ME
            uialert(fig, ME.message, 'Could not load spectrum');
        end
    end

    function doSavePreset()
        [fn, pth] = uiputfile('*.mat', 'Save parameter preset');
        if isequal(fn, 0), return; end
        P = collectParams();
        save(fullfile(pth, fn), 'P');
        setStatus(['Preset saved: ' fullfile(pth, fn)], [0.10 0.40 0.10]);
    end

    function doLoadPreset()
        [fn, pth] = uigetfile('*.mat', 'Load parameter preset');
        if isequal(fn, 0), return; end
        try
            S = load(fullfile(pth, fn));
            if ~isfield(S, 'P'), error('MAT file does not contain variable P.'); end
            applyParams(S.P);
            setStatus(['Preset loaded: ' fullfile(pth, fn)], [0.10 0.40 0.10]);
        catch ME
            uialert(fig, ME.message, 'Could not load preset');
        end
    end

    function doExportQc()
        if isempty(R) && isempty(E)
            uialert(fig, 'Generate or load a signal first.', 'Nothing to export');
            return;
        end
        [fn, pth] = uiputfile('*.csv', 'Export table');
        if isequal(fn, 0), return; end
        names = matlab.lang.makeValidName(tbl.ColumnName);
        T = cell2table(tbl.Data, 'VariableNames', names);
        writetable(T, fullfile(pth, fn));
        setStatus(['Table exported: ' fullfile(pth, fn)], [0.10 0.40 0.10]);
    end

    % ---- external signal ---------------------------------------------
    function doLoadExternal()
        [fn, pth] = uigetfile( ...
            {['*.csv;*.txt;*.tsv;*.dat;*.xlsx;*.xls;*.wav;*.mat;' ...
              '*.sgy;*.segy;*.sac;*.custom;*.vsci;*.fsci;*.bin;*.raw'], ...
             'Signals (text, Excel, WAV, MAT, SEG-Y, SAC, box, raw)'; ...
             '*.*', 'All files'}, 'Load external signal');
        if isequal(fn, 0), return; end
        try
            importExternal(fullfile(pth, fn));
        catch ME
            setStatus(['IMPORT ERROR: ' ME.message], [0.70 0.08 0.08]);
            uialert(fig, ME.message, 'Could not import signal');
        end
    end

    function importExternal(file)
        rawFmt = f.extRawFmt.Value;
        if strcmpi(rawFmt, 'auto'), rawFmt = ''; end
        phaseConv = f.extPhase.Value;
        if strcmpi(phaseConv, 'auto'), phaseConv = ''; end
        opts = struct( ...
            'dtMs', f.extDt.Value, ...
            'timeColumn', f.extTimeMode.Value, ...
            'timeUnit', f.extTimeUnit.Value, ...
            'channel', round(f.extChannel.Value), ...
            'trace', round(f.extTrace.Value), ...
            'detrend', f.extDetrend.Value, ...
            'normalize', f.extNorm.Value, ...
            'sampleFormat', rawFmt, ...
            'byteOrder', f.extByteOrder.Value, ...
            'phaseConvention', phaseConv);
        E  = vsw_importSignal(file, opts);
        EA = vsw_analyzeExternal(E, struct('spectrogram', true));
        C  = [];
        viewMode = 'external';
        f.extInfo.Text = sprintf( ...
            ['%s   [%s]\nN = %d, dt = %.6g ms, T = %.4g s, fs = %.6g Hz\n' ...
             'peak = %.4g, rms = %.4g, crest = %.3g, fdom = %.4g Hz'], ...
            E.name, E.kind, E.N, E.dtS*1e3, E.durationS, E.fsHz, ...
            E.peak, E.rms, E.crest, EA.dominantFreqHz);
        if isempty(E.warnings)
            f.extInfo.Tooltip = '';
        else
            f.extInfo.Tooltip = strjoin(E.warnings, newline);
        end
        drawPreview();
        updateTable();
        msg = sprintf('External loaded: %s  (%d samples)', E.name, E.N);
        if ~isempty(E.warnings)
            msg = sprintf('%s  |  %d warning(s), hover the info label', ...
                msg, numel(E.warnings));
        end
        setStatus(msg, [0.10 0.40 0.10]);
    end

    function doShowExternal()
        if isempty(E) || isempty(EA)
            uialert(fig, 'Load an external signal first.', 'Nothing to show');
            return;
        end
        viewMode = 'external';
        drawPreview();
        updateTable();
        setStatus(sprintf('Preview: external  %s', E.name), [0.15 0.25 0.55]);
    end

    function doShowGenerated()
        if isempty(R)
            uialert(fig, 'Generate a signal first.', 'Nothing to show');
            return;
        end
        viewMode = 'generated';
        drawPreview();
        updateTable();
        setStatus(sprintf('Preview: generated  %s', R.meta.signalId), [0.15 0.25 0.55]);
    end

    function doOpenExternalFigure()
        if isempty(E) || isempty(EA)
            uialert(fig, 'Load an external signal first.', 'Nothing to plot');
            return;
        end
        vsw_plotExternal(E, EA);
    end

    function doCompareExternal()
        if isempty(E) || isempty(EA)
            uialert(fig, 'Load an external signal first.', 'No external signal');
            return;
        end
        if isempty(R)
            uialert(fig, 'Generate a reference signal first.', 'No reference');
            return;
        end
        try
            C = vsw_compareExternal(E, R);
            vsw_plotCompare(E, EA, R, C);
            setStatus(C.summary, [0.15 0.25 0.55]);
            if strcmpi(viewMode, 'external'), updateTable(); end
        catch ME
            setStatus(['COMPARE ERROR: ' ME.message], [0.70 0.08 0.08]);
            uialert(fig, ME.message, 'Comparison failed');
        end
    end

    function drawPreview()
        if strcmpi(viewMode, 'external') && ~isempty(E) && ~isempty(EA)
            vsw_drawExternal([ax1 ax2 ax3 ax4], E, EA);
        elseif ~isempty(R)
            drawGenerated();
        else
            clearPlots();
        end
    end

    function drawGenerated()
        A = R.analysis; D = R.D;
        axis(ax1, 'on'); axis(ax2, 'on');
        axis(ax3, 'on'); axis(ax4, 'on');
        % (1) time
        cla(ax1);
        plot(ax1, D.tAxisS, R.derived.signal, 'k', 'LineWidth', 0.8);
        hold(ax1, 'on');
        plot(ax1, D.tAxisS,  R.derived.envelope, 'b--', 'LineWidth', 0.9);
        plot(ax1, D.tAxisS, -R.derived.envelope, 'b--', 'LineWidth', 0.9);
        hold(ax1, 'off'); grid(ax1, 'on');
        xlabel(ax1, 'time (s)'); ylabel(ax1, 'amplitude');
        title(ax1, '(1) time domain');
        xlim(ax1, [0 D.T]);

        % (2) spectrum
        cla(ax2);
        plot(ax2, A.freqAxisHz, A.ampSpectrumDB, 'r', 'LineWidth', 1.0);
        hold(ax2, 'on');
        if ~isempty(A.targetAmp)
            tn = A.targetAmp / max(A.targetAmp);
            plot(ax2, A.freqAxisHz, 20*log10(tn + eps), 'b--', 'LineWidth', 1.0);
            legend(ax2, {'signal','target'}, 'Location', 'southwest');
        end
        hold(ax2, 'off'); grid(ax2, 'on');
        xlabel(ax2, 'frequency (Hz)'); ylabel(ax2, 'dB');
        title(ax2, '(2) amplitude spectrum');
        xlim(ax2, [0 min(D.fHi*1.3, D.fNyqHz)]);
        ylim(ax2, [-80 5]);

        % (3) autocorrelation
        cla(ax3);
        lag = A.acfLagS; sel = abs(lag) <= 0.5;
        plot(ax3, lag(sel), A.acfDB(sel), 'm', 'LineWidth', 1.1);
        hold(ax3, 'on');
        yl = ylim(ax3);
        for kk = 1:2
            if isfinite(A.zeroCrossLagS(kk))
                plot(ax3, [1 1]*A.zeroCrossLagS(kk), yl, ':', ...
                    'Color', [0.4 0.4 0.4]);
            end
        end
        hold(ax3, 'off'); grid(ax3, 'on');
        xlabel(ax3, 'lag (s)'); ylabel(ax3, 'dB');
        title(ax3, sprintf('(3) ACF  zc=%.4g s, side=%.1f dB', ...
            A.zeroCrossS, A.sideLobeDB));
        ylim(ax3, [-70 3]);

        % (4) phase
        cla(ax4);
        plot(ax4, D.tAxisS, R.derived.phaseRad, 'k', 'LineWidth', 1.0);
        grid(ax4, 'on');
        xlabel(ax4, 'time (s)'); ylabel(ax4, 'phase (rad)');
        title(ax4, sprintf('(4) unwrapped phase   max err %.2g rad', ...
            max(abs(A.phaseErrorRad))));
    end

    function clearPlots()
        cla(ax1); cla(ax2); cla(ax3); cla(ax4);
    end

    function updateTable()
        if strcmpi(viewMode, 'external')
            updateTableExternal();
        else
            updateTableGenerated();
        end
    end

    function updateTableGenerated()
        items = R.qc.items;
        n = numel(items);
        data = cell(n, 6);
        for ii = 1:n
            it = items(ii);
            if ~it.applicable
                st = 'n/a';
            elseif isnan(it.pass)
                st = 'rec';
            elseif it.pass
                st = 'PASS';
            else
                st = 'FAIL';
            end
            data(ii,:) = {it.id, it.name, st, num2str(it.value, '%.4g'), ...
                num2str(it.threshold, '%.4g'), it.detail};
        end
        tbl.ColumnName = {'ID','Check','Status','Value','Limit','Detail'};
        tbl.ColumnWidth = {42, 190, 62, 90, 90, 340};
        tbl.Data = data;
        if isempty(data)
            tbl.Data = cell(0,6);
        end
    end

    function updateTableExternal()
        if isempty(E) || isempty(EA)
            tbl.ColumnName = {'ID','Check','Status','Value','Limit','Detail'};
            tbl.ColumnWidth = {42, 190, 62, 90, 90, 340};
            tbl.Data = cell(0,6);
            return;
        end
        d = {
            'X1', 'samples',              'info', E.N,                       '',     'N'
            'X2', 'sample interval',      'info', E.dtS*1e3,                 'ms',   sprintf('%.6g Hz', E.fsHz)
            'X3', 'duration',             'info', E.durationS,               's',    ''
            'X4', 'peak amplitude',       'info', E.peak,                    '',     ''
            'X5', 'RMS amplitude',        'info', E.rms,                     '',     ''
            'X6', 'crest factor',         'info', E.crest,                   '',     'peak / RMS'
            'X7', 'DC offset',            'info', E.dcOffset,                '',     ''
            'X8', 'dominant frequency',   'info', EA.dominantFreqHz,         'Hz',   ''
            'X9', 'occupied band (-20 dB)','info', EA.bandLowHz,             'Hz',   sprintf('to %.6g Hz', EA.bandHighHz)
            'X10','spectral centroid',    'info', EA.spectralCentroidHz,     'Hz',   ''
            'X11','zero-crossing rate',   'info', EA.zeroCrossRateHz,        'Hz',   ''
            'X12','time axis from file',  'info', yesNo(E.timeFromFile),    '',     ''
            'X13','source',               'info', E.kind,                    '',     E.file
            };
        if ~isempty(C)
            d(end+1,:) = {'X14','comparison |rho| peak','info', C.peakCorr, '', ...
                sprintf('lag %.4g s, gain %.2f dB', C.peakLagS, C.gainDB)};
            d(end+1,:) = {'X15','comparison lag',       'info', C.peakLagS, 's', ...
                'positive: external is later than reference'};
        end
        data = cell(size(d,1), 6);
        for ii = 1:size(d,1)
            data(ii,1) = d(ii,1);
            data(ii,2) = d(ii,2);
            data(ii,3) = d(ii,3);
            v = d{ii,4};
            if ischar(v)
                data{ii,4} = v;
            else
                data{ii,4} = num2str(v, '%.6g');
            end
            data(ii,5) = d(ii,5);
            data(ii,6) = d(ii,6);
        end
        tbl.ColumnName = {'ID','Metric','Kind','Value','Unit','Note'};
        tbl.ColumnWidth = {46, 210, 52, 110, 60, 320};
        tbl.Data = data;
    end

    function setStatus(txt, col)
        status.Text = txt;
        status.FontColor = col;
    end
end

% =======================================================================
% Small layout helpers (local to this file)
% =======================================================================
function e = numField(g, row, labelTxt, value, limits)
l = uilabel(g, 'Text', labelTxt, 'VerticalAlignment', 'center');
l.Layout.Row = row; l.Layout.Column = 1;
e = uieditfield(g, 'numeric', 'Value', value);
e.Layout.Row = row; e.Layout.Column = 2;
if nargin >= 5 && ~isempty(limits)
    e.Limits = limits;
end
end

function d = dropField(g, row, labelTxt, items, value)
l = uilabel(g, 'Text', labelTxt, 'VerticalAlignment', 'center');
l.Layout.Row = row; l.Layout.Column = 1;
d = uidropdown(g, 'Items', items, 'Value', value);
d.Layout.Row = row; d.Layout.Column = 2;
end

function c = checkField(g, row, labelTxt, value)
c = uicheckbox(g, 'Text', labelTxt, 'Value', value);
c.Layout.Row = row; c.Layout.Column = [1 2];
end

function e = textField(g, row, labelTxt, value)
l = uilabel(g, 'Text', labelTxt, 'VerticalAlignment', 'center');
l.Layout.Row = row; l.Layout.Column = 1;
e = uieditfield(g, 'text', 'Value', value);
e.Layout.Row = row; e.Layout.Column = 2;
end

function p = localIconPath()
if isdeployed
    p = fullfile(ctfroot, 'logo.png');
    if ~exist(p, 'file')
        p = fullfile(ctfroot, 'matlab', 'logo.png');
    end
else
    p = fullfile(fileparts(mfilename('fullpath')), '..', 'logo.png');
end
end

function v = parseNumList(s)
v = str2num(s); %#ok<ST2NM>
if isempty(v)
    v = [];
else
    v = v(:).';
end
end

function setEnable(h, tf)
if tf, h.Enable = 'on'; else, h.Enable = 'off'; end
end

function s = tf(v)
if v, s = 'PASS'; else, s = 'FAIL'; end
end

function s = yesNo(v)
if v, s = 'yes'; else, s = 'no'; end
end
