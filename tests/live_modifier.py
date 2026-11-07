"""Live check of the `modifier` setting (v1.3) with a virtual keyboard: with modifier = ctrl, Ctrl + Tab opens the list on a spare workspace with three windows
(recently used order C, B, A) and releasing Ctrl picks the second row (B). The setting is read at load, so the test writes it and reloads Hyprland first
(the binds are made after the 3.5 s snapshot). Super is not tested live: Omarchy owns Super + Tab, so by design nothing is bound there (see docs/gotchas.md).
Your own config is saved and put back. Usage: python3 tests/live_modifier.py"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class
from uinput_kbd import Keyboard

CFG = os.path.expanduser("~/.config/omahop/config.toml")
STATE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "state")
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def state():
    try:
        return open(STATE).read()
    except OSError:
        return ""


saved = open(CFG).read() if os.path.exists(CFG) else None
os.makedirs(os.path.dirname(CFG), exist_ok=True)
try:
    open(CFG, "w").write('reveal_delay_ms = 0\nmodifier = "ctrl"\n[windows]\nworkspaces = "current"\n')
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(6.0)
    with Spare() as sp, Keyboard() as kb:
        time.sleep(2.0)
        sp.reset_order()
        kb.down("ctrl"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        check("Ctrl + Tab opens the list", "open=1" in state(), state()[:100])
        kb.up("ctrl"); time.sleep(1.2)
        check("releasing Ctrl picks the second row (B)", active_class() == "omahop-B", active_class())
        check("the list is closed", "open=0" in state(), state()[:100])
        # Alt is not the held key now: Alt + Tab must not open the list
        sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        check("Alt + Tab does not open omahop's list", "open=1" not in state(), state()[:100])
        kb.up("alt"); time.sleep(0.5)
finally:
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(5.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall modifier checks passed")
sys.exit(1 if failed else 0)
