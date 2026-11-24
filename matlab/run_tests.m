function run_tests()
%RUN_TESTS  Checks on the model. Prints PASS or stops at the first failure.
%
%   Works in MATLAB and in GNU Octave. Takes about a minute in Octave.

here = fileparts(mfilename('fullpath'));
addpath(here);
p = cooling_params();
[rho90, ~, ~, ~, ~] = water_props(90);
mdot = rho90*p.cool.flow_lpm/60000;
n = 0;

% 1. the report's numbers come back from its own inputs
rc = report_check(p, true);
for i = 1:size(rc.rows, 1)
    printed = rc.rows{i, 2}; mine = rc.rows{i, 3};
    if strcmp(rc.rows{i, 1}, 'Air-side h (W/m2K)')
        check(abs(mine - 35*(0.1416/(0.31*0.255)/0.60)^0.78) < 1e-9 && mine < 85, ...
            'report air-side h is 35*2.985^0.78 = 82.1, not the printed 95.7');
    elseif any(strcmp(rc.rows{i, 1}, {'Fin parameter m (1/m)', 'Overall U (W/m2K)', ...
            'Radiator capability (kW)', 'Area needed at 35 % (m2)', 'Fin efficiency'}))
        % these follow from the air-side h; checked with the printed 95.7 below
    else
        check(abs(mine/printed - 1) < 2e-3, ['report value reproduced: ', rc.rows{i, 1}]);
    end
end
U_pr = 1/(1/95.7 + 9.00/(684.2*0.9690));
check(abs(U_pr - 41.62) < 0.01, 'printed U follows from the printed air-side h');
n = n + 1;

% 2. the radiator never beats the second law
for V = [0.5, 2, 5, 10]
    for md = [0.01, 0.1, mdot]
        [Q, d] = radiator_heat(100, 31, md, V, p);
        Qmax = min(d.C_air, d.C_cool)*(100 - 31);
        check(Q > 0 && Q <= Qmax*(1 + 1e-12), 'Q between 0 and C_min dT');
        check(d.eps > 0 && d.eps < 1, 'effectiveness between 0 and 1');
    end
end
check(radiator_heat(31, 31, mdot, 3, p) == 0, 'no heat without a temperature difference');
check(radiator_heat(100, 31, 0, 3, p) == 0, 'no heat without coolant flow');
check(radiator_heat(100, 31, mdot, 0, p) == 0, 'no heat without airflow');
n = n + 1;

% 3. more air, more coolant, hotter coolant: more heat
Q1 = radiator_heat(100, 31, mdot, 2, p); Q2 = radiator_heat(100, 31, mdot, 4, p);
check(Q2 > Q1, 'heat rises with airflow');
Q3 = radiator_heat(100, 31, mdot/4, 4, p);
check(Q2 > Q3, 'heat rises with coolant flow');
check(radiator_heat(110, 31, mdot, 4, p) > Q2, 'heat rises with coolant temperature');
n = n + 1;

% 4. the crossflow formula approaches the Cr -> 0 limit
NTU = 1.3; Cr = 1e-6;
e_cf = 1 - exp((NTU^0.22/Cr)*(exp(-Cr*NTU^0.78) - 1));
check(abs(e_cf - (1 - exp(-NTU))) < 1e-5, 'crossflow effectiveness -> 1 - exp(-NTU) as Cr -> 0');
n = n + 1;

% 5. the lap meets the Formula SAE endurance specification
lap = lap_profile(p);
check(lap.v_avg*3.6 >= 48 && lap.v_avg*3.6 <= 57, 'average lap speed 48-57 km/h');
check(max(lap.v)*3.6 <= 110, 'top speed about 105 km/h or less');
check(abs(p.track.laps*lap.L - 22000) < 500, 'about 22 km in total');
n = n + 1;

% 6. a short cycle: energy balance, step size, and the steady state
q = p; q.track.laps = 2; q.track.change = 30; q.track.idle0 = 10;
cyc = endurance_cycle(q);
res = simulate_cooling(cyc, q);
loss = q.eng.hA_ext*(res.T - q.env.T_amb);
net = trapz(res.t, res.Q_in - res.Q_rad - loss);
stored = q.eng.C*(res.T(end) - res.T(1));
check(abs(net - stored) < 1e-3*sum(abs(res.Q_in))*q.sim.dt, 'energy in = energy stored + energy out');
q2 = q; q2.sim.dt = q.sim.dt/2;
res2 = simulate_cooling(endurance_cycle(q2), q2);
check(abs(max(res2.T) - max(res.T)) < 0.05, 'halving the step changes the peak by under 0.05 K');
n = n + 1;

% 7. a long run at constant speed and load ends at the equilibrium temperature
q = p; Qc = 14e3; vc = 15;
Teq = equilibrium_temperature(Qc, vc, 1, q);
q.ctrl.fan_on = -100; q.ctrl.fan_off = -200;     % fan always on
c.t = 0:q.sim.dt:1500; nn = numel(c.t);
c.v = vc*ones(1, nn); c.Q_in = Qc*ones(1, nn); c.mdot = mdot*ones(1, nn);
r = simulate_cooling(c, q);
check(abs(r.T(end) - Teq) < 0.02, 'constant-load run settles at the equilibrium temperature');
n = n + 1;

% 8. the Simulink radiator block reads its inputs in the documented order
Tc = 97; mr = 0.6; fan = 1; v = 12; eta = 0.30; cfm = 280; Ta = 33;
y = radiator_block([Tc; mr; fan; v; eta; cfm; Ta]);
Vf = airflow(v, fan, eta, cfm, p);
check(abs(y(2) - Vf) < 1e-12, 'Simulink block: air speed at the core face');
check(abs(y(1) - radiator_heat(Tc, Ta, mr, Vf, p)) < 1e-9, 'Simulink block: heat to the air');
n = n + 1;

fprintf('PASS: %d groups of checks\n', n);
end

function check(ok, what)
if ~ok
    error('run_tests:fail', 'FAILED: %s', what);
end
end
