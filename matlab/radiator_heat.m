function [Q, d] = radiator_heat(T_cool, T_amb, mdot, V_face, p)
%RADIATOR_HEAT  Heat the radiator passes from the coolant to the air (W).
%
%   [Q, d] = radiator_heat(T_cool, T_amb, mdot, V_face, p)
%
%   T_cool  coolant temperature at the radiator inlet (degC)
%   T_amb   air temperature in front of the radiator (degC)
%   mdot    coolant mass flow through the radiator (kg/s)
%   V_face  air speed at the core face (m/s), from airflow.m
%   p       parameters from cooling_params
%
%   Method (details in docs/model.md):
%     air side      louvered fins, Chang and Wang (1997) j-factor, fin efficiency
%     coolant side  Gnielinski (turbulent), Shah and London (laminar), blended
%     exchanger     effectiveness-NTU, crossflow with both fluids unmixed
%
%   d returns the intermediate values (UA, effectiveness, h, Reynolds numbers, ...).
%   This function also runs inside the Simulink model, so it uses only
%   operations that MATLAB can compile.

%#codegen
g = radiator_geometry(p.geom);

d.UA = 0; d.NTU = 0; d.eps = 0; d.C_air = 0; d.C_cool = 0;
d.h_air = 0; d.h_cool = 0; d.eta_fin = 0; d.eta_o = 0;
d.Re_Lp = 0; d.Re_cool = 0; d.Nu_cool = 0; d.m_air = 0;
d.T_air_out = T_amb; d.T_cool_out = T_cool;

if mdot <= 1e-9 || V_face <= 1e-9
    Q = 0;
    return
end

% ---------------------------------------------------------------- coolant side
[rho_c, cp_c, mu_c, k_c, Pr_c] = water_props(T_cool); %#ok<ASGLU>
Re_c = mdot*g.Dh/(g.A_flow*mu_c);
% laminar, fully developed, rectangular duct, constant wall temperature (Shah and London)
a = g.aspect;
Nu_lam = 7.541*(1 - 2.610*a + 4.970*a^2 - 5.119*a^3 + 2.702*a^4 - 0.548*a^5);
if Re_c >= 4000
    Nu_c = gnielinski(Re_c, Pr_c);
elseif Re_c <= 2300
    Nu_c = Nu_lam;
else
    % transition: blend linearly between the laminar value and Gnielinski at Re = 4000
    w = (Re_c - 2300)/(4000 - 2300);
    Nu_c = (1 - w)*Nu_lam + w*gnielinski(4000, Pr_c);
end
h_c  = Nu_c*k_c/g.Dh;
hA_c = h_c*g.A_cool;
C_c  = mdot*cp_c;

% ---------------------------------------------------------------- air side
[rho_in, ~, cp_a0, ~, ~] = air_props(T_amb, p.env.p_amb);
m_air = rho_in*V_face*g.A_front;            % air mass flow, set at the inlet
C_a   = m_air*cp_a0;
G     = m_air/g.A_free;                     % mass velocity in the core, kg/(m^2 s)

Lp = p.geom.louver_pitch;
geo = (p.geom.louver_angle/90)^0.27 * (g.Fp/Lp)^(-0.14) * (g.Fl/Lp)^(-0.29) ...
    * (p.geom.core_depth/Lp)^(-0.23) * (g.Ll/Lp)^0.68 ...
    * (p.geom.tube_pitch/Lp)^(-0.28) * (p.geom.fin_thick/Lp)^(-0.05);

T_film = T_amb + 5;                         % first guess of the mean air temperature
Q = 0; UA = 0; NTU = 0; ef = 0; h_a = 0; eta_f = 0; eta_o = 0; Re_Lp = 0;
for it = 1:2                                % refine the air properties once
    [~, mu_a, cp_a, ~, Pr_a] = air_props(T_film, p.env.p_amb);
    Re_Lp = G*Lp/mu_a;
    jf    = geo*Re_Lp^(-0.49);            % Colburn j factor
    h_a   = jf*G*cp_a/Pr_a^(2/3);
    % fin efficiency: a fin joins two tubes, so its effective length is half the fin height
    m_fin = sqrt(2*h_a/(p.geom.k_fin*p.geom.fin_thick));
    ml    = m_fin*g.Fl/2;
    eta_f = tanh(ml)/ml;
    eta_o = 1 - (g.A_fin/g.A_air)*(1 - eta_f);
    hA_a  = eta_o*h_a*g.A_air;

    R_wall = p.geom.wall/(p.geom.k_fin*g.A_cool);
    UA = 1/(1/hA_a + R_wall + 1/hA_c);

    C_min = min(C_a, C_c);
    C_max = max(C_a, C_c);
    Cr    = C_min/C_max;
    NTU   = UA/C_min;
    if Cr < 1e-9
        ef = 1 - exp(-NTU);
    else
        ef = 1 - exp((NTU^0.22/Cr)*(exp(-Cr*NTU^0.78) - 1));
    end
    Q = ef*C_min*(T_cool - T_amb);
    T_film = T_amb + 0.5*Q/C_a;             % mean of the air inlet and outlet
end

d.UA = UA; d.NTU = NTU; d.eps = ef; d.C_air = C_a; d.C_cool = C_c;
d.h_air = h_a; d.h_cool = h_c; d.eta_fin = eta_f; d.eta_o = eta_o;
d.Re_Lp = Re_Lp; d.Re_cool = Re_c; d.Nu_cool = Nu_c; d.m_air = m_air;
d.T_air_out = T_amb + Q/C_a;
d.T_cool_out = T_cool - Q/C_c;
end

function Nu = gnielinski(Re, Pr)
% Gnielinski (1976), with the Petukhov friction factor; 3000 < Re < 5e6
f  = (0.790*log(Re) - 1.64)^(-2);
Nu = (f/8)*(Re - 1000)*Pr/(1 + 12.7*sqrt(f/8)*(Pr^(2/3) - 1));
end
