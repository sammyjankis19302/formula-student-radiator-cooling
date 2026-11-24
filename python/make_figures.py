"""Draw the figures in ../figures from the CSV files that matlab/run_all.m writes.

Run from the repository root:

    python3 python/make_figures.py

Each figure is saved twice: name.png for light pages and name-dark.png for dark
ones (the README picks the right one).
"""
import csv
from pathlib import Path

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "results"
FIG = ROOT / "figures"

THEMES = {
    "light": dict(surface="#fcfcfb", ink="#0b0b0b", ink2="#52514e", muted="#898781",
                  grid="#e1e0d9", axis="#c3c2b7", band="#f0efec",
                  s1="#2a78d6", s2="#eb6834",
                  seq5=["#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#104281"],
                  seq3=["#86b6ef", "#2a78d6", "#104281"]),
    "dark": dict(surface="#1a1a19", ink="#f0efec", ink2="#c3c2b7", muted="#898781",
                 grid="#2c2c2a", axis="#383835", band="#262624",
                 s1="#3987e5", s2="#d95926",
                 seq5=["#184f95", "#256abf", "#3987e5", "#6da7ec", "#9ec5f4"],
                 seq3=["#184f95", "#3987e5", "#9ec5f4"]),
}
LW = 1.8          # series lines
LW_REF = 0.9      # reference lines
T_LIMIT = 105.0   # design limit for the coolant, degC (cooling_params: p.ctrl.T_limit)


def table(name):
    with open(RES / name) as f:
        rows = list(csv.reader(f))
    head = rows[0]
    data = np.array([[float(x) for x in r] for r in rows[1:] if r])
    return {h: data[:, i] for i, h in enumerate(head)}


def text_rows(name):
    with open(RES / name) as f:
        return list(csv.reader(f))[1:]


def setup(theme):
    t = THEMES[theme]
    plt.rcParams.update({
        "figure.facecolor": t["surface"], "axes.facecolor": t["surface"],
        "savefig.facecolor": t["surface"], "text.color": t["ink"],
        "axes.labelcolor": t["ink2"], "xtick.color": t["ink2"], "ytick.color": t["ink2"],
        "axes.edgecolor": t["axis"], "axes.linewidth": 0.8,
        "grid.color": t["grid"], "grid.linewidth": 0.6,
        "font.family": "DejaVu Sans", "font.size": 9.5,
        "axes.titlesize": 10, "axes.titlecolor": t["ink"], "axes.titlepad": 6,
        "axes.labelsize": 9.5, "xtick.labelsize": 9, "ytick.labelsize": 9,
        "xtick.major.size": 0, "ytick.major.size": 0,
        "xtick.major.pad": 5, "ytick.major.pad": 5,
        "legend.frameon": False, "legend.fontsize": 9, "legend.handlelength": 1.6,
        "lines.solid_capstyle": "round", "lines.solid_joinstyle": "round",
    })
    return t


def frame(ax, t, grid="y"):
    if grid:
        ax.grid(True, axis=grid)
    ax.set_axisbelow(True)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(t["axis"])


def heading(fig, t, title, sub, y=0.965):
    fig.text(0.035, y, title, ha="left", va="top", fontsize=13, fontweight="bold", color=t["ink"])
    fig.text(0.035, y - 0.06, sub, ha="left", va="top", fontsize=9.5, color=t["ink2"])


def dot(ax, t, x, y, colour):
    ax.plot([x], [y], "o", ms=7, color=colour, mec=t["surface"], mew=2, zorder=5)


def save(fig, name, theme):
    FIG.mkdir(exist_ok=True)
    out = FIG / (f"{name}.png" if theme == "light" else f"{name}-dark.png")
    fig.savefig(out, dpi=200)
    plt.close(fig)


