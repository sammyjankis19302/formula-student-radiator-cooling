function mdl = build_cooling_model(cyc)
%BUILD_COOLING_MODEL  Create the Simulink model ../simulink/cooling_loop.slx by code.
%
%   build_cooling_model() builds the model for the endurance event in
%   cooling_params, block by block and wire by wire, and saves it. Run
%   check_simulink to build it, simulate it and compare it with the script.
%
%   The model:
%     time -> lookup tables: heat into the coolant, pump flow, car speed
%     coolant temperature [T] -> thermostat (lookup) -> flow through the radiator
%     coolant temperature [T] -> fan switch (relay, updated once per step)
%     radiator and fan block (radiator_block.m) -> heat to the air
%     heat in - heat to the air - engine surface loss -> 1/C -> integrator -> [T]
%
%   [T] is a Goto/From tag: it takes the integrator output to the blocks that
%   need the coolant temperature, so no wires run back across the model. The
%   numbers in the blocks are named variables in the model workspace (T_amb,
%   eta_ram, C, ...), copied from cooling_params.
%
%   Solver: fixed-step ode4 (Runge-Kutta) at p.sim.dt, as in simulate_cooling.

here = fileparts(mfilename('fullpath'));
addpath(here);
root = fileparts(here);
outdir = fullfile(root, 'simulink');
if ~exist(outdir, 'dir'), mkdir(outdir); end
p = cooling_params();
if nargin < 1, cyc = endurance_cycle(p); end
dt = p.sim.dt;

mdl = 'cooling_loop';
load_system('simulink');                   % the block library
if bdIsLoaded(mdl), close_system(mdl, 0); end
slx = fullfile(outdir, [mdl, '.slx']);
if exist(slx, 'file'), delete(slx); end
new_system(mdl);

set_param(mdl, 'SolverType', 'Fixed-step');
set_param(mdl, 'Solver', 'ode4', 'FixedStep', num(dt), ...
    'StartTime', '0', 'StopTime', num(cyc.t(end)));
set_param(mdl, 'ReturnWorkspaceOutputs', 'on');

