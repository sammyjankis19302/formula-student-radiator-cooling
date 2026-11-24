"""Independent Python implementation of the cooling model, used to check the MATLAB code.

It reads the parameters the MATLAB function cooling_params() returns (exported to
results/params.json by tests/export_params.m), recomputes the results, and
tests/check_against_python.py compares them with the CSV files run_all.m wrote.
Two separate codings of the same equations agreeing is the check.
"""
import json
import math
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def load_params(path=ROOT / "results" / "params.json"):
    p = json.loads(Path(path).read_text())
    p["track"]["seg"] = np.array(p["track"]["seg"], dtype=float).reshape(-1, 2)
    return p


# --------------------------------------------------------------------------- properties
def water_props(T):
    rho = 1000 * (1 - (T + 288.9414) / (508929.2 * (T + 68.12963)) * (T - 3.9863) ** 2)
    cp = 4208.854 - 2.049979 * T + 4.497839e-2 * T**2 - 3.713254e-4 * T**3 + 1.333042e-6 * T**4
    mu = 2.414e-5 * 10 ** (247.8 / (T + 273.15 - 140))
    k = 0.5706 + 1.756e-3 * T - 6.46e-6 * T**2
    return rho, cp, mu, k, mu * cp / k


def air_props(T, p_amb):
    TK = T + 273.15
    rho = p_amb / (287.05 * TK)
    mu = 1.716e-5 * (TK / 273.15) ** 1.5 * (273.15 + 110.4) / (TK + 110.4)
    cp = 1007.0
    k = 0.0241 * (TK / 273.15) ** 0.81
    return rho, mu, cp, k, mu * cp / k


# --------------------------------------------------------------------------- radiator
def geometry(geom):
    Fp = 25.4e-3 / geom["fpi"]
    Fl = geom["tube_pitch"] - geom["tube_thick"]
    L, Td, n, nr = geom["tube_length"], geom["core_depth"], geom["n_tubes"], geom["fin_rows"]
    g = {"Fp": Fp, "Fl": Fl, "Ll": geom["louver_ratio"] * Fl}
    g["A_front"] = (nr * Fl + n * geom["tube_thick"]) * L
    n_fins = L / Fp
    g["A_fin"] = nr * n_fins * 2 * Fl * Td
    contact = n_fins * geom["fin_thick"] * Td
    g["A_prim"] = n * (2 * (Td * L - contact) + 2 * geom["tube_thick"] * L)
    g["A_air"] = g["A_fin"] + g["A_prim"]
    g["A_free"] = nr * Fl * L * (1 - geom["fin_thick"] / Fp)
    wi = Td - 2 * geom["wall"]
    hi = geom["tube_thick"] - 2 * geom["wall"]
    g["A_flow"] = n * wi * hi
    P = 2 * (wi + hi)
    g["Dh"] = 4 * wi * hi / P
    g["A_cool"] = n * P * L
    g["aspect"] = hi / wi
    return g


def gnielinski(Re, Pr):
    f = (0.790 * math.log(Re) - 1.64) ** -2
    return (f / 8) * (Re - 1000) * Pr / (1 + 12.7 * math.sqrt(f / 8) * (Pr ** (2 / 3) - 1))


def radiator_heat(Tc, Ta, mdot, Vf, p, details=False):
    if mdot <= 1e-9 or Vf <= 1e-9:
        return (0.0, {}) if details else 0.0
    geom = p["geom"]
    g = geometry(geom)
    _, cp_c, mu_c, k_c, Pr_c = water_props(Tc)
    Re_c = mdot * g["Dh"] / (g["A_flow"] * mu_c)
    a = g["aspect"]
    Nu_lam = 7.541 * (1 - 2.610 * a + 4.970 * a**2 - 5.119 * a**3 + 2.702 * a**4 - 0.548 * a**5)
    if Re_c >= 4000:
        Nu = gnielinski(Re_c, Pr_c)
    elif Re_c <= 2300:
        Nu = Nu_lam
    else:
        w = (Re_c - 2300) / 1700
        Nu = (1 - w) * Nu_lam + w * gnielinski(4000, Pr_c)
    hA_c = Nu * k_c / g["Dh"] * g["A_cool"]
    C_c = mdot * cp_c

    rho_in, _, cp_a0, _, _ = air_props(Ta, p["env"]["p_amb"])
    m_air = rho_in * Vf * g["A_front"]
    C_a = m_air * cp_a0
    G = m_air / g["A_free"]
    Lp = geom["louver_pitch"]
    geo = ((geom["louver_angle"] / 90) ** 0.27 * (g["Fp"] / Lp) ** -0.14 * (g["Fl"] / Lp) ** -0.29
           * (geom["core_depth"] / Lp) ** -0.23 * (g["Ll"] / Lp) ** 0.68
           * (geom["tube_pitch"] / Lp) ** -0.28 * (geom["fin_thick"] / Lp) ** -0.05)
    T_film = Ta + 5
    Q = 0.0
    for _ in range(2):
        _, mu_a, cp_a, _, Pr_a = air_props(T_film, p["env"]["p_amb"])
        Re_Lp = G * Lp / mu_a
        h_a = geo * Re_Lp ** -0.49 * G * cp_a / Pr_a ** (2 / 3)
        ml = math.sqrt(2 * h_a / (geom["k_fin"] * geom["fin_thick"])) * g["Fl"] / 2
        eta_o = 1 - g["A_fin"] / g["A_air"] * (1 - math.tanh(ml) / ml)
        hA_a = eta_o * h_a * g["A_air"]
        UA = 1 / (1 / hA_a + geom["wall"] / (geom["k_fin"] * g["A_cool"]) + 1 / hA_c)
        Cmin, Cmax = min(C_a, C_c), max(C_a, C_c)
        Cr, NTU = Cmin / Cmax, UA / Cmin
        if Cr < 1e-9:
            eff = 1 - math.exp(-NTU)
        else:
            eff = 1 - math.exp(NTU**0.22 / Cr * (math.exp(-Cr * NTU**0.78) - 1))
        Q = eff * Cmin * (Tc - Ta)
        T_film = Ta + 0.5 * Q / C_a
    if details:
        return Q, {"UA": UA, "eps": eff, "h_air": h_a, "Re_Lp": Re_Lp, "Re_cool": Re_c}
    return Q


