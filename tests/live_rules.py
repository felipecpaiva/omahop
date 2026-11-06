"""Live check of the app rules (v0.4) with a virtual keyboard on a spare workspace with three windows titled alpha, bravo, charlie (classes omahop-A, -B, -C).
 ignore_titles drops a window from the list; first lists an app first; pass-through (a fullscreen focused window, or a named app) leaves Alt+Tab to stock.
Your own config is saved and put back. Usage: python3 tests/live_rules.py"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, addr, ev, sh
from uinput_kbd import Keyboard

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.expanduser("~/.config/omahop/config.toml")
STATE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "state")
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def state_lines():
    try:
        return open(STATE).read().split("\n")
    except OSError:
        return []


def listed():
    """Window classes in the state file, in list order."""
    return [l.split("\t")[2] for l in state_lines() if l.startswith("w\t")]


def session(kb, seconds=0.8):
    kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(seconds)


saved = open(CFG).read() if os.path.exists(CFG) else None
os.makedirs(os.path.dirname(CFG), exist_ok=True)
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare() as sp, Keyboard() as kb:
        time.sleep(2.5)
        base = 'reveal_delay_ms = 0\n[windows]\nworkspaces = "current"\n'
        # ignore_titles
        open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nworkspaces = "current"\nignore_titles = "brav"\n'); sp.reset_order()
        session(kb)
        check("ignore_titles: the window titled bravo is not listed", sorted(listed()) == ["omahop-A", "omahop-C"], str(listed()))
        kb.up("alt"); time.sleep(0.6)
        # first
        open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nworkspaces = "current"\nfirst = "omahop-A"\n'); sp.reset_order()
        session(kb)
        check("first: the listed app comes first", listed()[:1] == ["omahop-A"], str(listed()))
        kb.up("alt"); time.sleep(0.6)
        # pass-through by class: C focused, C listed
        open(CFG, "w").write('reveal_delay_ms = 0\npassthrough = "omahop-C"\n[windows]\nworkspaces = "current"\n'); sp.reset_order()
        session(kb, 0.6); opened = "open=1" in state_lines()
        kb.up("alt"); time.sleep(0.6)
        check("pass-through by class: with that app focused Alt+Tab is stock, omahop does not open", not opened)
        # pass-through for fullscreen
        open(CFG, "w").write('reveal_delay_ms = 0\npassthrough_fullscreen = true\n[windows]\nworkspaces = "current"\n'); sp.reset_order()
        ev('hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen" }))'); time.sleep(1.0)
        session(kb, 0.6); opened = "open=1" in state_lines()
        kb.up("alt"); time.sleep(0.6)
        ev('hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen" }))'); time.sleep(0.8)   # leave fullscreen
        check("pass-through for fullscreen: a fullscreen focused window gets stock Alt+Tab", not opened)
        sp.reset_order(); open(CFG, "w").write(base); time.sleep(0.3)
        session(kb); check("and a normal window still uses omahop (the rules are not sticky)", "open=1" in state_lines(), str(state_lines()[:3]))
        kb.up("alt"); time.sleep(0.6)
finally:
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall rules checks passed")
sys.exit(1 if failed else 0)
