import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from uinput_kbd import Keyboard
LOG = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "omahop-s9.log")
def mark(s):
    with open(LOG, "a") as f: f.write(f"---- {s}\n")
with Keyboard() as kb:
    mark("left alt down/up alone"); kb.down("alt"); time.sleep(0.2); kb.up("alt"); time.sleep(0.3)
    mark("right alt down/up alone"); kb.down("ralt"); time.sleep(0.2); kb.up("ralt"); time.sleep(0.3)
    mark("alt+f10 then release f10 then alt"); kb.down("alt"); kb.down("f10"); kb.up("f10"); kb.up("alt"); time.sleep(0.3)
    mark("alt+f10 then release alt first"); kb.down("alt"); kb.down("f10"); kb.up("alt"); kb.up("f10"); time.sleep(0.3)
    mark("done")
