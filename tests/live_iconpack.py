"""Live check of icon packs (v1.3): a throwaway pack in ~/.config/omahop/packs holds a solid magenta 64x64 PNG named omahop-a.png (the class of test window A).
With icon_pack set to it, the list's row for window A must show magenta; with the setting empty it must not. The pack and your config are removed and put back.
Needs the plugin enabled. Usage: python3 tests/live_iconpack.py"""
import os, shutil, struct, subprocess, sys, time, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare
from uinput_kbd import Keyboard

CFG = os.path.expanduser("~/.config/omahop/config.toml")
PACKS = os.path.expanduser("~/.config/omahop/packs")
PACK = "omahop-live-test"
SHOT = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "iconpack.ppm")
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def png(path, rgb, size=64):
    raw = b"".join(b"\x00" + bytes(rgb) * size for _ in range(size))
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d))
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def magenta():
    subprocess.run(["grim", "-t", "ppm", SHOT])
    raw = open(SHOT, "rb").read()
    data = raw.split(b"\n", 3)[3]
    n = sum(1 for i in range(0, len(data) - 2, 3) if data[i] > 200 and data[i + 1] < 60 and data[i + 2] > 200)
    os.remove(SHOT)
    return n


def list_open(kb):
    kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(1.2)


def list_close(kb):
    kb.down("escape"); kb.up("escape"); time.sleep(0.3); kb.up("alt"); time.sleep(0.8)


saved = open(CFG).read() if os.path.exists(CFG) else None
os.makedirs(os.path.dirname(CFG), exist_ok=True)
os.makedirs(f"{PACKS}/{PACK}/icons", exist_ok=True)
open(f"{PACKS}/{PACK}/pack.toml", "w").write('name = "omahop live test"\nauthor = "omahop tests"\nlicense = "CC0-1.0"\n')
png(f"{PACKS}/{PACK}/icons/omahop-a.png", (255, 0, 255))
try:
    with Spare() as sp, Keyboard() as kb:
        time.sleep(2.0)
        open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nworkspaces = "current"\n'); time.sleep(1.5); sp.reset_order()
        list_open(kb); base = magenta(); list_close(kb)
        check("no pack: no magenta icon", base < 200, str(base))
        open(CFG, "w").write(f'reveal_delay_ms = 0\nicon_pack = "{PACK}"\n[windows]\nworkspaces = "current"\n'); time.sleep(4.0); sp.reset_order()
        list_open(kb); with_pack = magenta(); list_close(kb)
        check("with the pack: the row of window A shows the pack icon", with_pack > 400, str(with_pack))
        open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nworkspaces = "current"\n'); time.sleep(4.0); sp.reset_order()
        list_open(kb); back = magenta(); list_close(kb)
        check("pack unset again: the icon is gone without a restart", back < 200, str(back))
finally:
    shutil.rmtree(f"{PACKS}/{PACK}", ignore_errors=True)
    try: os.rmdir(PACKS)
    except OSError: pass
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall icon pack checks passed")
sys.exit(1 if failed else 0)
