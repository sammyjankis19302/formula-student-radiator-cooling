function lap = lap_profile(p)
%LAP_PROFILE  Speed and engine power around one endurance lap.
%
%   lap = lap_profile(p) drives a point-mass car around the lap in p.track.seg:
%   full throttle (limited by engine power and traction) until it must brake
%   (limited by grip) for the next corner, whose speed is set by cornering grip.
%   This is the standard quasi-steady lap-time method. It only needs to give a
%   realistic pattern of engine load; it is not a lap-time prediction.
%
%   Returns node distance s, speed v and time t, and for each interval between
%   nodes the engine brake power P_b, plus the lap time T, length L and v_avg.

c  = p.car;
g0 = 9.81;
[rho, ~, ~, ~, ~] = air_props(p.env.T_amb, p.env.p_amb);
P_avail = p.eng.avail_frac*p.eng.P_peak;    % engine power at full throttle
ds  = p.track.ds;
seg = p.track.seg;

% curvature at each node of one lap
kap = zeros(1, 0);
for i = 1:size(seg, 1)
    n = round(seg(i, 1)/ds);
    if seg(i, 2) > 0
        k = 1/seg(i, 2);
    else
        k = 0;
    end
    kap = [kap, k*ones(1, n)]; %#ok<AGROW>
end
N = numel(kap);

% three laps in a row; the middle one no longer depends on the start speed
kap3 = [kap, kap, kap, kap(1)];
v_lim = inf(size(kap3));
v_lim(kap3 > 0) = sqrt(c.mu_lat*g0./kap3(kap3 > 0));

v = zeros(size(kap3));
v(1) = min(v_lim(1), 10);
for i = 1:numel(v) - 1                     % forward: accelerate
    F = 0.5*rho*c.CdA*v(i)^2 + c.Crr*c.m*g0;
    a_pow = c.eta_dt*P_avail/(c.m*max(v(i), 1)) - F/c.m;
    a_tra = c.mu_long*g0 - F/c.m;
    a = min(a_pow, a_tra);
    v(i+1) = min(sqrt(max(v(i)^2 + 2*a*ds, 0)), v_lim(i+1));
end
for i = numel(v) - 1:-1:1                  % backward: brake in time
    F = 0.5*rho*c.CdA*v(i+1)^2 + c.Crr*c.m*g0;
    a_b = c.mu_brake*g0 + F/c.m;
    v(i) = min(v(i), sqrt(v(i+1)^2 + 2*a_b*ds));
end

vm = v(N+1:2*N+1);                         % middle lap, N intervals
va = vm(1:end-1);
vb = vm(2:end);
dt_i  = 2*ds./(va + vb);
a_i   = (vb.^2 - va.^2)/(2*ds);
v_mid = 0.5*(va + vb);
F_mid = 0.5*rho*c.CdA*v_mid.^2 + c.Crr*c.m*g0;
P_w   = (c.m*a_i + F_mid).*v_mid;          % power at the wheels
P_b   = min(max(P_w, 0)/c.eta_dt, P_avail);% engine brake power

lap.s     = (0:N)*ds;
lap.v     = vm;
lap.t     = [0, cumsum(dt_i)];
lap.P_b   = P_b;
lap.T     = lap.t(end);
lap.L     = N*ds;
lap.v_avg = lap.L/lap.T;
lap.P_avg = sum(P_b.*dt_i)/lap.T;
lap.full_throttle = sum(dt_i(P_b >= 0.999*P_avail))/lap.T;
end
