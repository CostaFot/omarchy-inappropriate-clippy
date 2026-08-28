import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// Inappropriate Clippy: a keepLoaded panel plugin that draws a click-through
// overlay across the bar. Clippy paces it, and a timer makes him talk.
//
// Host contract (shell.qml): root is a plain Item; `shell` / `manifest` /
// `omarchyPath` are injected; `opened` + open()/close() drive
// `omarchy-shell shell summon|hide|toggle costafot.clippy`.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property bool opened: true

  readonly property string pluginId: "costafot.clippy"
  readonly property string pluginDir: {
    var dir = Qt.resolvedUrl(".").toString()
    return dir.replace(/^file:\/\//, "").replace(/\/$/, "")
  }

  function open(payloadJson) { opened = true }
  function close() { opened = false }

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function rand(lo, hi) { return lo + Math.random() * (hi - lo) }
  function randomFrom(list) {
    return list && list.length ? list[Math.floor(Math.random() * list.length)] : null
  }

  // ---- settings: inline keys on our entry in shell.json -------------------
  // Because we are also a bar widget, the shell files our entry in the bar
  // layout (`bar.layout.<section>[]`), the way it does omarchy.menu.
  // Installs from before the icon have it under `plugins[]`. Both are read;
  // shell.updateEntryInline writes back to whichever one it finds.
  function findEntry(cfg) {
    if (!cfg) return null
    var layout = cfg.bar && cfg.bar.layout ? cfg.bar.layout : null
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var arr = layout ? layout[sections[s]] : null
      if (!Array.isArray(arr)) continue
      for (var i = 0; i < arr.length; i++)
        if (arr[i] && arr[i].id === pluginId) return { where: "bar", entry: arr[i] }
    }
    var list = Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var j = 0; j < list.length; j++)
      if (list[j] && list[j].id === pluginId) return { where: "plugins", entry: list[j] }
    return null
  }
  readonly property var entryLocation: findEntry(shell ? shell.shellConfig : null)
  readonly property var settings: entryLocation ? entryLocation.entry : ({})

  // An entry under `plugins[]` is one the bar never looks at, so the icon
  // would not show up. Move it, keys and all, into the bar layout: the
  // place a fresh `omarchy plugin add --enable` puts it. `omarchy bar put`
  // can't do this itself; it sees an enabled plugin and leaves it alone.
  // The shell remounts us after the write; persisted state carries over.
  // Deferred: the write lands back on shellConfig, which this binding reads.
  readonly property bool strayEntry: entryLocation !== null && entryLocation.where === "plugins"
  onStrayEntryChanged: if (strayEntry) Qt.callLater(adoptIntoBar)
  function adoptIntoBar() {
    if (!shell || typeof shell.mutateShellConfig !== "function") return
    // No layout at all means the bar is running its defaults; a layout
    // holding only us would replace them. Leave that config alone. Checked
    // before mutating: a no-op write would still remount us, and loop.
    var cur = shell.shellConfig
    if (!cur || !cur.bar || typeof cur.bar !== "object" || !cur.bar.layout || typeof cur.bar.layout !== "object") {
      console.warn("clippy: shell.json has no bar.layout, leaving our entry under plugins[]; the bar icon needs it in the layout")
      return
    }
    console.log("clippy: moving our shell.json entry from plugins[] into the bar layout so the icon shows up")
    shell.mutateShellConfig(function (cfg) {
      if (!Array.isArray(cfg.plugins)) return
      var entry = null
      for (var i = cfg.plugins.length - 1; i >= 0; i--) {
        if (cfg.plugins[i] && cfg.plugins[i].id === pluginId) {
          entry = cfg.plugins.splice(i, 1)[0]
        }
      }
      if (!entry) return
      if (!cfg.bar || typeof cfg.bar !== "object") cfg.bar = {}
      if (!cfg.bar.layout || typeof cfg.bar.layout !== "object") cfg.bar.layout = {}
      if (!Array.isArray(cfg.bar.layout.right)) cfg.bar.layout.right = []
      // Next to the tray, where the shell itself drops new right-section widgets.
      var right = cfg.bar.layout.right
      var at = right.length
      for (var j = 0; j < right.length; j++)
        if (right[j] && right[j].id === "omarchy.tray") { at = j + 1; break }
      right.splice(at, 0, entry)
    })
  }
  function setting(key, fallback) {
    var v = settings[key]
    return v === undefined || v === null ? fallback : v
  }
  // Every key a user (or their agent, over IPC `set`/`get`) may touch, with
  // its default. The README table and this list say the same thing.
  // `flingSound` is null here because its default is whatever `slapSound` is.
  readonly property var settingDefaults: ({
    size: 30, clean: false, intervalMin: 90, intervalMax: 420, speed: 40, restless: 0.3,
    respawn: 300, screen: "", quotesFile: "",
    slap: true, slapSwipe: true, slapSound: true, flingSound: null, slapsToKill: 10,
    drag: true, fling: true, ai: false, aiAgent: "", aiModel: "",
    pauseWhenAway: true, avoidWidgets: true, tombstone: true
  })
  function defaultFor(key) { return key === "flingSound" ? slapSoundSetting : settingDefaults[key] }
  function isSettingKey(key) { return Object.prototype.hasOwnProperty.call(settingDefaults, key) }
  // IPC hands us strings. true/false and numbers become themselves, "unset"
  // (or "default", or nothing) removes the key, anything else stays a string.
  function parseSettingValue(s) {
    s = String(s === undefined || s === null ? "" : s).trim()
    if (s === "" || s === "unset" || s === "default") return undefined
    if (s === "true") return true
    if (s === "false") return false
    if (!isNaN(Number(s))) return Number(s)
    return s
  }
  readonly property real spriteSize: clamp(Number(setting("size", 30)) || 30, 20, 200)
  readonly property int intervalMin: Math.max(5, Number(setting("intervalMin", 90)) || 90)
  readonly property int intervalMax: Math.max(intervalMin, Number(setting("intervalMax", 420)) || 420)
  readonly property real speed: clamp(Number(setting("speed", 40)) || 40, 5, 500)
  // 0..1: how often an idle beat turns into a walk. Idle beats are 10-30 s apart.
  readonly property real restless: clamp(Number(setting("restless", 0.3)), 0, 1)
  // He tries not to park on top of bar widgets when picking a walk target.
  // Soft: drags, shoves and flings still land him anywhere.
  readonly property bool avoidWidgets: setting("avoidWidgets", true) !== false
  // A headstone at the death spot until the respawn. It is never part of
  // the window's input mask, so it cannot block a click on the bar.
  readonly property bool tombstoneEnabled: setting("tombstone", true) !== false

  // Writes one inline key on our shell.json entry (undefined removes it).
  // The shell rewrites shell.json and remounts us; persisted state carries over.
  function setSetting(key, value) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    var entry = { id: pluginId }
    for (var k in settings) if (k !== "id" && k !== key) entry[k] = settings[k]
    if (value !== undefined && value !== null) entry[key] = value
    shell.updateEntryInline(pluginId, entry)
    return true
  }
  readonly property bool clean: setting("clean", false) === true
  readonly property int respawnSeconds: Math.max(0, Number(setting("respawn", 300)))
  readonly property string screenName: String(setting("screen", "") || "")
  function expandHome(p) {
    p = String(p || "")
    return p.indexOf("~") === 0 ? Quickshell.env("HOME") + p.slice(1) : p
  }
  readonly property string quotesFile: expandHome(setting("quotesFile", ""))
  // Slapping: middle-click, or flinging the pointer across him. `slap: false`
  // turns both off and gives middle-click back to snooze.
  readonly property bool slapEnabled: setting("slap", true) !== false
  // Dragging: hold left on him, then move. `drag: false` turns it off.
  readonly property bool dragEnabled: setting("drag", true) !== false
  // Letting go of him mid-fling throws him off the bar, fatally.
  readonly property bool flingEnabled: setting("fling", true) !== false
  // `ai: true` has his unprompted and clicked lines come from the user's
  // default coding agent (scripts/clippy-ai), reacting to what's on screen,
  // battery, the hour. The book stays the fallback. `aiAgent` overrides
  // which agent, else whatever `omarchy default agent` says.
  readonly property bool aiEnabled: setting("ai", false) === true
  readonly property string aiAgent: String(setting("aiAgent", "") || "")
  readonly property string aiModel: String(setting("aiModel", "") || "")
  readonly property string aiAgentName: agentBrain.agent
  readonly property real flingSpeed: 1.8 // px/ms at release
  readonly property bool slapSwipe: setting("slapSwipe", true) !== false
  readonly property int slapsToKill: Math.max(0, Number(setting("slapsToKill", 10)))
  // `slapSound` / `flingSound`: true for the built-in ones, false for
  // silence, or a path to a WAV of your own. `flingSound` follows
  // `slapSound` unless set, so the menu's one toggle mutes both.
  readonly property var slapSoundSetting: setting("slapSound", true)
  readonly property bool slapSoundOn: slapSoundSetting !== false
  readonly property var flingSoundSetting: setting("flingSound", slapSoundOn)
  function soundList(value, builtins) {
    if (value === false) return []
    if (typeof value === "string" && value !== "") return ["file://" + expandHome(value)]
    var dir = "file://" + pluginDir + "/assets/sounds/"
    return builtins.map(function (f) { return dir + f })
  }
  readonly property var slapSounds: soundList(slapSoundSetting, ["slap-crack.wav", "slap-punch.wav", "slap-ahh.wav"])
  readonly property var flingSounds: soundList(flingSoundSetting, ["fall-cartoon.wav", "fall-mario.wav"])

  // ---- bar geometry (same idiom as plugins/notifications/Service.qml) -----
  readonly property string barPosition: shell && shell.barConfig ? String(shell.barConfig.position || "top") : "top"
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property bool barBottom: barPosition === "bottom"
  readonly property bool barHidden: shell && shell.bar ? shell.bar.barHidden === true : false
  readonly property int defaultBarSize: barVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property int barSize: shell && shell.bar ? Math.max(0, shell.bar.barSize) : defaultBarSize
  readonly property int bubbleReserve: 150
  readonly property bool shown: opened && !barVertical && !barHidden && !asleep

  // Asleep while nobody can see him: the session is locked, the shell's idle
  // cycle is on (screensaver up, lock on its way; our layer is Overlay, so
  // he'd otherwise pace across the screensaver), or every screen is off. No
  // walking, no lines, no agent calls. Lock and idle are the shell's own
  // services (`plugins/lock`, `plugins/services/idle`), live properties via
  // `serviceFor`, which re-evaluates as services register. DPMS has no
  // Hyprland event, so `dpmsPoll` asks the monitor list over the socket.
  // `pauseWhenAway: false` keeps him going regardless.
  readonly property bool pauseWhenAway: setting("pauseWhenAway", true) !== false
  readonly property var lockService: shell && typeof shell.serviceFor === "function" ? shell.serviceFor("omarchy.lock") : null
  readonly property var idleService: shell && typeof shell.serviceFor === "function" ? shell.serviceFor("omarchy.idle") : null
  readonly property bool sessionLocked: !!(lockService && lockService.locked === true)
  readonly property bool userIdle: !!(idleService && idleService.idledThisCycle === true)
  readonly property bool screensOff: {
    var list = Hyprland.monitors ? Hyprland.monitors.values : []
    var known = 0, lit = 0
    for (var i = 0; i < list.length; i++) {
      var o = list[i] ? list[i].lastIpcObject : null
      if (!o || o.disabled === true) continue
      known++
      if (o.dpmsStatus !== false) lit++
    }
    return known > 0 && lit === 0
  }
  readonly property bool asleep: pauseWhenAway && (sessionLocked || userIdle || screensOff)
  // Computed on demand, not bound: in onAsleepChanged the sibling bindings
  // may not have caught up yet.
  function awayReason() { return sessionLocked ? "session locked" : userIdle ? "you're idle" : screensOff ? "screens off" : "" }
  // Quicker while the screens are off so he's back soon after they light up.
  Timer {
    id: dpmsPoll
    interval: root.screensOff ? 2000 : 10000
    repeat: true
    running: root.pauseWhenAway
    onTriggered: Hyprland.refreshMonitors()
  }
  // Unlock turns the screens back on; don't wait a poll to notice.
  onSessionLockedChanged: if (!sessionLocked) Hyprland.refreshMonitors()
  onUserIdleChanged: if (!userIdle) Hyprland.refreshMonitors()
  onAsleepChanged: asleep ? fallAsleep() : wakeUp()

  // A `welcomeBack` line when he wakes, if you were gone long enough to
  // count (a screen blank you cancelled with the mouse isn't a trip).
  // `{away}` in a line becomes "47 minutes" / "3 hours" / "2 days".
  property real asleepSince: 0
  property real awayMs: 0
  readonly property int welcomeAfterMs: 60 * 1000
  Timer { id: welcomeTimer; interval: 1500; repeat: false; onTriggered: root.welcome() }
  function awayText(ms) {
    var m = Math.max(1, Math.round(ms / 60000))
    if (m < 60) return m + (m === 1 ? " minute" : " minutes")
    var h = Math.round(m / 60)
    if (h < 48) return h + (h === 1 ? " hour" : " hours")
    var d = Math.round(h / 24)
    return d + " days"
  }
  function welcome() {
    if (asleep || mood !== "idle" || dragging || isSnoozed()) return
    var q = randomQuoteFrom("welcomeBack")
    var text = (q ? q.text : "Welcome back. I counted.").replace(/\{away\}/g, awayText(awayMs))
    say(text, q && q.anim ? q.anim : "Wave")
  }

  function fallAsleep() {
    console.log("clippy: asleep, " + awayReason())
    asleepSince = Date.now()
    walkAnim.stop()
    shoveAnim.stop()
    brain.stop()
    quoteTimer.stop()
    bubbleTimer.stop()
    dragTalk.stop()
    // Dying, dead and reviving run their course (short, and the window is
    // hidden anyway); a respawn that lands meanwhile waits for wakeUp().
    if (mood === "walking" || mood === "talking" || mood === "idle") {
      persisted.lastX = actor.x
      bubble.shown = false
      sprite.stop()
      mood = "idle"
    }
  }

  function wakeUp() {
    var away = asleepSince > 0 ? Date.now() - asleepSince : 0
    asleepSince = 0
    if (!booted) return  // maybeBoot() takes it from here
    console.log("clippy: awake after " + Math.round(away / 1000) + "s")
    var longEnough = away >= welcomeAfterMs
    if (longEnough) agentBrain.remember("came back after " + awayText(away) + " away")
    if (mood === "dead") {
      if (persisted.deadUntil > 0 && persisted.deadUntil <= Date.now()) revive()
      return
    }
    if (mood === "idle" && !dragging) {
      idleAnim()
      if (longEnough) { awayMs = away; welcomeTimer.restart() }
    }
    scheduleQuote()
  }

  onBarVerticalChanged: if (barVertical) console.warn("clippy: vertical bars are not supported, hiding")

  // One Clippy, on the output Hyprland has focused (like navbar-cat does), so
  // he follows you between screens instead of multiplying. `screen: "<name>"`
  // pins him.
  readonly property string wantedScreenName: {
    if (screenName !== "" && screenName !== "focused") return screenName
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }
  readonly property var targetScreen: {
    var screens = Quickshell.screens
    if (!screens || !screens.length) return null
    for (var i = 0; i < screens.length; i++)
      if (String(screens[i].name) === wantedScreenName) return screens[i]
    return screens[0]
  }

  // ---- quotes ------------------------------------------------------------
  // Two books, merged per key at draw time so load order doesn't matter
  // (the two FileViews fire in whichever order the disk answers).
  readonly property var quoteKeys: ["quotes", "comeback", "lastWords", "slapped", "knockedOut", "dragged", "dropped", "flung", "welcomeBack", "epitaph"]
  property var book: emptyBook()
  property var extraBook: emptyBook()
  function emptyBook() {
    var b = {}
    for (var i = 0; i < quoteKeys.length; i++) b[quoteKeys[i]] = []
    return b
  }

  function normalizeQuotes(list) {
    if (!Array.isArray(list)) return []
    var out = []
    for (var i = 0; i < list.length; i++) {
      var q = list[i]
      if (typeof q === "string") out.push({ text: q, nsfw: false })
      else if (q && typeof q.text === "string") out.push({ text: q.text, nsfw: q.nsfw === true, anim: q.anim })
    }
    return out
  }
  function loadQuoteBook(json, extra) {
    var data
    try { data = JSON.parse(json) } catch (e) { console.warn("clippy: bad quotes JSON: " + e); return }
    var raw = Array.isArray(data) ? { quotes: data } : (data || {})
    var b = {}
    for (var i = 0; i < quoteKeys.length; i++) b[quoteKeys[i]] = normalizeQuotes(raw[quoteKeys[i]])
    if (extra) extraBook = b
    else book = b
  }
  function pool(key) {
    var all = book[key].concat(extraBook[key])
    if (!clean) return all
    return all.filter(function (q) { return !q.nsfw })
  }
  function randomQuote() { return randomFrom(pool("quotes")) }
  function randomLine(key, fallback) {
    var q = randomFrom(pool(key))
    return q ? q.text : fallback
  }
  function randomQuoteFrom(key) { return randomFrom(pool(key)) }
  // What he says when nothing in particular happened: an agent line if one
  // is cached, else one from the book.
  function nextQuote() {
    var line = agentBrain.take()
    if (line) return { text: line, ai: true }
    return randomQuote()
  }

  AgentBrain {
    id: agentBrain
    script: root.pluginDir + "/scripts/clippy-ai"
    enabled: root.aiEnabled
    paused: root.asleep
    clean: root.clean
    agentOverride: root.aiAgent
    model: root.aiModel
    quotesFile: root.quotesFile
  }

  FileView {
    path: root.pluginDir + "/quotes.json"
    onLoaded: root.loadQuoteBook(text(), false)
  }
  FileView {
    path: root.quotesFile
    printErrors: false
    onLoaded: root.loadQuoteBook(text(), true)
  }

  // ---- state -------------------------------------------------------------
  // idle | walking | talking | dying | dead | reviving
  property string mood: "idle"
  property bool booted: false

  readonly property var idleAnims: ["Idle1_1", "IdleEyeBrowRaise", "IdleFingerTap", "IdleHeadScratch",
    "IdleRopePile", "IdleAtom", "IdleSnooze", "LookLeft", "LookRight", "LookUp", "LookDown",
    "LookUpLeft", "LookUpRight", "LookDownLeft", "LookDownRight"]
  readonly property var talkAnims: ["Explain", "GetAttention", "Alert", "Wave", "Thinking", "Writing",
    "Searching", "Congratulate", "GetArtsy", "GetWizardy", "Print", "SendMail", "EmptyTrash",
    "CheckingSomething", "Hearing_1", "Processing"]

  // Survives the panel remount the shell does on every shell.json write.
  // deadUntil: 0 alive, -1 dead until respawn IPC, >0 epoch ms.
  PersistentProperties {
    id: persisted
    reloadableId: "costafotClippy"
    property real deadUntil: 0
    property real snoozedUntil: 0
    property real lastX: -1
    property real graveX: -1
    property int slapCount: 0
    property int killCount: 0
  }

  function isSnoozed() { return persisted.snoozedUntil > Date.now() }
  // The running tally: the menu's footer and IPC `stats` read these.
  readonly property int slapCount: persisted.slapCount
  readonly property int killCount: persisted.killCount
  readonly property bool talking: bubble.shown
  readonly property int actorHeight: actor.height

  function maybeBoot() {
    if (booted || stage.width <= 0) return
    booted = true
    if (persisted.deadUntil === -1 || persisted.deadUntil > Date.now()) {
      mood = "dead"
      armRespawn()
      return
    }
    persisted.deadUntil = 0
    var maxX = Math.max(0, stage.width - actor.width)
    actor.x = persisted.lastX >= 0 ? clamp(persisted.lastX, 0, maxX) : Math.round(randomSpot(maxX))
    mood = "idle"
    if (asleep) return  // wakeUp() starts him
    idleAnim()
    scheduleQuote()
  }

  // Brain: idle animation -> maybe walk -> idle ... ; quotes on their own timer.
  Timer { id: brain; repeat: false; onTriggered: root.decide() }
  Timer { id: quoteTimer; repeat: false; onTriggered: root.unprompted() }
  Timer { id: bubbleTimer; repeat: false; onTriggered: root.hideBubble() }
  Timer { id: respawnTimer; repeat: false; onTriggered: if (!root.asleep) root.revive() }
  Timer {
    id: dieTimer
    repeat: false
    onTriggered: {
      bubble.shown = false
      sprite.play("GoodBye", false, root.finishDeath)
    }
  }

  function schedule(ms) { brain.interval = Math.round(ms); brain.restart() }
  function scheduleQuote() {
    quoteTimer.interval = Math.round(rand(intervalMin, intervalMax) * 1000)
    quoteTimer.restart()
  }

  function decide() {
    if (mood !== "idle" || dragging || asleep) return
    // Parked on a widget (drag-drop, or one appeared under him): itchier
    // feet, but still the normal walk on the normal beat — no new timers.
    var urge = onWidget() ? Math.max(restless, 0.8) : restless
    if (Math.random() < urge) startWalk()
    else idleAnim()
  }

  function idleAnim() {
    mood = "idle"
    var name = randomFrom(idleAnims.filter(sprite.has))
    sprite.play(name || "RestPose", false, function () {
      if (root.mood === "idle") root.schedule(rand(10000, 30000))
    })
  }

  // ---- widget avoidance --------------------------------------------------
  // Occupied x-intervals [lo, hi] of visible bar widgets on his screen,
  // padded and merged. null = unknowable (setting off, no bar yet, a shell
  // without moduleSlots, vertical bar) — callers fall back to raw targets.
  // Read lazily at pick time, never from a binding: widget widths change
  // without signals (tray drawer, center peeks) and moduleSlots is
  // reassigned on every register/unregister.
  function occupiedIntervals() {
    if (!avoidWidgets || barVertical || !shell || !shell.bar) return null
    var slots = shell.bar.moduleSlots
    if (!slots || typeof shell.bar.slotScreenName !== "function") return null
    var mine = targetScreen ? String(targetScreen.name) : ""
    var pad = 6
    var boxes = []
    for (var i = 0; i < slots.length; i++) {
      var s = slots[i]
      // Same visibility test as the shell's debugBarGeometry(): collapsed
      // slots keep visible=true but drop to 0x0.
      if (!s || s.visible !== true || !(s.width > 0) || !(s.height > 0)) continue
      if (shell.bar.slotScreenName(s) !== mine) continue
      try { // slot windows can vanish mid bar-reload
        var p = s.mapToItem(null, 0, 0) // bar-window x == screen x == stage x
        boxes.push([p.x - pad, p.x + s.width + pad])
      } catch (e) {}
    }
    boxes.sort(function (a, b) { return a[0] - b[0] })
    var merged = []
    for (var j = 0; j < boxes.length; j++) {
      var last = merged.length ? merged[merged.length - 1] : null
      if (last && boxes[j][0] <= last[1]) last[1] = Math.max(last[1], boxes[j][1])
      else merged.push(boxes[j])
    }
    return merged
  }

  // Position intervals [lo, hi] where a thing of width `w` (the actor,
  // unless told otherwise — the tombstone is narrower) overlaps no widget.
  // An empty bar layout is one gap spanning everything.
  function freeGaps(w) {
    var occ = occupiedIntervals()
    if (occ === null) return null
    w = w || actor.width
    var maxX = Math.max(0, stage.width - w)
    var gaps = [], lo = 0
    for (var i = 0; i <= occ.length; i++) {
      var hi = Math.min(i < occ.length ? occ[i][0] - w : maxX, maxX)
      if (hi >= lo) gaps.push([lo, hi])
      if (i < occ.length) lo = Math.max(lo, occ[i][1])
    }
    return gaps
  }

  // A random position inside the gaps, weighted by width (+1 so exact-fit
  // gaps still count).
  function pickInGaps(gaps) {
    var total = 0
    for (var i = 0; i < gaps.length; i++) total += gaps[i][1] - gaps[i][0] + 1
    var r = Math.random() * total
    for (var j = 0; j < gaps.length; j++) {
      var len = gaps[j][1] - gaps[j][0] + 1
      if (r < len) return gaps[j][0] + r
      r -= len
    }
    return gaps[gaps.length - 1][1]
  }

  // A clear target stands; a dirty one snaps to the nearest clear position,
  // so a hop aimed at a widget cluster stops just short of it. The snap only
  // ever shortens the walk (the near edge is on his way there), so hops stay
  // hops. No gaps to snap to (crowded bar) and the target stands dirty.
  function nudge(target, gaps) {
    if (!gaps || !gaps.length) return target
    var best = target, dist = Infinity
    for (var i = 0; i < gaps.length; i++) {
      var p = clamp(target, gaps[i][0], gaps[i][1])
      if (Math.abs(p - target) < dist) { dist = Math.abs(p - target); best = p }
    }
    return best
  }

  // Fresh placement (boot without lastX, out-of-bounds revive) prefers a gap.
  function randomSpot(maxX) {
    var gaps = freeGaps()
    return gaps && gaps.length ? pickInGaps(gaps) : rand(0, maxX)
  }

  // Standing on a widget right now (drag-drop, or a tray drawer grew under
  // him)?
  function onWidget() {
    var occ = occupiedIntervals()
    if (!occ) return false
    for (var i = 0; i < occ.length; i++)
      if (actor.x < occ[i][1] && actor.x + actor.width > occ[i][0]) return true
    return false
  }

  function startWalk() {
    var maxX = Math.max(0, stage.width - actor.width)
    // Mostly short hops around where he is; one in five is a trek anywhere.
    // Both prefer the gaps between bar widgets, softly (widget avoidance).
    var gaps = freeGaps()
    var target
    if (Math.random() < 0.2) target = gaps && gaps.length ? pickInGaps(gaps) : rand(0, maxX)
    else target = nudge(actor.x + (Math.random() < 0.5 ? -1 : 1) * rand(80, 400), gaps)
    target = Math.round(clamp(target, 0, maxX))
    if (Math.abs(target - actor.x) < 60) { idleAnim(); return }
    mood = "walking"
    // Gesture names are the character's left/right: GestureLeft points screen-right.
    var cue = target > actor.x ? "GestureLeft" : "GestureRight"
    sprite.play(cue, false, function () {
      if (root.mood !== "walking") return
      sprite.play("IdleSideToSide", true)
      walkAnim.to = target
      walkAnim.duration = Math.round(Math.abs(target - actor.x) / root.speed * 1000)
      walkAnim.start()
    })
  }

  NumberAnimation {
    id: walkAnim
    target: actor
    property: "x"
    easing.type: Easing.InOutSine
    onFinished: root.arrive()
  }

  function arrive() {
    if (mood !== "walking") return
    persisted.lastX = actor.x
    sprite.exit()
    mood = "idle"
    schedule(rand(400, 1500))
  }

  // `ai` marks an agent line; the bubble dresses it up.
  function say(text, anim, ai) {
    text = String(text || "").trim()
    if (text === "") return false
    if (mood === "dead" || mood === "dying" || mood === "reviving" || asleep) return false
    walkAnim.stop()
    brain.stop()
    mood = "talking"
    bubble.ai = !!ai
    bubble.text = text
    bubble.shown = true
    var a = anim && sprite.has(anim) ? anim : randomFrom(talkAnims.filter(sprite.has))
    sprite.play(a || "Explain", false)
    var words = text.split(/\s+/).length
    bubbleTimer.interval = Math.max(4000, words * 450)
    bubbleTimer.restart()
    return true
  }

  function hideBubble() {
    bubbleTimer.stop()
    bubble.shown = false
    if (mood === "talking") {
      mood = "idle"
      if (!dragging) schedule(800)
    }
    if (!quoteTimer.running && mood !== "dead") scheduleQuote()
  }

  function unprompted() {
    if (asleep) return  // wakeUp() reschedules
    scheduleQuote()
    if (mood !== "idle" && mood !== "walking") return
    if (isSnoozed() || dragging) return
    var q = nextQuote()
    if (q) say(q.text, q.anim, q.ai)
  }

  function snooze(minutes) {
    var m = Math.max(1, Number(minutes) || 60)
    persisted.snoozedUntil = Date.now() + m * 60 * 1000
    say("Fine. " + m + " minutes. Then I'm back.")
  }

  function unsnooze() {
    persisted.snoozedUntil = 0
    scheduleQuote()
    say("Oh good, you missed me. Obviously.")
  }

  function kill(lineKey) {
    if (mood === "dead" || mood === "dying") return
    walkAnim.stop()
    shoveAnim.stop()
    brain.stop()
    quoteTimer.stop()
    bubbleTimer.stop()
    mood = "dying"
    agentBrain.remember(lineKey === "knockedOut" ? "knocked him out with slaps" : "killed him")
    var words = randomLine(lineKey || "lastWords", "Fine. Fuck off then.")
    bubble.ai = false
    bubble.text = words
    bubble.shown = true
    dieTimer.interval = 2500
    dieTimer.start()
  }

  function finishDeath() {
    mood = "dead"
    persisted.killCount++
    placeGrave()
    persisted.deadUntil = respawnSeconds > 0 ? Date.now() + respawnSeconds * 1000 : -1
    armRespawn()
  }

  // The tombstone marks where he died, snapped into a widget gap the same
  // way his walk targets are (it is narrower than him, so it fits in more
  // places). A fling carried him off-stage: its grave stands at the edge
  // he left by, which the clamp on his centre works out to.
  function placeGrave() {
    if (!tombstoneEnabled) { persisted.graveX = -1; return }
    var w = grave.width
    var maxX = Math.max(0, stage.width - w)
    var cx = clamp(actor.x + actor.width / 2, 0, stage.width)
    persisted.graveX = Math.round(nudge(clamp(cx - w / 2, 0, maxX), freeGaps(w)))
  }

  function armRespawn() {
    if (persisted.deadUntil > 0) {
      respawnTimer.interval = Math.max(100, persisted.deadUntil - Date.now())
      respawnTimer.start()
    }
  }

  function revive() {
    respawnTimer.stop()
    if (mood !== "dead") return
    persisted.deadUntil = 0
    if (actor.x < 0 || actor.x > stage.width - actor.width)
      actor.x = Math.round(randomSpot(Math.max(0, stage.width - actor.width)))
    actor.rotation = 0
    mood = "reviving"
    sprite.play("Greeting", false, function () {
      root.mood = "idle"
      root.say(root.randomLine("comeback", "I'm back. Don't act like you didn't miss me."))
    })
  }

  // Clicking the grave gets you the epitaph, spoken from beyond. Not
  // say() — that refuses while dead, rightly; this writes the bubble the
  // way the kill paths do, and the bubble anchors to the grave while he is
  // dead. `{back}` in a line becomes how long until the respawn.
  function epitaph() {
    if (!grave.shown || asleep) return false
    if (bubble.shown) { hideBubble(); return true }
    var q = randomQuoteFrom("epitaph")
    var text = (q ? q.text : "Here lies Clippy. You did this.").replace(/\{back\}/g, backText())
    bubble.ai = false
    bubble.text = text
    bubble.shown = true
    bubbleTimer.interval = Math.max(4000, text.split(/\s+/).length * 450)
    bubbleTimer.restart()
    return true
  }
  function backText() {
    if (persisted.deadUntil === -1) return "never"
    var ms = persisted.deadUntil - Date.now()
    if (ms <= 0) return "any second now"
    if (ms < 90000) return Math.max(1, Math.round(ms / 1000)) + " seconds"
    return awayText(ms)
  }

  // ---- slapping ----------------------------------------------------------
  // `dir` is the way he gets shoved: +1 screen-right, -1 screen-left. A
  // sound, a shove with a wobble, a line. Slaps close together add up;
  // `slapsToKill` of them inside `slapWindowMs` and he's out cold, through
  // the normal kill path with a `knockedOut` line, so the respawn timer and
  // the bar icon work as usual.
  property var slapTimes: []
  readonly property int slapWindowMs: 6000

  function slap(dir) {
    if (!slapEnabled || dragging) return false
    if (mood === "dead" || mood === "dying" || mood === "reviving") return false
    dir = Number(dir) < 0 ? -1 : 1
    var now = Date.now()
    var recent = slapTimes.filter(function (t) { return now - t < root.slapWindowMs })
    recent.push(now)
    slapTimes = recent

    persisted.slapCount++
    agentBrain.remember("slapped him")
    playSlapSound()
    walkAnim.stop()
    brain.stop()
    bubbleTimer.stop()
    bubble.shown = false
    if (mood === "walking") sprite.exit()

    var maxX = Math.max(0, stage.width - actor.width)
    var distance = rand(50, 120) * (spriteSize / 30)
    shoveAnim.stop()
    shoveAnim.to = Math.round(clamp(actor.x + dir * distance, 0, maxX))
    shoveAnim.start()
    wobble.stop()
    wobble.dir = dir
    wobble.start()

    if (slapsToKill > 0 && recent.length >= slapsToKill) {
      slapTimes = []
      kill("knockedOut")
      return true
    }
    var q = randomQuoteFrom("slapped")
    say(q ? q.text : "Ow.", q && q.anim ? q.anim : "Alert")
    return true
  }

  function playSlapSound() { playOneOf(slapFx) }
  function playFlingSound() { playOneOf(flingFx) }
  function playOneOf(fxs) {
    if (!fxs.count) return
    var fx = fxs.objectAt(Math.floor(Math.random() * fxs.count))
    if (fx && fx.status === SoundEffect.Ready) fx.play()
  }

  // One SoundEffect per file, decoded up front, so a slap lands without a
  // load stall. The built-ins, or the one from `slapSound` / `flingSound`.
  component SoundBank: Instantiator {
    delegate: SoundEffect {
      required property string modelData
      source: modelData
      onStatusChanged: if (status === SoundEffect.Error) console.warn("clippy: can't load sound " + source)
    }
  }
  SoundBank { id: slapFx; model: root.slapSounds }
  SoundBank { id: flingFx; model: root.flingSounds }

  NumberAnimation {
    id: shoveAnim
    target: actor
    property: "x"
    duration: 380
    easing.type: Easing.OutCubic
    onFinished: persisted.lastX = actor.x
  }

  // Head snaps the way he was hit, rebounds, settles. Pivot at his feet.
  SequentialAnimation {
    id: wobble
    property int dir: 1
    NumberAnimation { target: actor; property: "rotation"; to: wobble.dir * 16; duration: 70; easing.type: Easing.OutQuad }
    NumberAnimation { target: actor; property: "rotation"; to: -wobble.dir * 9; duration: 140; easing.type: Easing.InOutQuad }
    NumberAnimation { target: actor; property: "rotation"; to: wobble.dir * 4; duration: 120; easing.type: Easing.InOutQuad }
    NumberAnimation { target: actor; property: "rotation"; to: 0; duration: 160; easing.type: Easing.OutQuad }
  }

  // ---- dragging ----------------------------------------------------------
  // Hold left on him and he comes along with the pointer, leaning away from
  // the direction he's pulled and complaining the whole way. `grabX` is where
  // on him the pointer took hold, so he doesn't jump under the cursor.
  property bool dragging: false
  property real grabX: 0
  property real dragVel: 0     // px per event, for the lean
  property real dragSpeed: 0   // px/ms, smoothed pointer speed, for the fling
  property real dragLastPx: 0
  property real dragLastT: 0

  function grab(atX) {
    if (!dragEnabled || dragging) return false
    if (mood === "dead" || mood === "dying" || mood === "reviving") return false
    walkAnim.stop()
    shoveAnim.stop()
    wobble.stop()
    brain.stop()
    if (mood === "walking") sprite.exit()
    dragging = true
    agentBrain.remember("picked him up and dragged him along the bar")
    grabX = atX
    dragVel = 0
    dragSpeed = 0
    dragLastT = 0
    actor.rotation = 0
    complain("dragged", "Where are you taking me???", "Alert")
    dragTalk.interval = Math.round(rand(3000, 6000))
    dragTalk.restart()
    return true
  }

  // `atX` is the pointer's x on him (the MouseArea rides on the actor, so
  // the delta from `grabX` is how far the pointer got ahead of him).
  function dragTo(atX) {
    if (!dragging) return
    // Pointer speed from its stage position, so it still counts when he is
    // pinned against an edge and can't follow.
    var px = actor.x + atX
    var now = Date.now()
    if (dragLastT > 0) {
      var dt = Math.max(1, now - dragLastT)
      dragSpeed = dragSpeed * 0.5 + ((px - dragLastPx) / dt) * 0.5
    }
    dragLastPx = px
    dragLastT = now
    var dx = atX - grabX
    var maxX = Math.max(0, stage.width - actor.width)
    var next = clamp(actor.x + dx, 0, maxX)
    dragVel = next - actor.x
    actor.x = next
    // Lean back against the pull (smoothed, so it doesn't jitter with the
    // pointer); `dragSettle` brings him upright again when the pointer rests.
    actor.rotation = actor.rotation * 0.5 - clamp(dragVel * 2, -28, 28) * 0.5
    dragSettle.restart()
  }

  function drop() {
    if (!dragging) return
    dragging = false
    dragTalk.stop()
    dragSettle.stop()
    if (mood === "dead" || mood === "dying" || mood === "reviving") return
    // Still moving fast at release: that's a throw, and he doesn't survive it.
    if (flingEnabled && Math.abs(dragSpeed) >= flingSpeed && Date.now() - dragLastT < 100) {
      flingOff(dragSpeed < 0 ? -1 : 1)
      return
    }
    persisted.lastX = actor.x
    // Swing on with the momentum he had, then settle.
    wobble.stop()
    wobble.dir = dragVel < 0 ? -1 : 1
    wobble.start()
    complain("dropped", "Fine. I live here now.", "Alert")
  }

  // Off the end of the bar, spinning, yelling the whole way. The flight is
  // too quick to read a line in, so the bubble hangs at the edge he left
  // by for `flingHoldMs` after he's gone, then trails off over
  // `flingEchoMs`. Lands in the normal dead state, so respawn and the bar
  // icon work as usual.
  function flingOff(dir) {
    if (mood === "dead" || mood === "dying" || mood === "reviving") return false
    dir = Number(dir) < 0 ? -1 : 1
    dragging = false
    dragTalk.stop()
    dragSettle.stop()
    walkAnim.stop()
    shoveAnim.stop()
    wobble.stop()
    brain.stop()
    quoteTimer.stop()
    bubbleTimer.stop()
    mood = "dying"
    agentBrain.remember("threw him off the bar")
    playFlingSound()
    bubble.ai = false
    bubble.text = randomLine("flung", "Noooooooooooooooooooooooooooo")
    bubble.shown = true
    var to = dir > 0 ? stage.width + actor.width : -actor.width * 2
    flingAnim.stop()
    flingX.to = to
    flingSpin.to = dir * 540
    flingAnim.duration = Math.round(clamp(Math.abs(to - actor.x) / 1.4, 600, 1600))
    flingAnim.start()
    return true
  }

  readonly property int flingHoldMs: 1500
  readonly property int flingEchoMs: 1500
  Timer {
    id: flingHold
    interval: root.flingHoldMs
    onTriggered: {
      if (root.mood !== "dying") return
      bubble.fadeMs = root.flingEchoMs
      bubble.shown = false
      flingEcho.start()
    }
  }
  Timer {
    id: flingEcho
    interval: root.flingEchoMs
    onTriggered: {
      bubble.fadeMs = 140
      if (root.mood === "dying") root.finishDeath()
    }
  }

  ParallelAnimation {
    id: flingAnim
    property int duration: 400
    NumberAnimation { id: flingX; target: actor; property: "x"; duration: flingAnim.duration; easing.type: Easing.Linear }
    NumberAnimation { id: flingSpin; target: actor; property: "rotation"; duration: flingAnim.duration; easing.type: Easing.Linear }
    onFinished: if (root.mood === "dying") flingHold.start()
  }

  function complain(key, fallback, anim) {
    var q = randomQuoteFrom(key)
    say(q ? q.text : fallback, q && q.anim ? q.anim : anim)
  }

  // Another line every few seconds while he's still being carried.
  Timer {
    id: dragTalk
    repeat: true
    onTriggered: {
      if (!root.dragging) { stop(); return }
      root.complain("dragged", "Put me down.", "GetAttention")
      interval = Math.round(root.rand(3000, 6000))
    }
  }
  Timer {
    id: dragSettle
    interval: 30
    repeat: true
    onTriggered: {
      if (!root.dragging || Math.abs(actor.rotation) < 0.5) { actor.rotation = root.dragging ? 0 : actor.rotation; stop(); return }
      actor.rotation *= 0.7
    }
  }

  // Opens the menu with its card under screen x `atX`, on `onScreen` (null
  // means the monitor Clippy is on). The bar icon calls this from any bar.
  function showMenuAt(atX, onScreen) {
    menu.anchorScreen = onScreen || null
    menu.anchorPos = atX
    menu.open = true
  }
  function showMenu() { showMenuAt(actor.x + actor.width / 2, null) }

  // What the bar icon is for: undoes a kill, or a hide.
  function bringBack() {
    opened = true
    if (mood === "dead") revive()
  }

  // ---- IPC: omarchy-shell costafot.clippy <method> [arg] -------------------
  IpcHandler {
    target: "costafot.clippy"
    function ping(): string { return "ok" }
    function say(text: string): string { return !root.opened ? "hidden" : root.asleep ? "asleep" : (root.say(text) ? "ok" : "not now") }
    // A line of his own choosing: what a left-click does.
    function talk(): string { var q = root.nextQuote(); return q && root.say(q.text, q.anim, q.ai) ? "ok" : "not now" }
    function shutUp(): string { root.hideBubble(); return "ok" }
    // The grave's line, same as clicking the tombstone.
    function epitaph(): string {
      if (root.mood !== "dead") return "alive"
      if (!root.tombstoneEnabled) return "off"
      if (root.asleep) return "asleep"
      return root.epitaph() ? "ok" : "no grave"
    }
    function kill(): string { root.kill(); return "ok" }
    function respawn(): string {
      if (root.mood === "dying" || root.mood === "reviving") return root.mood
      if (root.mood !== "dead") return "alive"
      root.revive()
      return "ok"
    }
    function snooze(minutes: string): string { root.snooze(minutes); return "ok" }
    function unsnooze(): string {
      if (!root.isSnoozed()) return "not snoozed"
      root.unsnooze()
      return "ok"
    }
    // `slap left|right` is the way he flies; anything else picks one.
    function slap(direction: string): string {
      var d = String(direction || "").toLowerCase()
      var dir = d === "left" ? -1 : (d === "right" ? 1 : (Math.random() < 0.5 ? -1 : 1))
      return root.slap(dir) ? "ok" : (root.slapEnabled ? "not now" : "off")
    }
    // `fling left|right`: throws him off that end of the bar. Fatal.
    function fling(direction: string): string {
      var d = String(direction || "").toLowerCase()
      var dir = d === "left" ? -1 : (d === "right" ? 1 : (Math.random() < 0.5 ? -1 : 1))
      return root.flingOff(dir) ? "ok" : "not now"
    }
    function toggle(): string { root.opened = !root.opened; return root.opened ? "shown" : "hidden" }
    // Idempotent show/hide for scripts and agents. `show` also revives him if
    // he is dead: what the bar icon's "Bring him back" does.
    function show(): string {
      if (root.mood === "dying" || root.mood === "reviving") return root.mood
      if (root.opened && root.mood !== "dead") return "already"
      root.bringBack()
      return "ok"
    }
    function hide(): string {
      if (!root.opened) return "already"
      root.opened = false
      return "ok"
    }
    function hideMenu(): string { menu.open = false; return "ok" }
    function showMenu(): string { root.showMenu(); return "ok" }
    // What the agent side is doing: "off", or "<agent>: N cached[, busy]".
    function ai(): string { return root.aiEnabled ? agentBrain.status() : "off" }
    function state(): string {
      if (!root.opened) return "hidden"
      if (root.asleep) return "asleep"
      if (root.mood === "dead") return "dead"
      if (root.isSnoozed()) return "snoozed"
      return root.mood
    }
    // What the menu's footer shows.
    function stats(): string {
      return root.slapCount + (root.slapCount === 1 ? " slap, " : " slaps, ")
        + root.killCount + (root.killCount === 1 ? " kill" : " kills")
    }
    // The settings, same keys as shell.json and the menu: `set clean true`,
    // `set size 40`, `set aiModel unset`. Writes shell.json, so we remount.
    function set(key: string, value: string): string {
      key = String(key || "")
      if (!root.isSettingKey(key)) return "unknown key " + key + "; one of " + Object.keys(root.settingDefaults).join(", ")
      return root.setSetting(key, root.parseSettingValue(value)) ? "ok" : "can't write shell.json"
    }
    // The value in effect, as JSON (so "" and 0 and false are tellable apart).
    function get(key: string): string {
      key = String(key || "")
      if (!root.isSettingKey(key)) return "unknown key " + key + "; one of " + Object.keys(root.settingDefaults).join(", ")
      return JSON.stringify(root.setting(key, root.defaultFor(key)))
    }
    // Every key with the value in effect, defaults filled in. JSON object.
    function settings(): string {
      var out = {}
      var keys = Object.keys(root.settingDefaults)
      for (var i = 0; i < keys.length; i++) out[keys[i]] = root.setting(keys[i], root.defaultFor(keys[i]))
      return JSON.stringify(out)
    }
  }

  ClippyMenu {
    id: menu
    clippy: root
    // Stand still while the menu is up; it is anchored to where he was.
    onOpenChanged: {
      if (open) {
        walkAnim.stop()
        shoveAnim.stop()
        brain.stop()
        if (root.mood === "walking") { persisted.lastX = actor.x; sprite.exit(); root.mood = "idle" }
      } else if (root.mood === "idle") {
        root.schedule(root.rand(3000, 8000))
      }
    }
    onAct: function (name) {
      if (name === "say") { var q = root.nextQuote(); if (q) root.say(q.text, q.anim, q.ai) }
      else if (name === "shutUp") root.hideBubble()
      else if (name === "snooze") root.snooze(60)
      else if (name === "unsnooze") root.unsnooze()
      else if (name === "kill") root.kill()
      else if (name === "revive") root.bringBack()
    }
    onChose: function (key, value) { root.setSetting(key, value) }
  }

  // ---- window ------------------------------------------------------------
  PanelWindow {
    id: win
    screen: root.targetScreen
    visible: root.shown && root.targetScreen !== null
    color: "transparent"
    WlrLayershell.namespace: "costafot-clippy"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors {
      left: true
      right: true
      top: !root.barBottom
      bottom: root.barBottom
    }
    implicitHeight: root.barSize + root.bubbleReserve

    // Only Clippy and his bubble take input; the rest of the strip is
    // click-through so the bar underneath keeps working.
    mask: Region {
      item: actor
      regions: [
        Region {
          x: bubble.x
          y: bubble.y
          width: bubble.shown ? bubble.width : 0
          height: bubble.shown ? bubble.height : 0
        },
        // The grave takes clicks while it stands (the epitaph); it parks
        // in a widget gap, so this is normally empty bar anyway.
        Region {
          x: grave.x
          y: grave.y
          width: grave.shown ? grave.width : 0
          height: grave.shown ? grave.height : 0
        }
      ]
    }

    Item {
      id: stage
      anchors.fill: parent
      onWidthChanged: root.maybeBoot()

      Item {
        id: actor
        width: sprite.implicitWidth
        height: sprite.implicitHeight
        y: root.barBottom ? stage.height - height : 0
        visible: root.mood !== "dead"
        transformOrigin: Item.Bottom

        ClippySprite {
          id: sprite
          assetsDir: root.pluginDir + "/assets/clippy"
          size: root.spriteSize
        }

        MouseArea {
          id: touch
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
          hoverEnabled: true
          // A long left press (300 ms) picks him up (no `clicked` follows a hold).
          pressAndHoldInterval: 300
          onPressAndHold: function (mouse) {
            if (mouse.button === Qt.LeftButton) root.grab(mouse.x)
          }
          onReleased: root.drop()
          onCanceled: root.drop()

          // Swipe slap: the pointer only reports while it is over him, so
          // judge the crossing from where it came in to where it left. Fast
          // and mostly sideways across most of his width is a slap; a
          // pointer wandering over him on the way to the tray is not.
          property real enterX: 0
          property real enterY: 0
          property real enterT: 0
          property real lastX: 0
          property real lastY: 0
          onEntered: { enterX = mouseX; enterY = mouseY; lastX = mouseX; lastY = mouseY; enterT = Date.now() }
          onPositionChanged: function (mouse) {
            lastX = mouse.x; lastY = mouse.y
            if (root.dragging) root.dragTo(mouse.x)
          }
          onExited: {
            if (!root.slapEnabled || !root.slapSwipe || pressed) return
            var dx = lastX - enterX
            var dy = lastY - enterY
            var dt = Date.now() - enterT
            if (dt <= 0 || dt > 200) return
            if (Math.abs(dx) < width * 0.6 || Math.abs(dx) < Math.abs(dy) * 1.5) return
            if (Math.abs(dx) / dt < 1.2) return
            root.slap(dx > 0 ? 1 : -1)
          }

          onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) { root.showMenu(); return }
            if (mouse.button === Qt.MiddleButton) {
              // Hit on his left side and he flies right.
              if (root.slapEnabled) root.slap(mouse.x < width / 2 ? 1 : -1)
              else root.snooze(60)
              return
            }
            if (bubble.shown) { root.hideBubble(); return }
            var q = root.nextQuote()
            if (q) root.say(q.text, q.anim, q.ai)
          }
        }
      }

      // Where he died. Not in the window's input mask, so it can never
      // block a click on whatever it stands over — it only shades it.
      Tombstone {
        id: grave
        size: root.spriteSize
        x: persisted.graveX
        y: root.barBottom ? stage.height - height : root.actorHeight - height
        shown: root.tombstoneEnabled && root.mood === "dead" && persisted.graveX >= 0
        onPoked: root.epitaph()
        // Anchor the card to the grave, not to wherever the body ended up
        // (a fling leaves actor.x off-stage).
        onMenuWanted: root.showMenuAt(x + width / 2, null)
      }

      // While the grave stands, the bubble speaks from it (the epitaph);
      // otherwise from him. Same feet line, so only the heights differ.
      readonly property real mouthX: grave.shown ? grave.x + grave.width / 2 : actor.x + actor.width / 2

      Bubble {
        id: bubble
        above: root.barBottom
        x: Math.round(root.clamp(stage.mouthX - width / 2, 4, Math.max(4, stage.width - width - 4)))
        y: root.barBottom ? (grave.shown ? grave.y : actor.y) - height - 2
                          : (grave.shown ? grave.y + grave.height : actor.y + actor.height) + 2
        tailX: stage.mouthX - x
        onDismissed: root.hideBubble()
      }
    }
  }
}
