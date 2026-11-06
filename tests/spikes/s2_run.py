"""Spike S2 driver. Spare workspace with three overlapping coloured windows, B minimized, then a probe overlay with thumbnails.
Records: does a thumbnail show real content for an occluded window (A) and a minimized one (B)? CPU of Hyprland and the shell with 0, 10 live
and 10 snapshot views. Cleans up. Usage: python3 tests/spikes/s2_run.py <outdir>"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from livehelp import Spare, addr, ev, sh

OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
HZ = os.sysconf("SC_CLK_TCK")


def cpu(sub):
    t = 0
    for pid in os.listdir("/proc"):
        if pid.isdigit():
            try:
                if sub in open(f"/proc/{pid}/comm").read():
                    f = open(f"/proc/{pid}/stat").read().rsplit(")", 1)[1].split(); t += int(f[11]) + int(f[12])
            except OSError:
                pass
    return t


def run_probe(live, repeat, seconds=3.0, shot=None):
    env = dict(os.environ, S2_LIVE="1" if live else "0", S2_REPEAT=str(repeat))
    log = open(f"{OUT}/probe-{'live' if live else 'snap'}-{repeat}.log", "w")
    p = subprocess.Popen(["qs", "-p", os.path.abspath(os.path.join(os.path.dirname(__file__), "s2_probe.qml"))], env=env, stdout=log, stderr=subprocess.STDOUT)
    time.sleep(2.5)
    h0, q0 = cpu("Hyprland"), cpu("qs") + cpu("quickshell")
    t0 = time.time(); time.sleep(seconds); dt = time.time() - t0
    h1, q1 = cpu("Hyprland"), cpu("qs") + cpu("quickshell")
    if shot:
        subprocess.run(["grim", "-g", "20,30 640x360", shot])
    p.terminate(); p.wait(timeout=5); log.close()
    return (h1 - h0) / HZ / dt * 100, (q1 - q0) / HZ / dt * 100


with Spare() as sp:
    b = addr("omahop-B")
    # the same call omarchy-hyprland-window-minimize makes (that script only acts on workspaces with a saved floating mode, which the spare workspace has not)
    ev(f'local w = hl.get_window("address:{b}"); hl.dispatch(hl.dsp.window.move({{ workspace = "special:minimized", follow = false, window = w }}))'); time.sleep(1.0)
    ws = {c["class"]: c["workspace"]["name"] for c in __import__("json").loads(sh("hyprctl", "clients", "-j")) if c["class"].startswith("omahop-")}
    print("workspaces:", ws)
    idle_h0, idle_q0 = cpu("Hyprland"), cpu("qs") + cpu("quickshell"); time.sleep(3)
    print("idle CPU: Hyprland %.0f%%, shell %.0f%%" % ((cpu("Hyprland") - idle_h0) / HZ / 3 * 100, ((cpu("qs") + cpu("quickshell")) - idle_q0) / HZ / 3 * 100))
    for live, rep in [(True, 1), (True, 10), (False, 10), (True, 1)]:
        h, q = run_probe(live, rep, shot=f"{OUT}/shot-{'live' if live else 'snap'}-{rep}.png" if rep == 1 or not live else None)
        print(f"{'live' if live else 'snapshot'} x{rep * 3} views: Hyprland {h:.0f}% shell/qs {q:.0f}% of one core")
print(open(f"{OUT}/probe-live-1.log").read()[-700:])
