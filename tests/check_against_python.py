"""Recompute the results with python/reference.py and compare them with the CSV files
that matlab/run_all.m wrote. Run from the repository root:

    octave --no-gui tests/export_params.m      (or the same file in MATLAB)
    python3 tests/check_against_python.py
"""
import csv
import math
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))
import reference as ref  # noqa: E402

RES = ROOT / "results"
p = ref.load_params()
failures = []


def table(name):
    with open(RES / name) as f:
        rows = list(csv.reader(f))
    head = rows[0]
    data = np.array([[float(x) for x in r] for r in rows[1:] if r], dtype=float)
    return head, data


def close(label, a, b, rtol, atol):
    a, b = np.asarray(a, float), np.asarray(b, float)
    err = np.max(np.abs(a - b) / (atol + rtol * np.abs(b)))
    status = "ok " if err <= 1 else "BAD"
    if err > 1:
        failures.append(label)
    print(f"  {status} {label:44s} max |diff| = {np.max(np.abs(a - b)):.3e}")


md = ref.water_props(90)[0] * p["cool"]["flow_lpm"] / 60000
print("radiator heat vs speed")
head, M = table("radiator_map.csv")
etas = [0.15, 0.30, 0.45]
mine = np.zeros_like(M[:, 1:])
for i, s in enumerate(M[:, 0]):
    for j, e in enumerate(etas):
        for f in (0, 1):
            Vf = ref.airflow(s / 3.6, f, e, p["air"]["fan_cfm"], p)
            mine[i, 2 * j + f] = ref.radiator_heat(100, p["env"]["T_amb"], md, Vf, p) / 1e3
close("Q_rad map (kW)", mine, M[:, 1:], 1e-8, 1e-9)

print("what 300 CFM can carry")
head, A = table("airflow_limit.csv")
q = dict(p); q["env"] = dict(p["env"]); q["env"]["T_amb"] = 25; q["env"]["p_amb"] = 101325
rho95 = ref.water_props(95)[0]
model = [ref.radiator_heat(95, 25, rho95 * 139 / 60000, ref.airflow(0, 1, 0, c, q), q) / 1e3 for c in A[:, 0]]
close("model heat at the report design point (kW)", model, A[:, 2], 1e-8, 1e-9)

print("steady temperature vs speed")
head, E = table("equilibrium.csv")
loads = [8, 12, 16, 20, 24]
mine = np.array([[min(ref.equilibrium(L * 1e3, s / 3.6, 1, p), 999) for L in loads] for s in E[:, 0]])
close("equilibrium temperature (degC)", mine, E[:, 1:], 0, 1e-6)

print("lap")
head, L = table("lap.csv")
lap = ref.lap_profile(p)
close("lap distance (m)", lap["s"], L[:, 0], 0, 1e-9)
close("lap time (s)", lap["t"], L[:, 1], 1e-9, 1e-9)
close("lap speed (km/h)", 3.6 * lap["v"], L[:, 2], 1e-9, 1e-9)
close("lap engine power (kW)", np.append(lap["P_b"], lap["P_b"][-1]) / 1e3, L[:, 3], 1e-8, 1e-9)

print("endurance, baseline")
head, B = table("endurance_baseline.csv")
cyc = ref.endurance_cycle(p)
sim = ref.simulate(cyc, p)
k = np.arange(0, cyc["t"].size, 5)
close("time (s)", cyc["t"][k], B[:, 0], 0, 1e-9)
close("heat into coolant (kW)", cyc["Q_in"][k] / 1e3, B[:, 2], 1e-9, 1e-9)
close("coolant temperature (degC)", sim["T"][k], B[:, 4], 0, 1e-6)
close("fan state", sim["fan"][k][:-1], B[:-1, 5], 0, 1e-12)

print("scenarios and sensitivity (lap equilibrium)")
head, S = table("scenarios.csv")
close("baseline lap equilibrium (degC)", [ref.lap_equilibrium(p)], [S[0, 7]], 0, 1e-6)
with open(RES / "sensitivity.csv") as f:
    rows = list(csv.reader(f))[1:]
paths = {"Air temperature (degC)": ("env", "T_amb"), "Ram-air share": ("air", "eta_ram"),
         "Heat to coolant / brake power": ("eng", "r_cool"), "Fins per inch": ("geom", "fpi"),
         "Fan airflow through core (CFM)": ("air", "fan_cfm"),
         "Full-throttle power share": ("eng", "avail_frac"), "Louver pitch (mm)": ("geom", "louver_pitch"),
         "Tube thickness (mm)": ("geom", "tube_thick"), "Coolant flow (L/min)": ("cool", "flow_lpm")}
mine, theirs = [], []
for r in rows:
    grp, key = paths[r[0]]
    for val, Tm in ((float(r[1]), float(r[3])), (float(r[2]), float(r[4]))):
        q = {k2: (dict(v) if isinstance(v, dict) else v) for k2, v in p.items()}
        q[grp][key] = val
        mine.append(ref.lap_equilibrium(q))
        theirs.append(Tm)
close("sensitivity lap equilibria (degC)", mine, theirs, 0, 1e-6)

print()
if failures:
    print("FAIL:", ", ".join(failures))
    sys.exit(1)
print("PASS: the Python reference reproduces every MATLAB result")
