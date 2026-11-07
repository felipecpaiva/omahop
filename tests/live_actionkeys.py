"""Live check of action_keys (v1.3) with a virtual keyboard on a spare workspace with three windows (recently used order C, B, A).
 action_keys = "q=close, m=minimize": Alt + Tab selects the second row (B); q closes it and the selection moves on; m minimizes the selected row.
 With a letter typed first, q types into the search instead. Your own config is saved and put back. Usage: python3 tests/live_actionkeys.py"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, clients, ev
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


def present(cls):
    return any(c["class"] == cls and not c["workspace"]["name"].startswith("special") for c in clients())


def key(kb, k):
    kb.down(k); kb.up(k); time.sleep(0.4)


saved = open(CFG).read() if os.path.exists(CFG) else None
os.makedirs(os.path.dirname(CFG), exist_ok=True)
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare() as sp, Keyboard() as kb:
        time.sleep(2.5)
        # Omarchy's minimize script reads the workspace mode back from this file and only acts on floating workspaces; the Spare helper removes it again
        open(sp.mode_file, "w").write('o.workspace_mode({ workspace = "4", mode = "floating" })\n')
        open(CFG, "w").write('reveal_delay_ms = 0\naction_keys = "q=close, m=minimize"\n[windows]\nworkspaces = "current"\n'); sp.reset_order()
        # m minimizes the selected row (B)
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        key(kb, "m"); time.sleep(0.8)
        kb.up("alt"); time.sleep(2.0)
        minimized = [c["class"] for c in clients() if c["class"].startswith("omahop-") and c["workspace"]["name"].startswith("special")]
        check("m minimizes the selected window", len(minimized) == 1, str(minimized))
        # B is minimized now, so the rows are C, A, B: Tab selects A
        for n in "AC":
            sp.focus(n)
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        key(kb, "q"); time.sleep(0.8)
        check("q closes the selected window (A)", not present("omahop-A"), str([c["class"] for c in clients() if c["class"].startswith("omahop-")]))
        check("the list stays open after the action", "open=1" in state(), state()[:120])
        kb.up("alt"); time.sleep(1.0)
        check("releasing Alt picks the next row (B, back from minimized)", active_class() == "omahop-B", active_class())
        # a letter typed first: q types
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.6)
        key(kb, "c"); key(kb, "q")
        check("after a letter, q types into the search", "query=cq" in state(), state()[:160])
        key(kb, "escape"); key(kb, "escape"); kb.up("alt"); time.sleep(0.5)
finally:
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall action key checks passed")
sys.exit(1 if failed else 0)
