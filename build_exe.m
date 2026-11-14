function build_exe(makeInstaller)
%BUILD_EXE  Package the GUI as a standalone Windows executable.
%
%   build_exe()            -> build\VibroseisSweepStudio.exe
%   build_exe(true)        -> also try to build a redistributable installer
%
%   Requirements:
%     * MATLAB Compiler (the "MATLAB Compiler" toolbox)
%     * a C/C++ compiler supported by MATLAB Compiler (mcc checks this)
%
%   The generated EXE needs the matching MATLAB Runtime on the target
%   machine.  Use the installer option (or the Application Compiler app) to
%   bundle the runtime for machines that do not have MATLAB.

if nargin < 1, makeInstaller = false; end

here   = fileparts(mfilename('fullpath'));
srcDir = fullfile(here, 'src');
outDir = fullfile(here, 'build');
mainF  = fullfile(here, 'vsw_launch.m');
logoF  = fullfile(here, '..', 'logo.png');
exeName = 'VibroseisSweepStudio';

addpath(srcDir);
if ~exist(outDir, 'dir'), mkdir(outDir); end

if ~exist(mainF, 'file')
    error('build_exe:mainMissing', 'Entry point not found: %s', mainF);
end

fprintf('Building %s ...\n', exeName);
fprintf('  source : %s\n', srcDir);
fprintf('  output : %s\n', outDir);

try
    if exist(logoF, 'file')
        args = {'-m', mainF, '-a', srcDir, '-a', logoF, ...
                '-d', outDir, '-o', exeName, '-v'};
    else
        warning('build_exe:noLogo', 'Window icon not found: %s', logoF);
        args = {'-m', mainF, '-a', srcDir, '-d', outDir, '-o', exeName, '-v'};
    end
    mcc(args{:});
catch ME
    error('build_exe:mccFailed', ...
        ['mcc failed: %s\n' ...
         'Check that MATLAB Compiler and a supported C/C++ compiler are installed ' ...
         '(run "mex -setup" once).'], ME.message);
end

exeFile = fullfile(outDir, [exeName '.exe']);
if exist(exeFile, 'file')
    fprintf('\nBuilt: %s\n', exeFile);
else
    warning('build_exe:noExe', ...
        'mcc finished but %s was not found; inspect the build log above.', exeFile);
end

if makeInstaller
    try
        compiler.package.installer(outDir, ...
            'ApplicationName', 'Vibroseis Sweep Studio', ...
            'Version', '0.3.0', 'OutputDir', fullfile(outDir, 'installer'));
        fprintf('Installer written under %s\n', fullfile(outDir, 'installer'));
    catch ME
        warning('build_exe:installer', ...
            'Could not build installer (%s). Use the Application Compiler app instead.', ...
            ME.message);
    end
end
end
