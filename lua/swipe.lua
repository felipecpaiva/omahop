-- omahop swipe: turns a touchpad swipe (Hyprland's hl.gesture start, update and finish callbacks) into rows of the switcher list.
-- Pure: the glue (omahop.lua) feeds it the horizontal delta of each update and the clock, so it tests without Hyprland.
-- Design and evidence: docs/research/swipe-spike.md. Each `step_px` of travel is one row; the first row crossed opens the list,
-- so a few pixels of an accidental touch never flash an overlay. Lifting the fingers ends the swipe (the glue picks or cancels).
local W = {}
W.__index = W

W.idle_ms = 10000 -- no gesture event for this long while fingers are down: the glue cancels (a lost finish event must never leave the list up)

function W.new(step_px)
  return setmetatable({ step_px = step_px, active = false, opened = false, accum = 0, last_at = 0 }, W)
end

function W:is_active() return self.active end

function W:start(now)
  self.active, self.opened, self.accum, self.last_at = true, false, 0, now
end

function W:stop() self.active = false end

function W:expired(now) return self.active and now - self.last_at >= W.idle_ms end

-- Whole rows in `accum`, rounded toward zero (a half row left or right is no row).
local function whole_rows(accum, step)
  if accum >= 0 then return math.floor(accum / step) end
  return -math.floor(-accum / step)
end

-- One update: dx is the horizontal travel since the last event (Hyprland sends per-event deltas, not totals).
-- Returns the signed number of rows crossed (0: none yet) and whether these are the swipe's first rows (the glue opens the list on them).
function W:update(now, dx)
  if not self.active then return 0, false end
  self.last_at = now
  dx = tonumber(dx)
  if not dx or dx ~= dx or math.abs(dx) == math.huge then return 0, false end -- not a finite number: ignored
  self.accum = self.accum + dx
  local rows = whole_rows(self.accum, self.step_px)
  if rows == 0 then return 0, false end
  self.accum = self.accum - rows * self.step_px
  local first = not self.opened
  self.opened = true
  return math.tointeger(rows), first
end

-- The fingers lifted: the swipe is over. Returns whether it got far enough to open the list.
function W:finish()
  local opened = self.active and self.opened
  self.active = false
  return opened
end

return W
