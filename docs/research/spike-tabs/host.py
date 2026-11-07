#!/usr/bin/env python3
"""Throwaway spike host: native messaging stdio <-> files in $OMAHOP_RT (default $XDG_RUNTIME_DIR/omahop)."""
import json
import os
import select
import struct
import sys
import tempfile

RT = os.environ.get("OMAHOP_RT") or os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop")
os.makedirs(RT, mode=0o700, exist_ok=True)
FIFO = os.path.join(RT, "activate.fifo")
if not os.path.exists(FIFO):
    os.mkfifo(FIFO, 0o600)


def read_msg(stream):
    head = stream.read(4)
    if len(head) < 4:
        return None
    return json.loads(stream.read(struct.unpack("=I", head)[0]))


def write_msg(obj):
    raw = json.dumps(obj, separators=(",", ":")).encode()
    sys.stdout.buffer.write(struct.pack("=I", len(raw)) + raw)
    sys.stdout.buffer.flush()


def write_atomic(path, obj):
    fd, tmp = tempfile.mkstemp(dir=RT)
    with os.fdopen(fd, "w") as f:
        json.dump(obj, f)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


# O_RDWR so the read end never sees EOF while no writer is attached.
fifo = os.open(FIFO, os.O_RDWR | os.O_NONBLOCK)
while True:
    ready, _, _ = select.select([sys.stdin.buffer, fifo], [], [])
    if fifo in ready:
        for line in os.read(fifo, 4096).decode().splitlines():
            write_msg(json.loads(line))
    if sys.stdin.buffer in ready:
        msg = read_msg(sys.stdin.buffer)
        if msg is None:
            break
        write_atomic(os.path.join(RT, "tabs.json"), {"caller": sys.argv[1:], **msg})
