function y = radiator_block(u)
%RADIATOR_BLOCK  The radiator and fan, as one block of the Simulink model.
%
%   y = radiator_block(u) with
%     u = [coolant temperature (degC); coolant flow through the radiator (kg/s);
%          fan on (0 or 1); car speed (m/s); ram-air share;
%          fan airflow through the core (CFM); air temperature (degC)]
%     y = [heat to the air (W); air speed at the core face (m/s)]
%
%   The Simulink model calls this function, which calls the same airflow.m and
%   radiator_heat.m as the MATLAB scripts, so the two can never drift apart.

%#codegen
p = cooling_params();
V_face = airflow(u(4), u(3), u(5), u(6), p);
Q = radiator_heat(u(1), u(7), u(2), V_face, p);
y = [Q; V_face];
end
