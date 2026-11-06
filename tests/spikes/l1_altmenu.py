"""L1: does an app open its menu bar when it sees Alt down and up with nothing between (what happens when Hyprland consumes the Tab press)?
Runs an app with a menu bar (env L1_CLASS and L1_CMD; default LibreOffice Writer, which does NOT react to an Alt tap here, so use a Qt app) on a spare workspace, drives Alt through /dev/uinput, takes one screenshot of the menu strip each time.
Control = plain Alt tap. Test = Alt + a chord key that a Hyprland bind consumes (ALT + F10). Cleans up. Run: python3 tests/spikes/l1_altmenu.py <outdir>"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from uinput_kbd import Keyboard

OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
SPARE = "4"
CLASS = os.environ.get("L1_CLASS", "libreoffice")
CMD = os.environ.get("L1_CMD", "soffice --writer --norestore --nologo")
SETTLE = float(os.environ.get("L1_SETTLE", "6"))


def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout
def ev(lua): subprocess.run(["hyprctl", "eval", lua], capture_output=True)
def win(): return next((c for c in json.loads(sh("hyprctl", "clients", "-j")) if CLASS in c["class"].lower()), None)
def shot(name):
    w = win(); x, y = w["at"]; W = w["size"][0]
    subprocess.run(["grim", "-g", f"{x},{y} {min(W, 900)}x120", f"{OUT}/{name}.png"])
    return open(f"{OUT}/{name}.png", "rb").read()


origin = json.loads(sh("hyprctl", "activeworkspace", "-j"))["id"]
res = {}
try:
    ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{SPARE}" }}))'); time.sleep(0.8)
    ev('hl.exec_cmd("%s")' % CMD)
    for _ in range(40):
        time.sleep(1)
        if win(): break
    time.sleep(SETTLE)
    ev(f'hl.dispatch(hl.dsp.focus({{ window = hl.get_window("address:{win()["address"]}") }}))'); time.sleep(1)
    ev('pcall(hl.unbind, "ALT + F10"); hl.bind("ALT + F10", ' + os.environ.get("L1_HANDLER", "function() end") + ', {})')  # consuming bind, no repeating
    base = shot("0-before")
    with Keyboard() as kb:
        kb.down("alt"); time.sleep(0.15); kb.up("alt"); time.sleep(0.6)
        a = shot("1-after-plain-alt-tap")
        kb.tap("escape"); time.sleep(0.5)
        reset = shot("2-after-escape")
        kb.down("alt"); kb.down("f10"); kb.up("f10"); time.sleep(0.1); kb.up("alt"); time.sleep(0.6)   # Alt, consumed key, Alt up
        b = shot("3-after-alt-consumed-chord")
        kb.tap("escape"); time.sleep(0.4)
    res = {"plain Alt tap changes the menu strip": a != base, "Escape resets it": reset == base, "consumed chord changes the menu strip": b != base}
finally:
    ev('pcall(hl.unbind, "ALT + F10")')
    w = win()
    if w: ev(f'local w = hl.get_window("address:{w["address"]}"); if w then hl.dispatch(hl.dsp.window.close({{ window = w }})) end')
    time.sleep(2.5)
    if win(): subprocess.run(["pkill", "-f", CLASS])
    time.sleep(1)
    ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{origin}" }}))')
print(json.dumps(res, indent=1))
