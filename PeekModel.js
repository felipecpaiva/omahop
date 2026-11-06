.pragma library
// The peek strip's pure model: which windows it lists and how they group, and which screen edge it uses. No Qt, so Node tests it (tests/peek_model.test.mjs).

// A window is { address, appId, title, workspace, floating, minimized, monitor }. Windows group by app, in the order each app first appears; an app's windows keep their order.
// onlyFloating keeps windows on floating workspaces (and minimized ones, which sit on the dock's special workspace); monitor, when given, keeps that screen's windows.
// A minimized window has no real monitor (its origin is lost, as in the switcher), so it is listed on every screen.
function group(windows, opts) {
  var o = opts || {}
  var groups = [], byApp = {}
  for (var i = 0; i < windows.length; i++) {
    var w = windows[i]
    if (!w.appId) continue
    if (o.onlyFloating && !w.floating && !w.minimized) continue
    if (o.monitor && !w.minimized && w.monitor !== o.monitor) continue
    var g = byApp[w.appId]
    if (!g) {
      g = { appId: w.appId, windows: [] }
      byApp[w.appId] = g
      groups.push(g)
    }
    g.windows.push(w)
  }
  return groups
}

// The setting is auto or an edge. Auto is a FREE edge: not the stock dock's and not the bar's (two auto-hiding things on one edge would both react to the pointer,
// and a strip over the bar would cover its widgets), preferring right, then left, top, bottom. Unknown positions count as Omarchy's defaults (dock bottom, bar top).
function resolvePosition(setting, dockPosition, barPosition) {
  if (setting === "bottom" || setting === "top" || setting === "left" || setting === "right") return setting
  var dock = dockPosition || "bottom", bar = barPosition || "top"
  var order = ["right", "left", "top", "bottom"]
  for (var i = 0; i < order.length; i++) if (order[i] !== dock && order[i] !== bar) return order[i]
  return "right"
}

// "left" and "right" strips run vertically.
function isVertical(edge) { return edge === "left" || edge === "right" }

// Which group a pointer is over, by index along the strip: slot size and the strip's own padding. -1 when outside.
function slotAt(along, padding, slotSize, count) {
  var i = Math.floor((along - padding) / slotSize)
  return i >= 0 && i < count ? i : -1
}
