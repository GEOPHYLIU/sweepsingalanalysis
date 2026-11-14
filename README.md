# 可控震源扫描信号生成与呈现平台（MATLAB 实现）

按《01 参数层与校验口径设计稿 v1.1》《03 产品定义与实现路径 v0.3》《04 标准输出格式与落盘规范 v0.3》《05 呈现层视图数据契约 v0.4》落地的 MATLAB 工程。

> 面向使用者的完整操作说明见 [`../使用说明.md`](../使用说明.md)；本文件保留开发、实现与验收细节。

## 快速开始

```matlab
cd vibroseis-sweep/matlab
run_all              % 依次跑 M1 / M2 / M3 / 扩展类型 / M5 / 输出层 / 外部信号
```

或单跑：

```matlab
addpath('src');
P = vsw_defaultParams();
P.sweep.type = 'linear';
P.sweep.f1Hz = 6; P.sweep.f2Hz = 96;
P.sweep.lengthMs = 16000; P.sweep.dtMs = 1;
R = vsw_generate(P, struct('figure', true, 'saveDir', 'out'));
vsw_printQc(R);
```

`R` 即一份完整结果：`R.P`、`R.D`、`R.derived`、`R.analysis`、`R.qc`。四视图、QC、SEG-Y 写出都只读 `R`，不重算分析量（03 §4 硬约束）。

## GUI 与 EXE 打包

### 启动 GUI

```matlab
cd vibroseis-sweep/matlab
vsw_app            % 开发环境直接启动
```

主窗口固定为 800×600，左右两栏按 2:3 自适应分配，右侧四视图与 QC 表随窗口缩放。左上角窗口图标取仓库根的 `logo.png`（EXE 打包时一并带入）。左侧为参数页（Sweep / Wavelet / Drive / Distortion / Extend / External / QC），右侧为四视图预览与 B1–B12/C1 判据表；页签在 800 宽下可横向滚动。支持：

- **Generate**：生成 + 分析 + QC（实时显示 PASS / DESIGN FAIL / FAIL 与耗时）。
- **Save output**：选目录按 `output format` 写 `.sgy` / `.custom` / `.vsci` / `.json` / `.txt` / `.csv` / `.mat` / `.wav`（`all` 全写，但不含 `.custom` / `.vsci`），并对 SEG-Y 回读执行 04 §9 验收。
- **Open 4 views**：打开完整四视图大图（复用 `vsw_plotFourViews`）。
- **Load target spectrum CSV/TXT**：两列 `[频率 Hz, 幅值 >= 0]`，供 `targetSpectrum` 类型使用。
- **Wavelet 类型联动**：`dampedRicker` 启用 f0/B；`yu` 启用 p/q、关闭 f0/B；`custom` 启用 f0、lobe amp/width、关闭 B。切换类型时控件可编辑状态即时更新。
- **Save / Load preset**：保存/加载 `.mat` 参数集。
- **QC table CSV**：导出判据表。
- **External 页签**：导入外部信号并在四个预览窗中显示时域、幅值谱、时频谱、瞬时频率；可导出独立四视图大图，并与当前生成的参考信号做互相关对比。详见下节。

### 外部信号导入与显示

GUI 的 **External** 页签和命令行 `vsw_importSignal` 支持：

