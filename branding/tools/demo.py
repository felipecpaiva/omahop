#!/usr/bin/env python3
"""Records the feature GIFs for the README and the releases from the REAL overlay on a spare workspace (never a virtual monitor), with real key
and mouse events from /dev/uinput, demo windows that show public content only, and a screenshot frame loop. gifkit.py builds a captioned GIF and MP4 per scene.
Scenes: switch (list), cards, search, settings, pointer, peek, quick (quick closes a window, so it goes last), sameapp, hints. Needs grim, ffmpeg, kitty, chromium, bat, the plugin enabled and the shell restarted since the last QML change.
Your own ~/.config/omahop/config.toml is saved and put back. Do not touch the keyboard or mouse while it runs (about 2 minutes).
Usage: python3 branding/tools/demo.py [scene ...]   (no argument: all scenes)"""
import json, os, shutil, subprocess, sys, tempfile, threading, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tests")); sys.path.insert(0, HERE)
from livehelp import ev, sh
from uinput_kbd import Keyboard, Mouse
import gifkit

OUT = os.path.join(ROOT, "branding", "demo")
CFG = os.path.expanduser("~/.config/omahop/config.toml")
PROFILE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop-demo-chromium")
SPARE = 4
PLUGIN = "io.github.felipecpaiva.omahop"
REGION = "0,36 1280x764"   # logical pixels of the 1280x800 screen below the bar; grim -s 1 gives 1280x764 frames


def run_scene_config(extra):
    # top-level keys must come BEFORE the [windows] header, or they are read as window settings and ignored
    open(CFG, "w").write(extra + "[windows]\nworkspaces = \"current\"\n")


class Recorder:
    def __init__(self):
        self.frames, self.marks, self.stop, self.dir = [], [], threading.Event(), tempfile.mkdtemp(prefix="omahop-demo-")

    def __enter__(self):
        self.t0 = time.time()
        def grab():
            n = 0
            while not self.stop.is_set():
                p = os.path.join(self.dir, f"f{n:05d}.jpg"); a = time.time() - self.t0
                subprocess.run(["grim", "-s", "1", "-c", "-g", REGION, "-t", "jpeg", "-q", "85", p], capture_output=True)
                self.frames.append((a, p)); n += 1
        self.th = threading.Thread(target=grab); self.th.start()
        return self

    def caption(self, text):
        self.marks.append((time.time() - self.t0, text))

    def finish(self, name, width=960):
        self.marks.append((time.time() - self.t0, ""))
        self.stop.set(); self.th.join()
        total = time.time() - self.t0
        gifkit.build(self.frames, total, self.marks, OUT, name, width=width, fps=12)
        shutil.rmtree(self.dir, ignore_errors=True)
        print(f"wrote {name}.gif ({os.path.getsize(os.path.join(OUT, name + '.gif')) // 1024} KB, {total:.0f} s)")

    def __exit__(self, *exc):
        self.stop.set()


def focus_order(wins):
    """Recently-used order: the last in the list ends up most recent."""
    for w in wins:
        ev(f'local x = hl.get_window("address:{w["address"]}"); hl.dispatch(hl.dsp.focus({{ window = x }})); hl.dispatch(hl.dsp.window.alter_zorder({{ mode = "top", window = x }}))')
        time.sleep(0.5)


def tap_alt_tab(kb, hold=0.06):
    kb.down("alt"); kb.down("tab"); time.sleep(hold); kb.up("tab"); kb.up("alt")


def scene_switch(kb, wins):
    run_scene_config('style = "list"\nreveal_delay_ms = 120\n'); time.sleep(0.5)
    focus_order(wins)
    with Recorder() as r:
        time.sleep(0.8)
        r.caption("A quick Alt+Tab goes back to your last window"); time.sleep(0.9)
        tap_alt_tab(kb); time.sleep(1.3); tap_alt_tab(kb); time.sleep(1.4)
        r.caption("Hold Alt: the list shows, Tab moves on"); time.sleep(0.6)
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(1.1)
        kb.down("tab"); kb.up("tab"); time.sleep(1.0)
        kb.down("tab"); kb.up("tab"); time.sleep(1.0)
        kb.up("alt"); time.sleep(1.5)
        r.caption("Shift+Tab goes the other way"); time.sleep(0.5)
        kb.down("alt"); kb.down("shift"); kb.down("tab"); kb.up("tab"); kb.up("shift"); time.sleep(1.2)
        kb.down("shift"); kb.down("tab"); kb.up("tab"); kb.up("shift"); time.sleep(1.0)
        kb.up("alt"); time.sleep(1.5)
        r.finish("switch")


def scene_cards(kb, wins):
    run_scene_config('style = "cards"\nreveal_delay_ms = 120\n'); time.sleep(0.5)
    focus_order(wins)
    with Recorder() as r:
        time.sleep(0.8)
        r.caption("Cards: a picture of every window, covered ones too"); time.sleep(0.6)
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(1.4)
        for _ in range(2):
            kb.down("tab"); kb.up("tab"); time.sleep(1.1)
        kb.up("alt"); time.sleep(1.6)
        r.finish("cards")