def airflow(v_car, fan_on, eta_ram, fan_cfm, p):
    g = geometry(p["geom"])
    V_fan = fan_on * fan_cfm * 0.3048**3 / 60 / g["A_front"]
    return math.sqrt(V_fan**2 + (eta_ram * v_car) ** 2)


def thermostat(T, p):
    c = p["ctrl"]
    if T <= c["thermo_open"]:
        return c["thermo_min"]
    if T >= c["thermo_full"]:
        return 1.0
    return c["thermo_min"] + (1 - c["thermo_min"]) * (T - c["thermo_open"]) / (c["thermo_full"] - c["thermo_open"])


# --------------------------------------------------------------------------- lap and event
def lap_profile(p):
    c, g0 = p["car"], 9.81
    rho = air_props(p["env"]["T_amb"], p["env"]["p_amb"])[0]
    P_av = p["eng"]["avail_frac"] * p["eng"]["P_peak"]
    ds = p["track"]["ds"]
    kap = []
    for L, R in p["track"]["seg"]:
        kap += [1 / R if R > 0 else 0.0] * int(round(L / ds))
    kap = np.array(kap)
    N = kap.size
    kap3 = np.concatenate([kap, kap, kap, kap[:1]])
    vlim = np.full(kap3.size, np.inf)
    vlim[kap3 > 0] = np.sqrt(c["mu_lat"] * g0 / kap3[kap3 > 0])
    v = np.zeros(kap3.size)
    v[0] = min(vlim[0], 10.0)
    for i in range(v.size - 1):
        F = 0.5 * rho * c["CdA"] * v[i] ** 2 + c["Crr"] * c["m"] * g0
        a = min(c["eta_dt"] * P_av / (c["m"] * max(v[i], 1.0)) - F / c["m"], c["mu_long"] * g0 - F / c["m"])
        v[i + 1] = min(math.sqrt(max(v[i] ** 2 + 2 * a * ds, 0.0)), vlim[i + 1])
    for i in range(v.size - 2, -1, -1):
        F = 0.5 * rho * c["CdA"] * v[i + 1] ** 2 + c["Crr"] * c["m"] * g0
        v[i] = min(v[i], math.sqrt(v[i + 1] ** 2 + 2 * (c["mu_brake"] * g0 + F / c["m"]) * ds))
    vm = v[N:2 * N + 1]
    va, vb = vm[:-1], vm[1:]
    dt = 2 * ds / (va + vb)
    a = (vb**2 - va**2) / (2 * ds)
    vmid = 0.5 * (va + vb)
    F = 0.5 * rho * c["CdA"] * vmid**2 + c["Crr"] * c["m"] * g0
    Pb = np.minimum(np.maximum((c["m"] * a + F) * vmid, 0) / c["eta_dt"], P_av)
    t = np.concatenate([[0.0], np.cumsum(dt)])
    return {"s": np.arange(N + 1) * ds, "v": vm, "t": t, "P_b": Pb, "T": t[-1], "L": N * ds,
            "P_avg": float(np.sum(Pb * dt) / t[-1])}


