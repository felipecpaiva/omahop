-- Spike S9 probe: which Lua bind spelling reports an Alt RELEASE? Idempotent: unbinds its own keys first (loading twice doubled binds in S1).
local LOG = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omahop-s9.log"
local function now() local f = io.open("/proc/uptime"); local s = f:read("*n"); f:close(); return string.format("%.3f", s) end
local function log(s) local f = io.open(LOG, "a"); if f then f:write(now(), " ", s, "\n"); f:close() end end
local variants = {
  { "v1", "ALT_L",     { release = true, ignore_mods = true, non_consuming = true } },
  { "v2", "ALT_L",     { release = true, non_consuming = true } },
  { "v3", "ALT_L",     { release = true } },
  { "v4", "Alt_L",     { release = true, ignore_mods = true, non_consuming = true } },
  { "v5", "ALT + Alt_L", { release = true, ignore_mods = true, non_consuming = true } },
  { "v6", "ALT_R",     { release = true, ignore_mods = true, non_consuming = true } },
  { "v7", "ALT + F10", { release = true, non_consuming = true } },
}
for _, v in ipairs(variants) do pcall(hl.unbind, v[2]) end
for _, v in ipairs(variants) do
  local ok, err = pcall(hl.bind, v[2], function() log("FIRED " .. v[1] .. " " .. v[2]) end, v[3])
  log("bind " .. v[1] .. " " .. (ok and "ok" or ("ERR " .. tostring(err))))
end
