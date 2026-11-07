-- omahop JSON decoder: strict, small, pure (Lua 5.5 has none). Used only for the browser tab files, which come from another program, so
-- every input is untrusted: decode never raises, it returns nil and a reason. Objects become tables, arrays become sequences, null is J.null.
-- shortcut: decoder only, no encoder (omahop writes no JSON from Lua). Add one if a JSON file ever has to be written here.
local J = {}

J.null = setmetatable({}, { __tostring = function() return "null" end })
J.max_depth = 16

local ESC = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local decode_value -- forward

local function skip(s, i) return (s:find("[^ \t\r\n]", i)) or #s + 1 end

local function decode_string(s, i)
  local out, j = {}, i + 1
  while true do
    local k = s:find('["\\%c]', j)
    if not k then error("unterminated string") end
    out[#out + 1] = s:sub(j, k - 1)
    local c = s:sub(k, k)
    if c == '"' then return table.concat(out), k + 1 end
    if c ~= "\\" then error("control character in string") end
    local e = s:sub(k + 1, k + 1)
    if ESC[e] then out[#out + 1] = ESC[e]; j = k + 2
    elseif e == "u" then
      local hex = s:match("^%x%x%x%x", k + 2)
      if not hex then error("bad \\u escape") end
      local cp = tonumber(hex, 16); j = k + 6
      if cp >= 0xD800 and cp <= 0xDBFF then -- a surrogate pair (json.dumps writes non-ASCII this way)
        local lo = s:match("^\\u(%x%x%x%x)", j)
        local lv = lo and tonumber(lo, 16)
        if not (lv and lv >= 0xDC00 and lv <= 0xDFFF) then error("lone surrogate") end
        cp = 0x10000 + (cp - 0xD800) * 0x400 + (lv - 0xDC00); j = j + 6
      elseif cp >= 0xDC00 and cp <= 0xDFFF then error("lone surrogate") end
      out[#out + 1] = utf8.char(cp)
    else error("bad escape") end
  end
end

local function decode_number(s, i)
  local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
  if not num or not num:match("^-?%d") then error("bad number") end
  local v = math.tointeger(tonumber(num)) or tonumber(num)
  if not v then error("bad number") end
  return v, i + #num
end

local function decode_list(s, i, close, item)
  local t = {}
  i = skip(s, i + 1)
  if s:sub(i, i) == close then return t, i + 1 end
  while true do
    i = item(t, i)
    i = skip(s, i)
    local c = s:sub(i, i)
    if c == close then return t, i + 1 end
    if c ~= "," then error("expected , or " .. close) end
    i = skip(s, i + 1)
  end
end

local LITERALS = { ["true"] = true, ["false"] = false, null = J.null }

decode_value = function(s, i, depth)
  if depth > J.max_depth then error("nested too deep") end
  i = skip(s, i)
  local c = s:sub(i, i)
  if c == "{" then
    return decode_list(s, i, "}", function(t, j)
      if s:sub(j, j) ~= '"' then error("expected a key") end
      local k; k, j = decode_string(s, j)
      j = skip(s, j)
      if s:sub(j, j) ~= ":" then error("expected :") end
      t[k], j = decode_value(s, j + 1, depth + 1)
      return j
    end)
  elseif c == "[" then
    return decode_list(s, i, "]", function(t, j)
      local v; v, j = decode_value(s, j, depth + 1)
      t[#t + 1] = v
      return j
    end)
  elseif c == '"' then return decode_string(s, i)
  elseif c == "-" or c:match("%d") then return decode_number(s, i) end
  for word, v in pairs(LITERALS) do
    if s:sub(i, i + #word - 1) == word then return v, i + #word end
  end
  error("unexpected character")
end

-- text -> value, or nil and a reason (never the text itself: callers may log the reason).
function J.decode(text)
  if type(text) ~= "string" then return nil, "not text" end
  local ok, v, i = pcall(decode_value, text, 1, 1)
  if not ok then return nil, (tostring(v):gsub("^.-:%d+: ", "")) end
  if skip(text, i) <= #text then return nil, "trailing data" end
  return v
end

return J
