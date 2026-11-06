"""Live check of the settings panel: open it, click two buttons with a virtual mouse, and see that ~/.config/omahop/config.toml changes the way ConfigIO says
(one line, everything else untouched). Your own config file is saved and put back.
Click positions are logical pixels measured for a 1280x800 logical screen (2560x1600 at scale 2) with the panel centred; on another screen the test
SKIPs instead of clicking blind (an earlier editor test of ours clicked stale positions and hit the wrong controls).
Needs the plugin enabled and the shell restarted since the last QML change. Usage: python3 tests/live_panel.py"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from uinput_kbd import Mouse

CFG = os.path.expanduser("~/.config/omahop/config.toml")
PLUGIN = "io.github.felipecpaiva.omahop"


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def ev(lua):
    subprocess.run(["hyprctl", "eval", lua], capture_output=True)


def move(x, y):
    ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"); time.sleep(0.5)


mon = json.loads(sh("hyprctl", "monitors", "-j"))[0]
logical = (int(mon["width"] / mon["scale"]), int(mon["height"] / mon["scale"]))
if logical != (1280, 800):
    print(f"SKIP panel click test: logical screen is {logical}, the click positions are for (1280, 800)")
    sys.exit(0)

saved = open(CFG).read() if os.path.exists(CFG) else None
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


start_cursor = sh("hyprctl", "cursorpos").strip().replace(",", "").split()
try:
    os.makedirs(os.path.dirname(CFG), exist_ok=True)
    open(CFG, "w").write("# my notes\nschema = 1\nreveal_delay_ms = 0 # keep this comment\n")
    sh("omarchy-shell", "shell", "toggle", PLUGIN); time.sleep(1.5)
    check("panel layer is open", '"omahop-settings"' in sh("hyprctl", "layers", "-j"))
    with Mouse() as m:
        move(639, 298); m.press(); time.sleep(0.1); m.release(); time.sleep(1.3)
        text = open(CFG).read()
        check("clicking 'All workspaces' writes scope = \"all\"", 'scope = "all"' in text, text)
        check("the user's comments and other keys are untouched", "# my notes" in text and "reveal_delay_ms = 0 # keep this comment" in text, text)
        move(491, 298); m.press(); time.sleep(0.1); m.release(); time.sleep(1.3)
        text = open(CFG).read()
        check("clicking 'Floating workspaces only' changes that same line", 'scope = "floating"' in text and text.count("scope =") == 1, text)
finally:
    sh("omarchy-shell", "shell", "toggle", PLUGIN); time.sleep(0.8)
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    if len(start_cursor) == 2:
        move(int(float(start_cursor[0])), int(float(start_cursor[1])))
check("panel closed again", '"omahop-settings"' not in sh("hyprctl", "layers", "-j"))
print("\nFAILED: " + ", ".join(failed) if failed else "\nall panel checks passed")
sys.exit(1 if failed else 0)
