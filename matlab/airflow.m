function V_face = airflow(v_car, fan_on, eta_ram, fan_cfm, p)
%AIRFLOW  Air speed at the radiator face (m/s).
%
%   V_face = airflow(v_car, fan_on, eta_ram, fan_cfm, p)
%
%   v_car    car speed (m/s)
%   fan_on   1 when the fan runs, 0 when it is off
%   eta_ram  share of the car's speed that reaches the core face
%   fan_cfm  fan airflow through the core when the car stands still (CFM)
%
%   The fan is treated as a fixed pressure rise and the ram air as a dynamic
%   pressure, both pushing air through the same core, whose pressure loss grows
%   with the square of the airflow. The two pressures then add, so the squares
%   of the face speeds add:  V_face^2 = V_fan^2 + (eta_ram v_car)^2.

%#codegen
g = radiator_geometry(p.geom);
V_fan  = fan_on*fan_cfm*0.3048^3/60/g.A_front;
V_face = sqrt(V_fan^2 + (eta_ram*v_car)^2);
end
