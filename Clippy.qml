import QtQuick
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

  // ---- settings: inline keys on our plugins[] entry in shell.json ---------
  readonly property var settings: {
    var list = shell && shell.shellConfig && Array.isArray(shell.shellConfig.plugins)
      ? shell.shellConfig.plugins : []
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].id === pluginId) return list[i]
    return ({})
  }
  function setting(key, fallback) {
    var v = settings[key]
    return v === undefined || v === null ? fallback : v
  }
  readonly property real spriteSize: clamp(Number(setting("size", 30)) || 30, 20, 200)
  readonly property int intervalMin: Math.max(5, Number(setting("intervalMin", 90)) || 90)
  readonly property int intervalMax: Math.max(intervalMin, Number(setting("intervalMax", 420)) || 420)
  readonly property real speed: clamp(Number(setting("speed", 40)) || 40, 5, 500)
  // 0..1: how often an idle beat turns into a walk. Idle beats are 10-30 s apart.
  readonly property real restless: clamp(Number(setting("restless", 0.3)), 0, 1)

  // Writes one inline key on our plugins[] entry. The shell rewrites
  // shell.json and remounts us; persisted state carries over.
  function setSetting(key, value) {
    if (!shell || typeof shell.updateEntryInline !== "function") return
    var entry = { id: pluginId }
    for (var k in settings) if (k !== "id") entry[k] = settings[k]
    entry[key] = value
    shell.updateEntryInline(pluginId, entry)
  }
  readonly property bool clean: setting("clean", false) === true
  readonly property int respawnSeconds: Math.max(0, Number(setting("respawn", 300)))
  readonly property string screenName: String(setting("screen", "") || "")
  readonly property string quotesFile: {
    var p = String(setting("quotesFile", "") || "")
    return p.indexOf("~") === 0 ? Quickshell.env("HOME") + p.slice(1) : p
  }

  // ---- bar geometry (same idiom as plugins/notifications/Service.qml) -----
  readonly property string barPosition: shell && shell.barConfig ? String(shell.barConfig.position || "top") : "top"
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property bool barBottom: barPosition === "bottom"
  readonly property bool barHidden: shell && shell.bar ? shell.bar.barHidden === true : false
  readonly property int defaultBarSize: barVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property int barSize: shell && shell.bar ? Math.max(0, shell.bar.barSize) : defaultBarSize
  readonly property int bubbleReserve: 150
  readonly property bool shown: opened && !barVertical && !barHidden

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
  property var quotes: []
  property var comebacks: []
  property var lastWords: []
  property var extraQuotes: []

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
    var book = Array.isArray(data) ? { quotes: data } : (data || {})
    if (extra) {
      extraQuotes = normalizeQuotes(book.quotes)
      if (book.comeback) comebacks = comebacks.concat(normalizeQuotes(book.comeback))
      if (book.lastWords) lastWords = lastWords.concat(normalizeQuotes(book.lastWords))
    } else {
      quotes = normalizeQuotes(book.quotes)
      comebacks = normalizeQuotes(book.comeback)
      lastWords = normalizeQuotes(book.lastWords)
    }
  }
  function pool(list) {
    var all = list.concat(extraQuotes)
    if (!clean) return all
    return all.filter(function (q) { return !q.nsfw })
  }
  function randomQuote() { return randomFrom(pool(quotes)) }
  function randomLine(list, fallback) {
    var q = randomFrom(pool(list))
    return q ? q.text : fallback
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
  }

  function isSnoozed() { return persisted.snoozedUntil > Date.now() }
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
    actor.x = persisted.lastX >= 0 ? clamp(persisted.lastX, 0, maxX) : Math.round(rand(0, maxX))
    mood = "idle"
    idleAnim()
    scheduleQuote()
  }

  // Brain: idle animation -> maybe walk -> idle ... ; quotes on their own timer.
  Timer { id: brain; repeat: false; onTriggered: root.decide() }
  Timer { id: quoteTimer; repeat: false; onTriggered: root.unprompted() }
  Timer { id: bubbleTimer; repeat: false; onTriggered: root.hideBubble() }
  Timer { id: respawnTimer; repeat: false; onTriggered: root.revive() }
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
    if (mood !== "idle") return
    if (Math.random() < restless) startWalk()
    else idleAnim()
  }

  function idleAnim() {
    mood = "idle"
    var name = randomFrom(idleAnims.filter(sprite.has))
    sprite.play(name || "RestPose", false, function () {
      if (root.mood === "idle") root.schedule(rand(10000, 30000))
    })
  }

  function startWalk() {
    var maxX = Math.max(0, stage.width - actor.width)
    // Mostly short hops around where he is; one in five is a trek anywhere.
    var target
    if (Math.random() < 0.2) target = rand(0, maxX)
    else target = actor.x + (Math.random() < 0.5 ? -1 : 1) * rand(80, 400)
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

  function say(text, anim) {
    text = String(text || "").trim()
    if (text === "") return false
    if (mood === "dead" || mood === "dying" || mood === "reviving") return false
    walkAnim.stop()
    brain.stop()
    mood = "talking"
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
      schedule(800)
    }
    if (!quoteTimer.running && mood !== "dead") scheduleQuote()
  }

  function unprompted() {
    scheduleQuote()
    if (mood !== "idle" && mood !== "walking") return
    if (isSnoozed()) return
    var q = randomQuote()
    if (q) say(q.text, q.anim)
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

  function kill() {
    if (mood === "dead" || mood === "dying") return
    walkAnim.stop()
    brain.stop()
    quoteTimer.stop()
    bubbleTimer.stop()
    mood = "dying"
    var words = randomLine(lastWords, "Fine. Fuck off then.")
    bubble.text = words
    bubble.shown = true
    dieTimer.interval = 2500
    dieTimer.start()
  }

  function finishDeath() {
    mood = "dead"
    persisted.deadUntil = respawnSeconds > 0 ? Date.now() + respawnSeconds * 1000 : -1
    armRespawn()
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
      actor.x = Math.round(rand(0, Math.max(0, stage.width - actor.width)))
    mood = "reviving"
    sprite.play("Greeting", false, function () {
      root.mood = "idle"
      root.say(root.randomLine(root.comebacks, "I'm back. Don't act like you didn't miss me."))
    })
  }

  // ---- IPC: omarchy-shell costafot.clippy <method> [arg] -------------------
  IpcHandler {
    target: "costafot.clippy"
    function ping(): string { return "ok" }
    function say(text: string): string { return root.say(text) ? "ok" : "not now" }
    function shutUp(): string { root.hideBubble(); return "ok" }
    function kill(): string { root.kill(); return "ok" }
    function respawn(): string {
      if (root.mood !== "dead") return "alive"
      root.revive()
      return "ok"
    }
    function snooze(minutes: string): string { root.snooze(minutes); return "ok" }
    function toggle(): string { root.opened = !root.opened; return root.opened ? "shown" : "hidden" }
    function hideMenu(): string { menu.open = false; return "ok" }
    function showMenu(): string {
      if (root.mood === "dead" || root.mood === "dying") return "dead"
      menu.anchorPos = actor.x + actor.width / 2
      menu.open = true
      return "ok"
    }
    function state(): string {
      if (!root.opened) return "hidden"
      if (root.mood === "dead") return "dead"
      if (root.isSnoozed()) return "snoozed"
      return root.mood
    }
  }

  ClippyMenu {
    id: menu
    clippy: root
    // Stand still while the menu is up; it is anchored to where he was.
    onOpenChanged: {
      if (open) {
        walkAnim.stop()
        brain.stop()
        if (root.mood === "walking") { persisted.lastX = actor.x; sprite.exit(); root.mood = "idle" }
      } else if (root.mood === "idle") {
        root.schedule(root.rand(3000, 8000))
      }
    }
    onAct: function (name) {
      if (name === "say") { var q = root.randomQuote(); if (q) root.say(q.text, q.anim) }
      else if (name === "shutUp") root.hideBubble()
      else if (name === "snooze") root.snooze(60)
      else if (name === "unsnooze") root.unsnooze()
      else if (name === "kill") root.kill()
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

        ClippySprite {
          id: sprite
          assetsDir: root.pluginDir + "/assets/clippy"
          size: root.spriteSize
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          cursorShape: Qt.PointingHandCursor
          onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
              menu.anchorPos = actor.x + actor.width / 2
              menu.open = true
              return
            }
            if (mouse.button === Qt.MiddleButton) { root.snooze(60); return }
            if (bubble.shown) { root.hideBubble(); return }
            var q = root.randomQuote()
            if (q) root.say(q.text, q.anim)
          }
        }
      }

      Bubble {
        id: bubble
        above: root.barBottom
        x: Math.round(root.clamp(actor.x + actor.width / 2 - width / 2, 4, Math.max(4, stage.width - width - 4)))
        y: root.barBottom ? actor.y - height - 2 : actor.y + actor.height + 2
        tailX: actor.x + actor.width / 2 - x
        onDismissed: root.hideBubble()
      }
    }
  }
}
