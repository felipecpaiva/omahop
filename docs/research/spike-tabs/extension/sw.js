// Throwaway spike. A snapshot of all tabs goes to the native host; the host can ask to activate a tab.
const HOST = "com.omahop.tabs";
let port = null;
let timer = null;

const toRow = (t) => ({ id: t.id, win: t.windowId, active: t.active, title: t.title, url: t.url, icon: t.favIconUrl });

const snapshot = async () => {
  const wins = await chrome.windows.getAll({ populate: true, windowTypes: ["normal", "popup"] });
  return wins
    .filter((w) => !w.incognito)
    .map((w) => ({ id: w.id, focused: w.focused, type: w.type, tabs: w.tabs.map(toRow) }));
};

const push = async () => {
  if (!port) return;
  port.postMessage({ type: "tabs", windows: await snapshot() });
};

// Events come in bursts (one page load fires several), so coalesce them into one snapshot.
const schedule = () => {
  clearTimeout(timer);
  timer = setTimeout(push, 150);
};

const onHostMessage = async (m) => {
  if (m.type !== "activate") return;
  const tab = await chrome.tabs.get(m.tab);
  await chrome.tabs.update(tab.id, { active: true });
  if (m.focusWindow) await chrome.windows.update(tab.windowId, { focused: true });
};

const connect = () => {
  port = chrome.runtime.connectNative(HOST);
  port.onMessage.addListener(onHostMessage);
  port.onDisconnect.addListener(() => {
    port = null;
    setTimeout(connect, 2000);
  });
  push();
};

for (const ev of ["onCreated", "onUpdated", "onRemoved", "onActivated", "onMoved", "onAttached", "onDetached"]) {
  chrome.tabs[ev].addListener(schedule);
}
chrome.windows.onFocusChanged.addListener(schedule);
chrome.windows.onRemoved.addListener(schedule);
connect();

// Spike only: headless takes one start URL, so seed a second tab and a second window on install.
chrome.runtime.onInstalled.addListener(async () => {
  await chrome.tabs.create({ url: "data:text/html,<title>spike two</title>", active: false });
  await chrome.windows.create({ url: "data:text/html,<title>spike three</title>" });
});
