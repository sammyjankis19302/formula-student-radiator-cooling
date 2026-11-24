# The cooling model in detail

This page gives the equations behind the scripts in `matlab/` and every input in `matlab/cooling_params.m`. Temperatures are in °C and everything else is in SI units unless stated.

## 1. Coolant temperature

The coolant and the engine metal in contact with it share one temperature *T* and one effective heat capacity *C*:

$$C\frac{dT}{dt} = \dot Q_{in}(t) - \dot Q_{rad} - hA_{ext}(T - T_{amb})$$

$\dot Q_{rad}$ is the heat the radiator passes to the air, and $hA_{ext}(T - T_{amb})$ is the heat the engine loses from its own surface. *C* = 30 kJ/K and *hA*<sub>ext</sub> = 10 W/K are assumptions. The equation is integrated by `simulate_cooling.m` and, identically, by the Simulink model.

## 2. Radiator geometry (`radiator_geometry.m`)

The core has *n* = 25 flat tubes at pitch *T*<sub>p</sub> = 10.6 mm, *L* = 256 mm long and *T*<sub>d</sub> = 40 mm deep in the airflow, with louvered fins between them.

| Quantity | Formula | Value |
|---|---|---|
| Fin pitch | *F*<sub>p</sub> = 25.4 mm / FPI | 2.12 mm |
| Fin height | *F*<sub>l</sub> = *T*<sub>p</sub> − *t*<sub>tube</sub> | 8.6 mm |
| Louver length | *L*<sub>l</sub> = 0.85 *F*<sub>l</sub> | 7.31 mm |
| Core face area | (*n*<sub>rows</sub> *F*<sub>l</sub> + *n t*<sub>tube</sub>) *L* | 0.0700 m² |
| Fin area | *n*<sub>rows</sub> (*L*/*F*<sub>p</sub>) · 2 *F*<sub>l</sub> *T*<sub>d</sub> | 2.16 m² |
| Tube outside area | *n* [2 (*T*<sub>d</sub> *L* − fin contact) + 2 *t*<sub>tube</sub> *L*] | 0.51 m² |
| Air-side area | fins + tubes | 2.68 m² |
| Free-flow area | *n*<sub>rows</sub> *F*<sub>l</sub> *L* (1 − δ<sub>f</sub>/*F*<sub>p</sub>) | 0.0545 m² (σ = 0.78) |
| Tube inside | *w*<sub>i</sub> × *h*<sub>i</sub> = (*T*<sub>d</sub> − 2*t*<sub>w</sub>) × (*t*<sub>tube</sub> − 2*t*<sub>w</sub>) | 39.4 × 1.4 mm |
| Coolant flow area | *n w*<sub>i</sub> *h*<sub>i</sub> | 1.38 × 10⁻³ m² |
| Hydraulic diameter | 4 *w*<sub>i</sub> *h*<sub>i</sub> / 2(*w*<sub>i</sub> + *h*<sub>i</sub>) | 2.70 mm |
| Coolant-side area | *n* · 2(*w*<sub>i</sub> + *h*<sub>i</sub>) *L* | 0.52 m² |

## 3. Air side

The air mass flow is set at the inlet, $\dot m_a = \rho(T_{amb}) V_{face} A_{face}$, and the mass velocity in the core is $G = \dot m_a / A_{free}$. With the louver-pitch Reynolds number $Re_{Lp} = G L_p / \mu$, the Colburn factor for louvered fins (Chang and Wang 1997, valid for 100 < *Re*<sub>Lp</sub> < 3000) is

$$j = Re_{Lp}^{-0.49}\left(\frac{\theta}{90}\right)^{0.27}\left(\frac{F_p}{L_p}\right)^{-0.14}\left(\frac{F_l}{L_p}\right)^{-0.29}\left(\frac{T_d}{L_p}\right)^{-0.23}\left(\frac{L_l}{L_p}\right)^{0.68}\left(\frac{T_p}{L_p}\right)^{-0.28}\left(\frac{\delta_f}{L_p}\right)^{-0.05}$$

and $h_a = j\,G\,c_p / Pr^{2/3}$. Each fin joins two tubes, so its effective length is half the fin height:

$$m = \sqrt{\frac{2h_a}{k_f\delta_f}},\qquad \eta_f = \frac{\tanh(mF_l/2)}{mF_l/2},\qquad \eta_o = 1 - \frac{A_{fin}}{A_{air}}(1 - \eta_f)$$

Air properties (`air_props.m`: ideal gas, Sutherland viscosity) are taken at the mean of the inlet and outlet air temperatures, found by repeating the calculation once.

## 4. Coolant side

$Re = \dot m D_h / (A_{flow}\mu)$, with water properties at the coolant temperature (`water_props.m`).

- *Re* ≥ 4000: Gnielinski, $Nu = \dfrac{(f/8)(Re - 1000)Pr}{1 + 12.7\sqrt{f/8}\,(Pr^{2/3} - 1)}$ with $f = (0.790\ln Re - 1.64)^{-2}$.
- *Re* ≤ 2300: fully developed laminar flow in a rectangular duct at constant wall temperature (Shah and London), $Nu = 7.541(1 - 2.610a + 4.970a^2 - 5.119a^3 + 2.702a^4 - 0.548a^5)$, with aspect ratio *a* = *h*<sub>i</sub>/*w*<sub>i</sub>.
- In between, a linear blend of the two.

## 5. The exchanger

$$\frac{1}{UA} = \frac{1}{\eta_o h_a A_{air}} + \frac{t_w}{k\,A_{cool}} + \frac{1}{h_c A_{cool}}$$

With $NTU = UA/C_{min}$ and $C_r = C_{min}/C_{max}$, the effectiveness of a crossflow exchanger with both fluids unmixed is

$$\varepsilon = 1 - \exp\left[\frac{NTU^{0.22}}{C_r}\left(e^{-C_r NTU^{0.78}} - 1\right)\right],\qquad \dot Q_{rad} = \varepsilon\,C_{min}(T - T_{amb})$$

`radiator_heat.m` returns zero when either flow is zero. It uses only operations MATLAB can compile, because it also runs inside the Simulink model.

## 6. Air through the core (`airflow.m`)

$$V_{face} = \sqrt{(\text{fan}\cdot V_{fan})^2 + (\eta_{ram}\,v_{car})^2},\qquad V_{fan} = \frac{\dot V_{fan}}{A_{face}}$$

The fan moves 300 CFM through the core, the figure the 2025 report used; its free-air rating is 844 CFM. $\eta_{ram}$ is the share of the car's speed that reaches the core face. It depends on the duct and is the least certain input.

## 7. Thermostat and fan

The share of the pump flow that passes through the radiator is

$$x(T) = x_{min} + (1 - x_{min})\frac{T - 82}{95 - 82},\quad\text{clipped to } [x_{min}, 1],\qquad \dot m_{rad} = x\,\dot m_{pump}$$

with *x*<sub>min</sub> = 0.02. The fan is a relay: on when *T* ≥ 95 °C, off when *T* ≤ 90 °C, and otherwise unchanged. It is evaluated once per time step, at the start of the step.

## 8. Heat into the coolant and the lap (`lap_profile.m`)

$$\dot Q_{in} = \text{on}(t)\,\left[\dot Q_{idle} + r\,P_b(t)\right]$$

where on(*t*) is 0 during the driver change, *Q*<sub>idle</sub> = 2 kW, and *r* = 0.8.

The lap is a point-mass, quasi-steady simulation over 24 straights and corners that follow Formula SAE rule D.12.2.2:

- straights of at most 77 m between hairpins;
- constant turns of 30–54 m diameter;
- hairpins of at least 9 m outside diameter;
- slaloms with cones about 12 m apart.

On each 0.5 m step:

- **Forward pass:** the car accelerates at full throttle, limited by $\eta_{dt} P_{avail}/(m v)$ and by traction, $\mu_{long} g$, after drag and rolling resistance. Corner speed is capped at $\sqrt{\mu_{lat} g R}$.
- **Backward pass:** the car brakes at up to $\mu_{brake} g$ to make each corner.
- **Lap used:** three laps are driven in a row and the middle one kept, so that it starts and ends at the same speed.
- **Brake power:** $P_b = \min\left[\max(P_{wheel}, 0)/\eta_{dt},\ P_{avail}\right]$, with $P_{avail}$ = 0.85 × the 53.4 kW dyno peak.

The result is a 1000 m lap of 67.5 s, averaging 53.3 km/h with a top speed of 98.6 km/h, inside the rules' 48–57 km/h average and about 105 km/h top. The engine is at full throttle 25 % of the time and averages 14.8 kW.

## 9. The endurance event (`endurance_cycle.m`)

The event runs in this order:

1. 60 s idling on the grid.
2. 11 laps.
3. A 180 s driver change with the engine and pump off.
4. 11 more laps.

That is 22 km in 1726 s. Heat input, pump flow and car speed are tabulated every 0.1 s; between those points, the script and the Simulink lookup tables both interpolate linearly.

## 10. Balance temperatures

- `equilibrium_temperature.m` finds, by bisection, the temperature at which heat out (radiator plus engine surface, with the thermostat working) equals a steady heat input at a steady speed.
- `lap_equilibrium.m` does the same with the radiator's heat averaged over one lap, the fan on and the thermostat wide open. It measures whether the radiator is big enough, independent of *C* and of the thermostat.

## 11. Numerical method and checks

Both the script and Simulink use the classical fourth-order Runge–Kutta method (Simulink's `ode4`) with a fixed 0.1 s step, the same linear interpolation of the drive cycle, and the same once-per-step fan relay. Their results should therefore agree to rounding error, and in MATLAB R2026b they do: the largest difference over the event is 3.8 × 10⁻¹³ K. `run_tests.m` checks eight things:

1. The report's numbers come back from its own inputs, and its one arithmetic slip is identified.
2. Second law: 0 < *Q* ≤ *C*<sub>min</sub> Δ*T* and 0 < ε < 1 over a grid of conditions.
3. No heat passes without a temperature difference, coolant flow or airflow.
4. Heat rises with airflow, coolant flow and coolant temperature, and the crossflow ε tends to 1 − e<sup>−NTU</sup> as *C*<sub>r</sub> → 0.
5. The lap meets the rules: average 48–57 km/h, top speed under 110 km/h, about 22 km in total.
6. Energy balance over the whole event closes, and halving the step changes the peak temperature by less than 0.05 K.
7. A long run at constant load settles at the temperature `equilibrium_temperature.m` predicts, to within 0.02 K.
8. The Simulink radiator block reads its inputs in the documented order.

Beyond these, `check_simulink.m` compares Simulink with the script at every step, and `tests/check_against_python.py` recomputes every result file with the independent Python version in `python/reference.py`.

## 12. Every input

Sources: **sketch**, measured on the car (23 July 2025); **dyno**, the team's dyno run (24 December 2024); **report**, the value the 2025 report used; **source**, a published figure, named in the notes; **assumed**, an engineering estimate, to be replaced when a measurement exists.

| Input | Value | Source | Notes |
|---|---|---|---|
| Tubes | 25 | sketch | single pass, vertical |
| Tube pitch | 10.6 mm | sketch | centre to centre |
| Core depth | 40 mm | sketch | tube depth along the airflow |
| Core height | 256 mm | sketch | between the tanks |
| Tube outer thickness | 2.0 mm | assumed | flat tube |
| Tube wall | 0.3 mm | assumed | |
| Fin rows | 26 | assumed | between the tubes and at both side plates |
| Fin density | 12 per inch | report | |
| Fin thickness | 0.10 mm | assumed | |
| Louver pitch | 1.1 mm | assumed | typical automotive louvered fin |
| Louver angle | 27° | assumed | |
| Louver length | 0.85 × fin height | assumed | |
| Fin conductivity | 180 W/(m K) | assumed | brazed aluminium |
| Pump flow | 139 L/min | report | engine running |
| Peak engine power | 71.62 hp = 53.4 kW | dyno | at the clutch, 10,610 rpm |
| Mean power at full throttle | 0.85 × peak | assumed | across the gears |
| Heat into the coolant | 0.80 × brake power | assumed | the 2025 report implies 1.17 |
| Heat at idle and on overrun | 2 kW | assumed | |
| Effective heat capacity | 30 kJ/K | assumed | coolant plus engine metal |
| Engine surface loss | 10 W/K | assumed | |
| Starting temperature | 85 °C | assumed | |
| Thermostat starts to open | 82 °C | source | GSX-R600 service data |
| Thermostat fully open | 95 °C | source | 8 mm lift |
| Flow when the thermostat is shut | 2 % | assumed | |
| Fan on / off | 95 / 90 °C | assumed | |
| Design limit | 105 °C | assumed | |
| Air temperature | 31 °C | source | Coimbatore, average January high |
| Air pressure | 96.5 kPa | assumed | about 410 m altitude |
| Fan airflow through the core | 300 CFM | report | SPAL VA09-AP12/C-54A, 844 CFM in free air |
| Ram-air share | 0.30 | assumed | share of the car's speed at the core face |
| Car and driver | 300 kg | assumed | |
| Drag area | 1.0 m² | assumed | |
| Rolling resistance | 0.020 | assumed | |
| Engine-to-wheel efficiency | 0.90 | assumed | |
| Cornering grip | 1.4 g | assumed | |
| Traction-limited acceleration | 1.0 g | assumed | |
| Braking | 1.4 g | assumed | |
| Lap model step | 0.5 m | | |
| Laps | 22 | | about 1 km each, rule D.12.2.1 |
| Driver change | 180 s | assumed | engine off |
| Idle before the start | 60 s | assumed | |
| Time step | 0.1 s | | script and Simulink |
