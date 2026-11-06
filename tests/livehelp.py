"""Shared by the live tests: small helpers around hyprctl, grim and a spare workspace. Never creates virtual monitors."""
import json, os, subprocess, time

SPARE = "4"
COLORS = {"A": "#c00000", "B": "#00c000", "C": "#0000c0"}
POS = {"A": (300, 250), "B": (350, 300), "C": (400, 350)}
TITLES = {"A": "alpha", "B": "bravo", "C": "charlie"}  # distinct window titles, so search can pick one


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def ev(lua):
    subprocess.run(["hyprctl", "eval", lua], capture_output=True)


def clients():
    return json.loads(sh("hyprctl", "clients", "-j"))


def active_class():
    return json.loads(sh("hyprctl", "activewindow", "-j") or "{}").get("class", "")


def addr(cls):
    c = next((c for c in clients() if c["class"] == cls), None)
    return c["address"] if c else None


def pixel(x, y):
    """Which of the coloured test windows is on top at (x, y): 'A', 'B', 'C' or '?'."""
    raw = subprocess.run(["grim", "-g", f"{x},{y} 1x1", "-t", "ppm", "-"], capture_output=True).stdout
    r, g, b = raw[-3:]
    if max(r, g, b) - sorted((r, g, b))[1] < 25:
        return "?"
    return "ABC"[max(range(3), key=lambda i: (r, g, b)[i])]


def read_state(path=None):
    path = path or os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "omahop", "state")
    try:
        d = {}
        for line in open(path).read().splitlines():
            if "=" in line and not line.startswith("w\t"):
                k, v = line.split("=", 1)
                d[k] = v
        return d
    except OSError:
        return {}


class Spare:
    """A spare floating workspace with three overlapping coloured kitty windows (A, B, C; C created last, so C is focused)."""

    def __init__(self, mode="floating"):
        self.mode = mode
        self.origin = json.loads(sh("hyprctl", "activeworkspace", "-j"))["id"]
        self.mode_file = os.path.expanduser(f"~/.local/state/omarchy/workspace-layouts/{SPARE}.lua")
        self.had_file = os.path.exists(self.mode_file)

    def __enter__(self):
        ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{SPARE}" }}))'); time.sleep(0.8)
        ev(f'o.workspace_mode({{ workspace = "{SPARE}", mode = "{self.mode}" }})'); time.sleep(0.8)
        for n in "ABC":
            x, y = POS[n]
            ev(f'hl.exec_cmd("[float; size 700 450; move {x} {y}] kitty --class omahop-{n} -o background={COLORS[n]} -o background_opacity=1 --title {TITLES[n]} -e sleep 3600")')
            time.sleep(1.6)
        assert all(addr("omahop-" + n) for n in "ABC"), "test windows did not start"
        return self

    def __exit__(self, *exc):
        for n in "ABC":
            a = addr("omahop-" + n)
            if a:
                ev(f'local w = hl.get_window("address:{a}"); if w then hl.dispatch(hl.dsp.window.close({{ window = w }})) end')
        time.sleep(1.0)
        ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{self.origin}" }}))'); time.sleep(0.5)
        ev(f'o.workspace_mode({{ workspace = "{SPARE}", mode = "dwindle" }})'); time.sleep(0.5)
        if not self.had_file and os.path.exists(self.mode_file):
            os.remove(self.mode_file)

    def focus(self, n):
        a = addr("omahop-" + n)
        ev(f'local w = hl.get_window("address:{a}"); hl.dispatch(hl.dsp.focus({{ window = w }})); hl.dispatch(hl.dsp.window.alter_zorder({{ mode = "top", window = w }}))')
        time.sleep(0.5)

    def reset_order(self):
        """Recently-used order back to C, B, A (the same as at the start), whatever earlier steps did."""
        for n in "ABC":
            self.focus(n)