def scene_search(kb, wins):
    run_scene_config('style = "cards"\nreveal_delay_ms = 120\n'); time.sleep(0.5)
    focus_order(wins)
    with Recorder() as r:
        time.sleep(0.8)
        r.caption("Type to search: hold Alt, press Tab, then type"); time.sleep(0.6)
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(1.2)
        for k in ("e", "x", "a", "m"):
            kb.down(k); kb.up(k); time.sleep(0.55)
        time.sleep(1.0)
        kb.up("alt"); time.sleep(1.8)
        r.finish("search")


def scene_settings(kb, wins):
    run_scene_config('style = "list"\n'); time.sleep(0.5)
    focus_order(wins)
    def move(x, y): ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"); time.sleep(0.5)
    with Recorder() as r, Mouse() as m:
        time.sleep(0.6)
        r.caption("One settings window, saved as you click")
        sh("omarchy-shell", "shell", "toggle", PLUGIN); time.sleep(1.8)
        for label, x, y in (("Windows from: this workspace", 458, 474), ("floating workspaces", 590, 474), ("all workspaces", 721, 474)):
            r.caption("Windows from: " + label.split(": ")[-1]); move(x, y); time.sleep(0.4); m.press(); time.sleep(0.1); m.release(); time.sleep(1.4)
        r.caption("Changes apply to the next Alt+Tab, no reload"); time.sleep(1.6)
        sh("omarchy-shell", "shell", "toggle", PLUGIN); time.sleep(1.2)
        r.finish("settings")


RUN = os.environ["XDG_RUNTIME_DIR"]
TAG = os.environ.get("DEMO_TAG", "")   # when set (for example v0.3.0), scenes also save a sharp still into branding/highlights/


def still(name, region):
    if TAG:
        os.makedirs(os.path.join(ROOT, "branding", "highlights"), exist_ok=True)
        subprocess.run(["grim", "-g", region, "-c", os.path.join(ROOT, "branding", "highlights", f"{TAG}-{name}.png")])


def read_rects(name, n=None, seconds=4.0, kinds=None):
    """Rectangles the overlay writes: `geometry` has x,y,w,h per row or card; `peek-geometry-eDP-1` has kind,name,x,y,w,h per slot and popup card."""
    end = time.time() + seconds
    out = []
    while time.time() < end:
        try:
            out = []
            for line in open(os.path.join(RUN, "omahop", name)).read().split("\n"):
                if not line:
                    continue
                f = line.split(",")
                if name == "geometry":
                    out.append(tuple(int(v) for v in f))
                elif kinds is None or f[0] in kinds:
                    out.append((f[0], f[1]) + tuple(int(v) for v in f[2:]))
        except OSError:
            out = []
        if out and (n is None or len(out) >= n):
            return out
        time.sleep(0.2)
    return out


