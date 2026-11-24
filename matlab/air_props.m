function [rho, mu, cp, k, Pr] = air_props(T, p_amb)
%AIR_PROPS  Dry air at temperature T (degC) and pressure p_amb (Pa).
%
%   rho  ideal gas (kg/m^3); mu  Sutherland's law (Pa s);
%   cp   1007 J/(kg K);      k   power-law fit (W/(m K)); Pr = mu cp / k.

%#codegen
TK  = T + 273.15;
rho = p_amb/(287.05*TK);
mu  = 1.716e-5*(TK/273.15)^1.5*(273.15 + 110.4)/(TK + 110.4);
cp  = 1007;
k   = 0.0241*(TK/273.15)^0.81;
Pr  = mu*cp/k;
end
