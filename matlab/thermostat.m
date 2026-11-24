function x = thermostat(T, p)
%THERMOSTAT  Share of the pump flow that goes through the radiator.
%
%   Opens linearly from p.ctrl.thermo_open to p.ctrl.thermo_full (degC). When
%   shut, a small leak p.ctrl.thermo_min still passes. The Simulink model uses
%   a lookup table with the same two points.

c = p.ctrl;
if T <= c.thermo_open
    x = c.thermo_min;
elseif T >= c.thermo_full
    x = 1;
else
    x = c.thermo_min + (1 - c.thermo_min)*(T - c.thermo_open)/(c.thermo_full - c.thermo_open);
end
end
