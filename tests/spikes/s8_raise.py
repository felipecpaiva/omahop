"""Spike S8: which call makes a floating window come to the front on Hyprland 0.56.2, also over a maximized or fullscreen one?
Three coloured kitty windows overlap on a spare workspace made floating for the test; a one-pixel screenshot says which is on top.
Puts everything back at the end (workspace mode, windows, workspace in view). Needs kitty, grim. Run: python3 tests/spikes/s8_raise.py"""
import json, os, subprocess, time

SPARE = "4"
COLORS = {"A": "#c00000", "B": "#00c000", "C": "#0000c0"}  # red, green, blue
POS = {"A": (300, 250), "B": (350, 300), "C": (400, 350)}


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def ev(lua):
    subprocess.run(["hyprctl", "eval", lua], capture_output=True)


def clients():
    return json.loads(sh("hyprctl", "clients", "-j"))


def addr(name):
    c = next((c for c in clients() if c["class"] == "omahop-" + name), None)
    return c["address"] if c else None


def pixel(x, y):
    raw = subprocess.run(["grim", "-g", f"{x},{y} 1x1", "-t", "ppm", "-"], capture_output=True).stdout
    r, g, b = raw[-3:]
    dom = max(range(3), key=lambda i: (r, g, b)[i])
    return f"{'RGB'[dom]}({r},{g},{b})", {0: "A", 1: "B", 2: "C"}[dom] if max(r, g, b) - sorted((r, g, b))[1] > 25 else "?"


def lua_win(name, body):
    ev(f'local w = hl.get_window("address:{addr(name)}"); if w then {body} end')


def front(name):
    lua_win(name, "hl.dispatch(hl.dsp.focus({ window = w })); hl.dispatch(hl.dsp.window.alter_zorder({ mode = \"top\", window = w }))")
    time.sleep(0.4)


METHODS = {
    "focus only": "hl.dispatch(hl.dsp.focus({ window = w }))",
    "focus + alter_zorder top": "hl.dispatch(hl.dsp.focus({ window = w })); hl.dispatch(hl.dsp.window.alter_zorder({ mode = \"top\", window = w }))",
    "focus + bring_to_top": "hl.dispatch(hl.dsp.focus({ window = w })); hl.dispatch(hl.dsp.window.bring_to_top({ window = w }))",
    "alter_zorder top only": "hl.dispatch(hl.dsp.window.alter_zorder({ mode = \"top\", window = w }))",
}

origin = json.loads(sh("hyprctl", "activeworkspace", "-j"))["id"]
mode_file = os.path.expanduser(f"~/.local/state/omarchy/workspace-layouts/{SPARE}.lua")
had_mode_file = os.path.exists(mode_file)
results = []
try:
    ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{SPARE}" }}))'); time.sleep(0.8)
    ev(f'o.workspace_mode({{ workspace = "{SPARE}", mode = "floating" }})'); time.sleep(0.8)
    for n in "ABC":
        x, y = POS[n]
        ev(f'hl.exec_cmd("[float; size 700 450; move {x} {y}] kitty --class omahop-{n} -o background={COLORS[n]} -o background_opacity=1 -e sleep 3600")')
        time.sleep(1.6)
    for n in "ABC":
        assert addr(n), f"window {n} did not start"
    tags = {n: next(c for c in clients() if c["class"] == "omahop-" + n)["tags"] for n in "ABC"}
    results.append(("floating-workspace tag on test windows", str({n: "omarchy-floating-workspace" in t or any("floating" in x for x in t) for n, t in tags.items()}) + " raw=" + str(tags["A"])))
    for scenario, setup, probe in [
        ("plain floating windows (A is under B under C)", "", (900, 600)),
        ("C maximized", "maximized", (330, 300)),
        ("C fullscreen", "fullscreen", (330, 300)),
    ]:
        for name, body in METHODS.items():
            front("C")
            if setup:
                ev(f'hl.dispatch(hl.dsp.window.fullscreen({{ mode = "{setup}" }}))'); time.sleep(0.9)  # acts on the focused window (C), as Omarchy binds do
                state = next(c for c in clients() if c["class"] == "omahop-C")["fullscreen"]
                if state != {"maximized": 1, "fullscreen": 2}[setup]:
                    results.append((scenario, name, f"SETUP FAILED: C fullscreen field = {state}")); continue
            lua_win("A", body); time.sleep(0.7)
            got = pixel(*probe)
            results.append((scenario, name, f"A wanted on top, pixel says {got[1]} {got[0]}"))
            if setup:
                lua_win("C", "hl.dispatch(hl.dsp.focus({ window = w }))"); time.sleep(0.3)
                ev(f'hl.dispatch(hl.dsp.window.fullscreen({{ mode = "{setup}" }}))'); time.sleep(0.6)  # toggle off
finally:
    for n in "ABC":
        if addr(n):
            lua_win(n, 'hl.dispatch(hl.dsp.window.close({ window = w }))')
    time.sleep(1.0)
    ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{origin}" }}))'); time.sleep(0.5)
    if not had_mode_file and os.path.exists(mode_file):
        os.remove(mode_file)
    ev(f'o.workspace_mode({{ workspace = "{SPARE}", mode = "dwindle" }})')
    time.sleep(0.5)
    if not had_mode_file and os.path.exists(mode_file):
        os.remove(mode_file)
for r in results:
    print(" | ".join(r))
