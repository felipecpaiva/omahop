"""Live check of search_linger_seconds (v1.1b) with a virtual keyboard and mouse on a spare workspace with three windows (alpha, bravo, charlie;
recently used order C, B, A). Linger is 3 s. Five scenarios from docs/research/linger-spike.md:
 1. Alt+Tab, type "br" with Alt held, release Alt, wait 1 s, type Shift+A (a capital: only the overlay's own keyboard can take it), Return: bravo
    comes forward. Run several times: the focus call must land after the overlay lets go of the keyboard.
 2. Release, wait past the limit: the list closes and the focused window is unchanged.
 3. Escape twice: the first clears the search and the list stays, the second closes it.
 4. A click on a window outside the card: the list closes, that window does NOT take focus.
 5. hyprctl reload mid-linger: the list closes and the keyboard is free (a focus call works again).
Needs the plugin enabled and the shell restarted since the last QML change. Your own config is saved and put back. Usage: python3 tests/live_linger.py"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, addr, ev, read_state, sh
from uinput_kbd import Keyboard, Mouse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.expanduser("~/.config/omahop/config.toml")
LINGER_S = 3
PICK_RUNS = 5
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def key(kb, combo):
    kb.tap(combo); time.sleep(0.15)


def wait_for(cond, seconds=2.0):
    end = time.time() + seconds
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.05)
    return cond()


def linger(kb, letters="br"):
    """Alt+Tab, type with Alt held, release Alt: the session should now linger with the overlay holding the keyboard."""
    kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.4)
    for ch in letters:
        key(kb, ch)
    kb.up("alt")
    return wait_for(lambda: read_state().get("linger_ms") == str(LINGER_S * 1000) and read_state().get("grab") == "1")


def move(x, y):
    ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"); time.sleep(0.3)


saved = open(CFG).read() if os.path.exists(CFG) else None
start_cursor = sh("hyprctl", "cursorpos").strip().replace(",", "").split()
os.makedirs(os.path.dirname(CFG), exist_ok=True)
open(CFG, "w").write(f'reveal_delay_ms = 0\nsearch_linger_seconds = {LINGER_S}\n[windows]\nworkspaces = "current"\n')
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare() as sp, Keyboard() as kb, Mouse() as m:
        time.sleep(2.5)  # the snapshot of existing binds (Alt + letter chords need it)
        # 1. type, release Alt, keep typing (a capital), Return picks; repeated for the focus-after-release timing
        picked = 0
        for run in range(PICK_RUNS):
            sp.reset_order()
            ok = linger(kb)
            if run == 0:
                check("1: Alt up with a search lingers and the overlay holds the keyboard", ok, str(read_state()))
            time.sleep(1.0)
            check(f"1.{run}: still open 1 s after Alt up (no pick on release)", read_state().get("open") == "1" and active_class() == "omahop-C", f"{read_state().get('open')} {active_class()}")
            key(kb, "shift+a")
            q = wait_for(lambda: read_state().get("query") == "brA")
            if run == 0:
                check("1: Shift+A typed after Alt up reaches the search as a capital", q, read_state().get("query"))
            key(kb, "return")
            ok = wait_for(lambda: active_class() == "omahop-B", 1.5)
            picked += ok
            check(f"1.{run}: Return picks bravo after the grab is released", ok and read_state().get("open") == "0", f"{active_class()} open={read_state().get('open')}")
        print(f"     focus after release: {picked}/{PICK_RUNS}")
        # 2. timeout: closes, focus unchanged
        sp.reset_order()
        linger(kb)
        time.sleep(LINGER_S - 1)
        check("2: open before the limit", read_state().get("open") == "1")
        closed = wait_for(lambda: read_state().get("open") == "0", 2.5)
        check("2: past the limit the list closes", closed, str(read_state()))
        time.sleep(0.3)
        check("2: the timeout picks nothing (charlie still focused)", active_class() == "omahop-C", active_class())
        # 3. Escape twice
        sp.reset_order()
        linger(kb)
        key(kb, "escape")
        cleared = wait_for(lambda: read_state().get("query") == "" and read_state().get("open") == "1")
        check("3: first Escape clears the search, the list stays", cleared, str(read_state()))
        key(kb, "escape")
        check("3: second Escape closes it", wait_for(lambda: read_state().get("open") == "0"), str(read_state()))
        time.sleep(0.3)
        check("3: nothing picked", active_class() == "omahop-C", active_class())
        # 4. a click on window A outside the card cancels and does not focus A
        sp.reset_order()
        linger(kb)
        move(320, 270)   # only window A is under this point, left of the centred card
        m.press(); m.release()
        check("4: a click outside the card closes the list", wait_for(lambda: read_state().get("open") == "0"), str(read_state()))
        time.sleep(0.4)
        check("4: the clicked window did not take focus", active_class() == "omahop-C", active_class())
        key(kb, "shift+a")  # with the grab gone this goes to charlie's kitty (it runs sleep, so the key is harmless)
        check("4: keys no longer reach the list", read_state().get("open") == "0")
        # 5. a Hyprland reload mid-linger leaves no grab
        sp.reset_order()
        linger(kb)
        subprocess.run(["hyprctl", "reload"], capture_output=True)
        check("5: reload mid-linger closes the list", wait_for(lambda: read_state().get("open") == "0" and read_state().get("grab") == "0", 3.0), str(read_state()))
        time.sleep(1.0)
        a = addr("omahop-A")
        ev(f'local w = hl.get_window("address:{a}"); hl.dispatch(hl.dsp.focus({{ window = w }}))')
        check("5: after the reload a focus call works (the keyboard is free)", wait_for(lambda: active_class() == "omahop-A"), active_class())
finally:
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    if len(start_cursor) == 2:
        move(*start_cursor)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall linger checks passed")
sys.exit(1 if failed else 0)
