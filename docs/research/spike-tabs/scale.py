#!/usr/bin/env python3
"""Throwaway: size and write cost of a synthetic 200 tab, 10 window snapshot (no real titles)."""
import json
import os
import tempfile
import time

wins = [
    {"id": w, "focused": w == 0, "type": "normal",
     "tabs": [{"id": w * 100 + t, "win": w, "active": t == 0,
               "title": f"Synthetic page title number {t} of window {w} about nothing",
               "url": f"https://example.com/section/{w}/page/{t}?q=abcdefghij&ref=klmnop"} for t in range(20)]}
    for w in range(10)
]
raw = json.dumps({"type": "tabs", "windows": wins}, separators=(",", ":"))
print("bytes:", len(raw))
d = tempfile.mkdtemp()
n = 200
t0 = time.perf_counter()
for _ in range(n):
    fd, tmp = tempfile.mkstemp(dir=d)
    with os.fdopen(fd, "w") as f:
        f.write(raw)
    os.replace(tmp, os.path.join(d, "tabs.json"))
print("atomic write ms each:", round((time.perf_counter() - t0) / n * 1000, 3))
t0 = time.perf_counter()
for _ in range(n):
    json.loads(raw)
print("parse ms each (python):", round((time.perf_counter() - t0) / n * 1000, 3))
