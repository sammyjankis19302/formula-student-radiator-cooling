function cyc = endurance_cycle(p)
%ENDURANCE_CYCLE  Time history of the endurance event on a fixed time grid.
%
%   cyc = endurance_cycle(p) strings together: idling on the grid, the first
%   half of the laps, the driver change (engine off, so no heat and no pump
%   flow), and the second half. Time step p.sim.dt.
%
%   Fields: t (s), v (m/s), P_b (W), on (1 engine running), Q_in (heat into the
%   coolant, W), mdot (pump flow, kg/s), plus the lap struct and phase times.

lap = lap_profile(p);
dt  = p.sim.dt;
n1  = floor(p.track.laps/2);
n2  = p.track.laps - n1;
t_idle   = p.track.idle0;
t_half1  = n1*lap.T;
t_change = p.track.change;
t_half2  = n2*lap.T;
T_end    = t_idle + t_half1 + t_change + t_half2;

N = ceil(T_end/dt - 1e-9);
t = (0:N)*dt;
v  = zeros(size(t));
Pb = zeros(size(t));
on = ones(size(t));

ti = lap.t(1:end-1);                       % start time of each lap interval
for i = 1:numel(t)
    tau = t(i) - t_idle;
    if tau < 0                             % idling on the grid
        continue
    end
    if tau < t_half1                       % first half
        tl = mod(tau, lap.T);
    elseif tau < t_half1 + t_change        % driver change: engine off
        on(i) = 0;
        continue
    elseif tau < t_half1 + t_change + t_half2   % second half
        tl = mod(tau - t_half1 - t_change, lap.T);
    else                                   % finished, idling (less than one step)
        continue
    end
    v(i)  = interp1(lap.t, lap.v, tl);
    k     = find(ti <= tl, 1, 'last');
    Pb(i) = lap.P_b(k);
end

[rho90, ~, ~, ~, ~] = water_props(90);
cyc.t    = t;
cyc.v    = v;
cyc.P_b  = Pb;
cyc.on   = on;
cyc.Q_in = on.*(p.eng.Q_idle + p.eng.r_cool*Pb);
cyc.mdot = on*rho90*p.cool.flow_lpm/60000;
cyc.lap  = lap;
cyc.t_start  = t_idle;
cyc.t_change = [t_idle + t_half1, t_idle + t_half1 + t_change];
cyc.t_finish = T_end;
end
