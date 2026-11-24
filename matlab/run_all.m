function summary = run_all(fast)
%RUN_ALL  Every result in the README, written to ../results as CSV files.
%
%   run_all       full run (about 2 minutes in MATLAB, 15 in Octave)
%   run_all(true) skips the sensitivity study
%
%   Writes: report_check.csv, airflow_limit.csv, radiator_map.csv,
%   equilibrium.csv, lap.csv, endurance_<case>.csv, scenarios.csv,
%   sensitivity.csv, summary.csv.

if nargin < 1, fast = false; end
here = fileparts(mfilename('fullpath'));
addpath(here);
out = fullfile(fileparts(here), 'results');
if ~exist(out, 'dir'), mkdir(out); end
p = cooling_params();
[rho90, ~, ~, ~, ~] = water_props(90);
mdot = rho90*p.cool.flow_lpm/60000;

% ---------------------------------------------------------------- 1. the 2025 report
rc = report_check(p, true);
fid = fopen(fullfile(out, 'report_check.csv'), 'w');
fprintf(fid, 'quantity,printed,recomputed\n');
for i = 1:size(rc.rows, 1)
    fprintf(fid, '"%s",%.10g,%.10g\n', rc.rows{i, 1}, rc.rows{i, 2}, rc.rows{i, 3});
end
fprintf(fid, '\ncheck,value\n');
for i = 1:size(rc.checks, 1)
    fprintf(fid, '"%s",%.10g\n', rc.checks{i, 1}, rc.checks{i, 2});
end
fclose(fid);
fprintf('report check written\n');

% ---------------------------------------------------------------- 2. what 300 CFM can carry
q = p; q.env.T_amb = 25; q.env.p_amb = 101325;
[rho95, ~, ~, ~, ~] = water_props(95);
cfm = (100:25:900)';
A = zeros(numel(cfm), 3);
rho25 = 101325/(287.05*298.15);
for i = 1:numel(cfm)
    Vf = airflow(0, 1, 0, cfm(i), q);
    Qm = radiator_heat(95, 25, rho95*139/60000, Vf, q);
    A(i, :) = [cfm(i), cfm(i)*0.3048^3/60*rho25*1007*(95 - 25)/1e3, Qm/1e3];
end
write_csv(fullfile(out, 'airflow_limit.csv'), {'fan_cfm', 'air_limit_kW', 'model_kW'}, A);

% ---------------------------------------------------------------- 3. radiator heat vs car speed
spd = (0:2:110)';                           % km/h
etas = [0.15, 0.30, 0.45];
M = zeros(numel(spd), 1 + 2*numel(etas));
M(:, 1) = spd;
for j = 1:numel(etas)
    for i = 1:numel(spd)
        for f = 0:1
            Vf = airflow(spd(i)/3.6, f, etas(j), p.air.fan_cfm, p);
            M(i, 1 + 2*(j - 1) + f + 1) = radiator_heat(100, p.env.T_amb, mdot, Vf, p)/1e3;
        end
    end
end
write_csv(fullfile(out, 'radiator_map.csv'), ...
    {'speed_kmh', 'eta015_fan_off_kW', 'eta015_fan_on_kW', 'eta030_fan_off_kW', ...
     'eta030_fan_on_kW', 'eta045_fan_off_kW', 'eta045_fan_on_kW'}, M);
fprintf('radiator map written\n');

% ---------------------------------------------------------------- 4. steady temperature vs speed
spd = (0:5:110)';
loads = [8, 12, 16, 20, 24];                % kW
E = zeros(numel(spd), 1 + numel(loads));
E(:, 1) = spd;
for j = 1:numel(loads)
    for i = 1:numel(spd)
        E(i, j + 1) = equilibrium_temperature(loads(j)*1e3, spd(i)/3.6, 1, p);
    end
end
E(~isfinite(E)) = 999;                      % "no steady state below 250 degC"
write_csv(fullfile(out, 'equilibrium.csv'), ...
    {'speed_kmh', 'T_8kW', 'T_12kW', 'T_16kW', 'T_20kW', 'T_24kW'}, E);
fprintf('equilibrium curves written\n');

% ---------------------------------------------------------------- 5. the lap
lap = lap_profile(p);
Pb = [lap.P_b, lap.P_b(end)];
write_csv(fullfile(out, 'lap.csv'), {'s_m', 't_s', 'v_kmh', 'P_b_kW_next_interval'}, ...
    [lap.s', lap.t', 3.6*lap.v', Pb'/1e3]);

