function res = simulate_cooling(cyc, p)
%SIMULATE_COOLING  Coolant temperature through a drive cycle (plain MATLAB).
%
%   res = simulate_cooling(cyc, p) integrates
%
%       C dT/dt = Q_in(t) - Q_rad(T, ...) - hA_ext (T - T_amb)
%
%   with the classical fourth-order Runge-Kutta method at the fixed step of the
%   cycle. This is the same solver (ode4) and step the Simulink model uses, and
%   the fan switch is updated once per step, like the Simulink relay, so the two
%   give the same answer.
%
%   res.t, res.T (degC), res.fan, res.x (thermostat), res.Q_rad, res.Q_in,
%   res.V_face, res.mdot_rad, res.T_air_out.

t  = cyc.t(:);
N  = numel(t);
dt = t(2) - t(1);
C  = p.eng.C;

T   = zeros(N, 1);
fan = zeros(N, 1);
T(1) = p.eng.T0;
state = 0;                                  % fan relay starts off
for k = 1:N-1
    state = relay(T(k), state, p);
    fan(k) = state;
    tk = t(k);
    k1 = rhs(tk,        T(k),             state);
    k2 = rhs(tk + dt/2, T(k) + dt/2*k1,   state);
    k3 = rhs(tk + dt/2, T(k) + dt/2*k2,   state);
    k4 = rhs(tk + dt,   T(k) + dt*k3,     state);
    T(k+1) = T(k) + dt/6*(k1 + 2*k2 + 2*k3 + k4);
end
fan(N) = relay(T(N), state, p);

% record the heat flows along the way
res.t = t; res.T = T; res.fan = fan;
res.x = zeros(N, 1); res.Q_rad = zeros(N, 1); res.V_face = zeros(N, 1);
res.mdot_rad = zeros(N, 1); res.T_air_out = zeros(N, 1);
res.Q_in = cyc.Q_in(:); res.v = cyc.v(:);
for k = 1:N
    res.x(k) = thermostat(T(k), p);
    res.mdot_rad(k) = res.x(k)*cyc.mdot(k);
    res.V_face(k) = airflow(cyc.v(k), fan(k), p.air.eta_ram, p.air.fan_cfm, p);
    [res.Q_rad(k), d] = radiator_heat(T(k), p.env.T_amb, res.mdot_rad(k), res.V_face(k), p);
    res.T_air_out(k) = d.T_air_out;
end

    function dT = rhs(tt, TT, fan_state)
        u = sample(cyc, tt, dt);
        x = thermostat(TT, p);
        Vf = airflow(u.v, fan_state, p.air.eta_ram, p.air.fan_cfm, p);
        Qr = radiator_heat(TT, p.env.T_amb, x*u.mdot, Vf, p);
        dT = (u.Q_in - Qr - p.eng.hA_ext*(TT - p.env.T_amb))/C;
    end
end

function s = relay(T, s, p)
% on at fan_on, off at fan_off, otherwise keep the previous state
if T >= p.ctrl.fan_on
    s = 1;
elseif T <= p.ctrl.fan_off
    s = 0;
end
end

function u = sample(cyc, tt, dt)
% linear interpolation on the uniform time grid (what a Simulink lookup table does)
n = numel(cyc.t);
r = tt/dt;
i0 = floor(r);
if i0 < 0
    i0 = 0; f = 0;
elseif i0 >= n - 1
    i0 = n - 2; f = 1;
else
    f = r - i0;
end
a = i0 + 1;
b = i0 + 2;
u.v    = (1 - f)*cyc.v(a)    + f*cyc.v(b);
u.Q_in = (1 - f)*cyc.Q_in(a) + f*cyc.Q_in(b);
u.mdot = (1 - f)*cyc.mdot(a) + f*cyc.mdot(b);
end