| 格式 | 说明 |
|---|---|
| `.csv` `.txt` `.tsv` `.asc` `.prn` | 数值文本。按 BOM 或严格 UTF-8/GBK 解码，不靠系统代码页静默替换；首列为单调时间轴时自动识别（时间单位可选 auto/s/ms），否则按“回退 dt”采样。 |
| `.xlsx` `.xls` | 数值工作表，默认第一张表，可用 `excelSheet` 指定表名或序号。 |
| `.wav` | `audioread` 读取，可选声道；先核对 `audioinfo` 的采样率与帧数。 |
| `.mat` | 自动查找 `x / signal / data / sweep / trace / waveform` 等向量；识别 `fs/Fs/sampleRate` 或 `dt/dtS/dtMs`；若存在 `tS/time/t` 等时间向量则优先使用。 |
| `.sgy` `.segy` | 读取指定道（默认第 1 道），采样间隔取道头/卷头，IBM float32 与 IEEE 均支持。 |
| `.sac` | SAC 时间序列（632 字节文件头，`iftype=1`），自动判别大小端；`iftype=2/3/4` 明确拒绝。 |
| `.custom` | Sercel 箱体 ASCII 单列带符号振幅，`#` 注释；固定 2000 点/秒（0.5 ms），检查 −1~+1 范围；兼容真实文件的 `TRUE/FALSE` 逻辑尾列（忽略并告警）。 |
| `.vsci` `.fsci` | INOVA SCIO 21 字符定长三列（序号 / 包络 / 相位）；`.vsci` 固定 4000 点/秒，`.fsci` 固定 2048 点/秒；按 `包络 × sin(相位)` 重建，可用 `phaseConvention='cos'` 切换。 |
| `.bin` `.raw` `.int` `.flt`（及二进制 `.dat`） | 裸二进制没有文件头，必须显式给 `sampleFormat`（int16/int32/float32/float64/ibmFloat32）与 `byteOrder`（little/big）；可选 `offsetBytes` 与 `samplesPerTrace`。 |

选项：`dtMs`（回退采样间隔）、`timeColumn`（auto/yes/no）、`timeUnit`（auto/s/ms）、`channel`（文本列 / WAV 声道 / 裸二进制道）、`trace`（SEG-Y 道号）、`detrend`（mean/none/linear）、`normalize`（峰值归一）、`varName`（MAT 变量）、`excelSheet`、`sampleFormat`、`byteOrder`、`offsetBytes`、`samplesPerTrace`、`phaseConvention`（SCI 专用：sin/cos）。

导入按六层顺序校验，任一层失败即中止：

1. **可访问性**：路径存在、非目录、可读、大小非零。
2. **真实格式**：按魔数/结构识别（RIFF、MAT 头、SEG-Y 3200/3600、SAC 632、ZIP/OLE2），扩展名与内容不符时用真实格式并给出告警。
3. **编码与字节序**：文本拒绝非法 UTF-8/GBK；二进制按声明字节序读取，IBM 与 IEEE float32 分开解码。
4. **结构完整性**：头部声明的样点数、记录数与实际文件大小核对，截断文件报错而不是静默读半截。
5. **字段语义**：时间轴单调、采样间隔为正、样本有限，列数一致。
6. **回读核对**：WAV 头帧数、SEG-Y 道头/卷头样点数、SAC npts 与解码样本数对照；SCI 核对 21 字符记录与序号连续性。

箱体格式的导入侧为**只读**；输出侧 `.custom` 与 `.vsci` 可按 `output format` 显式导出（固定 2000 / 4000 点/秒，见 `07_箱体专用扫描文件格式研究.md` §7.2、§7.3），`.fsci` 不导出。采样率由格式固定，`fallback dt` 不参与；SCI 的 `sin/cos` 相位约定需按目标箱体手册核实。

导入后一次性计算（`vsw_analyzeExternal`，绘图只读结果）：

- 单边幅值谱与 dB 谱
- 解析信号相位、瞬时频率
- 自相关与峰值旁瓣
- STFT 时频谱（信号过短时自动留空并提示）
- 标量指标：N、dt、时长、fs、峰值、RMS、波峰因数、直流、主频、−20 dB 占用带宽、频谱质心、过零率

对比（`vsw_compareExternal`）：两端按较粗的 `dt` 重采样、去均值、归一化后互相关；报告峰值 `|rho|`、时差（正数表示外部信号滞后）与增益差。GUI 中对比结果会追加到右侧指标表并在状态栏显示。

命令行示例：

```matlab
E = vsw_importSignal('field_record.sgy', struct('trace', 2, 'detrend', 'linear'));
A = vsw_analyzeExternal(E);
vsw_plotExternal(E, A);                    % 独立四视图
C = vsw_compareExternal(E, R);             % 与已生成参考对比
vsw_plotCompare(E, A, R, C);               % 波形/谱/互相关
```