% ---------------------------------------------------------------- 6. endurance scenarios
cases = {
 'baseline',     {}
 'hot_day',      {'env.T_amb', 35}
 'poor_ducting', {'air.eta_ram', 0.15}
 'report_heat',  {'eng.r_cool', 0.35/0.30}
 'all_three',    {'env.T_amb', 35, 'air.eta_ram', 0.15, 'eng.r_cool', 0.35/0.30}
};
S = zeros(size(cases, 1), 8);
for c = 1:size(cases, 1)
    pc = apply(p, cases{c, 2});
    cyc = endurance_cycle(pc);
    res = simulate_cooling(cyc, pc);
    k = 1:5:numel(res.t);                   % every 0.5 s
    write_csv(fullfile(out, ['endurance_', cases{c, 1}, '.csv']), ...
        {'t_s', 'v_kmh', 'Q_in_kW', 'Q_rad_kW', 'T_C', 'fan', 'thermostat', 'V_face_ms'}, ...
        [res.t(k), 3.6*res.v(k), res.Q_in(k)/1e3, res.Q_rad(k)/1e3, res.T(k), ...
         res.fan(k), res.x(k), res.V_face(k)]);
    on = cyc.v(:) > 0;
    [Teq, ~] = lap_equilibrium(pc);
    S(c, :) = [c, max(res.T), res.T(end), sum(res.T > pc.ctrl.T_limit)*pc.sim.dt, ...
               mean(res.fan), mean(res.Q_in(on))/1e3, mean(res.Q_rad(on))/1e3, Teq];
    fprintf('%-13s peak %6.2f C, lap equilibrium %6.2f C\n', cases{c, 1}, S(c, 2), S(c, 8));
end
write_csv(fullfile(out, 'scenarios.csv'), {'case', 'T_peak_C', 'T_end_C', 's_above_limit', ...
    'fan_on_share', 'Q_in_on_track_kW', 'Q_rad_on_track_kW', 'T_lap_eq_C'}, S);
fid = fopen(fullfile(out, 'scenario_names.csv'), 'w');
fprintf(fid, 'case,name\n');
for c = 1:size(cases, 1), fprintf(fid, '%d,%s\n', c, cases{c, 1}); end
fclose(fid);

% ---------------------------------------------------------------- 7. sensitivity
if ~fast
    sens = {
     'Air temperature (degC)',         'env.T_amb',        25,      35
     'Ram-air share',                  'air.eta_ram',      0.15,    0.45
     'Heat to coolant / brake power',  'eng.r_cool',       0.60,    0.35/0.30
     'Fins per inch',                  'geom.fpi',         10,      16
     'Fan airflow through core (CFM)', 'air.fan_cfm',      200,     450
     'Full-throttle power share',      'eng.avail_frac',   0.75,    0.95
     'Louver pitch (mm)',              'geom.louver_pitch', 0.9e-3, 1.4e-3
     'Tube thickness (mm)',            'geom.tube_thick',  1.6e-3,  2.4e-3
     'Coolant flow (L/min)',           'cool.flow_lpm',    60,      139
    };
    [T0, ~] = lap_equilibrium(p);
    R = zeros(size(sens, 1), 5);
    fid = fopen(fullfile(out, 'sensitivity.csv'), 'w');
    fprintf(fid, 'parameter,low_value,high_value,T_low_C,T_high_C,T_base_C\n');
    for i = 1:size(sens, 1)
        Tl = lap_equilibrium(apply(p, {sens{i, 2}, sens{i, 3}}));
        Th = lap_equilibrium(apply(p, {sens{i, 2}, sens{i, 4}}));
        R(i, :) = [sens{i, 3}, sens{i, 4}, Tl, Th, T0];
        fprintf(fid, '"%s",%.10g,%.10g,%.10g,%.10g,%.10g\n', sens{i, 1}, R(i, :));
        fprintf('%-32s %7.2f %7.2f\n', sens{i, 1}, Tl, Th);
    end
    fclose(fid);
end

% ---------------------------------------------------------------- 8. headline numbers
[Teq0, info] = lap_equilibrium(p);
summary = [lap.L, lap.T, 3.6*lap.v_avg, 3.6*max(lap.v), lap.P_avg/1e3, ...
           100*lap.full_throttle, info.Q_in/1e3, Teq0, S(1, 2), rc.Q_model/1e3];
write_csv(fullfile(out, 'summary.csv'), {'lap_m', 'lap_s', 'v_avg_kmh', 'v_max_kmh', ...
    'P_avg_kW', 'full_throttle_pct', 'Q_in_avg_kW', 'T_lap_eq_C', 'T_peak_C', ...
    'Q_report_point_kW'}, summary);
fprintf('done: results in %s\n', out);
end

function q = apply(p, changes)
% set fields given as 'group.name', value pairs
q = p;
for i = 1:2:numel(changes)
    parts = strsplit(changes{i}, '.');
    q.(parts{1}).(parts{2}) = changes{i + 1};
end
end
