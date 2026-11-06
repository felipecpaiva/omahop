"""Spike S1/S9 driver: sends real key events through /dev/uinput while s1_probe.lua logs what Hyprland reports."""
import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from uinput_kbd import Keyboard

LOG = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "omahop-s1.log")
def mark(s):
    with open(LOG, "a") as f: f.write(f"---- {s}\n")

with Keyboard() as kb:
    mark("A: alt down, three f10 taps, alt up")
    kb.down("alt")
    for _ in range(3): kb.tap("f10", hold=0.03) if False else (kb.down("f10"), kb.up("f10"))
    kb.up("alt"); time.sleep(0.3)
    mark("B: alt down, f10 HELD 1.2 s (does it repeat?), f10 up, alt up")
    kb.down("alt"); kb.down("f10"); time.sleep(1.2); kb.up("f10"); kb.up("alt"); time.sleep(0.3)
    mark("C: alt down, f10 down, ALT UP FIRST, then f10 up (release order)")
    kb.down("alt"); kb.down("f10"); time.sleep(0.1); kb.up("alt"); time.sleep(0.2); kb.up("f10"); time.sleep(0.3)
    mark("D: right alt: ralt down, f10 tap, ralt up")
    kb.down("ralt"); kb.down("f10"); kb.up("f10"); kb.up("ralt"); time.sleep(0.3)
    mark("E: poll method: alt down, alt+f11 starts poll, 0.4 s, alt up, 0.4 s, alt+f12 stops")
    kb.down("alt"); kb.down("f11"); kb.up("f11"); time.sleep(0.4); kb.up("alt"); time.sleep(0.4)
    kb.down("alt"); kb.down("f12"); kb.up("f12"); kb.up("alt")
    time.sleep(0.3)
    mark("done")
