function out = report_check(p, quiet)
%REPORT_CHECK  Re-run the 2025 hand calculation, then check it against physics.
%
%   out = report_check(p) recomputes every number in original/2025-report.pdf
%   from the report's own inputs, prints them next to the printed values, and
%   then shows the three checks that change its conclusion:
%     1. how much heat 300 CFM of air can carry at all,
%     2. what 95 -> 80 degC at 139 L/min would mean,
%     3. the radiator re-calculated with the tube size from the sketch.
%
%   out.rows: {name, value printed in the report, value recomputed here}.

if nargin < 1 || isempty(p), p = cooling_params(); end
if nargin < 2, quiet = false; end

% ---------------------------------------------------------------- the report, as written
Pb = 68.46*0.7457;                  % kW, the report converts 68.46 hp
Qin = Pb/0.30;
Qc  = 0.35*Qin;
V   = 139/60000;                    % m^3/s
mdot = 1000*V;
mt  = mdot/25;
w = 0.036; h = 0.040; L = 0.255;    % the report's tube: 36 mm x 40 mm inside
At = w*h;
vt = mt/(1000*At);
Dh = 2*w*h/(w + h);
Re = 1000*vt*Dh/3.2e-4;
Nu = 0.023*Re^0.8*2.00^0.4;
hc = Nu*0.67/Dh;
vface = 0.1416/(0.31*0.255);
vch = vface/0.60;
ha  = 35*vch^0.78;
m   = sqrt(2*ha/(200*1e-3));
etaf = tanh(m*8e-3)/(m*8e-3);
Awet = 25*2*(w + h)*L;
Aext = 9.00;
U   = 1/(1/ha + Aext/(hc*Awet));
dTlm = (70 - 55)/log(70/55);
Qinst = U*Aext*dTlm/1e3;
Areq = Qc*1e3/(U*dTlm);

rows = {
 'Engine fuel power (kW)',              170.1687, Qin
 'Heat to coolant, 35 % (kW)',          59.5590,  Qc
 'Coolant mass flow (kg/s)',            2.316667, mdot
 'Flow per tube (kg/s)',                0.0926667, mt
 'Coolant speed in a tube (m/s)',       0.06435,  vt
 'Hydraulic diameter (m)',              0.03789,  Dh
 'Reynolds number, coolant',            7.62e3,   Re
 'Nusselt number, coolant',             38.70,    Nu
 'Coolant-side h (W/m2K)',              684.2,    hc
 'Face velocity (m/s)',                 1.791,    vface
 'Channel velocity (m/s)',              2.985,    vch
 'Air-side h (W/m2K)',                  95.7,     ha
 'Fin parameter m (1/m)',               30.93,    m
 'Fin efficiency',                      0.98,     etaf
 'Wetted area, coolant (m2)',           0.9690,   Awet
 'Overall U (W/m2K)',                   41.62,    U
 'Log-mean temperature difference (K)', 62.20,    dTlm
 'Radiator capability (kW)',            23.30,    Qinst
 'Area needed at 35 % (m2)',            23.00,    Areq
};

% ---------------------------------------------------------------- the checks
% These test the report's claims as printed: U = 41.62 W/m2K and 23.30 kW.
U_pr = 41.62; Q_pr = 23.30;
rho_air = 101325/(287.05*298.15);   % air at 25 degC, sea level (the report's conditions)
C_air   = 0.1416*rho_air*1007;      % W/K for 300 CFM
Q_air_max = C_air*(95 - 25)/1e3;    % even if the air left at the coolant inlet temperature
dT_air_needed = Q_pr*1e3/C_air;     % air temperature rise the printed 23.3 kW would need
C_cool = mdot*4186;
Q_95_80 = C_cool*(95 - 80)/1e3;     % heat that 95 -> 80 degC at 139 L/min would remove
dT_cool_Qc = Qc*1e3/C_cool;
NTU = U_pr*Aext/C_air;              % the report's own UA, done with effectiveness-NTU
Cr = C_air/C_cool;
ef = 1 - exp((NTU^0.22/Cr)*(exp(-Cr*NTU^0.78) - 1));
Q_report_UA = ef*C_air*(95 - 25)/1e3;

% this model at the report's design point: 95 degC coolant, 25 degC air, fan only
q = p; q.env.T_amb = 25; q.env.p_amb = 101325;
[rho95, ~, ~, ~, ~] = water_props(95);
Vf = airflow(0, 1, q.air.eta_ram, 300, q);
[Q_model, dm] = radiator_heat(95, 25, rho95*139/60000, Vf, q);
g = radiator_geometry(p.geom);
v_tube = rho95*139/60000/(rho95*g.A_flow);

checks = {
 'Most heat 300 CFM of air can carry, 25 -> 95 degC (kW)', Q_air_max
 'Air temperature rise the printed 23.3 kW would need (K)', dT_air_needed
 'Heat removed by 95 -> 80 degC at 139 L/min (kW)',        Q_95_80
 'Coolant cools by, for 59.6 kW (K)',                      dT_cool_Qc
 'Printed UA, done with effectiveness-NTU (kW)',           Q_report_UA
 'This model: coolant speed in a tube (m/s)',              v_tube
 'This model: Reynolds number, coolant',                   dm.Re_cool
 'This model: coolant-side h (W/m2K)',                     dm.h_cool
 'This model: air-side h (W/m2K)',                         dm.h_air
 'This model: air-side area (m2)',                         g.A_air
 'This model: UA (W/K)',                                   dm.UA
 'This model: radiator heat at the report design point (kW)', Q_model/1e3
};

out.rows = rows;
out.checks = checks;
out.Q_model = Q_model;
if ~quiet
    fprintf('\nThe 2025 report, recomputed from its own inputs\n');
    fprintf('%-40s %12s %12s\n', 'quantity', 'printed', 'recomputed');
    for i = 1:size(rows, 1)
        fprintf('%-40s %12.5g %12.5g\n', rows{i, 1}, rows{i, 2}, rows{i, 3});
    end
    fprintf('\nChecks\n');
    for i = 1:size(checks, 1)
        fprintf('%-58s %10.4g\n', checks{i, 1}, checks{i, 2});
    end
end
end