# ----------------------------------------------------------------------------- figures
def air_limit(theme):
    t = setup(theme)
    d = table("airflow_limit.csv")
    cfm, lim, mod = d["fan_cfm"], d["air_limit_kW"], d["model_kW"]
    Q_report = 23.30
    fig, ax = plt.subplots(figsize=(8, 4.6))
    fig.subplots_adjust(left=0.075, right=0.86, top=0.73, bottom=0.13)
    heading(fig, t, "300 CFM of air cannot carry the 23.3 kW in the 2025 report",
            "The report's design point: air at 25 °C, coolant at 95 °C, sea level")
    ax.plot(cfm, lim, color=t["s1"], lw=LW, label="Most heat the air can carry (all of it leaving at 95 °C)")
    ax.plot(cfm, mod, color=t["s2"], lw=LW, label="Heat this radiator model passes")
    ax.legend(loc="lower left", bbox_to_anchor=(-0.01, 1.0), ncol=2, borderaxespad=0.3)
    ax.axhline(Q_report, color=t["ink2"], lw=LW_REF, zorder=1)
    ax.text(cfm[0] + 6, Q_report + 0.6, "The report's heat\nrejection, 23.3 kW", color=t["ink2"], fontsize=9, va="bottom")
    ax.axvline(300, color=t["ink2"], lw=LW_REF, zorder=1)
    ax.text(310, 36.5, "The report's fan airflow,\n300 CFM", color=t["ink2"], fontsize=9, va="top")
    k = int(np.argmin(abs(cfm - 300)))
    dot(ax, t, 300, lim[k], t["s1"])
    ax.text(290, lim[k] + 0.9, f"{lim[k]:.1f} kW at most", color=t["ink"], fontsize=9, va="bottom", ha="right")
    dot(ax, t, 300, mod[k], t["s2"])
    ax.text(318, mod[k] - 0.8, f"{mod[k]:.1f} kW", color=t["ink"], fontsize=9, va="top")
    need = float(np.interp(Q_report, lim, cfm))
    dot(ax, t, need, Q_report, t["s1"])
    ax.text(need + 12, Q_report - 0.8, f"needs {need:.0f} CFM through the core", color=t["ink"], fontsize=9, va="top")
    ax.text(cfm[-1] + 12, lim[-1], "Air limit", color=t["ink"], fontsize=9, va="center", clip_on=False)
    ax.text(cfm[-1] + 12, mod[-1], "This model", color=t["ink"], fontsize=9, va="center", clip_on=False)
    ax.set_xlim(cfm[0], cfm[-1]); ax.set_ylim(0, 38)
    ax.set_xlabel("Airflow through the radiator core (CFM)"); ax.set_ylabel("Heat (kW)")
    frame(ax, t)
    save(fig, "report-vs-air-limit", theme)


def heat_vs_speed(theme):
    t = setup(theme)
    d = table("radiator_map.csv")
    s = table("scenarios.csv")
    q_track = s["Q_in_on_track_kW"][0]
    v = d["speed_kmh"]
    fig, axs = plt.subplots(1, 2, figsize=(8, 4.5), sharey=True)
    fig.subplots_adjust(left=0.075, right=0.92, top=0.68, bottom=0.13, wspace=0.16)
    heading(fig, t, "Ram air does most of the work once the car is moving",
            f"Heat the radiator passes with the coolant at 100 °C and the air at 31 °C. The grey line is\n"
            f"the average heat going into the coolant on track, {q_track:.1f} kW.")
    shares = (("015", "15 %"), ("030", "30 %"), ("045", "45 %"))
    for ax, fan, name in zip(axs, ("off", "on"), ("Fan off", "Fan on (300 CFM through the core)")):
        for c, (e, lab) in zip(t["seq3"], shares):
            y = d[f"eta{e}_fan_{fan}_kW"]
            ax.plot(v, y, color=c, lw=LW, label=lab)
            ax.text(v[-1] + 2, y[-1], lab, color=t["ink"], fontsize=9, va="center", clip_on=False)
        ax.axhline(q_track, color=t["ink2"], lw=LW_REF, zorder=1)
        ax.set_title(name, loc="left")
        ax.set_xlim(0, 110); ax.set_ylim(0, 31)
        ax.set_xlabel("Car speed (km/h)")
        frame(ax, t)
    axs[1].text(112, q_track, "heat in", color=t["ink2"], fontsize=9, va="center", clip_on=False)
    axs[0].set_ylabel("Heat to the air (kW)")
    axs[0].legend(title="Share of the car's speed that reaches the core", loc="lower left",
                  bbox_to_anchor=(-0.01, 1.08), ncol=3, borderaxespad=0.3, title_fontsize=9,
                  alignment="left")
    save(fig, "radiator-heat-vs-speed", theme)


