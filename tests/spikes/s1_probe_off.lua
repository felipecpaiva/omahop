for _, k in ipairs({ "ALT + F10", "ALT + F11", "ALT + F12", "ALT_L", "ALT_R" }) do pcall(hl.unbind, k) end
local f = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omahop-s1.log", "a"); if f then f:write("probe removed\n"); f:close() end
