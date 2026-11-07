"""Live check of browser tabs (v1.4) with a virtual keyboard on a spare workspace. No browser is involved: a stand-in helper (a small Python
process created here) owns a FIFO named after its pid, and this test writes a fake tabs.<pid>.json (made-up example.com tabs) whose `pid` is
the test window bravo's pid, so omahop matches that window. Checks: the flag file appears; no tab row without a search; a search finds a
hidden tab by its title and shows it under its window; Return focuses the matched window and the helper receives the tab id; turning the
setting off removes the flag and the tab file. Your own config is saved and put back. Usage: python3 tests/live_tabs.py"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, clients, ev
from uinput_kbd import Keyboard

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.expanduser("~/.config/omahop/config.toml")
RUN = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop")
STATE = os.path.join(RUN, "state")
FLAG = os.path.join(RUN, "tabs.enabled")
HIDDEN_TAB_ID = 4711
failed = []

# The stand-in helper: makes tabs.<own pid>.activate, holds it open (read and write end, so it never sees EOF), appends each line to argv[1].
READER = r"""
import os, select, sys
path = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "tabs.%d.activate" % os.getpid())
os.mkfifo(path, 0o600)
print(os.getpid(), flush=True)
fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
try:
    while True:
        if select.select([fd], [], [], 0.2)[0]:
            open(sys.argv[1], "ab").write(os.read(fd, 256))
finally:
    os.unlink(path)
"""


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def state_lines():
    try:
        return open(STATE).read().split("\n")
    except OSError:
        return []


def tab_lines():
    return [l.split("\t") for l in state_lines() if l.startswith("t\t")]


def wait_for(cond, seconds=2.0):
    end = time.time() + seconds
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.05)
    return cond()


def key(kb, combo):
    kb.tap(combo); time.sleep(0.15)


def write_tabs(hostpid, browser_pid):
    doc = {"schema": 1, "browser": "chromium", "pid": browser_pid, "caller": "chrome-extension://gbipjbmbimghgjofgocchemgnbibofhg/", "profile": None,
           "windows": [{"id": 1, "focused": True, "type": "normal", "tabs": [
               {"id": 4710, "active": True, "title": "bravo", "url": "https://bravo.example.com/"},
               {"id": HIDDEN_TAB_ID, "active": False, "title": "Quokka notes", "url": "https://quokka.example.com/notes"}]}]}
    path = os.path.join(RUN, f"tabs.{hostpid}.json")
    tmp = os.path.join(RUN, f".tabs.{hostpid}.tmp")
    with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
        json.dump(doc, f)
    os.replace(tmp, path)
    return path


saved = open(CFG).read() if os.path.exists(CFG) else None
os.makedirs(os.path.dirname(CFG), exist_ok=True)
base = 'reveal_delay_ms = 0\n[windows]\nworkspaces = "current"\n'
got = os.path.join(RUN, "live-tabs-got")
reader = tab_file = None
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare() as sp, Keyboard() as kb:
        time.sleep(2.5)
        open(CFG, "w").write("browser_tabs = true\n" + base); sp.reset_order()
        kb.down("alt"); key(kb, "tab"); time.sleep(0.4); kb.up("alt"); time.sleep(0.6)  # the next session start reads the config
        check("on: the flag file appears", wait_for(lambda: os.path.exists(FLAG)), "no " + FLAG)
        bravo = next(c for c in clients() if c["class"] == "omahop-B")
        if os.path.exists(got):
            os.remove(got)
        reader = subprocess.Popen([sys.executable, "-I", "-c", READER, got], stdout=subprocess.PIPE, text=True)
        hostpid = int(reader.stdout.readline())
        tab_file = write_tabs(hostpid, bravo["pid"])
        sp.reset_order()
        kb.down("alt"); key(kb, "tab"); time.sleep(0.4)
        check("no tab rows without a search", "open=1" in state_lines() and tab_lines() == [], str(tab_lines()))
        for ch in "quokka":
            key(kb, ch)
        rows = tab_lines()
        check("a search finds the hidden tab by its title", len(rows) == 1 and rows[0][-1] == "Quokka notes" and rows[0][5] == "quokka.example.com", str(rows))
        check("the tab row is under the test window", bool(rows) and rows[0][1] == bravo["address"], str(rows))
        key(kb, "return"); kb.up("alt"); time.sleep(0.8)
        check("Return focuses the matched window", active_class() == "omahop-B", active_class())
        check("the helper receives the tab id", wait_for(lambda: os.path.exists(got) and open(got).read() == f"{HIDDEN_TAB_ID}\n"),
              open(got).read() if os.path.exists(got) else "nothing arrived")
        # off: the next session start removes the flag and the tab file
        open(CFG, "w").write(base)
        kb.down("alt"); key(kb, "tab"); time.sleep(0.4); kb.up("alt"); time.sleep(0.6)
        check("off: flag and tab file removed", wait_for(lambda: not os.path.exists(FLAG) and not os.path.exists(tab_file)))
finally:
    if reader:
        reader.terminate(); reader.wait(2)
    for p in (got, tab_file):
        if p and os.path.exists(p):
            os.remove(p)
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall tabs checks passed")
sys.exit(1 if failed else 0)
