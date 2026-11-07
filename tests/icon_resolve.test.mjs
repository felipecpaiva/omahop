// Node check of IconResolve.js against synthetic cases and every desktop entry installed on this machine:  node tests/icon_resolve.test.mjs
import { readFileSync, readdirSync, existsSync } from "node:fs"
import { execFileSync } from "node:child_process"
import assert from "node:assert/strict"
const src = readFileSync(new URL("../IconResolve.js", import.meta.url), "utf8").replace(".pragma library", "")
const R = new Function(src + "; return { parseIndex, candidates, pick, resolve }")()

// synthetic
const idx = R.parseIndex("/i/google-chrome.png\n/i/Foo-Bar.svg\n/i/application-x-executable.svg\n/i/chrome.png\n")
assert.equal(R.resolve(idx, "google-chrome", ""), "/i/google-chrome.png")
assert.equal(R.resolve(idx, "Google-chrome", ""), "/i/google-chrome.png", "class in another case")
assert.equal(R.resolve(idx, "x", "foo-bar"), "/i/Foo-Bar.svg", "icon name in another case")
assert.equal(R.resolve(idx, "x", "/opt/app/icon.png"), "/opt/app/icon.png", "absolute path kept")
assert.equal(R.resolve(idx, "x", "file:///opt/a.svg"), "/opt/a.svg", "file URL")
assert.equal(R.resolve(idx, "com.google.Chrome", ""), "/i/chrome.png", "reverse-DNS id falls back to its last part")
assert.equal(R.resolve(idx, "Foo Bar", ""), "/i/Foo-Bar.svg", "spaces in a class")
assert.equal(R.resolve(idx, "totally-unknown", ""), "/i/application-x-executable.svg", "generic fallback")
assert.equal(R.resolve(R.parseIndex(""), "x", ""), "", "empty index gives empty, never throws")

// this machine
const index = R.parseIndex(execFileSync("bash", [new URL("../tools/icon-index.sh", import.meta.url).pathname], { maxBuffer: 1 << 28 }).toString())
const dirs = (process.env.XDG_DATA_DIRS || "/usr/local/share:/usr/share").split(":").concat([process.env.HOME + "/.local/share"]).map((d) => d + "/applications")
let total = 0
const generic = []
for (const dir of dirs) {
  if (!existsSync(dir)) continue
  for (const f of readdirSync(dir).filter((n) => n.endsWith(".desktop"))) {
    const t = readFileSync(dir + "/" + f, "utf8").split("[Desktop Action")[0]
    const icon = (t.match(/^Icon=(.*)$/m) || [])[1]
    const wm = (t.match(/^StartupWMClass=(.*)$/m) || [])[1]
    for (const id of [f.replace(/\.desktop$/, ""), wm].filter(Boolean)) {
      const path = R.resolve(index, id, icon || "")
      total++
      assert.ok(path !== "" && existsSync(path), `${f} (${id}): resolved "${path}" must exist`)
      if (icon && path === index.exact["application-x-executable"]) generic.push(`${f} Icon=${icon}`)
    }
  }
}
console.log(`ok   ${total} desktop entry ids resolved to an existing file`)
if (generic.length) console.log(`note ${generic.length} declared icons are in no icon folder (generic shown):\n  ` + [...new Set(generic)].join("\n  "))
console.log("icon resolve checks passed")