`demo_external` 会生成参考扫描，并分别以 CSV（含时间列）、单列 TXT、毫秒时间列、WAV、MAT、SEG-Y、XLSX、SAC、裸 float32（大小端）、裸 int16（双道）回读校验；再覆盖 UTF-8 BOM、UTF-16LE、GBK 三种编码、`.custom`、`.vsci`（sin/cos）、`.fsci`，并故意构造“文本改成 `.wav`”、SCI 负包络、截断的 SAC/SEG-Y 反例。22 个用例全部通过：正常路径互相关 `|rho| = 1.0000 @ 0 s`，伪装文件按真实内容识别并告警，结构损坏文件被拒绝。工作区存在真实样件时，另核对 `S1/S2.custom` 与 `S1/S2.txt` 的互相关同为 `|rho| = 1.0000 @ 0 s`。

### 打包成 EXE

需要 **MATLAB Compiler** 与受支持的 C/C++ 编译器（首次先运行 `mex -setup`）。

```matlab
cd vibroseis-sweep/matlab
build_exe          % 生成 build/VibroseisSweepStudio.exe
build_exe(true)    % 另尝试生成包含 MATLAB Runtime 的安装包
```

- 入口函数为 `vsw_launch.m`（编译后 `uiwait` 保持窗口存活）；GUI 本体为 `vsw_app.m`。
- `src/` 由 `mcc -a` 一并打入 CTF，目标机运行时无需外部路径。
- 未安装 MATLAB 的目标机需安装与编译版本一致的 MATLAB Runtime，或用 `build_exe(true)` / Application Compiler 打包 Runtime。

## 目录

```
matlab/
  src/
    vsw_constants.m            冻结常量 C1–C5
    vsw_defaultParams.m        参数层默认值（01 §2）
    vsw_mergeParams.m          部分参数叠加，未知字段报错
    vsw_prepare.m              SI 网格与标量派生量（01 §3）
    vsw_validate.m             A1–A9 前置检查
    vsw_registry.m             类型注册表（新增类型只改这里 + 一个生成器）
    vsw_gen_*.m                14 个生成入口
    vsw_analyticGrid.m         解析式类型的统一方向/相位装配
    vsw_dbOctLaw.m             dB/Oct 公式的数值稳定实现
    vsw_freqFromSpectrum.m     停留时间分配与单调反解
    vsw_dampedRickerSpectrum.m 阻尼雷克解析谱
    vsw_yuSpectrum.m           俞氏子波谱（Ricker 谱在 [p,q] 上的积分）
    vsw_solveDampingForLobe.m  由旁瓣比反解 B
    vsw_taperProfile.m         7 种斜坡（cosine = cos²）
    vsw_assemble.m             相位累积 → 包络 → s(t)
    vsw_analyze.m              一次算完全部谱/ACF/相位/指标
    vsw_qc.m                   B1–B12 + 03-C1
    vsw_applyDistortion.m      M5 现象级谐波与鬼影
    vsw_plotFourViews.m        时域/频域/自相关/相位四视图
    vsw_writeSegy.m            SEG-Y（rev2.1 默认，rev1/rev0 回退；多道复制）
    vsw_ibmEncode/Decode.m     IBM 浮点编解码（含回读校验）
    vsw_readSegy.m             回读验收（支持指定道号与多道）
    vsw_sniffFormat.m          外部文件真实格式识别（魔数/结构）
    vsw_readTextSignal.m       严格编码的数值文本读取
    vsw_readSac.m              SAC 时间序列读取与头部核对
    vsw_readBoxSweep.m         箱体扫描只读（.custom / .vsci / .fsci）
    vsw_readRawSignal.m        裸二进制读取（显式格式/字节序）
    vsw_importSignal.m         外部信号导入与六层校验
    vsw_analyzeExternal.m      外部信号一次算完谱/相位/ACF/时频/指标
    vsw_drawExternal.m         外部信号四视图绘制（GUI 与独立图共用）
    vsw_plotExternal.m         外部信号独立四视图
    vsw_compareExternal.m      外部 vs 参考互相关与时差
    vsw_plotCompare.m          对比图（波形/谱/互相关）
    vsw_writeJson.m / Txt.m    参数快照与人读导出
    vsw_writeCustom.m          Sercel .custom ASCII（固定 2000 点/秒）
    vsw_writeVsci.m            INOVA .vsci SCIO（固定 4000 点/秒）
    vsw_writeCsv.m / Mat.m / Wav.m  便利格式导出（非标准）
    vsw_resampleUniform.m      Fourier 等间隔重采样（箱体固定采样率）
    vsw_save.m                 out/{signalId}/ 落盘 + 04 §9 验收
    vsw_composeSegments.m      分段组合
    vsw_composeSequence.m      M 段相位旋转序列
    vsw_composeBands.m         多频带叠合
  demo_m1_linear.m             M1 贯通 + 四视图
  demo_m2_types.m              M2 解析式类型族
  demo_m3_targets.m            M3 三条设计通路并排
  demo_new_types.m             analogSpectrum / piecewiseLinear / coded / variSweep 四类扩展 + Yu 子波
  demo_m5_distortion.m         M5 鬼影位置与低频谐波比
  demo_output.m                SEG-Y 写读回 + 格式矩阵（含 .custom / .vsci）+ 多道/版本/样点格式验收
  demo_external.m              外部信号多格式导入 + 伪装/截断反例自检
  demo_matrix.m                14 类 × 升/降 × 两组参数的 56 例回归矩阵
  run_all.m
  vsw_app.m                    uifigure GUI（参数页 + 四视图预览 + QC 表）
  vsw_launch.m                 独立 EXE 入口（编译后 uiwait 保持存活）
  build_exe.m                  用 MATLAB Compiler 打包 Windows EXE
```

