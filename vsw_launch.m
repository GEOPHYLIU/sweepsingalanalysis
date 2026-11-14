function vsw_launch()
%VSW_LAUNCH  Entry point for the standalone Windows executable.
%
%   MATLAB Compiler uses this file as the application main (see build_exe.m).
%   vsw_app builds the GUI and returns; a deployed process must stay alive
%   until the user closes the window, so we block on uiwait here.  Running
%   this in a normal MATLAB session is non-blocking.

h = vsw_app();
if isdeployed && isstruct(h) && isfield(h, 'figure') && ishghandle(h.figure)
    uiwait(h.figure);
end
end
