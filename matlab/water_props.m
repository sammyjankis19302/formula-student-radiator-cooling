function [rho, cp, mu, k, Pr] = water_props(T)
%WATER_PROPS  Liquid water at temperature T (degC), valid about 10-120 degC.
%
%   rho  density (kg/m^3), Jones and Harris (1992) fit
%   cp   specific heat (J/(kg K)), 4th-order fit to saturated-liquid tables,
%        within 1.1 J/(kg K) from 10 to 120 degC
%   mu   viscosity (Pa s), Vogel equation, within 1.2 % from 20 to 100 degC
%   k    conductivity (W/(m K)), quadratic fit
%   Pr   Prandtl number

%#codegen
rho = 1000*(1 - (T + 288.9414)/(508929.2*(T + 68.12963))*(T - 3.9863)^2);
cp  = 4208.854 - 2.049979*T + 4.497839e-2*T^2 - 3.713254e-4*T^3 + 1.333042e-6*T^4;
mu  = 2.414e-5*10^(247.8/(T + 273.15 - 140));
k   = 0.5706 + 1.756e-3*T - 6.46e-6*T^2;
Pr  = mu*cp/k;
end