def scene_pointer(kb, wins):
    run_scene_config('style = "cards"\nreveal_delay_ms = 120\n'); time.sleep(0.5)
    focus_order(wins)
    def move(x, y): ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"); time.sleep(0.5)
    with Recorder() as r, Mouse() as m:
        time.sleep(0.8)
        r.caption("Hover a card: close and minimize buttons appear")
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(1.4)
        rects = read_rects("geometry", n=4)
        if len(rects) >= 3:
            x, y, w, h = rects[2]
            move(x + w // 2, y + h // 2); time.sleep(1.8)
            still("pointer", "260,200 760x340")
            r.caption("Click a card to go straight to that window")
            m.press(); time.sleep(0.1); m.release(); time.sleep(1.8)
        kb.up("alt"); time.sleep(1.0)
        r.finish("pointer")


def scene_peek(kb, wins):
    run_scene_config('peek = "edge"\n'); time.sleep(3.0)
    focus_order(wins)
    with Recorder() as r, Mouse() as m:
        def move(x, y):
            # a warp inside the window the pointer is already in sends the app no motion event: wiggle one pixel like a real mouse would
            ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"); time.sleep(0.4)
            m.move(1, 0); time.sleep(0.1); m.move(-1, 0); time.sleep(0.4)
        time.sleep(0.6)
        r.caption("Peek strip: off by default, shows at the edge")
        time.sleep(1.4); move(1279, 400); time.sleep(1.6)
        slots = [g for g in read_rects("peek-geometry-eDP-1", kinds=("slot",)) if g[1] == "chromium"]
        if slots:
            r.caption("Hover an app: a picture of each of its windows")
            _, _, x, y, w, h = slots[0]
            move(x + w // 2, y + h // 2); time.sleep(2.0)
            cards = read_rects("peek-geometry-eDP-1", kinds=("card",))
            if cards:
                r.caption("Click one to go there")
                still("peek", "640,120 640x560")
                _, _, cx, cy, cw, ch = cards[0]
                move(cx + cw // 2, cy + ch // 2); time.sleep(0.8)
                m.press(); time.sleep(0.1); m.release(); time.sleep(1.4)
        move(640, 400); time.sleep(1.8)
        r.finish("peek")


def scene_quick(kb, wins):
    run_scene_config('style = "cards"\nreveal_delay_ms = 120\n'); time.sleep(0.5)
    focus_order(wins)
    with Recorder() as r:
        time.sleep(0.8)
        r.caption("Alt + Delete closes the picked window")
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(1.2)
        kb.down("tab"); kb.up("tab"); time.sleep(1.2)
        kb.down("delete"); kb.up("delete"); time.sleep(2.0)
        kb.up("alt"); time.sleep(1.2)
        r.finish("quick")


def scene_sameapp(kb, wins):
    run_scene_config('style = "cards"\nreveal_delay_ms = 120\n'); time.sleep(3.5)
    kitties = [w for w in wins if w["class"] == "kitty"]
    focus_order(kitties)
    with Recorder() as r:
        time.sleep(0.8)
        r.caption("Alt + backtick: only the windows of this app")
        kb.down("alt"); kb.down("grave"); kb.up("grave"); time.sleep(1.4)
        still("sameapp", "260,200 760x340")
        kb.down("grave"); kb.up("grave"); time.sleep(1.2)
        kb.up("alt"); time.sleep(1.4)
        r.finish("sameapp")


def scene_hints(kb, wins):
    run_scene_config('style = "list"\nreveal_delay_ms = 120\nhints = "numbers"\n'); time.sleep(0.5)
    focus_order(wins)
    with Recorder() as r:
        time.sleep(0.8)
        r.caption("Number keys jump straight to a window")
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(1.6)
        still("hints", "300,230 680x340")
        r.caption("Press 3: that window comes forward")
        kb.down("3"); kb.up("3"); time.sleep(1.6)
        kb.up("alt"); time.sleep(1.2)
        r.finish("hints")


SCENES = {"switch": scene_switch, "cards": scene_cards, "search": scene_search, "settings": scene_settings, "pointer": scene_pointer, "peek": scene_peek, "quick": scene_quick, "sameapp": scene_sameapp, "hints": scene_hints}


def main():
    wanted = sys.argv[1:] or list(SCENES)
    origin = json.loads(sh("hyprctl", "activeworkspace", "-j"))["id"]
    if any(c["workspace"]["id"] == SPARE for c in json.loads(sh("hyprctl", "clients", "-j"))):
        raise SystemExit("spare workspace 4 is not empty; not touching it")
    mode_file = os.path.expanduser(f"~/.local/state/omarchy/workspace-layouts/{SPARE}.lua")
    had_file = os.path.exists(mode_file)
    saved = open(CFG).read() if os.path.exists(CFG) else None
    cursor = sh("hyprctl", "cursorpos").strip().replace(",", "").split()
    os.makedirs(OUT, exist_ok=True)
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
        arch = f"cd {ROOT} && bat --paging=never --style=plain --color=always --line-range=1:30 docs/architecture.md; sleep 3600"
        launch("size 640 420; move 560 230", f"kitty --title architecture.md -e sh -c '{arch}'")
        time.sleep(2)
        print("demo windows:", sorted(c["class"] + ":" + c["title"] for c in json.loads(sh("hyprctl", "clients", "-j")) if c["workspace"]["id"] == SPARE))
        by_class = {c["class"]: c for c in json.loads(sh("hyprctl", "clients", "-j")) if c["workspace"]["id"] == SPARE}
        order = [by_class[k] for k in ("kitty", "chromium", "org.gnome.Nautilus") if k in by_class]  # README terminal ends up least recent
        wins = [c for c in json.loads(sh("hyprctl", "clients", "-j")) if c["workspace"]["id"] == SPARE]
        wins.sort(key=lambda c: (c["class"] != "kitty", c["title"]))
        ev('dofile("' + ROOT + '/lua/omahop.lua")'); time.sleep(3.0)
        with Keyboard() as kb:
            for name in wanted:
                print("scene", name); SCENES[name](kb, wins)
    finally:
        for c in json.loads(sh("hyprctl", "clients", "-j")):
            if c["workspace"]["id"] == SPARE:
                ev(f'local w = hl.get_window("address:{c["address"]}"); if w then hl.dispatch(hl.dsp.window.close({{ window = w }})) end')
        time.sleep(2); subprocess.run(["pkill", "-f", PROFILE]); time.sleep(1)
        ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{origin}" }}))'); time.sleep(0.5)
        ev(f'o.workspace_mode({{ workspace = "{SPARE}", mode = "dwindle" }})'); time.sleep(0.5)
        if not had_file and os.path.exists(mode_file):
            os.remove(mode_file)
        shutil.rmtree(PROFILE, ignore_errors=True)
        if saved is not None:
            open(CFG, "w").write(saved)
        elif os.path.exists(CFG):
            os.remove(CFG)
        if len(cursor) == 2:
            ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {int(float(cursor[0]))}, y = {int(float(cursor[1]))} }}))")
        subprocess.run(["hyprctl", "reload"], capture_output=True)


main()
