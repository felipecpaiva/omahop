-- Spike D14: can the glue (a) call io.popen, (b) read the current binds with `hyprctl binds`, (c) register and remove ~40 ALT+<key> binds quickly?
local out = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omahop-d14.txt"
local f = io.open(out, "w")
local function say(s) f:write(s, "\n") end
local ok, p = pcall(io.popen, "echo hi")
say("io.popen available: " .. tostring(ok and p ~= nil))
local function now() local u = io.open("/proc/uptime"); local s = u:read("n"); u:close(); return s * 1000 end
local t0 = now()
local p2 = io.popen("hyprctl binds 2>&1")
local text = p2 and p2:read("a") or ""
if p2 then p2:close() end
say(string.format("hyprctl binds via popen: %.1f ms, %d bytes", now() - t0, #text))
-- chords already used with ALT (modmask 8) or ALT+SHIFT (9)
local used = {}
for block in text:gmatch("bind\n(.-)\n\n") do
  local mod, key = block:match("modmask: (%d+)"), block:match("key: ([^\n]+)")
  if mod and (tonumber(mod) == 8 or tonumber(mod) == 9) then used[#used + 1] = mod .. ":" .. key end
end
say("ALT or ALT+SHIFT binds in use: " .. table.concat(used, " "))
local keys = {}
for c = string.byte("A"), string.byte("Z") do keys[#keys + 1] = string.char(c) end
for c = string.byte("0"), string.byte("9") do keys[#keys + 1] = string.char(c) end
keys[#keys + 1] = "SPACE"; keys[#keys + 1] = "BACKSPACE"
local t1 = now()
for _, k in ipairs(keys) do pcall(hl.bind, "ALT + " .. k, function() end, {}) end
local t2 = now()
for _, k in ipairs(keys) do pcall(hl.unbind, "ALT + " .. k) end
local t3 = now()
say(string.format("register %d binds: %.1f ms, unregister: %.1f ms", #keys, t2 - t1, t3 - t2))
f:close()
