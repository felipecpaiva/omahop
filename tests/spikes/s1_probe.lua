-- Spike S1/S9 probe, loaded into the running Hyprland with `hyprctl eval 'dofile("<path>")'`. Uses the test chord ALT + F10 so the
-- stock ALT + TAB bind is never touched. Logs every event with a millisecond clock to LOG. Remove with s1_probe_off.lua.
local LOG = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omahop-s1.log"
local function now() return string.format("%.3f", hl.get_time and hl.get_time() or os.clock()) end
local function log(s) local f = io.open(LOG, "a"); if f then f:write(now(), " ", s, "\n"); f:close() end end
local function down(k) local ok, r = pcall(hl.is_key_down, k); if not ok then return "err" end; return tostring(r) end
log("probe loaded")
local function try(name, key, fn, opts)
  local ok, err = pcall(hl.bind, key, fn, opts)
  log("bind " .. name .. " " .. (ok and "ok" or ("ERR " .. tostring(err))))
end
try("press", "ALT + F10", function() log("PRESS alt+f10 altL=" .. down("Alt_L") .. " altR=" .. down("Alt_R")) end, { repeating = true })
-- release method A: a release bind on each Alt key, as a plain non-consuming bind
try("relA_L", "ALT_L", function() log("RELEASE-A Alt_L") end, { release = true, ignore_mods = true, non_consuming = true })
try("relA_R", "ALT_R", function() log("RELEASE-A Alt_R") end, { release = true, ignore_mods = true, non_consuming = true })
-- press side of the same keys, to see whether both press and release are seen
try("prsA_L", "ALT_L", function() log("PRESS-A Alt_L") end, { ignore_mods = true, non_consuming = true })
try("prsA_R", "ALT_R", function() log("PRESS-A Alt_R") end, { ignore_mods = true, non_consuming = true })
-- release method B: polling with is_key_down on one-shot timers
local gen = 0
function _G.omahop_s1_poll()
  gen = gen + 1; local g = gen
  local function tick()
    if g ~= gen then return end
    log("POLL altL=" .. down("Alt_L") .. " altR=" .. down("Alt_R"))
    hl.timer(tick, { type = "oneshot", timeout = 50 })
  end
  hl.timer(tick, { type = "oneshot", timeout = 50 })
end
try("poll", "ALT + F11", function() _G.omahop_s1_poll() end, {})
try("pollstop", "ALT + F12", function() gen = gen + 1; log("poll stopped") end, {})