def steady_temperature(theme):
    t = setup(theme)
    d = table("equilibrium.csv")
    lap = table("summary.csv")
    v = d["speed_kmh"]
    loads = (8, 12, 16, 20, 24)
    fig, ax = plt.subplots(figsize=(8, 4.6))
    fig.subplots_adjust(left=0.075, right=0.87, top=0.70, bottom=0.13)
    heading(fig, t, "Where the coolant settles at a steady speed",
            "Fan on, air at 31 °C, 30 % of the car's speed reaching the core. With heat to spare, the\n"
            "thermostat closes and holds the coolant near 83 °C.")
    ylim = (60, 150)
    for c, L in zip(t["seq5"], loads):
        y = d[f"T_{L}kW"].copy()
        y[y >= 999] = np.nan
        ax.plot(v, y, color=c, lw=LW, label=f"{L} kW")
        if L >= 20:
            ax.text(v[-1] + 2, y[-1], f"{L} kW", color=t["ink"], fontsize=9, va="center", clip_on=False)
    ax.text(v[-1] + 2, 81.5, "8 to 16 kW", color=t["ink"], fontsize=9, va="center", clip_on=False)
    ax.legend(title="Heat into the coolant", loc="lower left", bbox_to_anchor=(-0.01, 1.0), ncol=5,
              borderaxespad=0.3, title_fontsize=9, alignment="left")
    ax.axhline(T_LIMIT, color=t["ink2"], lw=LW_REF, zorder=1)
    ax.text(108, T_LIMIT + 1, "105 °C design limit", color=t["ink2"], fontsize=9, va="bottom", ha="right")
    va = lap["v_avg_kmh"][0]
    ax.axvline(va, color=t["ink2"], lw=LW_REF, zorder=1)
    ax.text(va + 1.5, ylim[1] - 2, f"average lap speed,\n{va:.0f} km/h", color=t["ink2"], fontsize=9, va="top")
    ax.set_xlim(0, 110); ax.set_ylim(*ylim)
    ax.set_xlabel("Car speed (km/h)"); ax.set_ylabel("Coolant temperature (°C)")
    frame(ax, t)
    save(fig, "steady-temperature", theme)


def endurance(theme):
    t = setup(theme)
    base = table("endurance_baseline.csv")
    peaks = dict(zip([r[1] for r in text_rows("scenario_names.csv")], table("scenarios.csv")["T_peak_C"]))
    cases = (("hot_day", "Hot day: air at 35 °C instead of 31 °C"),
             ("poor_ducting", "Poor ducting: 15 % of the car's speed reaches the core"),
             ("report_heat", "The report's heat ratio: 1.17 × brake power"),
             ("all_three", "All three at once"))
    fig, axs = plt.subplots(2, 2, figsize=(8, 6.0), sharex=True, sharey=True)
    fig.subplots_adjust(left=0.075, right=0.975, top=0.80, bottom=0.10, wspace=0.08, hspace=0.32)
    heading(fig, t, "The 22 km endurance event, changing one thing at a time",
            "Coolant temperature; the grey line is the baseline car in every panel", y=0.975)
    tb = base["t_s"] / 60
    off = base["Q_in_kW"] == 0
    t0, t1 = tb[off][0], tb[off][-1]
    for i, (ax, (key, title)) in enumerate(zip(axs.flat, cases)):
        d = table(f"endurance_{key}.csv")
        ax.axvspan(t0, t1, color=t["band"], lw=0, zorder=0)
        ax.axhline(T_LIMIT, color=t["ink2"], lw=LW_REF, zorder=1)
        ax.plot(tb, base["T_C"], color=t["muted"], lw=1.2, label="Baseline car")
        ax.plot(d["t_s"] / 60, d["T_C"], color=t["s1"], lw=1.6, label="Changed case")
        k = int(np.argmax(d["T_C"]))
        dot(ax, t, d["t_s"][k] / 60, d["T_C"][k], t["s1"])
        ax.text(d["t_s"][k] / 60, d["T_C"][k] + 3, f"peak {peaks[key]:.1f} °C", color=t["ink"],
                fontsize=8.5, ha="right" if k > len(d["T_C"]) / 2 else "left", va="bottom")
        ax.set_title(title, loc="left", fontsize=9.5)
        ax.set_ylim(78, 155); ax.set_xlim(0, tb[-1])
        frame(ax, t)
        if i == 0:
            ax.text((t0 + t1) / 2, 153, "driver\nchange", color=t["ink2"], fontsize=8, ha="center", va="top")
            ax.text(0.5, T_LIMIT + 1.5, "105 °C limit", color=t["ink2"], fontsize=8, va="bottom")
    for ax in axs[1]:
        ax.set_xlabel("Time (min)")
    for ax in axs[:, 0]:
        ax.set_ylabel("Coolant (°C)")
    axs[0, 0].legend(loc="lower left", bbox_to_anchor=(-0.01, 1.13), ncol=2, borderaxespad=0.3)
    save(fig, "endurance", theme)


