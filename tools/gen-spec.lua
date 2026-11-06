-- Writes spec.json from lua/config.lua so the settings panel (QML) reads the same definition as the Lua side.
--   lua tools/gen-spec.lua           write spec.json
--   lua tools/gen-spec.lua --check   exit 1 if the committed spec.json differs (run-all does this: no drift)
local here = (arg[0]:match("^(.*)/") or ".")
local root = here .. "/.."
local C = dofile(root .. "/lua/config.lua")

local function esc(s)
  return (s:gsub('[%c"\\]', function(c)
    local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }
    return map[c] or string.format("\\u%04x", c:byte())
  end))
end

local function enc(v, pad)
  local t = type(v)
  if t == "string" then return '"' .. esc(v) .. '"' end
  if t == "number" or t == "boolean" then return tostring(v) end
  if t == "table" and v[1] ~= nil or (t == "table" and next(v) == nil) then
    local parts = {}
    for _, x in ipairs(v) do parts[#parts + 1] = enc(x, pad) end
    return "[" .. table.concat(parts, ", ") .. "]"
  end
  -- object: keys in a fixed order so the file is stable
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = pad .. "  " .. enc(k, pad) .. ": " .. enc(v[k], pad .. "  ") end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
end

local function kind(rule)
  if type(rule.default) == "boolean" then return "bool" end
  if type(rule.default) == "number" then return "int" end
  return rule.values and "enum" or "text"
end

local groups = {}
for _, g in ipairs(C.groups) do groups[#groups + 1] = { id = g.id, title = g.title, settings = {} } end
local by_id = {}
for _, g in ipairs(groups) do by_id[g.id] = g end

for _, path in ipairs(C.order) do
  local section, key = path:match("^(%w+)%.([%w_]+)$")
  local rule = C.spec[section][key]
  local s = { id = path, section = section, key = key, type = kind(rule), default = rule.default, label = rule.label, help = rule.help,
    unit = rule.unit, min = rule.min, max = rule.max, values = rule.values, names = rule.names, reload = rule.reload or false, hidden = rule.hidden or false }
  local g = by_id[rule.group]
  g.settings[#g.settings + 1] = s
end

local out = enc({ schema = C.schema, groups = groups }, "") .. "\n"
local path = root .. "/spec.json"
if arg[1] == "--check" then
  local f = io.open(path, "r")
  local have = f and f:read("a") or ""
  if f then f:close() end
  if have ~= out then io.stderr:write("spec.json is out of date: run  lua tools/gen-spec.lua\n"); os.exit(1) end
  print("spec.json up to date")
else
  local f = assert(io.open(path, "w")); f:write(out); f:close()
  print("wrote " .. path)
end
