#!/usr/bin/env python3
"""Makes the highlight pictures for a release from the REAL overlay: a spare workspace with a few demo windows that show public content only
(this project's README and release notes in terminals, example.com in a fresh browser profile, the system icons folder), a state file written by hand with
their real addresses, and screenshots of the overlay. Never creates a virtual monitor. Usage: python3 branding/tools/highlight.py v0.2.0"""
import json, os, shutil, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tests"))
from livehelp import ev, sh

TAG = sys.argv[1]
OUT = os.path.join(ROOT, "branding", "highlights")
STATE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "state")
PROFILE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop-demo-chromium")
SPARE = "4"
origin = json.loads(sh("hyprctl", "activeworkspace", "-j"))["id"]
if any(c["workspace"]["id"] == int(SPARE) for c in json.loads(sh("hyprctl", "clients", "-j"))):
    raise SystemExit("spare workspace 4 is not empty; not touching it")
mode_file = os.path.expanduser(f"~/.local/state/omarchy/workspace-layouts/{SPARE}.lua")
had_file = os.path.exists(mode_file)


def write(sel, wins, style, query="", thumbs="snapshot", open_=1):
    lines = ["version=1", f"open={open_}", f"revealed={open_}", f"selected={sel}", f"style={style}", f"thumbnails={thumbs}", "border=auto", f"query={query}"]
    for w in wins:
        lines.append(f"w\t{w['address']}\t{w['class']}\t0\t{w['title']}")
    open(STATE + ".new", "w").write("\n".join(lines) + "\n"); os.rename(STATE + ".new", STATE)


def launch(rule, cmd):
    ev(f'hl.exec_cmd("[float; {rule}] {cmd}")'); time.sleep(2.2)


try:
    ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{SPARE}" }}))'); time.sleep(0.8)
    ev(f'o.workspace_mode({{ workspace = "{SPARE}", mode = "floating" }})'); time.sleep(0.8)
    readme = f"cd {ROOT} && bat --paging=never --style=plain --color=always --line-range=1:34 README.md; sleep 3600"
    notes = f"cd {ROOT} && bat --paging=never --style=plain --color=always --line-range=1:34 docs/releases/v0.1.0.md; sleep 3600"
    launch("size 760 470; move 60 80", f"kitty --title README.md -e sh -c '{readme}'")
    launch("size 760 470; move 480 150", f"kitty --title release-notes.md -e sh -c '{notes}'")
    launch("size 700 460; move 300 90", f"chromium --user-data-dir={PROFILE} --no-first-run --no-default-browser-check --new-window https://example.com")
    time.sleep(3)
    launch("size 640 420; move 560 230", "nautilus /usr/share/icons")
    time.sleep(2)
    wins = [c for c in json.loads(sh("hyprctl", "clients", "-j")) if c["workspace"]["id"] == int(SPARE)]
    wins.sort(key=lambda c: c["focusHistoryID"])  # most recently used first, like the switcher
    print("demo windows:", [(w["class"], w["title"]) for w in wins])
    os.makedirs(OUT, exist_ok=True)
    for name, style, sel, query, shown in [("cards", "cards", 2, "", wins), ("list", "list", 2, "", wins), ("search", "cards", 1, "exam", [w for w in wins if "exam" in (w["title"] + w["class"]).lower()])]:
        write(sel, shown, style, query); time.sleep(2.2)
        subprocess.run(["grim", "-g", "0,36 1280x764", os.path.join(OUT, f"{TAG}-{name}.png")])
        print("saved", f"{TAG}-{name}.png")
finally:
    write(0, [], "list", open_=0); time.sleep(0.5)
    for c in json.loads(sh("hyprctl", "clients", "-j")):
        if c["workspace"]["id"] == int(SPARE):
            ev(f'local w = hl.get_window("address:{c["address"]}"); if w then hl.dispatch(hl.dsp.window.close({{ window = w }})) end')
    time.sleep(2)
    subprocess.run(["pkill", "-f", PROFILE])
    time.sleep(1)
    ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{origin}" }}))'); time.sleep(0.5)
    ev(f'o.workspace_mode({{ workspace = "{SPARE}", mode = "dwindle" }})'); time.sleep(0.5)
    if not had_file and os.path.exists(mode_file):
        os.remove(mode_file)
    shutil.rmtree(PROFILE, ignore_errors=True)
