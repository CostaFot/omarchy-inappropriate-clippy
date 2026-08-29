import QtQuick
import Quickshell
import Quickshell.Io

// Lines from the user's default coding agent instead of the book.
//
// `scripts/clippy-ai` does the work: gathers what the user is up to, asks
// the agent picked by `omarchy default agent` in its one-shot, tool-less
// mode, prints a JSON array of lines. This side runs it in the background,
// keeps the answers in a small cache and hands them out one at a time, so a
// click never waits on a model (a call is 5-20 s). The cache lives in
// PersistentProperties: the shell remounts us on every shell.json write and
// that must not cost a call.
//
// Lines go stale (they react to the window that was focused when they were
// made), so they expire after `maxAgeMs`, and the cache refills when it runs
// low. Failures back off, doubling up to half an hour, and never surface:
// `take()` returns null and the caller falls back to the book.
Item {
  id: brain

  property string script: ""
  property bool enabled: false
  // No calls while he's asleep (screen locked/off); the next take() refills.
  property bool paused: false
  property bool clean: false
  // Override for the agent; "" means whatever `omarchy default agent` says.
  property string agentOverride: ""
  // Model for that agent; "" means the agent's own default.
  property string model: ""
  // The user's own quotes file, for the examples in the prompt.
  property string quotesFile: ""
  property string promptFile: ""
  property int batch: 5
  property int lowWater: 1
  property int maxAgeMs: 20 * 60 * 1000
  property int minGapMs: 60 * 1000
  // Things the user did to him lately, for the prompt. Newest last.
  property var recent: []

  // A batch of new lines just landed in the cache. The root pre-renders
  // them into the voice-clone cache so speaking one later is instant.
  signal linesArrived(var lines)

  readonly property bool busy: proc.running
  readonly property string agent: agentOverride !== "" ? agentOverride : detected.agent
  readonly property int cached: store.lines.length

  // For `omarchy-shell costafot.clippy ai`.
  function status() {
    var s = (agent || "no agent") + ": " + cached + " cached"
    if (cached) s += " (" + Math.round((Date.now() - store.madeAt) / 1000) + "s old)"
    if (store.lastRun) s += ", last call " + Math.round((Date.now() - store.lastRun) / 1000) + "s ago"
    if (store.failures) s += ", " + store.failures + " failed"
    if (busy) s += ", busy"
    return s
  }

  PersistentProperties {
    id: store
    reloadableId: "costafotClippyBrain"
    property var lines: []
    property real madeAt: 0
    property real lastRun: 0
    property int failures: 0
  }

  // The name from ~/.config/omarchy/defaults/agent, for the menu label.
  Item {
    id: detected
    property string agent: ""
    Process {
      id: whichAgent
      command: ["omarchy-default-agent"]
      stdout: StdioCollector { onStreamFinished: detected.agent = String(text).trim() }
    }
  }
  Component.onCompleted: whichAgent.running = true
  onEnabledChanged: if (enabled) { whichAgent.running = true; Qt.callLater(brain.topUp) }

  function remember(what) {
    var list = recent.slice()
    list.push(what)
    if (list.length > 5) list = list.slice(list.length - 5)
    recent = list
  }

  // A fresh line, or null (nothing cached, or the cache is stale). Either
  // way it kicks off a refill when the cache is low.
  function take() {
    if (!enabled) return null
    var lines = fresh()
    var line = null
    if (lines.length) {
      var i = Math.floor(Math.random() * lines.length)
      line = lines[i]
      lines.splice(i, 1)
    }
    store.lines = lines
    console.log("clippy: " + (line ? "took an agent line" : "no agent line") + ", " + lines.length + " left")
    if (lines.length <= lowWater) topUp()
    return line
  }

  function fresh() {
    if (Date.now() - store.madeAt > maxAgeMs) return []
    return Array.isArray(store.lines) ? store.lines.slice() : []
  }

  function topUp() {
    if (!enabled || paused || proc.running || script === "") return
    var gap = minGapMs * Math.pow(2, Math.min(5, store.failures))
    if (Date.now() - store.lastRun < gap) {
      retry.interval = Math.max(1000, gap - (Date.now() - store.lastRun))
      retry.restart()
      return
    }
    store.lastRun = Date.now()
    var cmd = [script, "--count", String(batch)]
    if (clean) cmd.push("--clean")
    if (agentOverride !== "") cmd.push("--agent", agentOverride)
    if (model !== "") cmd.push("--model", model)
    if (quotesFile !== "") cmd.push("--quotes", quotesFile)
    if (promptFile !== "") cmd.push("--prompt-file", promptFile)
    if (recent.length) cmd.push("--recent", recent.join("; "))
    proc.command = cmd
    proc.running = true
  }

  Timer { id: retry; repeat: false; onTriggered: brain.topUp() }

  Process {
    id: proc
    stdout: StdioCollector { id: out }
    stderr: StdioCollector { id: err }
    onExited: function (code) {
      var lines = []
      try {
        var parsed = JSON.parse(String(out.text))
        if (Array.isArray(parsed))
          lines = parsed.filter(function (l) { return typeof l === "string" && l.trim() !== "" })
      } catch (e) {}
      if (code !== 0 || !lines.length) {
        store.failures = Math.min(6, store.failures + 1)
        console.warn("clippy: agent lines failed (exit " + code + "): " + String(err.text).trim())
        return
      }
      store.failures = 0
      if (lines.length < brain.batch)
        console.warn("clippy: asked " + brain.agent + " for " + brain.batch + " lines, got " + lines.length + ": " + String(out.text).trim())
      var keep = brain.fresh()
      store.lines = keep.concat(lines)
      store.madeAt = Date.now()
      brain.recent = []
      console.log("clippy: " + lines.length + " lines from " + brain.agent + ", " + store.lines.length + " cached")
      brain.linesArrived(lines)
    }
  }
}