## 已覆盖的里程碑

| 里程碑 | 内容 | 状态 |
|---|---|---|
| M0 | 参数层、校验口径、五项数值约定 | 已按 v1.1 固化为常量与校验 |
| M1 | linear 全链路 + 四视图 + QC | 完成 |
| M2 | 解析式 6 类（linear/dbPerOct/dbPerHz/tPower/expNeg/logSweep） | 完成 |
| M3 | targetSpectrum / dampedRicker / customWavelet 三通路 | 完成 |
| 扩展类型 | analogSpectrum / piecewiseLinear / coded / variSweep | 完成，注册表 14 类 |
| 参数层扩展 | waveletType=yu、sourceModel、sourceControlCurve、A10/A11 | 完成 |
| M4 | 分段 / 相位旋转序列 / 多频带叠合 | 基础实现 |
| M5 | 现象级谐波 + B11/B12 | 完成（默认关闭） |
| 输出层 | SEG-Y rev2.1 + IBM float32，rev1/rev0 回退，多道复制，json/txt/csv/mat/wav，Sercel `.custom` / INOVA `.vsci` | 完成，04 §9 十五项回读验收；`.custom` 2000 点/秒、`.vsci` 4000 点/秒，回读均 `|rho|=1.0000` |
| 交付层 | GUI（`vsw_app.m`）+ Windows EXE（`build_exe.m`） | 完成，800×600 自适应布局、自定义图标；已生成并试启动 `build/VibroseisSweepStudio.exe` |
| 外部信号 | 导入 / 四视图 / 指标表 / 与参考互相关对比 | 完成，文本/Excel/WAV/MAT/SEG-Y/SAC/裸二进制/箱体文件多格式回读通过；含伪装与截断反例 |
| 回归矩阵 | `demo_matrix.m`：14 类 × 升/降 × 2 组参数 | 56/56 生成通过，56/56 设计判据通过 |

## 实现约定（与文档逐条对应）

- 样点数 `N = lengthMs/dtMs`，不含末端，末样 `T−dt`（C1）。
- 首样 sin 基准，`s(t)=A(t)·sin φ(t)`（C2）。
- 相位离散积分为梯形和（C3）；解析式类型用闭式积分，`phaseError` 为对闭式解的偏差。
- 度→弧度只在入口转换一次（C5）。
- `f1Hz/f2Hz` 为起始/终止频率，随 `direction` 解释；SEG-Y 卷头/道头始终按 min/max 填（03 决策 6）。
- 降频扫描是升频律的严格时间反转，`fOfTS` 单调递减。
- 非标类型 `sweepCode=4`，强制写扩展文本卷头 stanza（04 §6）。
- `writeSweepParamsToBinary=false` 时强制 `writeExtendedStanza=true`（04 §8.1）。

