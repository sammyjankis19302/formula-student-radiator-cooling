function [T, info] = lap_equilibrium(p)
%LAP_EQUILIBRIUM  Temperature the coolant settles at, lap after lap (degC).
%
%   [T, info] = lap_equilibrium(p) finds the coolant temperature at which the
%   heat the radiator and engine surface lose, averaged over one lap, equals the
%   lap-averaged heat into the coolant, with the thermostat fully open and the
%   fan running. It does not depend on the thermal mass or the thermostat, so it
%   is a clean measure of whether the radiator is big enough:
%   below about 95 degC the thermostat will hold the coolant in its range;
%   above the design limit (105 degC) the car will overheat.

lap = lap_profile(p);
ts  = 0:0.25:lap.T;                        % sample the lap every 0.25 s
ti  = lap.t(1:end-1);
v   = interp1(lap.t, lap.v, ts);
Q_in = p.eng.Q_idle + p.eng.r_cool*lap.P_avg;
[rho90, ~, ~, ~, ~] = water_props(90);
mdot = rho90*p.cool.flow_lpm/60000;
Vf = zeros(size(ts));
for i = 1:numel(ts)
    Vf(i) = airflow(v(i), 1, p.air.eta_ram, p.air.fan_cfm, p);
end

lo = p.env.T_amb + 0.1;
hi = 250;
if heat_out(hi) < Q_in
    T = Inf;
else
    for it = 1:40
        T = 0.5*(lo + hi);
        if heat_out(T) > Q_in
            hi = T;
        else
            lo = T;
        end
    end
    T = 0.5*(lo + hi);
end
info.Q_in = Q_in;
info.lap = lap;

    function q = heat_out(TT)
        qs = zeros(size(ts));
        for k = 1:numel(ts)
            qs(k) = radiator_heat(TT, p.env.T_amb, mdot, Vf(k), p);
        end
        % time average over the lap (trapezoid on the uniform samples)
        q = trapz(ts, qs)/(ts(end) - ts(1)) + p.eng.hA_ext*(TT - p.env.T_amb);
    end
end