def endurance_cycle(p):
    lap = lap_profile(p)
    dt = p["sim"]["dt"]
    n1 = p["track"]["laps"] // 2
    n2 = p["track"]["laps"] - n1
    t_idle, t_ch = p["track"]["idle0"], p["track"]["change"]
    h1, h2 = n1 * lap["T"], n2 * lap["T"]
    T_end = t_idle + h1 + t_ch + h2
    N = math.ceil(T_end / dt - 1e-9)
    t = np.arange(N + 1) * dt
    v, Pb, on = np.zeros(t.size), np.zeros(t.size), np.ones(t.size)
    ti = lap["t"][:-1]
    for i, tt in enumerate(t):
        tau = tt - t_idle
        if tau < 0:
            continue
        if tau < h1:
            tl = math.fmod(tau, lap["T"])
        elif tau < h1 + t_ch:
            on[i] = 0
            continue
        elif tau < h1 + t_ch + h2:
            tl = math.fmod(tau - h1 - t_ch, lap["T"])
        else:
            continue
        v[i] = np.interp(tl, lap["t"], lap["v"])
        Pb[i] = lap["P_b"][np.searchsorted(ti, tl, side="right") - 1]
    rho90 = water_props(90)[0]
    return {"t": t, "v": v, "P_b": Pb, "on": on,
            "Q_in": on * (p["eng"]["Q_idle"] + p["eng"]["r_cool"] * Pb),
            "mdot": on * rho90 * p["cool"]["flow_lpm"] / 60000}


def simulate(cyc, p):
    t, dt = cyc["t"], cyc["t"][1] - cyc["t"][0]
    n = t.size
    T = np.zeros(n)
    fan = np.zeros(n)
    T[0] = p["eng"]["T0"]
    Ta, C = p["env"]["T_amb"], p["eng"]["C"]

    def sample(tt):
        r = tt / dt
        i0 = math.floor(r)
        if i0 < 0:
            i0, f = 0, 0.0
        elif i0 >= n - 1:
            i0, f = n - 2, 1.0
        else:
            f = r - i0
        return [(1 - f) * cyc[k][i0] + f * cyc[k][i0 + 1] for k in ("v", "Q_in", "mdot")]

    def rhs(tt, TT, s):
        v, Qin, md = sample(tt)
        Vf = airflow(v, s, p["air"]["eta_ram"], p["air"]["fan_cfm"], p)
        Qr = radiator_heat(TT, Ta, thermostat(TT, p) * md, Vf, p)
        return (Qin - Qr - p["eng"]["hA_ext"] * (TT - Ta)) / C

    s = 0
    for k in range(n - 1):
        if T[k] >= p["ctrl"]["fan_on"]:
            s = 1
        elif T[k] <= p["ctrl"]["fan_off"]:
            s = 0
        fan[k] = s
        tk = t[k]
        k1 = rhs(tk, T[k], s)
        k2 = rhs(tk + dt / 2, T[k] + dt / 2 * k1, s)
        k3 = rhs(tk + dt / 2, T[k] + dt / 2 * k2, s)
        k4 = rhs(tk + dt, T[k] + dt * k3, s)
        T[k + 1] = T[k] + dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
    return {"t": t, "T": T, "fan": fan}


def equilibrium(Q_in, v_car, fan_on, p):
    Ta = p["env"]["T_amb"]
    md = water_props(90)[0] * p["cool"]["flow_lpm"] / 60000
    Vf = airflow(v_car, fan_on, p["air"]["eta_ram"], p["air"]["fan_cfm"], p)

    def out(T):
        return radiator_heat(T, Ta, thermostat(T, p) * md, Vf, p) + p["eng"]["hA_ext"] * (T - Ta)

    lo, hi = Ta, 250.0
    if out(hi) < Q_in:
        return math.inf
    for _ in range(60):
        T = 0.5 * (lo + hi)
        if out(T) > Q_in:
            hi = T
        else:
            lo = T
    return 0.5 * (lo + hi)


def lap_equilibrium(p):
    lap = lap_profile(p)
    ts = np.arange(0, lap["T"] + 1e-12, 0.25)
    ts = ts[ts <= lap["T"]]
    v = np.interp(ts, lap["t"], lap["v"])
    Qin = p["eng"]["Q_idle"] + p["eng"]["r_cool"] * lap["P_avg"]
    md = water_props(90)[0] * p["cool"]["flow_lpm"] / 60000
    Vf = [airflow(x, 1, p["air"]["eta_ram"], p["air"]["fan_cfm"], p) for x in v]
    Ta = p["env"]["T_amb"]

    def out(T):
        qs = np.array([radiator_heat(T, Ta, md, vf, p) for vf in Vf])
        trap = getattr(np, "trapezoid", None) or np.trapz
        return trap(qs, ts) / (ts[-1] - ts[0]) + p["eng"]["hA_ext"] * (T - Ta)

    lo, hi = Ta + 0.1, 250.0
    if out(hi) < Qin:
        return math.inf
    for _ in range(40):
        T = 0.5 * (lo + hi)
        if out(T) > Qin:
            hi = T
        else:
            lo = T
    return 0.5 * (lo + hi)