def sensitivity(theme):
    t = setup(theme)
    rows = text_rows("sensitivity.csv")
    pct = lambda x: f"{100 * x:.0f} %"
    nice = {"Air temperature (degC)": ("Air temperature", lambda x: f"{x:g} °C"),
            "Ram-air share": ("Share of car speed at the core", pct),
            "Heat to coolant / brake power": ("Heat to coolant ÷ brake power", lambda x: f"{x:.2f}"),
            "Fins per inch": ("Fins per inch", lambda x: f"{x:g}"),
            "Fan airflow through core (CFM)": ("Fan airflow through the core", lambda x: f"{x:g} CFM"),
            "Full-throttle power share": ("Mean power at full throttle", pct),
            "Louver pitch (mm)": ("Louver pitch", lambda x: f"{1e3 * x:.1f} mm"),
            "Tube thickness (mm)": ("Tube thickness", lambda x: f"{1e3 * x:.1f} mm"),
            "Coolant flow (L/min)": ("Coolant flow", lambda x: f"{x:g} L/min")}
    data = []
    for r in rows:
        name, fmt = nice[r[0]]
        lo, hi, Tlo, Thi, Tb = float(r[1]), float(r[2]), float(r[3]), float(r[4]), float(r[5])
        data.append((abs(Thi - Tlo), name, fmt(lo), fmt(hi) + (" (baseline)" if abs(Thi - Tb) < 1e-9 else ""),
                     Tlo, Thi, Tb))
    data.sort(reverse=True)
    Tb = data[0][6]
    fig, ax = plt.subplots(figsize=(8, 5.0))
    fig.subplots_adjust(left=0.30, right=0.95, top=0.74, bottom=0.11)
    heading(fig, t, "What moves the coolant temperature most",
            "Lap-average balance temperature with the fan on and the thermostat wide open,\n"
            "changing one input at a time")
    h = 0.36
    for i, (_, name, slo, shi, Tlo, Thi, _) in enumerate(data):
        y = -i
        ax.barh(y + h / 2 + 0.02, Tlo - Tb, left=Tb, height=h, color=t["s1"],
                label="Lower value" if i == 0 else None)
        ax.barh(y - h / 2 - 0.02, Thi - Tb, left=Tb, height=h, color=t["s2"],
                label="Higher value" if i == 0 else None)
        for T, s, dy in ((Tlo, slo, h / 2 + 0.02), (Thi, shi, -h / 2 - 0.02)):
            right = T >= Tb
            ax.text(T + (0.6 if right else -0.6), y + dy, s, color=t["ink2"], fontsize=8.5,
                    va="center", ha="left" if right else "right")
    ax.set_yticks([-i for i in range(len(data))])
    ax.set_yticklabels([d[1] for d in data], color=t["ink"])
    ax.axvline(Tb, color=t["ink"], lw=1.0, zorder=3)
    ax.text(Tb + 0.5, 0.75, f"baseline {Tb:.1f} °C", color=t["ink"], fontsize=9, ha="left", va="bottom")
    ax.axvline(T_LIMIT, color=t["ink2"], lw=LW_REF, zorder=1)
    ax.text(T_LIMIT + 0.5, -len(data) + 0.45, "105 °C limit", color=t["ink2"], fontsize=9, va="bottom")
    ax.set_xlim(70, 114); ax.set_ylim(-len(data) + 0.4, 1.3)
    ax.set_xlabel("Coolant temperature (°C)")
    ax.legend(loc="lower left", bbox_to_anchor=(-0.01, 1.0), ncol=2, borderaxespad=0.3)
    frame(ax, t, grid="x")
    ax.spines["bottom"].set_visible(False)
    ax.tick_params(axis="y", pad=8)
    save(fig, "sensitivity", theme)


def lap_profile(theme):
    t = setup(theme)
    d = table("lap.csv")
    s = table("summary.csv")
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(8, 4.8), sharex=True)
    fig.subplots_adjust(left=0.075, right=0.975, top=0.80, bottom=0.11, hspace=0.32)
    heading(fig, t, "One lap of the endurance course",
            f"A 1 km lap built to the Formula SAE course rules: {s['lap_s'][0]:.1f} s, "
            f"average {s['v_avg_kmh'][0]:.1f} km/h, top {s['v_max_kmh'][0]:.1f} km/h")
    a1.plot(d["s_m"], d["v_kmh"], color=t["s1"], lw=1.6)
    a1.set_title("Speed (km/h)", loc="left"); a1.set_ylim(0, 110)
    a2.fill_between(d["s_m"], 0, d["P_b_kW_next_interval"], color=t["s1"], lw=0, alpha=0.9, step="post")
    a2.set_title("Engine power (kW)", loc="left"); a2.set_ylim(0, 62)
    a2.text(1000, 61, f"full throttle {s['full_throttle_pct'][0]:.0f} % of the lap, "
            f"average {s['P_avg_kW'][0]:.1f} kW", color=t["ink2"], fontsize=9, ha="right", va="top")
    a2.set_xlabel("Distance along the lap (m)"); a2.set_xlim(0, 1000)
    for ax in (a1, a2):
        frame(ax, t)
    save(fig, "lap", theme)


if __name__ == "__main__":
    for theme in ("light", "dark"):
        air_limit(theme)
        heat_vs_speed(theme)
        steady_temperature(theme)
        endurance(theme)
        sensitivity(theme)
        lap_profile(theme)
    print("figures written to", FIG)