% the drive cycle and the parameters live in the model workspace, so the .slx
% file is self-contained
mws = get_param(mdl, 'ModelWorkspace');
assignin(mws, 'cyc_t',    cyc.t(:)');
assignin(mws, 'cyc_Qin',  cyc.Q_in(:)');
assignin(mws, 'cyc_mdot', cyc.mdot(:)');
assignin(mws, 'cyc_v',    cyc.v(:)');
vars = {'dt', dt; 'T_amb', p.env.T_amb; 'eta_ram', p.air.eta_ram; ...
        'fan_cfm', p.air.fan_cfm; 'C', p.eng.C; 'hA_ext', p.eng.hA_ext; ...
        'T0', p.eng.T0; 'thermo_open', p.ctrl.thermo_open; ...
        'thermo_full', p.ctrl.thermo_full; 'thermo_min', p.ctrl.thermo_min; ...
        'fan_on', p.ctrl.fan_on; 'fan_off', p.ctrl.fan_off};
for k = 1:size(vars, 1)
    assignin(mws, vars{k, 1}, vars{k, 2});
end

% ---------------------------------------------------------------- drive cycle
add('simulink/Sources/Clock', 'Time', [30 165 60 185]);
lookup('Heat into coolant', [120 30 220 60],   'cyc_t', 'cyc_Qin');
lookup('Pump flow',         [120 160 220 190], 'cyc_t', 'cyc_mdot');
lookup('Car speed',         [120 295 220 325], 'cyc_t', 'cyc_v');
logger('Log time',          [120 375 180 395], 't_log');

% ---------------------------------------------------------------- thermostat and fan
from_T('T to thermostat', [240 195 270 215]);
lookup('Thermostat', [300 190 380 220], '[thermo_open thermo_full]', '[thermo_min 1]');
add('simulink/Math Operations/Product', 'Flow through radiator', [440 160 470 220]);
from_T('T to fan switch', [240 240 270 260]);
add('simulink/Discrete/Zero-Order Hold', 'Once per step', [300 235 330 265]);
set_param(blk('Once per step'), 'SampleTime', 'dt');
add('simulink/Discontinuities/Relay', 'Fan switch', [370 235 410 265]);
set_param(blk('Fan switch'), 'OnSwitchValue', 'fan_on', 'OffSwitchValue', 'fan_off', ...
    'OnOutputValue', '1', 'OffOutputValue', '0');
logger('Log fan', [460 266 520 284], 'fan_log');

% ---------------------------------------------------------------- radiator and fan
from_T('T to radiator', [470 120 500 140]);
constant('Ram-air share',   [430 360 500 380], 'eta_ram');
constant('Fan airflow CFM', [430 420 500 440], 'fan_cfm');
constant('Air temperature', [430 480 500 500], 'T_amb');
add('simulink/Signal Routing/Mux', 'Inputs to radiator', [560 100 566 520]);
set_param(blk('Inputs to radiator'), 'Inputs', '7');
radiator_block_matlab_function([620 280 760 340]);
add('simulink/Signal Routing/Demux', 'Radiator outputs', [800 270 806 350]);
set_param(blk('Radiator outputs'), 'Outputs', '2');
logger('Log radiator heat', [900 280 960 300], 'Qrad_log');
set_param(blk('Log radiator heat'), 'NamePlacement', 'alternate');
logger('Log face speed',    [900 320 960 340], 'Vface_log');

% ---------------------------------------------------------------- heat balance of the coolant
add('simulink/Math Operations/Sum', 'Heat balance', [900 25 930 145]);
set_param(blk('Heat balance'), 'Inputs', '+--', 'IconShape', 'rectangular', ...
    'NamePlacement', 'alternate');
add('simulink/Math Operations/Gain', 'Divide by heat capacity', [980 70 1040 100]);
set_param(blk('Divide by heat capacity'), 'Gain', '1/C');
add('simulink/Continuous/Integrator', 'Coolant temperature', [1140 70 1170 100]);
set_param(blk('Coolant temperature'), 'InitialCondition', 'T0');
add('simulink/Signal Routing/Goto', 'T out', [1250 75 1280 95]);
set_param(blk('T out'), 'GotoTag', 'T', 'ShowName', 'off');
add('simulink/Sinks/Scope', 'Coolant temperature plot', [1250 15 1280 45]);
set_param(blk('Coolant temperature plot'), 'NamePlacement', 'alternate');
logger('Log temperature', [1250 115 1310 135], 'T_log');
% engine surface loss hA_ext*(T - T_amb), drawn right to left under the heat balance
add('simulink/Math Operations/Bias', 'Above air temperature', [1100 185 1150 215]);
set_param(blk('Above air temperature'), 'Bias', '-T_amb', 'Orientation', 'left');
add('simulink/Math Operations/Gain', 'Engine surface loss', [960 185 1010 215]);
set_param(blk('Engine surface loss'), 'Gain', 'hA_ext', 'Orientation', 'left');

% ---------------------------------------------------------------- wires
wire('Time/1', 'Pump flow/1');
wire('Time/1', 'Heat into coolant/1');
wire('Time/1', 'Car speed/1');
wire('Time/1', 'Log time/1');
wire('T to thermostat/1', 'Thermostat/1');
wire('Pump flow/1', 'Flow through radiator/1');
wire('Thermostat/1', 'Flow through radiator/2');
wire('T to fan switch/1', 'Once per step/1');
wire('Once per step/1', 'Fan switch/1');
wire('T to radiator/1', 'Inputs to radiator/1');
wire('Flow through radiator/1', 'Inputs to radiator/2');
wire('Fan switch/1', 'Inputs to radiator/3');
wire('Fan switch/1', 'Log fan/1');
wire('Car speed/1', 'Inputs to radiator/4');
wire('Ram-air share/1', 'Inputs to radiator/5');
wire('Fan airflow CFM/1', 'Inputs to radiator/6');
wire('Air temperature/1', 'Inputs to radiator/7');
wire('Inputs to radiator/1', 'Radiator and fan/1');
wire('Radiator and fan/1', 'Radiator outputs/1');
wire('Radiator outputs/1', 'Log radiator heat/1');
wire('Radiator outputs/1', 'Heat balance/2');
wire('Radiator outputs/2', 'Log face speed/1');
wire('Heat into coolant/1', 'Heat balance/1');
wire('Heat balance/1', 'Divide by heat capacity/1');
wire('Divide by heat capacity/1', 'Coolant temperature/1');
T = 'Coolant temperature/1';
wire(T, 'T out/1');
wire(T, 'Coolant temperature plot/1');
wire(T, 'Log temperature/1');
wire(T, 'Above air temperature/1');
wire('Above air temperature/1', 'Engine surface loss/1');
wire('Engine surface loss/1', 'Heat balance/3');

% ---------------------------------------------------------------- compile check
% The MATLAB Function block is compiled when the model first runs. If that
% fails on this computer, swap in an Interpreted MATLAB Function block, which
% runs the same radiator_block.m through MATLAB itself.
try
    sim(mdl, 'StopTime', num(10*dt));
    fprintf('Radiator block: MATLAB Function block (compiled)\n');
catch err
    fprintf('MATLAB Function block did not compile here. The reasons:\n');
    show_causes(err, '  ');
    fprintf('Switching to an Interpreted MATLAB Function block running the same code.\n');
    pos = get_param(blk('Radiator and fan'), 'Position');
    delete_line(mdl, 'Inputs to radiator/1', 'Radiator and fan/1');
    delete_line(mdl, 'Radiator and fan/1', 'Radiator outputs/1');
    delete_block(blk('Radiator and fan'));
    add('simulink/User-Defined Functions/Interpreted MATLAB Function', 'Radiator and fan', pos);
    set_param(blk('Radiator and fan'), 'MATLABFcn', 'radiator_block(u)', 'OutputDimensions', '2');
    wire('Inputs to radiator/1', 'Radiator and fan/1');
    wire('Radiator and fan/1', 'Radiator outputs/1');
    sim(mdl, 'StopTime', num(10*dt));
    fprintf('Radiator block: Interpreted MATLAB Function block\n');
end

save_system(mdl, slx);
fprintf('Saved %s\n', slx);

% ---------------------------------------------------------------- helpers
    function b = blk(name)
        b = [mdl, '/', name];
    end
    function add(lib, name, pos)
        add_block(lib, blk(name), 'Position', pos);
    end
    function lookup(name, pos, bp, tab)
        add('simulink/Lookup Tables/1-D Lookup Table', name, pos);
        set_param(blk(name), 'BreakpointsForDimension1', bp, 'Table', tab, 'ExtrapMethod', 'Clip');
    end
    function constant(name, pos, value)
        add('simulink/Sources/Constant', name, pos);
        set_param(blk(name), 'Value', value);
    end
    function from_T(name, pos)
        add('simulink/Signal Routing/From', name, pos);
        set_param(blk(name), 'GotoTag', 'T', 'ShowName', 'off');
    end
    function logger(name, pos, var)
        add('simulink/Sinks/To Workspace', name, pos);
        set_param(blk(name), 'VariableName', var, 'SaveFormat', 'Array', ...
            'SampleTime', 'dt', 'MaxDataPoints', 'inf');
    end
    function wire(from, to)
        try
            add_line(mdl, from, to, 'autorouting', 'smart');
        catch
            add_line(mdl, from, to, 'autorouting', 'on');   % releases before smart routing
        end
    end
    function radiator_block_matlab_function(pos)
        add('simulink/User-Defined Functions/MATLAB Function', 'Radiator and fan', pos);
        code = sprintf(['function y = radiator_and_fan(u)\n', ...
            '%%#codegen\n', ...
            '%% u = [coolant temperature; coolant flow through the radiator; fan on;\n', ...
            '%%      car speed; ram-air share; fan airflow (CFM); air temperature]\n', ...
            '%% y = [heat to the air (W); air speed at the core face (m/s)]\n', ...
            '%% The equations are in ../matlab/radiator_block.m, shared with the scripts.\n', ...
            'y = radiator_block(u);\n']);
        try
            cfg = get_param(blk('Radiator and fan'), 'MATLABFunctionConfiguration');
            cfg.FunctionScript = code;
        catch
            % older releases: set the script through the Stateflow API
            chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', blk('Radiator and fan'));
            chart.Script = code;
        end
    end
end

function s = num(x)
% full-precision text for a block parameter
s = sprintf('%.17g', x);
end

function show_causes(err, indent)
% print an error and the errors that caused it
fprintf('%s%s\n', indent, strtrim(err.message));
try
    causes = err.cause;
catch
    causes = {};
end
for k = 1:numel(causes)
    show_causes(causes{k}, [indent, '  ']);
end
end
