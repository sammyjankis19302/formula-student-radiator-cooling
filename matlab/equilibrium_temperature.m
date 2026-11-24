function T = equilibrium_temperature(Q_in, v_car, fan_on, p)
%EQUILIBRIUM_TEMPERATURE  Coolant temperature where heat in = heat out (degC).
%
%   T = equilibrium_temperature(Q_in, v_car, fan_on, p) for a steady heat input
%   Q_in (W) at a steady car speed v_car (m/s), pump running, thermostat free.
%   Heat out (radiator + engine surface) rises with temperature, so bisection
%   on [T_amb, 250] degC finds the single crossing. Returns Inf if even 250 degC
%   is not enough (the model is single-phase water, so read that as "boils").

g_lo = p.env.T_amb;
g_hi = 250;
[rho90, ~, ~, ~, ~] = water_props(90);
mdot = rho90*p.cool.flow_lpm/60000;
Vf = airflow(v_car, fan_on, p.air.eta_ram, p.air.fan_cfm, p);
if heat_out(g_hi) < Q_in
    T = Inf;
    return
end
for it = 1:60
    T = 0.5*(g_lo + g_hi);
    if heat_out(T) > Q_in
        g_hi = T;
    else
        g_lo = T;
    end
end
T = 0.5*(g_lo + g_hi);

    function q = heat_out(TT)
        q = radiator_heat(TT, p.env.T_amb, thermostat(TT, p)*mdot, Vf, p) ...
            + p.eng.hA_ext*(TT - p.env.T_amb);
    end
end
