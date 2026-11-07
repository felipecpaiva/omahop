"""Builds one good and several hostile pack zips into the folder given as argv[1]. Test fixtures only; nothing here is shipped."""
import os
import struct
import sys
import zipfile
import zlib

out = sys.argv[1]
os.makedirs(out, exist_ok=True)


def png(w=64, h=64):
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    raw = b"".join(b"\x00" + b"\x00\x00\x00\xff" * w for _ in range(h))
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


TOML = b'schema = 1\nid = "demo"\nname = "Demo"\nauthor = "A"\nlicence = "CC0-1.0"\n'


def make(name, files, symlink=None):
    with zipfile.ZipFile(os.path.join(out, name), "w", zipfile.ZIP_DEFLATED) as z:
        for n, data in files.items():
            z.writestr(n, data)
        if symlink:
            i = zipfile.ZipInfo(symlink[0])
            i.create_system = 3
            i.external_attr = 0o120777 << 16
            z.writestr(i, symlink[1])


SVG = b'<svg xmlns="http://www.w3.org/2000/svg"><rect width="4" height="4"/></svg>'
make("good.zip", {"pack.toml": TOML, "icons/firefox.png": png(), "icons/kitty.svg": SVG})
make("traversal.zip", {"pack.toml": TOML, "icons/../../evil.png": png()})
make("absolute.zip", {"pack.toml": TOML, "/etc/cron.d/x.png": png()})
make("backslash.zip", {"pack.toml": TOML, "icons\\a.png": png()})
make("hidden.zip", {"pack.toml": TOML, "icons/.a.png": png()})
make("symlink.zip", {"pack.toml": TOML}, symlink=("icons/a.png", "/etc/passwd"))
make("script.zip", {"pack.toml": TOML, "icons/run.sh": b"#!/bin/sh\nid\n"})
make("nested.zip", {"pack.toml": TOML, "icons/sub/a.png": png()})
make("dupcase.zip", {"pack.toml": TOML, "icons/A.png": png(), "icons/a.png": png()})
make("nomanifest.zip", {"icons/a.png": png()})
make("bomb.zip", {"pack.toml": TOML, "icons/zeros.png": b"\x00" * (1900 * 1024)})
make("manyfiles.zip", dict({"pack.toml": TOML}, **{"icons/i%d.png" % i: b"x" for i in range(2200)}))
make("bigpng.zip", {"pack.toml": TOML, "icons/huge.png": png(60000, 1)})