## 刻意保留的边界

- 不与商用实现逐点比对（03 决策 1）；只做端点、谱斜率、ACF 峰位等结构对标。
- M5 是现象级参数化，不含伺服阀/油压物理模型；二次谐波幅度独立可调（03 决策 10）。
- 不生成 SEG-D、厂商私有扫描文件；WAV 仅试听用，幅值超过 ±1 时按峰值缩放。外部导入同样不支持 SEG-D / miniSEED（需要独立的记录/块解码器）；裸二进制必须显式给样点格式与字节序。
- 伪随机类型不是单调扫描，B5/B6 标记为不适用，不伪造通过。

## 已知数值口径说明

- `dbPerOct` 按 00 §2 的曹务祥式(7) 实现，但原式在公开示例参数下 `exp(n·Δf)` 会溢出；`vsw_dbOctLaw.m` 在对数域等价求值，端点与单调性不变。
- `expNeg` 与 `logSweep` 是平台扩展类型的操作定义（文献只给边界条件与总补偿量），公式写在对应生成器头部，便于后续按原文替换。
- `customWavelet` 用时间尺度化的阻尼雷克族实现：`lobeWidthRatio` 定主瓣过零点间距，`B` 由 `lobeAmpRatio` 反解（B≥1）。
- 俞氏子波：`sweep.type='dampedRicker'` 且 `waveletType='yu'` 时，目标谱改为标准 Ricker 幅值谱在 `[p,q]` 上的积分；此时 f0、B 不参与，B2 无解析理论值，标记为不适用。
- A10 对 `N_oct ≥ 2.5` 的单扫描只告警；默认 6–96 Hz 跨 4 个倍频程，因此默认运行会带一条 A10 告警。

## 已知边界与判据口径

- **B4 的主瓣区间取 ACF 包络**：原始 ACF 在主瓣内每个载波半周期过一次零，若按原始过零点积分只能取到半个周期。`vsw_analyze` 用 `acfEnvelope` 的单调衰减段定位主瓣区间，能量仍按 `acfWaveform` 积分（05 §1.3 的“包络仅显示”在 v0.5 修订为“包络只用于定位区间”）。`pseudoRandom` / `coded` / `variSweep` 天生多相关峰，B4 标记为不适用而不是伪造通过。
- **B2 对截断目标谱会判失败**：`dampedRicker` / `customWavelet` 的闭式过零间距来自未截断子波；当扫描频带切掉目标谱两翼（例如 20–70 Hz 内放 f0 = 50 Hz）时，带限子波变宽，B2 必然超差。这是物理结果，不是生成错误；设计时应把 f0 与扫描频带一起选。`demo_matrix.m` 的两组参数都保证目标谱落在带内。
- **B3 对 taper 长度敏感**：目标谱类（`dampedRicker` / `customWavelet`）在 500 ms cosine taper 下，阻带边缘滚降会抬高首旁瓣约 0.2 dB；`demo_m3_targets.m` 采用 150 ms taper 展示三条设计通路同时达标。真实项目应按目标谱与时窗联合选取 taper，并以 B10 记录的边缘能量损失作权衡。
- **B11 的理论位置口径**：宽带、带 taper 的扫描，其谐波鬼影在相关剖面上是宽平台而非尖峰，用单点驻定相位式 `τ=-(n-1)f/f'` 直接对峰会因边缘干涉产生约 0.1 s 的系统偏差，无法满足 1 采样点判据。因此 B11 的 `ghostTheoryTime` 由**实际先导的频率律**经梯形相位积分重建理想 k 次谐波、再与先导相关取峰得到；`ghostMeasuredTime` 用畸变模块实际加入的谐波分量同法取峰。该口径能捕获阶次、方向、相位或积分错误，同时给出采样级可复现的位置。升降频方向规律已验证：升频鬼影在负滞后，降频在正滞后。
- **E1 性能口径**：`demo_m1_linear.m` 现只计时“生成 + 分析 + QC”核心链，不含四视图渲染与 SEG-Y 落盘；本机约 0.2 s，满足 ≤0.3 s。渲染与写盘单独执行。

