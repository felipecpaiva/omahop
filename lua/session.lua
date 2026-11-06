-- omahop switch session: the state machine behind one Alt+Tab. Pure: time and key state are passed in, so it tests without Hyprland.
-- Times are milliseconds. Glue (omahop.lua) feeds it Tab presses from binds and polls Alt and Tab with hl.is_key_down on a timer.
--
--   open(now, n, selected)  first Tab: a session starts, nothing is shown yet (a quick tap must not flash an overlay)
--   step(now, delta)        a Tab or Shift+Tab press
--   key(now, name)          escape, return, left, right, up, down while the overlay is up
--   tick(now, keys)         keys = { alt = true|false|nil, tab = true|false|nil } (nil: cannot tell, counts as held)
-- Each call returns a list of actions: { type = "reveal" } | { type = "select", index = i } | { type = "commit", index = i } | { type = "cancel" }
local S = {}
S.__index = S

S.alt_gone_ticks = 2 -- Alt must read as up on this many ticks in a row (omagnet's stuck-drag lesson: one nil or glitch must not end it)
S.max_ms = 60000 -- failsafe: a session never outlives this

function S.new(cfg)
  return setmetatable({
    reveal_ms = cfg.reveal_delay_ms,
    repeat_delay_ms = cfg.keys.repeat_delay_ms,
    repeat_ms = cfg.keys.repeat_ms,
    open_ = false,
  }, S)
end

function S:is_open() return self.open_ end
function S:is_revealed() return self.revealed == true end
function S:selected() return self.sel end

function S:open(now, n, selected)
  if self.open_ or n < 1 then return {} end
  self.open_, self.revealed, self.n, self.sel = true, false, n, selected
  self.opened_at, self.last_step_at, self.repeating, self.dir, self.alt_gone = now, now, false, 1, 0
  return { { type = "select", index = selected } }
end

local function finish(self)
  self.open_, self.revealed = false, false
end

local function move(self, delta)
  if self.n < 1 then return { type = "select", index = 0 } end -- an empty list (search found nothing): nothing to move to
  self.sel = (self.sel - 1 + delta) % self.n + 1
  return { type = "select", index = self.sel }
end

-- The list changed under the session (search): a new size and selection. Nothing is announced; the caller writes the state.
function S:resize(n, selected)
  if not self.open_ then return end
  self.n, self.sel = n, selected
end

function S:step(now, delta)
  if not self.open_ then return {} end
  self.last_step_at, self.repeating, self.dir = now, false, delta
  return { move(self, delta) }
end

function S:key(now, name)
  if not self.open_ then return {} end
  if name == "escape" then finish(self); return { { type = "cancel" } } end
  if name == "return" then local i = self.sel; finish(self); return { { type = "commit", index = i } } end
  if name == "left" or name == "up" then return { move(self, -1) } end
  if name == "right" or name == "down" then return { move(self, 1) } end
  return {}
end

function S:tick(now, keys)
  if not self.open_ then return {} end
  local out = {}
  if now - self.opened_at > S.max_ms then finish(self); return { { type = "cancel" } } end
  if keys.alt == false then self.alt_gone = self.alt_gone + 1 else self.alt_gone = 0 end
  if self.alt_gone >= S.alt_gone_ticks then
    local i = self.sel
    finish(self)
    return { { type = "commit", index = i } }
  end
  if not self.revealed and now - self.opened_at >= self.reveal_ms then
    self.revealed = true
    out[#out + 1] = { type = "reveal" }
  end
  -- holding Tab: the bind fired once at the press, so repeat here after a delay, then at an interval
  if keys.tab == true then
    local wait = self.repeating and self.repeat_ms or self.repeat_delay_ms
    if now - self.last_step_at >= wait then
      self.last_step_at, self.repeating = now, true
      out[#out + 1] = move(self, self.dir)
    end
  end
  return out
end

return S
