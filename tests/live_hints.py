"""Live check of the hints (v0.4) with a virtual keyboard on a spare workspace with three windows (recently used order C, B, A).
 hints = numbers: Alt + Tab, then 3 jumps to the third row; a number with a query typed already types instead.
 hints = apps with hint_keys: a letter jumps to that app's window. Hints off: digits type into the search.
Your own config is saved and put back. Usage: python3 tests/live_hints.py"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, ev
from uinput_kbd import Keyboard

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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


def hints():
    return [l.split("\t")[4] for l in state().split("\n") if l.startswith("w\t")]


def key(kb, k):
    kb.down(k); kb.up(k); time.sleep(0.3)


saved = open(CFG).read() if os.path.exists(CFG) else None
os.makedirs(os.path.dirname(CFG), exist_ok=True)
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare() as sp, Keyboard() as kb:
        time.sleep(2.5)   # the snapshot of existing binds
        # numbers
        open(CFG, "w").write('reveal_delay_ms = 0\nhints = "numbers"\n[windows]\nworkspaces = "current"\n'); sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        check("numbers: each row carries its number in the state", hints() == ["1", "2", "3"], str(hints()))
        key(kb, "3")
        check("numbers: pressing 3 jumps to the third row (window A)", active_class() == "omahop-A" and "open=0" in state(), active_class())
        kb.up("alt"); time.sleep(0.5)
        # a query typed first: digits type
        sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.6)
        key(kb, "b"); key(kb, "2")
        check("numbers: after a letter is typed, a digit types too", "query=b2" in state(), state()[:200])
        kb.down("escape"); kb.up("escape"); time.sleep(0.3)
        kb.up("alt"); time.sleep(0.5)
        # apps
        open(CFG, "w").write('reveal_delay_ms = 0\nhints = "apps"\nhint_keys = "c=omahop-C, b=omahop-B"\n[windows]\nworkspaces = "current"\n'); sp.reset_order(); sp.focus("A")
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        check("apps: the mapped rows carry their letters", sorted(h for h in hints() if h) == ["b", "c"], str(hints()))
        key(kb, "b")
        check("apps: pressing b jumps to that app's window", active_class() == "omahop-B", active_class())
        kb.up("alt"); time.sleep(0.5)
        # off
        open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nworkspaces = "current"\n'); sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.6)
        key(kb, "3")
        check("hints off: a digit types into the search", "query=3" in state() and "open=1" in state(), state()[:200])
        kb.down("escape"); kb.up("escape"); time.sleep(0.2); kb.up("alt"); time.sleep(0.5)
finally:
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall hints checks passed")
sys.exit(1 if failed else 0)
