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
  // False until shellConfig has delivered our entry — in that window every
  // setting reads as its default, which must never be acted on outwardly:
  // default-on leaderboard would post an anonymous bump for a user whose
  // "off" (or handle) just hasn't loaded yet.
  readonly property bool settingsLoaded: entryLocation !== null

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
  // its default. The docs/configuration.md table and this list say the same thing.
  // `flingSound`/`dodgeSound` are null here because their default is whatever
  // `slapSound` is.
  readonly property var settingDefaults: ({
    size: 30, clean: false, intervalMin: 90, intervalMax: 420, speed: 40, restless: 0.3,
    respawn: 300, screen: "", quotesFile: "", promptFile: "",
    slap: true, slapSwipe: true, slapSound: true, flingSound: null, slapsToKill: 10, dodge: 0.1, dodgeSound: null,
    drag: true, fling: true, tts: false, ttsVoice: "en+m3", ttsSpeed: 155, ttsPitch: 45,
    ttsSaved: "", cloneTempo: 1, clonePitch: 1, voiceCacheMb: 500, duck: 0.8, duckSaved: "",
    ai: false, aiAgent: "", aiModel: "",
    pauseWhenAway: true, avoidWidgets: true, tombstone: true, crashLines: true, gags: true, peekChance: 0.04,
    greeted: false, leaderboard: "", leaderboardSaved: ""
  })
  function defaultFor(key) { return key === "flingSound" || key === "dodgeSound" ? slapSoundSetting : settingDefaults[key] }
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
  readonly property real spriteSize: clamp(Number(setting("size", 30)) || 30, 20, 400)
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
  // Full-screen stunts (the skyfall entrance, the fling's long drop).
  readonly property bool gagsEnabled: setting("gags", true) !== false

  // Writes inline keys on our shell.json entry (undefined removes a key).
  // The shell rewrites shell.json and remounts us; persisted state carries
  // over. `changes` is a map so related keys (tts + ttsSaved) land in one
  // write — two sequential writes would race the remount.
  function setSettings(changes) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    var entry = { id: pluginId }
    for (var k in settings) if (k !== "id") entry[k] = settings[k]
    for (var c in changes) {
      if (changes[c] === undefined || changes[c] === null) delete entry[c]
      else entry[c] = changes[c]
    }
    shell.updateEntryInline(pluginId, entry)
    return true
  }
  function setSetting(key, value) {
    var changes = {}
    changes[key] = value
    return setSettings(changes)
  }
  readonly property bool clean: setting("clean", false) === true
  readonly property int respawnSeconds: Math.max(0, Number(setting("respawn", 300)))
  readonly property string screenName: String(setting("screen", "") || "")
  function expandHome(p) {
    p = String(p || "")
    return p.indexOf("~") === 0 ? Quickshell.env("HOME") + p.slice(1) : p
  }
  readonly property string quotesFile: expandHome(setting("quotesFile", ""))
  // A text file whose contents REPLACE clippy-ai's built-in character
  // prompt (persona, tone and the per-mode rule lists) in every mode —
  // the facts, the three mode framings and the JSON output contract stay.
  // Register examples then come only from quotesFile. Free-text path, so
  // IPC/agent only, no menu row; a bad path falls back to the built-in.
  readonly property string promptFile: expandHome(setting("promptFile", ""))
  // Whether that file is actually readable and non-empty — the `ai` verb
  // reports it, so a typo'd path doesn't silently fall back to the
  // built-in character with only a journal note (clippy-ai guards itself
  // either way; this is the surfacing). Probed at mount and on changes;
  // async like ttsProbe, so `ai` in the same breath as the `set` may
  // read one probe stale.
  property bool promptFileMissing: false
  onPromptFileChanged: promptProbe.check()
  Process {
    id: promptProbe
    function check() {
      if (root.promptFile === "") { root.promptFileMissing = false; return }
      command = ["bash", "-c", '[[ -r $1 && -s $1 ]]', "promptprobe", root.promptFile]
      running = true
    }
    onExited: function (code) { root.promptFileMissing = code !== 0 }
    Component.onCompleted: check()
  }
  // Slapping: middle-click, or flinging the pointer across him. `slap: false`
  // turns both off and gives middle-click back to snooze.
  readonly property bool slapEnabled: setting("slap", true) !== false
  // Dragging: hold left on him, then move. `drag: false` turns it off.
  readonly property bool dragEnabled: setting("drag", true) !== false
  // Letting go of him mid-fling throws him off the bar, fatally.
  readonly property bool flingEnabled: setting("fling", true) !== false
  readonly property bool crashLinesOn: setting("crashLines", true) !== false
  // `ai: true` has his unprompted and clicked lines come from the user's
  // default coding agent (scripts/clippy-ai), reacting to what's on screen,
  // battery, the hour. The book stays the fallback. `aiAgent` overrides
  // which agent, else whatever `omarchy default agent` says.
  readonly property bool aiEnabled: setting("ai", false) === true
  onAiEnabledChanged: if (!aiEnabled) abortListen() // a live mic dies with its context
  readonly property string aiAgent: String(setting("aiAgent", "") || "")
  readonly property string aiModel: String(setting("aiModel", "") || "")
  readonly property string aiAgentName: agentBrain.agent
  readonly property real flingSpeed: 1.8 // px/ms at release
  readonly property bool slapSwipe: setting("slapSwipe", true) !== false
  readonly property int slapsToKill: Math.max(0, Number(setting("slapsToKill", 10)))
  // Chance a slap misses (0-1). true = every one, false/0 = never; a
  // non-number falls back to the default.
  readonly property real dodgeChance: {
    var v = setting("dodge", 0.1)
    var n = v === true ? 1 : Number(v)
    return clamp(isNaN(n) ? 0.1 : n, 0, 1)
  }
  // `slapSound` / `flingSound` / `dodgeSound`: true for the built-in ones,
  // false for silence, or a path to a WAV of your own. `flingSound` and
  // `dodgeSound` follow `slapSound` unless set, so the menu's one toggle
  // mutes all three.
  readonly property var slapSoundSetting: setting("slapSound", true)
  readonly property bool slapSoundOn: slapSoundSetting !== false
  readonly property var flingSoundSetting: setting("flingSound", slapSoundOn)
  readonly property var dodgeSoundSetting: setting("dodgeSound", slapSoundOn)
  function soundList(value, builtins) {
    if (value === false) return []
    if (typeof value === "string" && value !== "") return ["file://" + expandHome(value)]
    var dir = "file://" + pluginDir + "/assets/sounds/"
    return builtins.map(function (f) { return dir + f })
  }
  readonly property var slapSounds: soundList(slapSoundSetting, ["slap-crack.wav", "slap-punch.wav"])
  readonly property var flingSounds: soundList(flingSoundSetting, ["fall-cartoon.wav"])
  readonly property var dodgeSounds: soundList(dodgeSoundSetting, ["dodge-whoosh.wav"])
  // `tts`: false for silence (the default), true for espeak-ng — install that
  // yourself — or your own shell command as a string, handed every line on
  // stdin. The machinery lives next to the SoundBanks below.
  readonly property var ttsSetting: setting("tts", false)
  readonly property bool ttsOn: ttsSetting === true || (typeof ttsSetting === "string" && ttsSetting !== "")
  // Tuning for the built-in engine only — a custom command is one opaque
  // string on stdin and ignores all three. The voice sheds single quotes so
  // the quoting in startTts() can't be broken by one.
  readonly property string ttsVoice: String(setting("ttsVoice", "en+m3")).replace(/'/g, "") || "en+m3"
  readonly property real ttsSpeed: clamp(Number(setting("ttsSpeed", 155)) || 155, 80, 450)
  readonly property real ttsPitch: clamp(Number(setting("ttsPitch", 45)), 0, 99)
  // Clone knobs, factors around 1: cloneTempo speeds him up (pitch kept),
  // clonePitch shifts the voice (tempo kept). Appended to speak-clone at
  // launch time, never baked into the stored tts string — the picker keeps
  // calling the voice by name and setup-voice's strings stay canonical.
  // Both derive from the line cache (ffmpeg, milliseconds), so auditioning
  // values is instant and warm-voice never needs a rerun.
  readonly property real cloneTempo: clamp(Number(setting("cloneTempo", 1)) || 1, 0.5, 2)
  readonly property real clonePitch: clamp(Number(setting("clonePitch", 1)) || 1, 0.5, 2)
  readonly property bool cloneKnobsApply: typeof ttsSetting === "string" && ttsSetting.indexOf("speak-clone") !== -1
  // MB the clone line cache may hold; the daemon prunes least-recently-played
  // renders past it, 0 = no cap. Reaches the daemon through the environment
  // of whichever of our processes spawns it (a spoken line or a warm), so a
  // change applies from the daemon's next start (it exits after 15 idle
  // minutes). Sanitized to a clean integer here — the env string must never
  // be something the daemon's int() would choke on.
  readonly property int voiceCacheMb: {
    var n = Number(setting("voiceCacheMb", 500))
    return isNaN(n) ? 500 : Math.max(0, Math.round(n))
  }
  readonly property var voiceCacheEnv: ({ CLIPPY_VOICE_CACHE_MB: String(voiceCacheMb) })
  // Ducking: every *other* audio stream drops to `duck` of its volume
  // while he speaks and comes back after. Works with any engine: the
  // snapshot is taken before the engine spawns (see scripts/duck).
  // Hardwired 0.3 originally ("ALWAYS duck other audio"), softened to
  // 0.8 ("kinda annoying"), then made a setting (v1.31.0): a 0-1
  // fraction by IPC, on/off in the menu — the ratio is terminal/agent
  // only, Costa's call. false (or 1) means no duck; the menu toggle
  // parks a custom ratio in duckSaved so off/on round-trips it.
  readonly property real duckFactor: {
    var v = setting("duck", 0.8)
    if (v === false) return 1
    if (v === true) return 0.8
    var n = Number(v)
    return isNaN(n) ? 0.8 : clamp(n, 0, 1)
  }
  readonly property bool duckOn: duckFactor < 1
  // The ttsSaved idiom a third time: off stashes an explicit ratio, on
  // restores it (else the default), one setSettings write each way.
  function setDuckEnabled(on) {
    if (on) {
      var stash = setting("duckSaved", undefined)
      return setSettings({ duck: typeof stash === "number" ? stash : undefined, duckSaved: undefined })
    }
    var cur = setting("duck", undefined)
    return setSettings({ duck: false, duckSaved: typeof cur === "number" ? cur : undefined })
  }
  // An inline `set` doesn't remount us (keepLoaded — the binding just
  // updates), so a changed engine gets its failure warning back here, and
  // turning the voice off shuts him up instead of finishing the line. Two
  // handlers: inside onTtsSettingChanged the dependent ttsOn binding hasn't
  // re-evaluated yet, so a `!ttsOn` check there reads stale (bit us).
  onTtsSettingChanged: { ttsWarned = false; ttsProbe.running = true; voiceScan.running = true; warmBook() }
  // Whether the built-in engine exists — the menu row and the IPC `set`
  // reply point at it, so nobody wonders why the voice is silent. Probed at
  // mount, on `tts` changes and on menu open (fresh right after an
  // install). A custom command is the user's own problem.
  property bool ttsEngineMissing: false
  readonly property bool ttsNeedsEngine: ttsEngineMissing && typeof ttsSetting !== "string"
  Process {
    id: ttsProbe
    command: ["bash", "-c", "command -v espeak-ng >/dev/null"]
    onExited: function (code) { root.ttsEngineMissing = code !== 0 }
    Component.onCompleted: running = true
  }
  // Turning the voice on with nothing to speak through gets told to your
  // face, in a bubble — the journal and the IPC reply aren't where a user
  // looks. ttsSetting is fresh here (it fired first); ttsNeedsEngine may
  // not be, hence the inline typeof.
  onTtsOnChanged: {
    if (!ttsOn) { stopSpeaking(); return }
    if (ttsEngineMissing && typeof ttsSetting !== "string")
      Qt.callLater(function () { root.say("You want me to actually talk? Install espeak-ng. I'll wait.") })
  }
  // `hide` only flips `opened` — the bubble props stay put, and without this
  // he'd keep talking out of an invisible window.
  onOpenedChanged: if (!opened) { stopSpeaking(); abortListen() }

  // ---- voice inventory ----------------------------------------------------
  // Every voice already on disk, so the menu can offer a picker and an agent
  // can enumerate (`voices`) and switch (`useVoice`) without reading the
  // docs. scripts/voice-scan fills it: espeak/GPU/kokoro presence, clone
  // wavs, piper models, drop-in command files (~/.local/share/clippy-voices).
  // Installing NEW voices stays with scripts/setup-voice —
  // switching here is only ever a `set tts` write, never a download.
  property var voiceInv: ({ espeak: false, gpu: false, kokoro: false, clones: [], piper: [], dropins: [] })
  // A useVoice for a name the (possibly stale) inventory doesn't know parks
  // the name here and kicks a rescan — the natural agent flow is "write a
  // drop-in file, useVoice it in the same breath", and without this the
  // first try always answered "unknown". Applied once when the scan lands,
  // only if the name resolved (no retry loop for a genuinely unknown name).
  property string voicePendingApply: ""
  Process {
    id: voiceScan
    command: [root.pluginDir + "/scripts/voice-scan"]
    stdout: StdioCollector { id: voiceScanOut }
    onExited: function (code) {
      if (code !== 0) return
      try { root.voiceInv = JSON.parse(voiceScanOut.text) } catch (e) { /* best-effort */ }
      if (root.voicePendingApply !== "") {
        var id = root.voicePendingApply
        root.voicePendingApply = ""
        if (root.voiceOptions.indexOf(id) !== -1) root.applyVoice(id)
      }
    }
    Component.onCompleted: running = true
  }
  // The exact command strings scripts/setup-voice writes, rebuilt so the
  // picker and `useVoice` can switch between installed voices without the
  // script. Keep in lockstep with setup-voice — drift just means the picker
  // calls that voice "custom", nothing breaks.
  readonly property string homeDir: Quickshell.env("HOME")
  // The trap/&/wait wrapper on the pipeline commands mirrors setup-voice:
  // TERM on bash must kill aplay promptly (a foreground pipeline defers the
  // trap and a replaced line would play out over the next one).
  readonly property string georgeCmd: "trap 'kill $! 2>/dev/null' TERM; KOKORO_VOICE=bm_george " + homeDir + "/.local/share/kokoro-tts/say.py"
    + " | ffmpeg -hide_banner -loglevel quiet -f s16le -ar 24000 -ac 1 -i -"
    + " -af 'asetrate=24000*1.15,aresample=24000,atempo=0.870,tremolo=f=45:d=0.8,acrusher=bits=6:mode=log:aa=1,highpass=f=250,lowpass=f=3400'"
    + " -f s16le - | aplay -q -t raw -r 24000 -f S16_LE -c 1 - & wait $!"
  function cloneCmd(name) {
    var cb = homeDir + "/.local/share/chatterbox-tts"
    return "exec " + cb + "/speak-clone --ref " + cb + "/voices/" + name + ".wav --exag 0.5 --cfg 0.5"
  }
  function piperCmd(name, rate) {
    return "trap 'kill $! 2>/dev/null' TERM; " + homeDir + "/.local/share/piper-tts/venv/bin/piper -m " + homeDir + "/.local/share/piper-voices/" + name
      + ".onnx --output-raw 2>/dev/null | aplay -q -t raw -r " + rate + " -f S16_LE -c 1 - & wait $!"
  }
  // The tts value, as a name: "off", "robot" (espeak), "george", a clone or
  // piper name, or "custom" for any other command string. A clone keeps its
  // name through knob changes (--exag/--cfg/--pitch) — it's still that voice.
  readonly property string currentVoiceId: {
    if (!ttsOn) return "off"
    if (typeof ttsSetting !== "string") return "robot"
    if (ttsSetting === georgeCmd) return "george"
    var m = ttsSetting.match(/speak-clone .*--ref \S*\/([A-Za-z0-9_-]+)\.wav/)
    if (m) return m[1]
    m = ttsSetting.match(/\/piper -m \S*\/([A-Za-z0-9_.-]+)\.onnx/)
    if (m) return m[1]
    var ds = voiceInv.dropins || []
    for (var i = 0; i < ds.length; i++) if (ds[i].cmd === ttsSetting) return ds[i].name
    return "custom"
  }
  // What the picker offers: only the usable. Clones need the GPU they
  // synthesize on; "custom" appears when a hand-set command is live or
  // parked in ttsSaved, so it is never more than one tap away.
  readonly property var voiceOptions: {
    var opts = ["off", "robot"]
    if (voiceInv.kokoro) opts.push("george")
    var i
    if (voiceInv.gpu) for (i = 0; i < (voiceInv.clones || []).length; i++) opts.push(voiceInv.clones[i])
    for (i = 0; i < (voiceInv.piper || []).length; i++) opts.push(voiceInv.piper[i].name)
    var ds = voiceInv.dropins || []
    for (i = 0; i < ds.length; i++) if (opts.indexOf(ds[i].name) === -1) opts.push(ds[i].name)
    if (currentVoiceId === "custom" || String(setting("ttsSaved", "") || "") !== "") opts.push("custom")
    return opts
  }
  // One resolver behind the menu picker and IPC `useVoice`: a name in, the
  // right tts/ttsSaved write out, an agent-first reply either way. Leaving a
  // hand-set command for a named voice parks it in ttsSaved — same
  // no-eating rule as the on/off toggle (v1.16.0).
  function applyVoice(id) {
    id = String(id || "")
    var cur = currentVoiceId
    if (id === cur) return "already the voice in use"
    var changes = {}
    if (cur === "custom" && typeof ttsSetting === "string")
      changes.ttsSaved = ttsSetting
    if (id === "off") {
      changes.tts = false
      if (!setSettings(changes)) return "can't write shell.json"
      return changes.ttsSaved ? "ok — voice off; the custom command is kept in ttsSaved (useVoice custom brings it back)" : "ok — voice off"
    }
    if (id === "robot" || id === "espeak") {
      changes.tts = true
      if (!setSettings(changes)) return "can't write shell.json"
      return ttsEngineMissing ? "ok — but espeak-ng isn't installed, so the robot is silent until it is" : "ok — the espeak robot"
    }
    if (id === "custom") {
      var saved = String(setting("ttsSaved", "") || "")
      if (saved === "") return "no custom command saved — set tts <shell command handed each line on stdin>"
      if (!setSettings({ tts: saved, ttsSaved: undefined })) return "can't write shell.json"
      return "ok — restored the custom command: " + saved
    }
    if (id === "george") {
      if (!voiceInv.kokoro) return "george isn't installed — run scripts/setup-voice --robot in " + pluginDir + " (~340 MB, no GPU needed)"
      changes.tts = georgeCmd
      if (!setSettings(changes)) return "can't write shell.json"
      return "ok — robot george"
    }
    if ((voiceInv.clones || []).indexOf(id) !== -1) {
      if (!voiceInv.gpu) return id + " is a clone, and clones synthesize on an NVIDIA GPU — none found here"
      changes.tts = cloneCmd(id)
      if (!setSettings(changes)) return "can't write shell.json"
      return "ok — the " + id + " clone (the book is pre-rendered for him in the background if it wasn't already)"
    }
    var ps = voiceInv.piper || []
    for (var i = 0; i < ps.length; i++) {
      if (ps[i].name !== id) continue
      changes.tts = piperCmd(id, ps[i].rate)
      if (!setSettings(changes)) return "can't write shell.json"
      return "ok — " + id + " (piper)"
    }
    var ds = voiceInv.dropins || []
    for (i = 0; i < ds.length; i++) {
      if (ds[i].name !== id) continue
      changes.tts = ds[i].cmd
      if (!setSettings(changes)) return "can't write shell.json"
      return "ok — " + id + " (drop-in)"
    }
    voicePendingApply = id
    voiceScan.running = true
    return JSON.stringify(id) + " isn't in the last inventory scan — rescanning now: a just-dropped file in ~/.local/share/clippy-voices switches in a beat (`voices` confirms). If it's genuinely not installed: scripts/setup-voice in " + pluginDir + " (a kokoro/piper name, --robot, or --clone <sample.wav> <name> on an NVIDIA GPU), or drop a command file in ~/.local/share/clippy-voices"
  }

  // ---- bar geometry (same idiom as plugins/notifications/Service.qml) -----
  readonly property string barPosition: shell && shell.barConfig ? String(shell.barConfig.position || "top") : "top"
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property bool barBottom: barPosition === "bottom"
  readonly property bool barHidden: shell && shell.bar ? shell.bar.barHidden === true : false
  readonly property int defaultBarSize: barVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property int barSize: shell && shell.bar ? Math.max(0, shell.bar.barSize) : defaultBarSize
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
  // The first hello: one `firstRun` line on the very first boot after an
  // install, pointing at the menu and the agent. `greeted` lands inline on
  // our shell.json entry once it's been said, so a shell restart doesn't
  // repeat it — only a reinstall (or `set greeted unset`) does.
  Timer { id: greetTimer; interval: 2000; repeat: false; onTriggered: root.firstHello() }
  function maybeGreet() { if (!setting("greeted", false)) greetTimer.restart() }
  function firstHello() {
    if (asleep || mood !== "idle" || dragging || isSnoozed()) return
    if (setting("greeted", false)) return
    // Deterministic, not random: the first line of the pool IS the greeting
    // (under `clean` the nsfw one is filtered and the clean line steps up).
    var p = pool("firstRun")
    var q = p.length ? p[0] : null
    say(q ? q.text : "Welcome, you fuck. Set me up in the options — right-click me. Or ask your agent, eh?",
        q && q.anim ? q.anim : "Wave")
    setSetting("greeted", true)
  }
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
    abortListen()
    peekCancel(true) // before the lastX write below: store the bar spot, not a corner
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
    // A remount while locked skips maybeBoot's flush (asleep returns first)
    // and drops the retry timer with the old instance — so the wake re-runs
    // it: held deltas land, lbCache refills, a dead server just backs off.
    // Before the dead branch: the graveyard cares about kills, not moods.
    if (leaderboardOn) flushLeaderboard(true)
    if (mood === "dead") {
      if (persisted.deadUntil > 0 && persisted.deadUntil <= Date.now()) revive()
      return
    }
    if (mood === "idle" && !dragging) {
      idleAnim()
      if (!setting("greeted", false)) maybeGreet()
      else if (longEnough) { awayMs = away; welcomeTimer.restart() }
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
  readonly property var quoteKeys: ["quotes", "comeback", "lastWords", "slapped", "knockedOut", "dragged", "dropped", "flung", "crashed", "welcomeBack", "epitaph", "firstRun", "noBrain", "heardNothing", "dodged"]
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
  // `{kills}` / `{slaps}` in any line become the running tally (the one
  // `stats` prints). A death in progress counts itself: killCount is
  // bumped in finishDeath(), after the last words are written, so "murder
  // number {kills}" is right on the way down, not one behind.
  function fill(text) {
    var kills = killCount + (mood === "dying" ? 1 : 0)
    return String(text).replace(/\{kills\}/g, kills).replace(/\{slaps\}/g, slapCount)
  }
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
    promptFile: root.promptFile
    onLinesArrived: lines => root.warmAgentLines(lines)
  }

  // ---- the look ----------------------------------------------------------
  // IPC `look` and the menu's "Judge my screen": grim his screen into
  // $XDG_RUNTIME_DIR, hand it to clippy-ai --image (one jab through the
  // user's agent — the vision is the agent's), and the verdict lands in the
  // bubble agent-dressed. Explicitly user-triggered ONLY — never on a timer,
  // never from decide()/unprompted(): a screenshot leaving the machine on
  // his own schedule would be surveillance, not a gag. The screenshot is
  // deleted the moment the agent call returns, success or not.
  property bool looking: false
  property bool lookFailed: false
  function lookAtScreen() {
    if (!opened) return "hidden"
    if (asleep) return "asleep"
    if (mood === "dead" || mood === "dying" || mood === "reviving") return "dead — he judges nothing from the grave; respawn first"
    if (peeking) return "not now" // mid-peek; the verdict-say would tangle the dwell
    if (!aiEnabled) return "off — the look runs through your coding agent; set ai true first"
    if (listening || replying) return "busy — he's mid-conversation; wait for the comeback"
    if (lookProc.running) return "busy — already looking; the verdict lands in his bubble"
    if (!targetScreen) return "not now"
    var file = Quickshell.env("XDG_RUNTIME_DIR") + "/clippy-look.png"
    var cmd = [pluginDir + "/scripts/clippy-ai", "--image", file]
    if (clean) cmd.push("--clean")
    if (aiAgent !== "") cmd.push("--agent", aiAgent)
    if (aiModel !== "") cmd.push("--model", aiModel)
    // Deliberately NO --recent: the look remember()s itself, so feeding the
    // list back made repeated looks count each other ("fifth screenshot
    // this hour") instead of attacking the screen. Batches still get it.
    if (quotesFile !== "") cmd.push("--quotes", quotesFile)
    if (promptFile !== "") cmd.push("--prompt-file", promptFile)
    lookProc.command = ["bash", "-c",
      'f=$1; out=$2; shift 2; grim -o "$out" "$f" || exit 6; "$@"; rc=$?; rm -f "$f"; exit $rc',
      "clippy-look", file, String(targetScreen.name)].concat(cmd)
    lookProc.running = true
    looking = true
    // He visibly inspects the screen while the agent chews on it — the
    // 5-15 s of latency played as timing instead of dead air.
    walkAnim.stop()
    brain.stop()
    if (mood === "walking") { persisted.lastX = actor.x; mood = "idle" }
    sprite.play(sprite.has("CheckingSomething") ? "CheckingSomething" : "Thinking", true)
    return "ok — looking; the verdict lands in his bubble in ~10 s"
  }
  Process {
    id: lookProc
    stdout: StdioCollector { id: lookOut }
    stderr: StdioCollector { id: lookErr }
    onExited: function (code) {
      root.looking = false
      var line = null
      try {
        var parsed = JSON.parse(String(lookOut.text))
        if (Array.isArray(parsed) && typeof parsed[0] === "string" && parsed[0].trim() !== "") line = parsed[0].trim()
      } catch (e) {}
      if (code !== 0 || !line) {
        root.lookFailed = true
        console.warn("clippy: screen look failed (exit " + code + "): " + String(lookErr.text).trim())
        root.backToIdle()
        return
      }
      root.lookFailed = false
      agentBrain.remember("shoved their screen in his face for a verdict")
      // Asleep or dead by the time the verdict arrived: stale, drop it.
      if (!root.say(line, null, true)) root.backToIdle()
    }
  }

  // ---- talk back ---------------------------------------------------------
  // IPC `listen` (toggle) / `reply <text>` and the menu's "Say it to his
  // face": the user answers his last line, voxtype transcribes it locally
  // (the audio never leaves the machine — only the text goes to the user's
  // agent), and clippy-ai --reply fires the comeback back through that
  // agent, agent-dressed. Explicit gesture ONLY, the look's rule extended
  // to audio: the mic never opens on his own schedule. The wav dies with
  // the transcription stage, success or not. A live mic dies with its
  // context (sleep, death, hide, ai off) via abortListen(); an in-flight
  // transcription or agent call is never killed — its result is gated on
  // arrival instead (the look's stale-verdict rule).
  property bool listening: false
  property bool replying: false
  property bool replyFailed: false
  property bool recordAborted: false
  property string lastHeard: ""
  readonly property string listenWav: Quickshell.env("XDG_RUNTIME_DIR") + "/clippy-listen.wav"
  // He's mid-conversation: no idle walks, no unprompted lines, no crash
  // heckles stepping on the exchange.
  readonly property bool occupied: looking || listening || replying
  // Whether voxtype exists — the menu row hides without it, the `listen`
  // reply points at it. Probed like ttsProbe: mount and menu open.
  property bool voxtypeMissing: true
  Process {
    id: voxProbe
    command: ["bash", "-c", "command -v voxtype >/dev/null"]
    onExited: function (code) { root.voxtypeMissing = code !== 0 }
    Component.onCompleted: running = true
  }

  // Back to the idle loop when a stage ends with nothing to say — but never
  // while asleep (fallAsleep stopped the sprite; wakeUp restarts it) and
  // never over a drag or another mood's animation.
  function backToIdle() {
    if (mood === "idle" && !dragging && !asleep) { idleAnim(); schedule(rand(3000, 8000)) }
  }

  function toggleListen() {
    if (listening) { recordProc.signal(2); return "ok — heard you; the comeback lands in his bubble" }
    if (!opened) return "hidden"
    if (asleep) return "asleep"
    if (mood === "dead" || mood === "dying" || mood === "reviving") return "dead — he hears nothing from the grave; respawn first"
    if (peeking) return "not now" // listen hides the bubble, which would fire the out-leg mid-record
    if (!aiEnabled) { sayNoBrain(); return "off — the comeback runs through your coding agent; set ai true first (he told you himself)" }
    if (voxtypeMissing) return "no ears — voxtype isn't installed; `reply <text>` talks back without a mic"
    if (looking) return "busy — he's judging the screen; wait for the verdict"
    if (replying) return "busy — still cooking the last comeback"
    hideBubble() // his own voice must not end up in the transcript
    recordAborted = false
    // The 15 s cap lives in the child, and `timeout` forwards a received
    // INT — so the toggle-stop and the cap are the same signal path, and
    // INT is pw-record's designed stop (the WAV header gets finalized).
    recordProc.command = ["timeout", "-s", "INT", "15", "pw-record",
      "--rate", "16000", "--channels", "1", listenWav]
    recordProc.running = true
    listening = true
    walkAnim.stop()
    brain.stop()
    if (mood === "walking") { persisted.lastX = actor.x; mood = "idle" }
    sprite.play(sprite.has("Hearing_1") ? "Hearing_1" : "Thinking", true)
    return "ok — listening (15 s cap; `listen` again to stop); the comeback lands in his bubble"
  }

  function abortListen() {
    if (!listening) return
    recordAborted = true
    recordProc.signal(2)
  }

  // The ai-off sass, shared by both verbs: he answers the attempt himself.
  function sayNoBrain() {
    var q = randomQuoteFrom("noBrain")
    say(q ? q.text : "You want a reaction? I'm too dumb without an agent. set ai true.", q && q.anim)
  }

  Process {
    id: recordProc
    // A shell exit must not leave a live mic (the ttsProc rule, but INT:
    // pw-record's designed stop).
    Component.onDestruction: signal(2)
    onExited: function (code) {
      root.listening = false
      // Aborted, or the world changed under the mic: swallow the take.
      if (root.recordAborted || !root.aiEnabled || !root.opened || root.asleep
          || root.mood === "dead" || root.mood === "dying" || root.mood === "reviving") {
        wavCleanup.running = true
        root.backToIdle()
        return
      }
      root.replying = true
      sprite.play(sprite.has("CheckingSomething") ? "CheckingSomething" : "Thinking", true)
      transcribeProc.running = true
    }
  }
  Process { id: wavCleanup; command: ["rm", "-f", root.listenWav] }

  Process {
    id: transcribeProc
    command: ["bash", "-c",
      'f=$1; voxtype transcribe "$f"; rc=$?; rm -f "$f"; exit $rc',
      "clippy-listen", root.listenWav]
    stdout: StdioCollector { id: transcribeOut }
    stderr: StdioCollector { id: transcribeErr }
    onExited: function (code) {
      if (code !== 0) {
        root.replying = false
        root.replyFailed = true
        console.warn("clippy: transcription failed (exit " + code + "): " + String(transcribeErr.text).trim().slice(-300))
        root.backToIdle()
        return
      }
      // voxtype's stdout is progress + ANSI-colored log lines, one blank
      // line, then the transcript — take what follows the last blank line
      // and strip any stray escape codes.
      var chunks = String(transcribeOut.text).split(/\n\s*\n/)
      var text = chunks[chunks.length - 1]
        .replace(/\x1b\[[0-9;]*m/g, "").replace(/\s+/g, " ").trim()
      // Whisper transcribes silence as "." — that's not talking back.
      if (/^[\s.,!?;:\u2026\-\u2013\u2014'"]*$/.test(text)) {
        root.replying = false
        var q = root.randomQuoteFrom("heardNothing")
        if (!root.say(q ? q.text : "Fifteen seconds of mic. You said nothing.", q && q.anim)) root.backToIdle()
        return
      }
      // The world may have changed during the seconds of whisper.
      if (!root.aiEnabled || !root.opened || root.asleep
          || root.mood === "dead" || root.mood === "dying" || root.mood === "reviving") {
        root.replying = false
        root.backToIdle()
        return
      }
      root.sendReply(text)
    }
  }

  // The shared back half: voice lands here after transcription, IPC
  // `reply <text>` lands here directly.
  function sendReply(userText) {
    replying = true
    lastHeard = userText
    var cmd = [pluginDir + "/scripts/clippy-ai", "--reply", userText]
    // bubble.text survives the hide — his last line is what they answered.
    var said = String(bubble.text || "").trim()
    if (said !== "") cmd.push("--said", said)
    if (clean) cmd.push("--clean")
    if (aiAgent !== "") cmd.push("--agent", aiAgent)
    if (aiModel !== "") cmd.push("--model", aiModel)
    // Deliberately NO --recent, the look's reasoning: the exchange
    // remember()s itself, and feeding the list back would make repeat
    // rounds count each other instead of attacking the words.
    if (quotesFile !== "") cmd.push("--quotes", quotesFile)
    if (promptFile !== "") cmd.push("--prompt-file", promptFile)
    replyProc.command = cmd
    replyProc.running = true
    walkAnim.stop()
    brain.stop()
    if (mood === "walking") { persisted.lastX = actor.x; mood = "idle" }
    sprite.play(sprite.has("CheckingSomething") ? "CheckingSomething" : "Thinking", true)
  }

  Process {
    id: replyProc
    stdout: StdioCollector { id: replyOut }
    stderr: StdioCollector { id: replyErr }
    onExited: function (code) {
      root.replying = false
      var line = null
      try {
        var parsed = JSON.parse(String(replyOut.text))
        if (Array.isArray(parsed) && typeof parsed[0] === "string" && parsed[0].trim() !== "") line = parsed[0].trim()
      } catch (e) {}
      if (code !== 0 || !line) {
        root.replyFailed = true
        console.warn("clippy: comeback failed (exit " + code + "): " + String(replyErr.text).trim())
        root.backToIdle()
        return
      }
      root.replyFailed = false
      agentBrain.remember("talked back to his face: \"" + root.lastHeard.slice(0, 80) + "\" — he answered")
      // Asleep, dead or hidden by the time it landed: stale, drop it.
      if (!root.say(line, null, true)) root.backToIdle()
    }
  }

  // ---- crash reactions ---------------------------------------------------
  // systemd-coredump journals every dump under a fixed MESSAGE_ID with
  // structured COREDUMP_* fields — the same stream omarchy-crash-watch
  // follows for its "Process crashed" toast, but read directly so the
  // reaction doesn't inherit that watcher's gates (default agent chosen,
  // capture toggled on). `_UID=$(id -u)` matches inside journald, so every
  // line the follower emits is already one of the user's own crashes, and
  // `-n 0` means a remount never replays dealt-with ones. The reaction is a
  // book line — instant, nothing leaves the machine, works with `ai` off
  // (the agent still hears about crashes via clippy-ai's extremes facts).
  // His own host crashing needs no special case: a quickshell dump takes
  // this follower down with it and the restart starts at -n 0.
  property var crashLastAt: ({})
  Process {
    id: crashWatch
    running: root.crashLinesOn
    command: ["bash", "-c",
      'exec journalctl -f -n 0 -o json "MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1" "_UID=$(id -u)"']
    stdout: SplitParser {
      onRead: line => root.crashReact(line)
    }
  }
  function crashReact(jsonLine) {
    var e
    try { e = JSON.parse(jsonLine) } catch (err) { return }
    // COMM is truncated to 15 chars, so prefer the executable's basename.
    var exe = String(e.COREDUMP_EXE || "")
    var name = exe.indexOf("/") === 0 ? exe.slice(exe.lastIndexOf("/") + 1) : String(e.COREDUMP_COMM || "")
    if (name === "" || name.indexOf("omarchy-crash-") === 0 || name.indexOf("omarchy-agent-") === 0) return
    // A crash loop dumps core repeatedly; one line per program per minute.
    var now = Date.now()
    if (crashLastAt[name] && now - crashLastAt[name] < 60000) return
    crashLastAt[name] = now
    agentBrain.remember(name + " crashed on them")
    if (isSnoozed() || dragging || occupied || peeking) return
    var q = randomQuoteFrom("crashed")
    if (q) say(q.text.replace(/\{app\}/g, name), q.anim)
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
    gagAnim.stop()
    peekCancel(false) // a remount reset the flags anyway; the fresh gagDy = 0 lands him
    peekGrown = false
    gagDy = 0
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
    maybeGreet()
    if (leaderboardOn) flushLeaderboard(true) // refill lbCache after a remount
  }

  // Brain: idle animation -> maybe walk -> idle ... ; quotes on their own timer.
  Timer { id: brain; repeat: false; onTriggered: root.decide() }
  Timer { id: quoteTimer; repeat: false; onTriggered: root.unprompted() }
  // The word-count interval can lose the race with the voice — a clone pays
  // ~2 s of synthesis on a novel line and speaks slower than 450 ms/word —
  // and hiding the bubble cuts the engine mid-word (every deliberate hide
  // relies on exactly that). So the timeouts — this one, dieTimer for last
  // words, flingHold for the flung line — wait: while the voice is still on
  // the line they re-arm in half-second beats, capped so a hung engine
  // can't pin a mood forever.
  Timer {
    id: bubbleTimer
    repeat: false
    property int holds: 0
    onTriggered: {
      if (root.speakingThisBubble() && holds < 60) { holds++; interval = 500; restart() }
      else root.hideBubble()
    }
  }
  Timer { id: respawnTimer; repeat: false; onTriggered: if (!root.asleep) root.revive() }
  Timer {
    id: dieTimer
    repeat: false
    property int holds: 0
    onTriggered: {
      if (root.speakingThisBubble() && holds < 60) { holds++; interval = 500; restart(); return }
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
    if (mood !== "idle" || dragging || asleep || occupied || peeking) return
    // A beat can be the corner peek instead of a walk (needs gags on; not
    // while snoozed — a peek speaks). Same beat, no new timers.
    if (gagsEnabled && peekChance > 0 && !isSnoozed() && Math.random() < peekChance) { gagPeek(); return }
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

  // `ai` marks an agent line; the bubble dresses it up. `silent` shows the
  // line without speaking it — slap reactions, where the crack plays first
  // and slapSoundDone() un-silences the bubble when it ends.
  function say(text, anim, ai, silent) {
    text = fill(text || "").trim()
    if (text === "") return false
    if (mood === "dead" || mood === "dying" || mood === "reviving" || asleep) return false
    if (listening) return false // his own voice must never end up in the transcript
    walkAnim.stop()
    brain.stop()
    mood = "talking"
    bubble.ai = !!ai
    bubble.silent = !!silent
    bubble.text = text
    bubble.shown = true
    var a = anim && sprite.has(anim) ? anim : randomFrom(talkAnims.filter(sprite.has))
    sprite.play(a || "Explain", false)
    var words = text.split(/\s+/).length
    bubbleTimer.holds = 0
    bubbleTimer.interval = Math.max(4000, words * 450)
    bubbleTimer.restart()
    return true
  }

  function hideBubble() {
    bubbleTimer.stop()
    bubble.shown = false
    if (mood === "talking") {
      mood = "idle"
      if (!dragging && !peeking) schedule(800) // mid-peek the gag owns the beat
    }
    if (!quoteTimer.running && mood !== "dead") scheduleQuote()
    // The peek dwells exactly as long as its bubble lives: any bubble
    // death starts the out-leg. After a slap the recoil already ran, so
    // this side of the rendezvous finishes when the recoil beat the voice.
    if (peeking) {
      if (!peekLeaving) peekOut(350)
      else if (!peekAnim.running) peekFinish()
    }
  }

  function unprompted() {
    if (asleep) return  // wakeUp() reschedules
    scheduleQuote()
    if (mood !== "idle" && mood !== "walking") return
    if (isSnoozed() || dragging || occupied || peeking) return
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
    abortListen()
    peekCancel(false) // dies where he hangs; finishDeath zeroes gagDy, placeGrave clamps
    walkAnim.stop()
    shoveAnim.stop()
    brain.stop()
    quoteTimer.stop()
    bubbleTimer.stop()
    mood = "dying"
    agentBrain.remember(lineKey === "knockedOut" ? "knocked him out with slaps" : "killed him")
    var words = fill(randomLine(lineKey || "lastWords", "Fine. Fuck off then."))
    bubble.ai = false
    bubble.silent = false
    bubble.text = words
    bubble.shown = true
    dieTimer.holds = 0
    dieTimer.interval = 2500
    dieTimer.start()
  }

  function finishDeath() {
    mood = "dead"
    gagDy = 0 // a fling's long drop ends here; the grave stands on the bar
    peekGrown = false // a mid-peek death stayed giant until now
    persisted.killCount++
    bumpLeaderboard(1, 0)
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
    gagAnim.stop()
    peekCancel(false) // belt-and-braces: the kill already cleared it
    peekGrown = false
    gagDy = 0
    if (mood !== "dead") return
    persisted.deadUntil = 0
    if (actor.x < 0 || actor.x > stage.width - actor.width)
      actor.x = Math.round(randomSpot(Math.max(0, stage.width - actor.width)))
    actor.rotation = 0
    var comeback = function () {
      root.mood = "idle"
      root.say(root.randomLine("comeback", "I'm back. Don't act like you didn't miss me."))
    }
    if (gagsEnabled && !asleep && Math.random() < entranceChance) {
      gagEntrance(comeback)
      return
    }
    mood = "reviving"
    sprite.play("Greeting", false, comeback)
  }

  // Clicking the grave gets you the epitaph, spoken from beyond. Not
  // say() — that refuses while dead, rightly; this writes the bubble the
  // way the kill paths do, and the bubble anchors to the grave while he is
  // dead. `{back}` in a line becomes how long until the respawn.
  function epitaph() {
    if (!grave.shown || asleep) return false
    if (bubble.shown) { hideBubble(); return true }
    var q = randomQuoteFrom("epitaph")
    var text = fill((q ? q.text : "Here lies Clippy. You did this.").replace(/\{back\}/g, backText()))
    bubble.ai = false
    bubble.silent = false
    bubble.text = text
    bubble.shown = true
    bubbleTimer.holds = 0
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
    // Mid-peek every swing lands: there is no room to sidestep at a
    // corner, and the dodge's shove writes persisted.lastX.
    if (!peeking && dodgeChance > 0 && Math.random() < dodgeChance) return dodge(dir)
    var now = Date.now()
    var recent = slapTimes.filter(function (t) { return now - t < root.slapWindowMs })
    recent.push(now)
    slapTimes = recent

    persisted.slapCount++
    bumpLeaderboard(0, 1)
    agentBrain.remember("slapped him")
    var fx = playSlapSound()
    walkAnim.stop()
    brain.stop()
    bubbleTimer.stop()
    bubble.shown = false
    if (mood === "walking") sprite.exit()

    if (!peeking) { // the recoil replaces the shove (whose finish writes lastX)
      var maxX = Math.max(0, stage.width - actor.width)
      var distance = rand(50, 120) * (spriteSize / 30)
      shoveAnim.stop()
      shoveAnim.duration = 380
      shoveAnim.to = Math.round(clamp(actor.x + dir * distance, 0, maxX))
      shoveAnim.start()
    }
    wobble.stop()
    wobble.dir = dir
    wobble.start()

    if (slapsToKill > 0 && recent.length >= slapsToKill) {
      slapTimes = []
      kill("knockedOut")
      return true
    }
    var q = randomQuoteFrom("slapped")
    say(q ? q.text : "Ow.", q && q.anim ? q.anim : "Alert", false, !!fx)
    if (fx) { slapWaitFx = fx; slapVoiceCap.restart() }
    // Swatted back into his corner: the recoil starts at once and the
    // bubble rides the live bindings, speaking clamped at the corner
    // until it dies and the rendezvous in hideBubble() restores him.
    if (peeking) peekOut(250)
    return true
  }

  // The miss (v1.39.0): a flat `dodge` chance per slap — a whoosh instead
  // of the crack, no tally, no leaderboard delta, no entry in `slapTimes`
  // (a miss can't add up to a knockout). He sidesteps the way the hand
  // was going, fast (the shove's animation at a fraction of its duration,
  // no wobble — a wobble is the hit landing), flipping to the other side
  // when the edge leaves him no room, and gloats with a `dodged` line that
  // waits for the whoosh the way the slapped line waits for the crack.
  // Returns "dodged" so the IPC verb can say so.
  function dodge(dir) {
    agentBrain.remember("swung at him and missed")
    var fx = playDodgeSound()
    walkAnim.stop()
    brain.stop()
    bubbleTimer.stop()
    bubble.shown = false
    if (mood === "walking") sprite.exit()

    var maxX = Math.max(0, stage.width - actor.width)
    var distance = Math.round(actor.width * 1.2)
    var to = Math.round(clamp(actor.x + dir * distance, 0, maxX))
    if (Math.abs(to - actor.x) < distance / 2) to = Math.round(clamp(actor.x - dir * distance, 0, maxX))
    shoveAnim.stop()
    wobble.stop()
    shoveAnim.duration = 150
    shoveAnim.to = to
    shoveAnim.start()

    var q = randomQuoteFrom("dodged")
    say(q ? q.text : "Missed.", q && q.anim ? q.anim : "GetAttention", false, !!fx)
    if (fx) { slapWaitFx = fx; slapVoiceCap.restart() }
    return "dodged"
  }

  function playSlapSound() { return playOneOf(slapFx) }
  function playFlingSound() { playOneOf(flingFx) }
  function playDodgeSound() { return playOneOf(dodgeFx) }
  function playOneOf(fxs) {
    if (!fxs.count) return null
    var fx = fxs.objectAt(Math.floor(Math.random() * fxs.count))
    if (!fx || fx.status !== SoundEffect.Ready) return null
    fx.play()
    return fx
  }

  // One SoundEffect per file, decoded up front, so a slap lands without a
  // load stall. The built-ins, or the one from `slapSound` / `flingSound` /
  // `dodgeSound`.
  component SoundBank: Instantiator {
    delegate: SoundEffect {
      required property string modelData
      source: modelData
      onStatusChanged: if (status === SoundEffect.Error) console.warn("clippy: can't load sound " + source)
      onPlayingChanged: if (!playing) root.slapSoundDone(this)
    }
  }
  SoundBank { id: slapFx; model: root.slapSounds }
  SoundBank { id: flingFx; model: root.flingSounds }
  SoundBank { id: dodgeFx; model: root.dodgeSounds }

  // The slapped line waits for the crack: slap() shows it silent, and when
  // the chosen SoundEffect finishes — or slapVoiceCap gives up at 2 s (a
  // backend that never flips `playing`, or a re-play of an already-playing
  // effect, which restarts without a false→true toggle) — the bubble is
  // un-silenced; the voice watches the bubble, so that alone starts the
  // line. Identity-guarded (a re-slap replaces slapWaitFx, so a stale
  // finish is ignored; fling sounds land here too and never match) and
  // state-guarded (a dismissed, replaced, dead or asleep bubble stays
  // silent).
  property var slapWaitFx: null
  Timer { id: slapVoiceCap; interval: 2000; onTriggered: root.slapSoundDone(root.slapWaitFx) }
  function slapSoundDone(fx) {
    if (!fx || fx !== slapWaitFx) return
    slapWaitFx = null
    slapVoiceCap.stop()
    if (mood === "talking" && bubble.shown && bubble.silent) bubble.silent = false
  }

  // ---- the voice ----------------------------------------------------------
  // Speaks whatever the bubble shows. Driven by watching the bubble itself
  // (handlers on the Bubble instance) rather than the say paths, so the
  // death lines and the epitaph — which write bubble.text directly — get
  // spoken too, and everything that hides the bubble cuts him off mid-word.
  // One process at a time; a replacement line queues until the old process
  // has actually died, because the SIGTERM is asynchronous.
  property string ttsLine: ""    // what the running process is speaking
  property string ttsQueued: ""  // spoken once the old process has died
  property bool ttsWarned: false // one journal line per engine, not per quote
  function syncSpeech() {
    if (ttsOn && opened && bubble.shown && bubble.text !== "" && !bubble.silent) {
      if (ttsLine === bubble.text && (ttsProc.running || ttsQueued !== "")) return
      ttsLine = bubble.text
      if (ttsProc.running) { ttsQueued = ttsLine; ttsProc.signal(15) }
      else startTts()
    } else stopSpeaking()
  }
  // True while the voice is (or is about to be) speaking the current bubble
  // line: engine running, a replacement parked, or the duck snapshot still
  // in flight ahead of the launch. ttsLine alone isn't enough — a normal
  // exit leaves it holding the finished line.
  function speakingThisBubble() {
    return ttsOn && !bubble.silent && ttsLine === bubble.text
        && (ttsProc.running || ttsQueued !== ""
            || (ducked && duckProc.running && duckProc.action === "start"))
  }
  // IPC replies that would say "ok" while the voice can't be heard say so.
  function ipcOkVoice() { return ttsOn && ttsNeedsEngine ? "ok — but silent: espeak-ng not installed" : "ok" }
  // Voice on/off without losing a custom `tts` command (a clone, a
  // pipeline): turning off a string stashes it in `ttsSaved`, turning on
  // restores the stash. Menu toggle and IPC `set tts true|false` both land
  // here — the menu's old bare set ate Costa's clone command twice. Forcing
  // the espeak robot while a stash exists is `set ttsSaved unset` first.
  function setVoiceEnabled(on) {
    if (on) {
      var saved = String(setting("ttsSaved", "") || "")
      if (saved !== "") { setSettings({ tts: saved, ttsSaved: undefined }); return saved }
      setSetting("tts", true)
      return true
    }
    if (typeof ttsSetting === "string" && ttsSetting !== "")
      setSettings({ tts: false, ttsSaved: ttsSetting })
    else setSetting("tts", false)
    return false
  }
  function stopSpeaking() {
    ttsLine = ""      // cleared first so onExited knows the kill was ours
    ttsQueued = ""
    // signal, not running=false — the latter quietly leaves the child alive
    // (verified with a sleep-30 stand-in engine).
    if (ttsProc.running) ttsProc.signal(15)
  }
  function startTts() {
    // Duck first, speak second: scripts/duck snapshots the streams playing
    // right now and lowers them, so it must run before the engine's own
    // stream exists — the launch continues from duckProc's onExited. A
    // replacement line finds `ducked` already true and skips straight to
    // the engine.
    duckRelease.stop() // a line inside the release window keeps the duck
    // Ducking off skips the fork entirely; a duck already held (the
    // setting flipped mid-window) still gets its restore via duckStop.
    if (!ducked && duckOn) { ducked = true; duckRun("start"); return }
    launchTts()
  }
  function launchTts() {
    // Always through bash: bash itself always starts, so a missing engine is
    // exit 127 in onExited — QProcess swallows a straight fail-to-start and
    // exited would never fire. exec so the kill lands on espeak, not on a
    // wrapper; a custom pipeline keeps its bash and may finish the line.
    // Dead overrides ttsVoice: epitaphs whisper no matter who he was.
    var cmd = typeof ttsSetting === "string" ? ttsSetting
            : "exec espeak-ng -v '" + (mood === "dead" ? "en+whisper" : ttsVoice)
              + "' -s " + ttsSpeed + " -p " + ttsPitch
    // The clone knobs ride here, not in the stored string. Appended last,
    // so on a hand-set command that already carries the flags these win
    // (argparse keeps the final occurrence).
    if (cloneKnobsApply && (cloneTempo !== 1 || clonePitch !== 1))
      cmd += " --tempo " + cloneTempo + " --pitch " + clonePitch
    ttsProc.command = ["bash", "-c", cmd]
    ttsProc.stdinEnabled = true
    ttsProc.running = true
  }
  Process {
    id: ttsProc
    environment: root.voiceCacheEnv // the voice daemon inherits its cache cap
    // Belt and braces for a real unload (plugin disable, shell exit):
    // nothing else kills the child there, and running=false wouldn't either.
    Component.onDestruction: signal(15)
    onStarted: { write(root.ttsLine + "\n"); stdinEnabled = false }
    onExited: function (code) {
      if (code === 0) root.ttsWarned = false // heard again — stop claiming "failing"
      if (root.ttsQueued !== "") {
        root.ttsQueued = ""
        root.startTts() // the duck is held across a replacement line
        return
      }
      duckRelease.restart() // done talking — volumes come back after a beat
      if (code !== 0 && root.ttsLine !== "" && !root.ttsWarned) {
        root.ttsWarned = true
        console.warn("clippy: tts failed (exit " + code + ") — "
          + (typeof root.ttsSetting === "string" ? root.ttsSetting : "is espeak-ng installed?"))
      }
    }
  }

  // ---- ducking ------------------------------------------------------------
  // One process, serialized: a flip that arrives while a duck run is still
  // in flight parks in duckNext instead of clobbering the command. `ducked`
  // is gated on itself so a duck that was issued always gets its restore
  // when the sentence ends.
  property bool ducked: false   // a start has been issued and not yet undone
  property string duckNext: ""
  // The restore waits a beat instead of firing the instant speech ends:
  // PipeWire tears sink-inputs down asynchronously, so a back-to-back
  // line's fresh snapshot could catch the PREVIOUS line's dying stream,
  // duck it, and lose it before the restore — at which point PipeWire's
  // stream-restore memorizes the ducked volume as that app's default,
  // compounding 30 % → 9 % → ~1 % per hit (this silenced the clone's own
  // aplay on Costa's box). A held duck never re-snapshots, so consecutive
  // lines share one duck cycle and the last stream is long gone before
  // any future snapshot.
  Timer {
    id: duckRelease
    interval: 1000
    onTriggered: root.duckStop()
  }
  function duckStop() {
    if (!ducked) return
    ducked = false
    duckRun("stop")
  }
  function duckRun(action) {
    if (duckProc.running) { duckNext = action; return }
    duckProc.action = action
    duckProc.command = [pluginDir + "/scripts/duck", action, String(duckFactor)]
    duckProc.running = true
  }
  Process {
    id: duckProc
    property string action: ""
    // Heal on mount: a shell death mid-sentence leaves the snapshot file
    // standing and everyone quiet; `duck stop` restores it, and is a no-op
    // when there is nothing to restore.
    Component.onCompleted: { action = "stop"; command = [root.pluginDir + "/scripts/duck", "stop"]; running = true }
    onExited: {
      if (root.duckNext !== "") {
        var next = root.duckNext
        root.duckNext = ""
        root.duckRun(next)
        return
      }
      if (action !== "start") return
      // The line this duck was for may already be gone (bubble hidden while
      // the snapshot ran) — restore instead of speaking into it.
      if (root.ttsLine === "") duckRelease.restart()
      else if (!ttsProc.running) root.launchTts()
    }
  }

  // Agent lines are novel text, so the clone cache never has them ready at
  // speak time — each would trail the bubble by the ~2 s a fresh render
  // costs. They do sit in AgentBrain for up to 20 minutes first, so render
  // them the moment a batch lands (warm-voice --lines, silent, over the
  // daemon socket). speak-clone only: espeak and other custom commands have
  // no cache to warm. While the warm runs a live novel line queues behind
  // it on the daemon, but the only still-novel lines are the ones being
  // warmed, so that resolves itself in seconds.
  property var warmQueued: []
  function warmAgentLines(lines) {
    if (!ttsOn || typeof ttsSetting !== "string" || ttsSetting.indexOf("speak-clone") === -1) return
    if (warmProc.running) { warmQueued = warmQueued.concat(lines); return }
    warmProc.command = [pluginDir + "/scripts/warm-voice", "--lines"].concat(lines)
    warmProc.running = true
  }
  // The book itself is warmed by the plugin, not by the user: whenever the
  // live voice becomes a speak-clone command (mount, useVoice, set tts,
  // setup-voice's set) the whole book is rendered into the cache in the
  // background, so a fresh clone's slap reaction doesn't land 2 s late.
  // The cache is keyed by the sample's contents and pruned least-recently-
  // played-first (voiceCacheMb), with every warm pass counting as a play,
  // so a voice warmed once stays warm; with a full cache this is a ~0.3 s
  // no-op, which is why it can run on every mount without a flag. The
  // command is handed over explicitly (--tts) so the warm can't race the
  // settings write, and a warm in flight for the previous voice is killed
  // first — it would be rendering the wrong reference. Separate from
  // warmProc so a 10-20 minute book never blocks an agent batch's --lines.
  readonly property bool warmingBook: warmBookProc.running
  property bool warmBookSuperseded: false
  function warmBook() {
    var cmd = ttsSetting
    if (warmBookProc.running) { warmBookSuperseded = true; warmBookProc.running = false }
    if (typeof cmd !== "string" || cmd.indexOf("speak-clone") === -1) return
    warmBookProc.command = [pluginDir + "/scripts/warm-voice", "--tts", cmd]
    warmBookProc.running = true
  }
  Process {
    id: warmBookProc
    environment: root.voiceCacheEnv // a warm may be what spawns the daemon
    stderr: StdioCollector { id: warmBookErr }
    stdout: StdioCollector { id: warmBookOut }
    onExited: function (code) {
      // Our own kill on a voice change exits 15 (SIGTERM) — not a failure.
      if (root.warmBookSuperseded) { root.warmBookSuperseded = false; console.log("clippy: book warm superseded by a voice change"); return }
      if (code !== 0)
        console.warn("clippy: book warm failed (exit " + code + "): " + String(warmBookErr.text).trim())
      else
        console.log("clippy: book warm — " + String(warmBookOut.text).trim().split("\n").pop())
    }
    Component.onCompleted: root.warmBook()
  }
  Process {
    id: warmProc
    environment: root.voiceCacheEnv // a warm may be what spawns the daemon
    stderr: StdioCollector { id: warmErr }
    onExited: function (code) {
      // Not-a-speak-clone is gated before the spawn, so nonzero is real.
      if (code !== 0)
        console.warn("clippy: warm-voice failed (exit " + code + "): " + String(warmErr.text).trim())
      if (root.warmQueued.length) {
        var queued = root.warmQueued
        root.warmQueued = []
        root.warmAgentLines(queued)
      }
    }
  }

  // ---- leaderboard --------------------------------------------------------
  // Default-on bragging: every slap and kill is POSTed as a delta to the
  // public graveyard — a handle and two small numbers, nothing else. Unset
  // means the shared anonymous stone (one alias for every install, so
  // nothing identifies anyone); "off" is the only silence; a handle claims
  // a stone of your own. Handles are claim-free: the server merges
  // collisions and an IPC while-loop is an instant world record, which is
  // fine — every score was self-reported murder to begin with. The flush is
  // the duckProc park-don't-clobber idiom (deltas accumulate while a POST
  // is in flight, so a beating coalesces), a failure puts the sent deltas
  // back and backs off like AgentBrain's topUp. Pending deltas die with the
  // shell — the same trade the tally itself makes.
  readonly property string leaderboardUrl: "https://graveyard.costafotiadis.com"
  readonly property string lbAnonHandle: "anonymous-clippy-abuser"
  readonly property string lbSetting: String(setting("leaderboard", "") || "").trim().toLowerCase()
  readonly property bool leaderboardOff: lbSetting === "off"
  readonly property bool leaderboardNamed: !leaderboardOff && lbSetting !== ""
  readonly property string leaderboardHandle: leaderboardOff ? "" : (leaderboardNamed ? lbSetting : lbAnonHandle)
  readonly property bool leaderboardOn: !leaderboardOff
  property int lbPendingKills: 0
  property int lbPendingSlaps: 0
  property int lbSentKills: 0
  property int lbSentSlaps: 0
  property int lbFailures: 0
  property var lbCache: null // last /bump reply: {handle, kills, slaps, rank, total}
  // curl missing means the Process never starts and onExited never fires
  // (the espeak lesson), so it has to be probed and said out loud.
  property bool lbCurlMissing: false
  Process {
    id: lbProbe
    command: ["bash", "-c", "command -v curl >/dev/null"]
    onExited: function (code) { root.lbCurlMissing = code !== 0 }
    Component.onCompleted: running = true
  }
  // A handle change announces itself with a zero-delta bump: the stone
  // appears on the page at once and the reply fills lbCache with the rank.
  // maybeBoot can run before shellConfig delivers the entry — flush is
  // gated on settingsLoaded, a named/off value arriving fires the change
  // handler below, and an unset one changes nothing, so this handler
  // announces the anonymous default. Asleep is wakeUp's flush to re-run.
  // Turning off just stops posting — claim-free has no delete. Every mount
  // re-announces from maybeBoot for the same cache refill (default-on means
  // that includes the shared anonymous stone).
  onLeaderboardHandleChanged: {
    lbCache = null
    lbFailures = 0
    lbRetry.stop()
    if (leaderboardOn) { lbProbe.running = true; flushLeaderboard(true) }
  }
  onSettingsLoadedChanged: if (settingsLoaded && booted && !asleep && leaderboardOn) flushLeaderboard(true)
  // A forced flush that lands while a POST is in flight parks here instead
  // of being dropped — before this, the mount announce could swallow the
  // handle-change announce and leave lbCache showing the wrong stone.
  property bool lbFlushQueued: false
  function bumpLeaderboard(kills, slaps) {
    if (!leaderboardOn) return
    lbPendingKills += kills
    lbPendingSlaps += slaps
    flushLeaderboard(false)
  }
  // The menu toggle and `set leaderboard true|false|off`. Mirrors
  // setVoiceEnabled: turning off parks a named handle in `leaderboardSaved`
  // so the toggle never eats it; turning on restores the stash, else lands
  // on the anonymous default. One setSettings write each way.
  function setLeaderboardEnabled(on) {
    if (on) {
      var saved = String(setting("leaderboardSaved", "") || "").trim().toLowerCase()
      if (/^[a-z0-9_.-]{1,24}$/.test(saved) && saved !== "off")
        return setSettings({ leaderboard: saved, leaderboardSaved: undefined })
      return setSetting("leaderboard", undefined)
    }
    if (leaderboardNamed) return setSettings({ leaderboard: "off", leaderboardSaved: lbSetting })
    return setSetting("leaderboard", "off")
  }
  function flushLeaderboard(force) {
    if (!settingsLoaded || !leaderboardOn || lbCurlMissing) return
    if (lbProc.running) { lbFlushQueued = lbFlushQueued || force; return }
    if (!force && lbPendingKills === 0 && lbPendingSlaps === 0) return
    lbSentKills = lbPendingKills
    lbSentSlaps = lbPendingSlaps
    lbPendingKills = 0
    lbPendingSlaps = 0
    var body = JSON.stringify({ handle: leaderboardHandle, kills: lbSentKills, slaps: lbSentSlaps })
    // The server's doorman: /bump only answers to this User-Agent prefix.
    var ua = "costafot.clippy/" + (manifest && manifest.version ? manifest.version : "dev")
    lbProc.command = ["curl", "-fsS", "-m", "10", "-A", ua, "-H", "content-type: application/json", "-d", body, leaderboardUrl + "/bump"]
    lbProc.running = true
  }
  Process {
    id: lbProc
    stdout: StdioCollector { id: lbOut }
    stderr: StdioCollector { id: lbErr }
    onExited: function (code) {
      if (code === 0) {
        try { root.lbCache = JSON.parse(lbOut.text) } catch (e) { /* the POST still landed */ }
        root.lbSentKills = 0
        root.lbSentSlaps = 0
        root.lbFailures = 0
        var again = root.lbFlushQueued
        root.lbFlushQueued = false
        root.flushLeaderboard(again) // deltas (or a parked announce) that accumulated mid-flight
        return
      }
      root.lbPendingKills += root.lbSentKills
      root.lbPendingSlaps += root.lbSentSlaps
      root.lbSentKills = 0
      root.lbSentSlaps = 0
      if (root.lbFailures === 0)
        console.warn("clippy: leaderboard POST failed (curl exit " + code + "): "
          + String(lbErr.text).trim() + " — holding the deltas, backing off")
      root.lbFailures = Math.min(6, root.lbFailures + 1)
      lbRetry.interval = 30000 * Math.pow(2, root.lbFailures - 1)
      lbRetry.restart()
    }
  }
  Timer {
    id: lbRetry
    // Gated like AgentBrain.paused: no curl into a lock screen. Re-arms
    // instead of dropping, so held deltas still flush after a long lock.
    onTriggered: root.asleep ? lbRetry.restart() : root.flushLeaderboard(true)
  }

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

  // ---- gags --------------------------------------------------------------
  // Vertical stunts on the full-screen stage. All y motion is this one
  // additive offset on the actor's feet-line binding (the Tombstone thud
  // pattern): a gag animates gagDy and ends — or is aborted — at 0, which
  // is the return-to-the-bar guarantee. Nothing persists it, so a remount
  // lands him back on the feet line for free.
  property real gagDy: 0
  // How often a revive turns into the skyfall. A constant, not a setting:
  // the on/off taste call is the `gags` key, the odds are ours.
  readonly property real entranceChance: 0.35

  NumberAnimation {
    id: gagAnim
    target: root
    property: "gagDy"
    to: 0
    // Never overshoots, so he can't clip through the far screen edge —
    // and the landing bounce reads as hitting the bar either way up.
    easing.type: Easing.OutBounce
    property var landed: null
    onFinished: { var f = landed; landed = null; if (f) f() }
  }

  // The skyfall: he enters from the far screen edge — falls the whole
  // screen onto a bottom bar, shoots up at a top one — and bounces onto
  // his feet line, waving the whole way. Runs inside "reviving", so every
  // existing gate (say, slap, grab, decide, fling) refuses for free.
  // `onLanded` runs after mood is back to idle; null settles him into the
  // idle loop quietly (the IPC test path — no line, see the gag verb).
  function gagEntrance(onLanded) {
    walkAnim.stop()
    shoveAnim.stop()
    wobble.stop()
    brain.stop()
    quoteTimer.stop()
    mood = "reviving"
    gagAnim.stop()
    gagDy = barBottom ? -stage.height : stage.height
    gagAnim.duration = Math.round(clamp(stage.height * 0.7, 600, 1100))
    gagAnim.landed = function () {
      root.mood = "idle"
      if (onLanded) onLanded()
      else { root.idleAnim(); root.scheduleQuote() }
    }
    sprite.play("Wave", true)
    gagAnim.start()
  }

  // The corner peek (v1.44.0): he slides half-in from a far-edge corner,
  // says a line, dwells while the bubble lives, slides back out. `peeking`
  // — not mood — is the truth here: mood goes idle→talking when he speaks
  // mid-peek (the entrance's "reviving" trick would make say() and slap()
  // refuse, and the peek needs both). The vertical never animates: gagDy
  // is set to the far edge while he is fully off-stage (the teleport is
  // invisible), and both legs are one NumberAnimation on actor.x.
  property bool peeking: false
  property bool peekLeaving: false // the out-leg has started
  property real peekReturnX: 0     // his bar spot, restored after — never a corner x
  // He peeks in BIG — at bar size he was an unslappable speck in the
  // corner. A separate flag (not `peeking ? …` on the sprite) so a
  // mid-peek death keeps the giant through the whole choreography;
  // finishDeath() clears it the way it zeroes gagDy. The multiplier is
  // ours, the entranceChance rule.
  property bool peekGrown: false
  readonly property real peekSize: clamp(spriteSize * 5, 140, 400)
  // Chance an idle beat turns into a peek (the dodge reader: 0 = never,
  // true = every beat, a non-number falls back to the default).
  readonly property real peekChance: {
    var v = setting("peekChance", 0.04)
    var n = v === true ? 1 : Number(v)
    return clamp(isNaN(n) ? 0.04 : n, 0, 1)
  }

  NumberAnimation {
    id: peekAnim
    target: actor
    property: "x"
    property var done: null
    onFinished: { var f = done; done = null; if (f) f() }
  }
  // Fallback dwell only for the say-that-failed corner (empty pool): no
  // bubble will ever hide to end the peek, so this does.
  Timer { id: peekDwell; onTriggered: root.peekOut(350) }

  function gagPeek() {
    walkAnim.stop()
    shoveAnim.stop()
    wobble.stop()
    brain.stop()
    quoteTimer.stop()
    peeking = true
    peekLeaving = false
    peekReturnX = actor.x // a bar coordinate: only reachable from idle
    peekGrown = true      // before the geometry below: it reads the big dims
    var left = Math.random() < 0.5
    gagDy = (barBottom ? -1 : 1) * (stage.height - actor.height)
    actor.x = left ? -actor.width : stage.width
    // The vertical Look reads right from either far corner and sidesteps
    // the character-mirroring question the side Looks raise (IDEAS.md).
    var look = barBottom ? "LookDown" : "LookUp"
    sprite.play(sprite.has(look) ? look : "RestPose", true)
    peekAnim.stop()
    peekAnim.duration = 450
    peekAnim.easing.type = Easing.OutCubic
    // Nearly all the way out (a corner still bites his last 10%): the
    // swipe judge wants a travel of 60% of his width, so a half-in peek
    // was mathematically unswipeable — the pointer only reports over him.
    peekAnim.to = left ? Math.round(-actor.width * 0.10) : Math.round(stage.width - actor.width * 0.90)
    peekAnim.done = function () {
      var q = root.nextQuote()
      if (!q || !root.say(q.text, look, q.ai)) { peekDwell.interval = 2500; peekDwell.restart() }
    }
    peekAnim.start()
  }

  // The dwell is the bubble's lifecycle — hideBubble() starts this leg
  // when the line dies (timer, click dismissal, shutUp). A slap recoils
  // through here too, faster, with the bubble still up: the restore then
  // waits for the bubble (the two-sided rendezvous with hideBubble).
  function peekOut(ms) {
    peekLeaving = true
    peekDwell.stop()
    peekAnim.stop()
    peekAnim.duration = ms
    peekAnim.easing.type = Easing.InCubic
    peekAnim.to = actor.x + actor.width / 2 < stage.width / 2 ? -actor.width : stage.width
    peekAnim.done = function () { if (!bubble.shown) root.peekFinish() }
    peekAnim.start()
  }

  // Deliberately does NOT write persisted.lastX — peekReturnX came from a
  // spot lastX already knows.
  function peekFinish() {
    peeking = false
    peekLeaving = false
    peekGrown = false // back to bar size before the x clamp reads his width
    peekAnim.done = null
    peekAnim.stop()
    peekDwell.stop()
    gagDy = 0
    actor.x = Math.round(clamp(peekReturnX, 0, Math.max(0, stage.width - actor.width)))
    wobble.stop() // a mid-peek slap's wobble may still be settling
    actor.rotation = 0
    sprite.exit()
    mood = "idle"
    schedule(rand(400, 1500))
    if (!quoteTimer.running) scheduleQuote()
  }

  // Interrupt teardown (sleep, kill, remount, screen change). restore=false
  // leaves x and gagDy for a death choreography in progress: he dies where
  // he hangs, finishDeath() zeroes gagDy and placeGrave() clamps — the
  // fling-grave behavior.
  function peekCancel(restore) {
    if (!peeking) return
    peekAnim.done = null
    peekAnim.stop()
    peekDwell.stop()
    peeking = false
    peekLeaving = false
    if (restore) {
      peekGrown = false // restore=false keeps the giant: he dies the size he was slapped at
      gagDy = 0
      actor.x = Math.round(clamp(peekReturnX, 0, Math.max(0, stage.width - actor.width)))
      actor.rotation = 0
    }
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
    if (!dragEnabled || dragging || peeking) return false // drop() writes lastX
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
    dragTalk.interval = Math.round(rand(5000, 9000))
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
    // Mid-peek refused: flingFall.from = 0 would snap gagDy out from
    // under him, and the only route here then is IPC (drag is refused).
    if (mood === "dead" || mood === "dying" || mood === "reviving" || peeking) return false
    abortListen()
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
    bubble.silent = false
    bubble.text = fill(randomLine("flung", "Noooooooooooooooooooooooooooo"))
    bubble.shown = true
    var to = dir > 0 ? stage.width + actor.width : -actor.width * 2
    flingHold.holds = 0
    flingHold.interval = root.flingHoldMs // the wait-for-voice re-arm overwrote the binding
    flingAnim.stop()
    flingX.to = to
    flingSpin.to = dir * 540
    flingFall.from = 0
    flingFall.to = !barBottom && gagsEnabled ? stage.height : 0
    flingAnim.duration = Math.round(clamp(Math.abs(to - actor.x) / 1.4, 600, 1600))
    flingAnim.start()
    return true
  }

  readonly property int flingHoldMs: 1500
  readonly property int flingEchoMs: 1500
  Timer {
    id: flingHold
    interval: root.flingHoldMs
    property int holds: 0
    onTriggered: {
      if (root.mood !== "dying") return
      if (root.speakingThisBubble() && holds < 60) { holds++; interval = 500; restart(); return }
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
    // The long drop (gags): a throw off a top bar also plummets the whole
    // screen. Bottom bar or gags off leaves to at 0 — a no-op, the flat
    // sideways exit. finishDeath() zeroes gagDy either way.
    NumberAnimation { id: flingFall; target: root; property: "gagDy"; duration: flingAnim.duration; easing.type: Easing.InQuad }
    onFinished: if (root.mood === "dying") flingHold.start()
  }

  function complain(key, fallback, anim) {
    var q = randomQuoteFrom(key)
    say(q ? q.text : fallback, q && q.anim ? q.anim : anim)
  }

  // Another line every few seconds while he's still being carried. 5-9 s,
  // not shorter: clone lines run 3-5 s, and a tighter beat cuts every one
  // mid-word.
  Timer {
    id: dragTalk
    repeat: true
    onTriggered: {
      if (!root.dragging) { stop(); return }
      root.complain("dragged", "Put me down.", "GetAttention")
      interval = Math.round(root.rand(5000, 9000))
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
    ttsProbe.running = true // the Voice row's espeak state, kept fresh
    voxProbe.running = true // the "Say it to his face" row's ears, same idea
    voiceScan.running = true // and the picker's inventory (fresh after a setup-voice run)
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
    // The way in for a blind agent: every verb, one per line. Quickshell's
    // "Function not found" names nothing, so this has to be guessable.
    function help(): string {
      return [
        "omarchy-shell costafot.clippy <verb> [args] — args are strings",
        "say <text> — a line in his bubble (spoken if the voice is on)",
        "talk — a line of his own choosing; shutUp drops the bubble",
        "look — he screenshots his screen and your agent delivers the verdict in his bubble ~10 s later (needs ai true)",
        "listen — toggle the mic: he transcribes you locally (voxtype) and your agent fires the comeback back (needs ai true)",
        "reply <text> — the typed version of listen; same comeback, no mic",
        "slap left|right — hit him (answers dodged when he slips it); fling left|right — off the bar, fatal",
        "kill / respawn — the deliberate versions",
        "gag entrance|peek — the skyfall re-entry, or a corner peek: half-in from a far corner, one line, back out (revives roll the entrance; idle beats roll the peek at peekChance)",
        "epitaph — poke the grave while he's dead",
        "snooze <minutes> / unsnooze",
        "show / hide / toggle — show also revives him",
        "showMenu / hideMenu — the right-click menu, no pointer needed",
        "state / stats — what he's doing, the lifetime tally",
        "ai / voice — the agent lines and the voice; each answers with what's wrong and the fix",
        "voices / useVoice <name> — every voice installed on this machine, switching to one, and how to add a new one (clone anyone from a 10-20 s clip)",
        "leaderboard — the public graveyard: posting state, rank and the page (default: the shared anonymous stone; set leaderboard <handle> claims yours, off stops posting)",
        "set <key> <value> / get <key> / settings — the config; settings lists every key, unset restores a default",
        "any verb drops into a Hyprland bind: bindd = SUPER SHIFT C, T, Clippy talks, exec, omarchy-shell costafot.clippy talk",
        "docs: " + root.pluginDir + "/docs/ — scripting.md is every verb with examples, configuration.md every key with its default",
        "online: https://costafot.github.io/omarchy-inappropriate-clippy/"
      ].join("\n")
    }
    function say(text: string): string { return !root.opened ? "hidden" : root.asleep ? "asleep" : (root.say(text) ? root.ipcOkVoice() : "not now") }
    // A line of his own choosing: what a left-click does.
    function talk(): string { var q = root.nextQuote(); return q && root.say(q.text, q.anim, q.ai) ? root.ipcOkVoice() : "not now" }
    // Screenshot his screen, one jab from the agent about what's on it.
    // Async: the reply is immediate, the verdict lands in the bubble.
    function look(): string { return root.lookAtScreen() }
    // Toggle the mic: voxtype transcribes the take locally, the agent fires
    // back. Async like `look` — the comeback lands in the bubble.
    function listen(): string { return root.toggleListen() }
    // The typed version: same comeback plumbing, no mic.
    function reply(text: string): string {
      text = String(text || "").trim()
      if (text === "") return "say something — reply needs words"
      if (!root.opened) return "hidden"
      if (root.asleep) return "asleep"
      if (root.mood === "dead" || root.mood === "dying" || root.mood === "reviving") return "dead — he hears nothing from the grave; respawn first"
      if (root.peeking) return "not now"
      if (!root.aiEnabled) { root.sayNoBrain(); return "off — the comeback runs through your coding agent; set ai true first (he told you himself)" }
      if (root.looking) return "busy — he's judging the screen; wait for the verdict"
      if (root.listening) return "busy — the mic is live; he's listening, not reading"
      if (root.replying) return "busy — still cooking the last comeback"
      root.sendReply(text)
      return "ok — thinking; the comeback lands in his bubble in ~10 s"
    }
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
      var r = root.slap(dir)
      return r === "dodged" ? "dodged" : r ? "ok" : (root.slapEnabled ? "not now" : "off")
    }
    // `gag entrance|peek`: the stunts on demand — the organic rolls aren't
    // pointer-testable and an agent should get to run one at will. The
    // forced entrance says no line on landing (the comeback book assumes a
    // death happened); the forced peek speaks like the organic one — its
    // line is the ordinary quotes pool, always valid.
    function gag(name: string): string {
      var n = String(name || "").toLowerCase()
      if (n !== "entrance" && n !== "peek") return "no such gag — the set: entrance, peek"
      if (!root.gagsEnabled) return "off — set gags true first"
      if (!root.opened) return "hidden"
      if (root.asleep) return "asleep"
      if (root.mood === "dead")
        return n === "entrance"
          ? "dead — respawn does it, with a " + Math.round(root.entranceChance * 100) + "% chance"
          : "dead — respawn him first"
      if (root.mood !== "idle" || root.dragging || root.occupied || root.peeking) return "not now"
      if (n === "entrance") root.gagEntrance(null)
      else root.gagPeek()
      return "ok"
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
    // What the agent side is doing: "off", or "<agent>: N cached[, busy]",
    // plus what the last `look` or `listen`/`reply` is up to.
    function ai(): string {
      if (!root.aiEnabled) return "off"
      var s = agentBrain.status()
      if (root.looking) s += "; looking at the screen right now"
      else if (root.listening) s += "; the mic is live — he's listening (15 s cap)"
      else if (root.replying) s += "; heard them, cooking the comeback"
      else if (root.lookFailed) s += "; the last screen look failed (journalctl --user -o cat | grep clippy)"
      else if (root.replyFailed) s += "; the last comeback failed (journalctl --user -o cat | grep clippy)"
      if (root.promptFile !== "")
        s += root.promptFileMissing
          ? "; custom prompt: " + root.promptFile + " — unreadable or empty, so the BUILT-IN character is running (fix the path, or set promptFile unset)"
          : "; custom prompt: " + root.promptFile + " (replaces his whole character)"
      return s
    }
    // Agent-first status for the voice: what `tts` resolves to and whether
    // it can actually be heard right now.
    function voice(): string {
      if (!root.ttsOn) {
        var saved = String(root.setting("ttsSaved", "") || "")
        if (saved !== "") return "off — set tts true restores the saved custom voice: " + saved
        return "off — `voices` lists what's installed (useVoice <name> switches), scripts/setup-voice in the plugin dir installs real ones (--clone <sample.wav> clones any voice, GPU required)"
      }
      var s = typeof root.ttsSetting === "string"
            ? "custom command: " + root.ttsSetting
              + (root.cloneKnobsApply && (root.cloneTempo !== 1 || root.clonePitch !== 1)
                 ? " — bent by cloneTempo " + root.cloneTempo + " / clonePitch " + root.clonePitch
                 : "")
              + (root.ttsSetting.indexOf("speak-clone") !== -1
                 ? (root.warmingBook ? " — pre-rendering the book for this voice in the background right now (10-20 min of GPU, once per voice, automatic; he's usable meanwhile, an uncached line just takes ~2 s)" : "")
                   + " (clone wavs live in ~/.local/share/chatterbox-tts/voices — useVoice <name> switches; new voices: scripts/setup-voice; cloneTempo/clonePitch bend speed and pitch, factors around 1)"
                 : "")
            : (root.ttsEngineMissing
               ? "espeak-ng: not installed — silent (sudo pacman -S espeak-ng, or set tts to a shell command)"
               : "espeak-ng: ready — " + root.ttsVoice + ", " + root.ttsSpeed + " wpm, pitch " + root.ttsPitch
                 + " (a better voice: scripts/setup-voice in the plugin dir)")
      if (root.ttsWarned) s += "; failing, see journal"
      if (ttsProc.running) s += "; speaking"
      s += root.duckOn
        ? "; other audio ducks to " + Math.round(root.duckFactor * 100) + "% of its volume while he talks"
        : "; ducking is off — other audio keeps its volume"
      return s
    }
    // The whole voice inventory, for agents: what's active, what's on disk
    // (useVoice-able right now), and where new voices come from.
    function voices(): string {
      voiceScan.running = true // async — this reply is the last scan, the next one is fresh
      var inv = root.voiceInv
      var lines = []
      lines.push("active: " + root.currentVoiceId
        + (typeof root.ttsSetting === "string" ? " — set tts holds: " + root.ttsSetting : ""))
      lines.push("installed — switch with useVoice <name>: " + root.voiceOptions.join(", "))
      if (!inv.espeak) lines.push("note: robot needs espeak-ng, which isn't installed")
      if ((inv.clones || []).length > 0 && !inv.gpu) lines.push("note: clone wavs exist but there's no NVIDIA GPU to synthesize on — not offered")
      lines.push("more voices: scripts/setup-voice in " + root.pluginDir
        + " — bare ships a Rubick clone on an NVIDIA GPU (else robot george), a kokoro/piper name installs that voice, --clone <sample> <name> [--from M:SS --to M:SS] clones anything from 10-20 s of clean speech, cut out of any audio/video ffmpeg reads and loudness-normalised for you (GPU); the book is pre-rendered in the background for every clone")
      lines.push("drop-ins: a file at ~/.local/share/clippy-voices/<name> whose first non-comment line is a shell command (line on stdin) shows up here by name")
      lines.push("raw: set tts <shell command handed each line on stdin> | true (espeak) | false")
      return lines.join("\n")
    }
    // Switch to an installed voice by name. Answers with the fix when it
    // can't (not installed, no GPU, unknown name).
    function useVoice(name: string): string { return root.applyVoice(name) }
    function state(): string {
      if (!root.opened) return "hidden"
      if (root.asleep) return "asleep"
      if (root.mood === "dead") return "dead"
      if (root.isSnoozed()) return "snoozed"
      if (root.peeking) return "peeking"
      return root.mood
    }
    // What the menu's footer shows.
    function stats(): string {
      return root.slapCount + (root.slapCount === 1 ? " slap, " : " slaps, ")
        + root.killCount + (root.killCount === 1 ? " kill" : " kills")
    }
    // Agent-first status for the graveyard: who he posts as, the rank the
    // last reply carried, and whatever is currently wrong.
    function leaderboard(): string {
      if (root.leaderboardOff)
        return "off — nothing is posted; set leaderboard unset posts anonymously (the shared '" + root.lbAnonHandle
          + "' stone), set leaderboard <handle> (1-24 of a-z 0-9 _ . -) claims your own: " + root.leaderboardUrl
      var s = root.leaderboardNamed
        ? "posting as " + root.leaderboardHandle
        : "posting anonymously to the shared '" + root.lbAnonHandle + "' stone (set leaderboard <handle> claims your own, off stops posting)"
      var c = root.lbCache
      if (c && c.rank)
        s += ": #" + c.rank + " of " + c.total + " with " + c.kills + (c.kills === 1 ? " kill, " : " kills, ")
          + c.slaps + (c.slaps === 1 ? " slap" : " slaps")
      else
        s += " — no reply from the graveyard yet"
      s += " — " + root.leaderboardUrl
      var held = root.lbPendingKills + root.lbSentKills + root.lbPendingSlaps + root.lbSentSlaps
      if (root.lbCurlMissing) s += "; curl isn't installed, so nothing is being posted"
      else if (root.lbFailures > 0) s += "; unreachable — holding " + held + (held === 1 ? " delta" : " deltas") + ", retrying"
      return s
    }
    // The settings, same keys as shell.json and the menu: `set clean true`,
    // `set size 40`, `set aiModel unset`. Writes shell.json, so we remount.
    function set(key: string, value: string): string {
      key = String(key || "")
      if (!root.isSettingKey(key)) return "unknown key " + key + "; one of " + Object.keys(root.settingDefaults).join(", ")
      var parsed = root.parseSettingValue(value)
      if (key === "tts") {
        // true/false take the stash/restore path (see setVoiceEnabled);
        // an explicit command string supersedes any stash.
        if (parsed === true || parsed === false) {
          var wasCustom = typeof root.ttsSetting === "string" && root.ttsSetting !== ""
          var landed = root.setVoiceEnabled(parsed)
          if (parsed === false && wasCustom)
            return "ok — voice off; the custom command is kept in ttsSaved, set tts true restores it"
          if (parsed === true && typeof landed === "string")
            return "ok — restored the custom voice: " + landed + " (for the espeak robot instead: set ttsSaved unset, then set tts true)"
          if (parsed === true && root.ttsEngineMissing)
            return "ok — but espeak-ng isn't installed, so he stays silent until it is (or set tts to a shell command)"
          return "ok"
        }
        var wasTts = root.ttsSetting
        var changes = typeof parsed === "string" ? { tts: parsed, ttsSaved: undefined } : { tts: parsed }
        if (!root.setSettings(changes)) return "can't write shell.json"
        if (typeof parsed === "string" && parsed.indexOf("speak-clone") !== -1 && parsed !== wasTts)
          return "ok — new clone voice: pre-rendering the book for it in the background (10-20 min of GPU, once; `voice` says when it's done)"
        return "ok"
      }
      if (key === "leaderboard") {
        // Default-on: unset is the shared anonymous stone, "off" the only
        // silence, a handle a stone of your own. Booleans toggle like the
        // menu row (replies read pre-write state — the settings binding
        // may not have updated within this call).
        if (parsed === false || parsed === "off") {
          var wasNamed = root.leaderboardNamed
          if (!root.setLeaderboardEnabled(false)) return "can't write shell.json"
          return "ok — off; nothing is posted"
            + (wasNamed ? " (your handle is parked in leaderboardSaved; set leaderboard true restores it)" : "")
            + " — the graveyard keeps what was already posted (handles are claim-free, there is no delete)"
        }
        if (parsed === true) {
          var stash = String(root.setting("leaderboardSaved", "") || "").trim().toLowerCase()
          if (!root.setLeaderboardEnabled(true)) return "can't write shell.json"
          var who = /^[a-z0-9_.-]{1,24}$/.test(stash) && stash !== "off" ? stash : root.lbAnonHandle
          if (root.lbCurlMissing) return "ok — but curl isn't installed, so nothing gets posted"
          return "ok — posting as " + who + "; the graveyard: " + root.leaderboardUrl
        }
        if (parsed === undefined) {
          if (!root.setSetting(key, undefined)) return "can't write shell.json"
          return "ok — posting anonymously to the shared '" + root.lbAnonHandle
            + "' stone (the default; set leaderboard <handle> claims your own, set leaderboard off stops posting)"
        }
        var handle = String(parsed).trim().toLowerCase()
        if (!/^[a-z0-9_.-]{1,24}$/.test(handle)) return "no — a handle is 1-24 of a-z 0-9 _ . - (it lands lowercased)"
        if (!root.setSettings({ leaderboard: handle, leaderboardSaved: undefined })) return "can't write shell.json"
        if (root.lbCurlMissing) return "ok — but curl isn't installed, so nothing gets posted"
        return "ok — posting as " + handle + "; the graveyard: " + root.leaderboardUrl + " (`leaderboard` reports your rank)"
      }
      if (key === "duck") {
        // Booleans take the menu toggle's stash/restore path; a number is
        // the fraction of volume other audio keeps while he talks (the
        // ratio is IPC-only — no chips in the menu, Costa's call).
        if (parsed === false) {
          if (!root.setDuckEnabled(false)) return "can't write shell.json"
          return "ok — ducking off; other audio keeps its volume while he talks (a custom ratio is parked in duckSaved; set duck true restores it)"
        }
        if (parsed === true) {
          var duckStash = root.setting("duckSaved", undefined)
          if (!root.setDuckEnabled(true)) return "can't write shell.json"
          var restored = typeof duckStash === "number" ? root.clamp(duckStash, 0, 1) : 0.8
          return "ok — other audio drops to " + Math.round(restored * 100) + "% of its volume while he talks"
        }
        if (parsed === undefined) {
          if (!root.setSetting(key, undefined)) return "can't write shell.json"
          return "ok — the default: other audio drops to 80% of its volume while he talks"
        }
        if (typeof parsed !== "number") return "no — duck is 0-1 (the fraction of volume other audio keeps while he talks), or true/false"
        var duckVal = root.clamp(parsed, 0, 1)
        if (!root.setSettings({ duck: duckVal, duckSaved: undefined })) return "can't write shell.json"
        if (duckVal >= 1) return "ok — 1 is no duck; other audio keeps its volume while he talks"
        return "ok — other audio drops to " + Math.round(duckVal * 100) + "% of its volume while he talks"
          + (root.ttsOn ? "" : " (tts is off, so nothing talks yet)")
      }
      if (key === "voiceCacheMb" && parsed !== undefined && (typeof parsed !== "number" || parsed < 0))
        return "no — voiceCacheMb is a size in MB, 0 for no cap"
      if (!root.setSetting(key, parsed)) return "can't write shell.json"
      if (key === "voiceCacheMb" && parsed !== undefined)
        return (parsed === 0 ? "ok — no cap; the voice line cache grows unpruned"
          : "ok — the voice line cache trims least-recently-played renders past " + Math.round(parsed) + " MB")
          + " (applies from the voice daemon's next start; it exits after 15 idle minutes)"
      if (key === "ttsVoice" || key === "ttsSpeed" || key === "ttsPitch") {
        if (typeof root.ttsSetting === "string") return "ok — but tts is a custom command, which ignores the built-in tuning (a clone bends with cloneTempo/clonePitch instead)"
        if (root.ttsEngineMissing) return "ok — but espeak-ng isn't installed, so he stays silent until it is"
        if (!root.ttsOn) return "ok — heard once tts is on"
      }
      if ((key === "cloneTempo" || key === "clonePitch") && parsed !== undefined) {
        if (root.cloneKnobsApply) return "ok — heard on the next line (derived from the line cache, so it's instant and warm-voice needs no rerun)"
        if (!root.ttsOn && String(root.setting("ttsSaved", "") || "").indexOf("speak-clone") !== -1)
          return "ok — heard once the clone voice is back on (set tts true)"
        return "ok — but the active voice isn't a clone, so this won't be heard (the knobs bend speak-clone voices only; espeak has ttsSpeed/ttsPitch)"
      }
      if (key === "promptFile" && parsed !== undefined)
        return (root.aiEnabled ? "ok — " : "ok — but ai is off (set ai true first); once on, ")
          + "that file's contents replace his whole AI prompt in every mode — persona, rules, tone — and register examples then come from quotesFile only; an unreadable path falls back to the built-in character, which the `ai` verb reports"
      if ((key === "aiAgent" || key === "aiModel") && parsed !== undefined && !root.aiEnabled)
        return "ok — but ai is off, so there are no agent lines to apply it to; set ai true first"
      return "ok"
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
      else if (name === "look") root.lookAtScreen()
      else if (name === "listen") root.toggleListen()
      else if (name === "shutUp") root.hideBubble()
      else if (name === "snooze") root.snooze(60)
      else if (name === "unsnooze") root.unsnooze()
      else if (name === "kill") root.kill()
      else if (name === "revive") root.bringBack()
    }
    onChose: function (key, value) {
      // "voice" is the menu picker, not a settings key: a name resolved by
      // the same applyVoice behind IPC useVoice.
      if (key === "voice") root.applyVoice(value)
      // The old Voice toggle path, kept for IPC parity: toggling the voice
      // off never throws away a custom command.
      else if (key === "tts" && (value === true || value === false)) root.setVoiceEnabled(value)
      else if (key === "graveyardOn") root.setLeaderboardEnabled(value)
      else if (key === "duckOn") root.setDuckEnabled(value)
      else root.setSetting(key, value)
    }
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
    // Full-screen, like ClippyMenu's window: four anchors, no size. The
    // gags need the whole screen to fall through; his feet line is still
    // the bar edge (actor.y below), so nothing else moved.
    anchors {
      left: true
      right: true
      top: true
      bottom: true
    }

    // Only Clippy and his bubble take input; the rest of the screen is
    // click-through so everything underneath keeps working.
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
      // A resolution or monitor change invalidates a live peek's gagDy:
      // cancel-and-restore beats a mid-air hang.
      onWidthChanged: { if (root.peeking) root.peekCancel(true); root.maybeBoot() }
      onHeightChanged: if (root.peeking) root.peekCancel(true)

      Item {
        id: actor
        width: sprite.implicitWidth
        height: sprite.implicitHeight
        // The feet line stays a binding; gags ride the additive gagDy
        // offset (the Tombstone thud pattern) so nothing ever assigns y
        // and the binding can't be destroyed.
        y: (root.barBottom ? stage.height - height : 0) + root.gagDy
        visible: root.mood !== "dead"
        transformOrigin: Item.Bottom

        ClippySprite {
          id: sprite
          assetsDir: root.pluginDir + "/assets/clippy"
          size: root.peekGrown ? root.peekSize : root.spriteSize
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
        // A silent line shows without speaking (slap reactions — the SFX
        // plays first; slapSoundDone() un-silences when it ends). Lives on
        // the bubble because the voice watches the bubble, not the say
        // paths; a silent line landing mid-speech still cuts the old line
        // (syncSpeech falls through to the stop).
        property bool silent: false
        // Mid-peek he hangs at the far edge, so the bubble flips to his
        // bar side — otherwise the vertical clamp parks it on top of him
        // and the dwell is a bubble with no Clippy. A grave never shows
        // while peeking (the kill clears the peek), so the grave branch
        // is unaffected.
        readonly property bool aboveHim: root.peeking ? !root.barBottom : root.barBottom
        above: aboveHim
        x: Math.round(root.clamp(stage.mouthX - width / 2, 4, Math.max(4, stage.width - width - 4)))
        y: Math.round(root.clamp(aboveHim ? (grave.shown ? grave.y : actor.y) - height - 2
                                          : (grave.shown ? grave.y + grave.height : actor.y + actor.height) + 2,
                                 4, Math.max(4, stage.height - height - 4)))
        tailX: stage.mouthX - x
        onDismissed: root.hideBubble()
        // The voice rides on the bubble: whatever shows it speaks, whatever
        // hides it shuts him up. callLater coalesces say()'s text+shown
        // double-fire into one sync.
        onShownChanged: Qt.callLater(root.syncSpeech)
        onTextChanged: Qt.callLater(root.syncSpeech)
        onSilentChanged: Qt.callLater(root.syncSpeech)
      }
    }
  }
}
