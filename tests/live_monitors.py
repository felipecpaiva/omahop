"""Live check on EVERY monitor attached (v1.0): the window set follows `windows.monitors`, from each monitor in turn, and picking a window on any other
monitor moves focus there. Works with 2, 3 or more monitors. Skips (exit 0, says SKIP) with one monitor: lua/test_monitors.lua covers 1 to 6 monitors
and unplugging without hardware, and virtual monitors are never created on a dev machine.
Method: the first monitor has the usual spare workspace (windows A, B, C). Every other monitor gets its own spare floating workspace with two windows
(omahop-M<i>a and omahop-M<i>b, titles mon<i>a and mon<i>b). Then, with each monitor focused in turn:
  monitors = active: the list holds exactly the test windows that sit on that monitor (read from hyprctl, not assumed);
  monitors = all: it holds every test window;
  and for every other monitor, searching a window's title and releasing Alt focuses that window and moves focus to its monitor.
All test windows are closed at the end and your config is put back. Usage: python3 tests/live_monitors.py"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, ev, sh
from uinput_kbd import Keyboard

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.expanduser("~/.config/omahop/config.toml")
STATE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "state")
FIRST_WS = 30
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def monitors():
    return json.loads(sh("hyprctl", "monitors", "-j"))


def focused_monitor():
    return next(m["name"] for m in monitors() if m["focused"])


def state():
    try:
        return open(STATE).read()
    except OSError:
        return ""


def listed():
    """The test windows in the switcher's list (your own windows may be listed too)."""
    return sorted(c for c in (l.split("\t")[2] for l in state().split("\n") if l.startswith("w\t")) if c.startswith("omahop-"))


def on_monitor(name):
    """The test windows that Hyprland says sit on this monitor."""
    ids = {m["id"]: m["name"] for m in monitors()}
    return sorted(c["class"] for c in json.loads(sh("hyprctl", "clients", "-j")) if c["class"].startswith("omahop-") and ids.get(c["monitor"]) == name)


def every_test_window():
    return sorted(c["class"] for c in json.loads(sh("hyprctl", "clients", "-j")) if c["class"].startswith("omahop-"))


def key(kb, k):
    kb.down(k); kb.up(k); time.sleep(0.3)


def focus_monitor(name):
    ev(f'hl.dispatch(hl.dsp.focus({{ monitor = "{name}" }}))'); time.sleep(0.6)


def open_list(kb):
    kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)


def close_list(kb):
    key(kb, "escape"); kb.up("alt"); time.sleep(0.5)


mons = monitors()
if len(mons) < 2:
    print("SKIP live_monitors: only one monitor connected (lua/test_monitors.lua covers 1 to 6 monitors without hardware)")
    sys.exit(0)
home = next(m["name"] for m in mons if m["focused"])
extra = [m["name"] for m in mons if m["name"] != home]
print(f"{len(mons)} monitors: {home} (first) and {', '.join(extra)}")
layouts = os.path.expanduser("~/.local/state/omarchy/workspace-layouts")
extra_ws = {name: str(FIRST_WS + i) for i, name in enumerate(extra)}
had_layout = {ws: os.path.exists(f"{layouts}/{ws}.lua") for ws in extra_ws.values()}
saved = open(CFG).read() if os.path.exists(CFG) else None
os.makedirs(os.path.dirname(CFG), exist_ok=True)
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare() as sp, Keyboard() as kb:
        time.sleep(2.5)
        # two windows on a floating workspace of each other monitor
        for i, name in enumerate(extra, 1):
            ws = extra_ws[name]
            focus_monitor(name)
            ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{ws}" }}))'); time.sleep(0.6)
            ev(f'o.workspace_mode({{ workspace = "{ws}", mode = "floating" }})'); time.sleep(0.6)
            for part in "ab":
                ev(f'hl.exec_cmd("[float; size 500 300] kitty --class omahop-M{i}{part} --title mon{i}{part} -e sleep 3600")'); time.sleep(1.6)
            check(f"setup: two test windows on {name}", len(on_monitor(name)) == 2, on_monitor(name))
        focus_monitor(home)
        check("setup: the first monitor holds its three", len(on_monitor(home)) == 3, on_monitor(home))
        everyone = every_test_window()

        for start in [home] + extra:
            focus_monitor(start)
            if start == home:
                sp.reset_order()
            check(f"focus on {start}", focused_monitor() == start, focused_monitor())

            open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nmonitors = "active"\n')
            open_list(kb)
            check(f"from {start}, monitors = active: exactly the windows on {start}", listed() == on_monitor(start), f"{listed()} vs {on_monitor(start)}")
            close_list(kb)

            open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nmonitors = "all"\n')
            open_list(kb)
            check(f"from {start}, monitors = all: every test window", listed() == everyone, f"{listed()} vs {everyone}")
            close_list(kb)

            # pick a window on each other monitor by its title
            for i, other in enumerate(extra, 1):
                if other == start:
                    continue
                focus_monitor(start)
                open_list(kb)
                for ch in f"mon{i}a":
                    key(kb, ch)
                kb.up("alt"); time.sleep(1.0)
                check(f"from {start}, picking mon{i}a focuses it", active_class() == f"omahop-M{i}a", active_class())
                check(f"... and focus moves to {other}", focused_monitor() == other, focused_monitor())
            if start != home:  # and back to a window on the first monitor (title alpha)
                focus_monitor(start)
                open_list(kb)
                for ch in "alpha":
                    key(kb, ch)
                kb.up("alt"); time.sleep(1.0)
                check(f"from {start}, picking alpha focuses it", active_class() == "omahop-A", active_class())
                check(f"... and focus moves to {home}", focused_monitor() == home, focused_monitor())
        focus_monitor(home)
finally:
    for c in json.loads(sh("hyprctl", "clients", "-j")):
        if c["class"].startswith("omahop-M"):
            ev(f'local w = hl.get_window("address:{c["address"]}"); if w then hl.dispatch(hl.dsp.window.close({{ window = w }})) end')
    time.sleep(1.0)
    ev(f'hl.dispatch(hl.dsp.focus({{ monitor = "{home}" }}))')
    for ws in extra_ws.values():
        ev(f'o.workspace_mode({{ workspace = "{ws}", mode = "dwindle" }})')
        path = f"{layouts}/{ws}.lua"
        if not had_layout[ws] and os.path.exists(path):
            os.remove(path)
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)

if failed:
    print("\nFAILED: " + ", ".join(failed))
    sys.exit(1)
print("\nall monitors checks passed")
