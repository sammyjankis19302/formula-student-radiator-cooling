function p = cooling_params()
%COOLING_PARAMS  Every input to the cooling model, in one place.
%
%   p = cooling_params() returns a struct of numbers (SI units: m, kg, s, W,
%   temperatures in degC). Each value is tagged with where it comes from:
%
%     [sketch]  measured on the radiator, hand sketch of 23 July 2025
%     [dyno]    Ashwa Racing dyno run, 24 December 2024
%     [report]  the value the 2025 report used
%     [source]  from the reference named in the comment (see docs/model.md)
%     [assumed] an engineering estimate; replace it when a measurement exists
%
%   The Simulink model calls this function too, so editing a value here
%   changes both the MATLAB scripts and the Simulink model.

%#codegen
% ---------------------------------------------------------------- radiator core
% 25 single-pass vertical tubes between a top and a bottom tank.
p.geom.n_tubes      = 25;        % [sketch]
p.geom.tube_pitch   = 10.6e-3;   % [sketch] centre-to-centre spacing of the tubes
p.geom.core_depth   = 0.040;     % [sketch] core thickness = tube depth along the airflow
p.geom.tube_length  = 0.256;     % [sketch] core height between the tanks
p.geom.tube_thick   = 2.0e-3;    % [assumed] outer thickness of one flat tube
p.geom.wall         = 0.3e-3;    % [assumed] tube wall thickness
p.geom.fin_rows     = 26;        % [assumed] fin rows: between the tubes and at both side plates
p.geom.fpi          = 12;        % [report] fins per inch
p.geom.fin_thick    = 0.10e-3;   % [assumed] fin sheet thickness
p.geom.louver_pitch = 1.1e-3;    % [assumed] typical louvered automotive fin
p.geom.louver_angle = 27;        % [assumed] degrees
p.geom.louver_ratio = 0.85;      % [assumed] louver length / fin height
p.geom.k_fin        = 180;       % [assumed] W/(m K), brazed aluminium alloy

% ---------------------------------------------------------------- coolant loop
p.cool.flow_lpm     = 139;       % [report] pump flow with the engine running, L/min

% ---------------------------------------------------------------- engine
p.eng.P_peak     = 71.62*745.7;  % [dyno] peak clutch power, 71.62 hp at 10,610 rpm, W
p.eng.avail_frac = 0.85;         % [assumed] mean share of peak power at full throttle, across the gears
p.eng.r_cool     = 0.80;         % [assumed] heat to coolant / brake power (2025 report: 1.17)
p.eng.Q_idle     = 2000;         % [assumed] heat to coolant at idle and on overrun, W
p.eng.C          = 30e3;         % [assumed] effective heat capacity, coolant + engine metal, J/K
p.eng.hA_ext     = 10;           % [assumed] engine surface to air, W/K
p.eng.T0         = 85;           % [assumed] coolant temperature at the start, degC

% ---------------------------------------------------------------- thermostat and fan
p.ctrl.thermo_open = 82;         % [source] GSX-R thermostat starts to open, degC
p.ctrl.thermo_full = 95;         % [source] fully open (8 mm lift), degC
p.ctrl.thermo_min  = 0.02;       % [assumed] share of the pump flow through the radiator when shut
p.ctrl.fan_on      = 95;         % [assumed] fan switches on, degC
p.ctrl.fan_off     = 90;         % [assumed] fan switches off, degC
p.ctrl.T_limit     = 105;        % [assumed] design limit for the coolant, degC

% ---------------------------------------------------------------- air and weather
p.env.T_amb   = 31;              % [source] Coimbatore, average January high, degC
p.env.p_amb   = 96.5e3;          % [assumed] air pressure at about 410 m altitude, Pa
p.air.fan_cfm = 300;             % [report] fan airflow through the core (free-air rating 844 CFM)
p.air.eta_ram = 0.30;            % [assumed] share of the car's speed that reaches the core face

% ---------------------------------------------------------------- car (for the lap)
p.car.m        = 300;            % [assumed] car + driver, kg
p.car.CdA      = 1.0;            % [assumed] drag area, m^2
p.car.Crr      = 0.020;          % [assumed] rolling resistance coefficient
p.car.eta_dt   = 0.90;           % [assumed] engine-to-wheel efficiency
p.car.mu_lat   = 1.4;            % [assumed] cornering grip, g
p.car.mu_long  = 1.0;            % [assumed] traction-limited acceleration, g
p.car.mu_brake = 1.4;            % [assumed] braking, g

% ---------------------------------------------------------------- track and event
% One lap built to the Formula SAE endurance course rules (D.12.2.2): straights of
% at most 77 m between hairpins, constant turns of 30-54 m diameter, hairpins of at
% least 9 m outside diameter, slaloms with 9-15 m cone spacing.
% Rows: [length (m), corner radius (m)]; radius 0 means a straight.
p.track.seg = [ 70  0      % main straight
                14  4.5    % hairpin
                50  0
                63 20      % 40 m diameter constant turn
                12  0
                60  6.0    % slalom, cones about 12 m apart
                40  0
                24 15      % 30 m diameter turn
                77  0      % back straight
                14  4.5    % hairpin
                45  0
                38 12      % chicane
                61  0
                85 27      % 54 m diameter sweeper
                30  0
                14  4.5    % hairpin
                40  0
                48  6.0    % second slalom
                25  0
                28  9      % decreasing-radius turn
                40  0
                22  6.5
                60  0
                40 18 ];
p.track.ds      = 0.5;           % lap-model resolution, m
p.track.laps    = 22;            % laps of about 1 km: the 22 km endurance (D.12.2.1)
p.track.change  = 180;           % driver change at half distance, engine off, s
p.track.idle0   = 60;            % idling on the grid before the start, s

% ---------------------------------------------------------------- solver
p.sim.dt = 0.1;                  % fixed step for both the script and Simulink, s
end
