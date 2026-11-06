import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from uinput_kbd import Keyboard
with Keyboard() as kb:
    print("S1 alt alone"); kb.down("alt"); time.sleep(0.2); kb.up("alt"); time.sleep(0.4)
    print("S2 alt, f10 tap, release f10, release alt"); kb.down("alt"); kb.down("f10"); kb.up("f10"); time.sleep(0.2); kb.up("alt"); time.sleep(0.4)
    print("S3 alt, f10 held 0.6s (repeats?), release f10, release alt"); kb.down("alt"); kb.down("f10"); time.sleep(0.6); kb.up("f10"); kb.up("alt"); time.sleep(0.4)
    print("S4 alt, f10, alt released first"); kb.down("alt"); kb.down("f10"); kb.up("alt"); time.sleep(0.2); kb.up("f10"); time.sleep(0.4)
    print("S5 right alt, f10, release both"); kb.down("ralt"); kb.down("f10"); kb.up("f10"); kb.up("ralt"); time.sleep(0.4)
