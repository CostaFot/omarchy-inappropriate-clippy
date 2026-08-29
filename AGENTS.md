# omarchy-inappropriate-clippy — agent notes

Clippy walks the Omarchy bar and insults you. The repo root IS the plugin
(`manifest.json`, id `costafot.clippy`, kinds `panel` + `bar-widget`,
`keepLoaded: true`, entries `Clippy.qml` and `BarWidget.qml`). `omarchy plugin
add <repo> --enable` clones it to `~/.config/omarchy/plugins/costafot.clippy/`
and inserts `{"id":"costafot.clippy"}` into `bar.layout.right[]` in
`~/.config/omarchy/shell.json` (the `defaultSection`; that one entry is both
the icon's slot and the plugin's enabled flag, so `omarchy plugin disable`
removes both). Because we also have the `panel` kind, the shell's
`isBarWidgetPanelPlugin` says no and `summon|hide|toggle` route to the panel
loader, like omarchy.menu — not to the bar widget.

## Architecture

- `Clippy.qml` — root `Item` (the shell loads panels into a non-visual Loader,
  so the root must not be a window). Injected by the host: `shell`, `manifest`,
  `omarchyPath`. Nothing else — no `settings`, no `bar`. Settings are inline
  keys on our shell.json entry. **Where that entry lives changed with the bar
  icon**: a plugin with a `bar-widget` kind is filed by the shell in
  `bar.layout.<section>[]` (like omarchy.menu), not `plugins[]`;
  `findEntry()` reads both, `shell.updateEntryInline` writes to whichever it
  finds. An entry still under `plugins[]` (pre-icon install) is moved into
  `bar.layout.right` after `omarchy.tray` by `adoptIntoBar()` once, on mount,
  via `shell.mutateShellConfig` — `omarchy bar put` can't do it (it sees an
  enabled plugin and stops), and disable+enable would drop the keys. It is
  deferred with `Qt.callLater` because the write lands on `shellConfig`,
  which the `entryLocation` binding reads (binding-loop warning otherwise),
  and it refuses to run when there is no `bar.layout` at all (a layout with
  only us would replace the bar's defaults). `opened` + `open()`/`close()`
  are the `shell summon|hide|toggle` contract. Owns:
  - a single `PanelWindow` on `WlrLayer.Overlay` (the bar is `Top`), anchored
    left+right and top (or bottom), height `barSize + 150`, transparent,
    `ExclusionMode.Ignore`. Input `mask: Region { item: actor; regions: [bubble rect] }`
    so everything except Clippy and his bubble is click-through.
  - the brain: `mood` ∈ idle | walking | talking | dying | dead | reviving, a
    `brain` Timer for idle→walk decisions, `quoteTimer` for unprompted lines,
    `bubbleTimer`, `respawnTimer`, `dieTimer`. Walking is a `NumberAnimation`
    on `actor.x` at `speed` px/s with `IdleSideToSide` looping; the direction
    cue is `GestureLeft` for screen-right (gesture names are the character's
    left/right, verified by cropping the frames).
  - `IpcHandler { target: "costafot.clippy" }` — string args only.
    `set key value` / `get key` / `settings` are the config surface for
    scripts and the user's coding agent: keys come from `settingDefaults`
    (keep it equal to the README table), values are parsed by
    `parseSettingValue` (true/false/number/"unset"→remove/else string) and
    written through the same `setSetting()` the menu uses. `show`/`hide`
    are the idempotent pair next to `toggle` (`show` = `bringBack()`, so it
    also revives), `unsnooze` next to `snooze`; `say` answers `hidden`
    when `opened` is false rather than talking into an invisible window.
    `showMenu`/`hideMenu` exist so the menu can be driven without a pointer
    (there is no ydotool on the box; that is how it was screenshotted).
  - `PersistentProperties { reloadableId: "costafotClippy" }` for `deadUntil`
    (0 alive, -1 dead until `respawn`, >0 epoch ms), `snoozedUntil`, `lastX`,
    and the tally `slapCount`/`killCount` — bumped in `slap()` and
    in `finishDeath()` (the one place every death path lands, so a fling is
    one kill and a knockout is ten slaps plus one kill), shown dim at the
    foot of the menu and by IPC `stats`. PersistentProperties survive
    remounts but not a shell restart, so the score resets on reboot — the
    pitch chose that trade and the README owns up to it. Just the numbers:
    the `{kills}`/`{slaps}` placeholders from the IDEAS.md pitch were
    skipped on purpose (Costa: keep it simple).
  - `asleep` (`pauseWhenAway`, default true): he stops while nobody can see
    him. Three sources, all bindings: `shell.serviceFor("omarchy.lock").locked`
    (the shell's own lock, `$OMARCHY_PATH/shell/plugins/lock/Service.qml`; it
    also DPMS-blanks 5 s after locking), `shell.serviceFor("omarchy.idle")
    .idledThisCycle` (`plugins/services/idle`: `IdleMonitor` → screensaver
    at `idle.screensaver` s, lock at `idle.lock` s; the screensaver is a
    fullscreen *window*, and our layer is Overlay, so without this he'd walk
    on top of it), and `screensOff` = every non-disabled
    `Hyprland.monitors` entry has `lastIpcObject.dpmsStatus === false`.
    Hyprland has no DPMS event, so `dpmsPoll` calls
    `Hyprland.refreshMonitors()` (socket, no fork) every 10 s, 2 s while
    off, and unlock/idle-end refresh at once. `serviceFor` works as a binding
    because the shell reassigns `_services` on registration (navbar-cat
    relies on the same). `fallAsleep()` stops walk/brain/quote/bubble/drag
    timers, stops the sprite and drops the bubble (idle/walking/talking
    only; dying/reviving finish on their own), and `shown` hides the window.
    `decide()`, `unprompted()`, `say()` and `maybeBoot()` gate on it;
    `respawnTimer` swallows a revive while asleep and `wakeUp()` runs it if
    `deadUntil` has passed, else `idleAnim()` + `scheduleQuote()`.
    `AgentBrain.paused` blocks `topUp()` (the retry timer would otherwise
    fire a call into a lock screen). IPC `state` → `asleep`, `say` → `asleep`.
    Waking after ≥ `welcomeAfterMs` (60 s; a blank cancelled by the mouse is
    not a trip) says a `welcomeBack` line 1.5 s later (`welcomeTimer`, so the
    window is mapped and the unlock has faded), `{away}` → `awayText()`
    ("47 minutes"/"3 hours"/"2 days"), and `agentBrain.remember()` gets
    "came back after N away" so agent lines can pick it up. Book only: the
    agent cache is about the screen from before the lock.
    Tested by hand with `omarchy-brightness-display off|on`; the lock and
    idle paths are the same kind of binding but were not exercised (needs
    Costa's password / 150 s idle with stay-awake off).
- `ClippySprite.qml` — port of clippy.js `src/animator.js`. The full sheet is
  one `Image` inside a `clip: true` 124×93 viewport, translated to the cell
  (`x = -cell.x`) — the CSS background-position approach, so a frame change is
  a translation, not a texture reload. The viewport is scaled with `scale`
  from the top-left. Frame stepper: exitBranch when exiting → weighted
  `branching` (subtract-and-compare, remainder falls through to i+1) → i+1;
  clamped to the last frame; durations clamped to ≥16 ms. A frame with no
  `images` means "hidden" (GoodBye ends hidden, Greeting/Show start hidden).
  `play(name, loop, onDone)`, `exit()`, `stop()`, `has(name)`.
  **Named `ClippySprite`, not `Sprite`** — QtQuick ships a `Sprite` type and it
  wins over a sibling file; the symptom is "Cannot assign to non-existent
  property" on our properties.
- `ClippyMenu.qml` — the menu (right-click on him, or the bar icon),
  navbar-cat's `CatMenu` pattern: its own full-screen transparent
  `PanelWindow` (input region only while open, click anywhere dismisses, no
  keyboard focus) with a card under `anchorPos` on `anchorScreen` (null =
  Clippy's screen). Takes `clippy` (the root Item), emits `act(name)` for
  actions and `chose(key, value)` for settings; the root maps the latter
  onto `shell.updateEntryInline(pluginId, entry)`, which rewrites shell.json
  and remounts us. Opening it freezes the walk. When he is dead or hidden
  (`opened` false) the action rows collapse to "Bring him back" →
  `act("revive")` → `root.bringBack()`.
- `BarWidget.qml` — the bar icon, `kind: "bar-widget"` on the same manifest
  (the yeet/agx.screen-time shape: `qs.Ui` `BarWidget` + `WidgetButton`,
  nerd-font paperclip `󰏢`, dimmed when he is dead or hidden). One per
  monitor. It has no state of its own: it finds the panel instance through
  `bar.shell.panelLoaders["costafot.clippy"].item` (the table the shell
  routes summon/hide/toggle through) and calls `showMenuAt(x, screen)`, so
  the card opens under the icon on whichever monitor's bar was clicked. If
  the panel isn't mounted it falls back to `bar.run("omarchy-shell
  costafot.clippy showMenu")`. No IpcHandler here — the panel owns the
  target.
- Slapping (in `Clippy.qml`): `slap(dir)` — middle-click (side hit decides
  the direction) or a pointer fling across him, judged in the actor
  `MouseArea` from `onEntered` to `onExited` because the input mask means
  motion is only reported over him: ≤200 ms, ≥60 % of his width, mostly
  horizontal, ≥1.2 px/ms. A `SoundEffect` per file via an `Instantiator`
  (QtMultimedia loads fine in quickshell; verified with the ffmpeg backend),
  a `shoveAnim` on `actor.x`, a `wobble` on `actor.rotation` (pivot
  `Item.Bottom`), then `say()` with a `slapped` line. Slap timestamps in
  `slapTimes`; `slapsToKill` inside `slapWindowMs` → `kill("knockedOut")`,
  so the usual respawn machinery applies. Default is 10 (was 0 for a
  day; Costa settled on a limit). `0` = never. IPC `slap
  left|right` — the argument is required, IpcHandler has no optional
  params. `assets/sounds/slap-*.wav` are mono 44.1 kHz conversions of three
  mp3s Costa picked (SoundEffect wants WAV; `ffmpeg -ac 1 -ar 44100`).
  Slapped lines are never spoken (v1.22.0, Costa: "i think it's funnier
  with SFX") — `say()` grew a 4th `silent` arg landing in `bubble.silent`,
  and `syncSpeech` treats a silent bubble as stop-speaking: the line shows,
  any in-flight voice is cut, no duck fires, the crack plays clean. The
  knockout (10th slap) still speaks its lastWords — a death, not a slap
  reaction.
- Dragging (in `Clippy.qml`): a 300 ms left press (`pressAndHoldInterval`)
  → `grab(x)`; `dragTo(x)` moves `actor.x` by the pointer's offset from
  `grabX` (the MouseArea rides on the actor, so the offset is how far the
  pointer got ahead), leaning `actor.rotation` against the pull with
  hand-rolled smoothing (no `Behavior`: the slap `wobble` animates the same
  property); `drop()` on release runs `wobble` with the last velocity's sign.
  A `dragged` line on pickup and every 3-6 s (`dragTalk`), a `dropped` line
  on release. `dragging` gates `decide()`, `unprompted()`, `slap()` and the
  post-bubble reschedule so he doesn't walk off mid-carry. No `clicked`
  follows a hold, so a drag never fires the say-something click. `drag:
  false` turns it off.
- Flinging (in `Clippy.qml`): `dragTo` also keeps a smoothed pointer speed
  in px/ms from the pointer's *stage* position (so it counts while he's
  pinned at an edge). `drop()` with `|dragSpeed| ≥ flingSpeed` (1.8) and a
  motion event inside the last 100 ms → `flingOff(dir)`: mood `dying`, a
  `flung` line in the bubble (it clamps to the stage, so it stays at the
  edge he left by), `flingAnim` carries `actor.x` past the edge at ~1.4
  px/ms (600-1600 ms) and spins `rotation` 540°. That's too quick to read
  a line in, so when it finishes the bubble stays at the edge at full
  opacity for `flingHoldMs` (1500, `flingHold`), then is hidden with
  `Bubble.fadeMs` stretched to `flingEchoMs` (1500) so it trails off, then
  `flingEcho` restores `fadeMs` and runs `finishDeath()`. (First cut ended
  the line at the edge; unreadable. Second faded immediately; Costa wanted
  it to linger.)
  `revive()` resets `rotation` and re-places him. IPC `fling left|right`.
  `fling: false` makes a fast release a plain drop. `flingOff` plays one of
  two falling sounds (`flingSounds`, `assets/sounds/fall-*.wav`, mono 44.1
  kHz from mp3s Costa picked) through the same `SoundBank` Instantiator
  component as the slaps; `flingSound` defaults to `slapSoundOn` so the
  menu's "Sounds" row mutes both.
- Voice (in `Clippy.qml`, v1.11.0): `tts` — `false` (default) silent, `true`
  speaks every bubble line through espeak-ng, a string is a user shell
  command. Tri-state like `slapSound`. The hook is two handlers on the
  Bubble instance (`onShownChanged`/`onTextChanged` → `Qt.callLater(
  syncSpeech)`, coalescing say()'s text+shown double-fire) rather than
  calls in the say paths, so the three direct `bubble.text` writes
  (`kill`, `epitaph`, `flingOff`) are covered and every bubble hide —
  slap, sleep, death fade, dismissal — cuts the voice mid-word;
  `fallAsleep()` hides the bubble, so sleep gating is free, and
  `onOpenedChanged` stops it on `hide` (close() only flips `opened`; the
  bubble props stay put, so without that he talks out of an invisible
  window — caught in testing). `syncSpeech` → `startTts()` runs
  `["bash", "-c", cmd]` with the line on stdin (bash always starts, so a
  missing engine is exit 127 in `onExited` — a raw fail-to-start never
  fires `exited`; `exec` prepended to the built-in so the kill lands on
  espeak itself; speak-clone execvps into aplay at play time for the same
  reason — v1.21.1, a child aplay survived the kill and stacked voices
  during drags; the generated kokoro/piper commands wrap their pipeline
  in `trap 'kill $! 2>/dev/null' TERM; … & wait $!` — v1.21.2, bash defers
  traps while a foreground job runs, so only backgrounding + `wait` lets
  the TERM reach aplay promptly; a hand-rolled custom pipeline without
  the wrap keeps its bash and may finish the line). One `ttsProc`. **Kills are `signal(15)`, never `running = false`
  — that quietly leaves the child alive** (verified with a sleep-30
  stand-in; same reason there's `Component.onDestruction: signal(15)`).
  A replacement line parks in `ttsQueued` until the old process's
  `onExited`, since the SIGTERM is async. Deliberate kills clear
  `ttsLine` first so `onExited` doesn't mistake them for failures; real
  failures warn once per engine (`ttsWarned`, reset by
  `onTtsSettingChanged`). Two change handlers on purpose: inside
  `onTtsSettingChanged` the dependent `ttsOn` binding is still stale, so
  the turn-off kill lives in `onTtsOnChanged` (bit us). The built-in
  voice is `en+m3`, or `en+whisper` while `mood == "dead"` (epitaphs are
  whispered). Verified engine-less end to end by pointing `tts` at
  `cat >> file` and `sleep 30` — the contract is just stdin. The missing
  engine is surfaced, not just journaled (Costa: always point it out in
  the UI and to agents): `ttsProbe` (`command -v espeak-ng`) runs at
  mount, on `tts` changes and on menu open, feeding `ttsEngineMissing`;
  `ttsNeedsEngine` (false when a custom command is set) turns the menu
  row into "Voice · install espeak-ng", makes him say "Install espeak-ng.
  I'll wait." in a bubble when the voice is switched on engine-less
  (`onTtsOnChanged`, `Qt.callLater` so it runs outside the binding
  update), and drives the agent-first IPC: `voice` → off / "espeak-ng:
  ready" / "espeak-ng: not installed — silent (fix)" / "custom command:
  …" (+ "; failing, see journal" after a warn, "; speaking" while
  audible), `set tts true` answers "ok — but espeak-ng isn't
  installed…", and `say`/`talk` answer "ok — but silent: …" via
  `ipcOkVoice()` instead of a bare ok. The probe is async, so a `set`
  in the same breath as the install may still warn once (v1.11.1).
  Tuning (v1.12.0): `ttsVoice` (default `en+m3`; single quotes stripped so
  the quoting in `startTts()` holds), `ttsSpeed` (80–450), `ttsPitch`
  (0–99) shape the built-in command only — a custom command stays one
  opaque string and ignores all three, and dead still overrides to
  `en+whisper` whatever `ttsVoice` says. Agent-first: `voice` appends
  "— <voice>, <speed> wpm, pitch <pitch>" when the engine is ready, and
  `set` on the three keys answers "ok — but …" when a custom command,
  a missing engine or `tts` off means the change can't be heard.
- Ducking (in `Clippy.qml` + `scripts/duck`, v1.20.0; always-on since
  v1.21.0): every *other* audio stream drops to 30 % while he speaks and
  is restored after. No setting — Costa: "do not give option to duck other
  audio. ALWAYS duck other audio"; `duckFactor` is a hardwired 0.3.
  The script snapshots `pactl list sink-inputs` volumes (raw values, not
  the rounded percent — a 100 %+0.12 dB stream must restore exactly) into
  `$XDG_RUNTIME_DIR/clippy-duck` and scales each; the snapshot is taken
  BEFORE the engine spawns, so his own stream is never in it — no
  name-matching against aplay/espeak/whatever a custom command runs, and
  any engine works. The one name-match (v1.22.0): sink-inputs with
  `node.name = "quickshell"` are skipped — the slap/fall SoundEffects
  play through quickshell itself, they're his audio not "other audio",
  and a short SFX dying mid-duck poisoned its stream-restore memory to
  a permanent 30 % (found live: the slap crack was quiet no matter what
  until a live quickshell stream was pinned back to 100 %). Idempotent both ways under flock. QML side: `startTts`
  ducks first and the launch continues from `duckProc.onExited`
  (`launchTts` is the old body); the duck is held across a replacement
  line (`ducked` already true → straight to the engine, and the
  queued-restart branch in `ttsProc.onExited` returns before the
  restore); every speech end with an empty queue lands on `duckStop()`,
  which is gated on `ducked`, not `duckEnabled` — `set duck false`
  mid-sentence still restores. A line cancelled while the snapshot is in
  flight restores instead of speaking (`ttsLine === ""` in the duck's
  onExited); overlapping flips park in `duckNext` (one Process); a mount
  runs `duck stop` as crash healing, so a shell death mid-sentence gives
  the volumes back next start. No menu row, no `duck` key (v1.21.0
  removed both; a stale inline `duck` in shell.json is simply unread);
  `voice` states the always-on ducking. Known trade-off: PipeWire's
  stream-restore memorizes a stream's volume, so an app whose stream
  *ends while ducked* is remembered at 30 % and starts there next time —
  that exact poisoning (from the v1.20 terminal tests) once made aplay,
  and with it every clone line, inaudible; the fix is
  `pactl set-sink-input-volume <id> 100%` on a live stream of that app.
  Orthogonal to Costa's `costafot.autoduck` plugin: that one *mutes*
  browser streams against other *browser* streams and never touches
  volumes, so they compose.
- `Tombstone.qml` — a headstone at the death spot while `mood == "dead"`
  (`tombstone: true`): tooltip-coloured stone, paperclip-over-RIP engraving,
  mound, OutBounce thud on appear, 500 ms fade out when `revive()` flips the
  mood. `placeGrave()` (called from `finishDeath()`) snaps it into a widget
  gap with the walk machinery — `freeGaps(w)` takes a width now, and the
  stone is narrower than him, so it fits more places; a fling's grave is
  placed by clamping his (off-stage) centre to the stage, so it stands at
  the edge he left by, nudged off whatever occupies it (the workspaces, on
  the left). `persisted.graveX` (-1 = none) survives remounts; verified two
  `set`-triggered remounts keep it pixel-identical. In the input mask
  **only while shown** (a Region that collapses to 0 wide, like the
  bubble's): a click says an `epitaph` line and a right-click opens the
  menu anchored to the grave (not to actor.x — a fling leaves that
  off-stage). `epitaph()` writes the bubble directly the way the kill
  paths do, since `say()` refuses while dead; `{back}` in a line becomes
  time-to-respawn via `backText()` ("45 seconds"/"4 minutes"/"never").
  While the grave stands the bubble anchors to it (`stage.mouthX`, plus
  the grave-vs-actor y ternaries; same feet line, different heights). So
  while he's dead the stone's ~20 px does take clicks — it parks in a
  gap, so that's normally empty bar, which is the whole covering story.
  IPC `epitaph` (alive/off/asleep/ok) exists because pokes aren't
  pointer-testable.
- `AgentBrain.qml` + `scripts/clippy-ai` — lines from the user's default
  coding agent (`ai: true`, off by default). Omarchy's "default agent" is
  only a name in `~/.config/omarchy/defaults/agent` (`omarchy-default-agent`
  prints it) plus `omarchy-agent`, which opens it interactively; there is
  no headless API, so the script carries its own one-shot table mirroring
  `omarchy-agent`'s `case` (`claude -p --tools "" --setting-sources ""
  --system-prompt`, `codex exec -o`, `pi -p --no-tools`, `opencode run
  --pure`, the rest from docs; `--model` mapped per agent). It gathers the
  facts itself (hyprctl window/clients, battery, load, mem, uptime,
  playerctl, the hour, `~/.local/state/omarchy/agents/usage/<agent>.json`
  limits, plus a `--recent` note of slaps/drags/kills the QML side
  collects) and hands them over as text, tool-less, from `$TMPDIR` so no
  CLAUDE.md is picked up. Twelve random lines from `quotes.json` (+
  `--quotes <quotesFile>`, nsfw dropped under `--clean`) go in the system
  prompt as register examples; without them the model guessed mild. The
  prompt asks for "jabs" under explicit rules (accusation not description,
  one short sentence, numbers only as setups, no "champ"/Twitch-isms) —
  the first prompt asked for "remarks" and got wordy observation-plus-sneer
  lines that never swore; Costa wanted more pointed, more irreverent.
  `--context` prints the facts, `--prompt` the whole prompt. Output is a
  JSON array of lines, parsed three ways in turn: as JSON; else every JSON
  string literal in the text (claude sometimes emits the array with blank
  lines and **no commas** between items, which is what this catches —
  before it, 1 of 3-5 lines survived); else one per non-empty line. ~4-8 s
  for claude, ~16 s opencode.
  `AgentBrain` runs it through a `Process`, caches the lines in
  `PersistentProperties` (`costafotClippyBrain`: remounts must not cost a
  call; verified a shell.json write keeps the cache), expires them at 20
  min, refills when ≤1 left with a 60 s minimum gap doubling on failure
  (cap 32 min) — batch 5, so ~one call per 15 min at the default quote
  cadence — and `take()` returns null on anything wrong. Root's
  `nextQuote()` prefers it over `randomQuote()` for unprompted lines,
  left-click, menu "Say something" and IPC `talk`; `slapped`/`dragged`/etc
  stay on the book (they must be instant). IPC `ai` → `status()`:
  "`<agent>: N cached (Ns old), last call Ns ago[, N failed][, busy]`";
  `take()` logs what it took and a short answer is logged with the raw
  output, so `journalctl --user -o cat | grep clippy` tells the story.
  `aiModel`: unset is the agent's default, which for claude is the CLI
  default (opus-5 today), *not* settings.json's `model`, because
  `--setting-sources ""` is on (verified: with it `modelUsage` shows
  opus-5, without it Costa's fable-5). Costa asked; kept the isolation and
  made the model a setting; the menu shows it in the "Lines from <agent>"
  row label when set (no picker: the names differ per agent). Timed on the
  real prompt: opus-5 and sonnet-5
  ~4 s, haiku-4-5 44-63 s (twice; bare "say hi" is 3 s on all three), so
  don't suggest haiku. The shell's env has the mise shims on PATH, so the
  agent binaries resolve. codex and pi are installed here but not logged
  in (401 / no key), so only claude and opencode were actually run.
- `Bubble.qml` — tooltip-coloured rounded rect + wrapping text, capped at
  320 px. Two rotated-square tails: bordered one behind the body for the
  outline, borderless one on top to hide the body's border across the join.
  `ai: true` (set by `say(text, anim, ai)`; `nextQuote()` tags agent lines
  with it) is the "this came from the agent" dress: border in
  `Color.accent` and a nf-md-creation sparkle (U+F0674, literal in the
  file) in the top-right of the padding. A typewriter reveal was tried and
  dropped — too slow to read at any speed that still looked like typing.
  The kill and fling paths write `bubble.text` directly and set
  `bubble.ai = false` first.
- `quotes.json` — `{ quotes, lastWords, comeback, slapped, knockedOut, dragged, dropped, flung, welcomeBack, epitaph }`
  (the key list is `quoteKeys` in Clippy.qml; add there and here), entries
  `{ text, nsfw, anim? }`. `clean: true` filters `nsfw`. `quotesFile` is
  merged in (same shape, or a bare array).
- `assets/clippy/{map.png,agent.json}` — from clippy.js via
  `scripts/fetch-assets` (dev-time only, results are committed). map.png is
  3348×3162, 27×34 cells of 124×93; one 8-bit palette PNG → ~42 MB as an
  RGBA texture. Fine for a joke; slice a trimmed atlas if it ever matters.

## Dev loop and gotchas

- Symlink the checkout in: `ln -s ~/Work/omarchy-inappropriate-clippy
  ~/.config/omarchy/plugins/costafot.clippy`, then `omarchy plugin enable
  costafot.clippy`. `omarchy-plugin-validate` refuses a symlinked plugin dir
  (validate the real checkout path instead); the shell itself is fine with it.
- The shell's `inotifywait -r` watcher does **not** follow the symlink, so
  edits don't hot-reload, and `omarchy-shell shell rescanPlugins` reuses the
  cached compile. Use `omarchy restart shell` after every QML change.
- Every write to `shell.json` (by anyone — `omarchy bar move`, a widget saving
  a setting) rebuilds the panel Instantiator and remounts us. That's why
  dead/snooze/x live in `PersistentProperties`. Keep mount cheap.
  (Observed 2026-08-29 while testing the voice: an inline `set` on our own
  entry did *not* remount — plain properties survived and no destructors
  ran; the new value arrived as a live binding update through
  `shellConfig`. Don't rely on a `set` to reset plain state; layout-shaped
  writes may still rebuild.)
- `shell.bar` is null while the bar loads and is reassigned on bar reload —
  every geometry read guards it and falls back to `Style.bar.*`.
- Never name a property on any Item-derived object after an Item property
  (`bottom`, `top`, `state`, `scale`…) — "Cannot override FINAL property", and
  the reported line can be stale when the compile is cached. Bit us twice.
- IPC from a terminal is `omarchy-shell costafot.clippy <method> [args]` —
  no `ipc call` subcommand; that form prints "Target not found".
- Logs: `journalctl --user -o cat | grep -iE 'clippy|WARN.*scene'`.
- One quickshell SIGSEGV was seen during development, right after
  "Exiting due to IPC request" while plugins were still incubating
  asynchronously (`QQmlObjectCreator::finalize` → `__dynamic_cast` in stripped
  quickshell code). It looked like an `omarchy restart shell` landing on a
  shell that was still starting; not reproduced since.

## Status (2026-08-28) and what's next

Working end to end on Costa's machine: walks (parking in the gaps between
the bar's widgets), talks on a timer, left/middle click, slap (with knockout
at 10), long-press drag, fling-to-death,
right-click menu (actions + clean/sounds/restless/size), bar icon → same menu
(dimmed + "Bring him back" when dead/hidden), kill → respawn with a comeback,
snooze, sleep while locked/idle/screens-off with a welcome-back line, top and
bottom bars, IPC, settings inline on the bar-layout entry.
On GitHub at the README install URL, v1.11.0 (no tag yet). Not on the
marketplace: see `PUBLISHING.md` for the flow, prior submissions and the
gap list.

Movement is a random brain (`decide()`): idle beats 10-30 s apart, each one
turns into a walk with probability `restless` (default 0.3), walks are mostly
short hops of 80-400 px with 1 in 5 a trek anywhere. Costa wanted him mostly
still — tune, don't make him busier. Targets avoid parking on the bar's
widgets — see the widget-avoidance paragraph below.

Verified by hand (2026-08-28): click-through with a real pointer, `clean`,
and `quotesFile` (object and bare-array shapes, all three keys, bad JSON and a
missing path both fall back to the built-in book). Quotes are two books,
`book` + `extraBook`, merged per key in `pool(key)` so FileView load order
doesn't matter — an earlier version leaked the file's `quotes` into
`lastWords`/`comeback`.

Slapping done (2026-08-28, v1.2.0): middle-click and pointer-fling, sound,
shove + wobble, knockout after `slapsToKill` (10) inside six seconds.
Middle-click used to snooze; `slap: false` restores that. Costa supplied the
three sounds.

Dragging done (2026-08-28, v1.3.0): long-press (300 ms) and carry him along
the bar, with lines on the way and on landing. Flinging (v1.4.0): let go
while moving fast and he's thrown off the bar and dies, with a `flung` line
that lingers at the edge and a falling sound. Neither is pointer-testable
from a terminal (no ydotool) — `fling left|right` over IPC covers the
throw itself; Costa verifies the grab and the release speed by hand.

Bar icon done (2026-08-28, v1.1.0): opens the same `ClippyMenu`, and is the
way back after a kill/hide. The menu is the config surface, `shell.json` the
fallback. Keep every setting a flat scalar key with a default, a README table
row, and (if it's something a user would reach for) a row in the menu. Don't
build a `barWidget.schema` unprompted.

Agent lines done (2026-08-28, v1.5.0): `ai: true` swaps the random book for
lines from the user's default coding agent about what they are doing (see
`AgentBrain.qml` above). Verified live with claude on Costa's machine, and
opencode from the terminal. Costa's question was whether Clippy could "be
powered by the user's AI agent on omarchy"; the answer is yes, via each
agent's one-shot CLI mode, not via anything Omarchy provides. Agent lines
are marked in the bubble (accent border + sparkle, see `Bubble.qml`) so
you can tell which book a line came from without the journal.

Sleeping done (2026-08-28, v1.6.0): locked / idle-screensaver / DPMS-off
pauses everything, including agent calls, and a `welcomeBack` line greets
you after a minute or more away. Costa's question was whether he fires while
the screen is off or locked; he did, ~4 agent calls an hour all night with
`ai: true`. See the `asleep` bullet above. DPMS path tested by hand; lock
and idle paths not yet.

Widget avoidance done (2026-08-28, v1.7.0): when he picks where to walk he
parks in the gaps between bar widgets (`avoidWidgets`, default true).
`shell.bar.moduleSlots` holds every widget slot across all monitors;
`occupiedIntervals()` filters by `slotScreenName(slot)` == his screen and the
shell's own visibility test (a collapsed slot keeps visible=true but drops to
0x0), maps each with `mapToItem(null, 0, 0)` — bar-window x == screen x ==
stage x, both windows anchored full-width — pads 6 px and merges; `freeGaps()`
inverts that into the positions where the whole actor fits. Sampled lazily at
pick time, never from a binding: widget widths change without signals (tray
drawer, center peeks) and `moduleSlots` is reassigned per register/unregister,
so a binding would churn. Treks pick a width-weighted random gap; hops snap to
the nearest clear position, which only ever shortens them — he pulls up beside
the clock instead of onto it. (A first cut capped the snap at 120 px so a hop
would "stay a hop"; deep-in-cluster targets stood dirty and he parked on the
workspaces within minutes. Uncapped, the snap IS the hop aesthetic.) Standing
on a widget — drag-drop, a tray drawer growing under him — raises the next
beat's walk chance to 0.8 so he steps off on his own schedule; that is the
only busier-making change. Boot and revive placement prefer a gap too
(`randomSpot()`); drags, shoves and flings still land him anywhere. Null
`shell.bar`, a shell without `moduleSlots`, or no gap he fits in all fall
back to raw targets. Verified with `restless 1` and screenshot pairs against
`omarchy-shell shell debugBarGeometry` (same coordinate space).

Tombstone done (2026-08-28, v1.8.0): every death leaves a grave until the
respawn (see `Tombstone.qml` above). Costa's worry was covering the bar; the
answer is the input mask plus gap-snapping (it rarely even overlaps).
Verified over IPC: kill mid-bar, fling off the left edge (grave nudged
right of the workspaces/media cluster), two remounts while dead, respawn
fade. The thud/bounce on appear is not pointer-verifiable from a terminal;
it's a 450 ms OutBounce on the stone. The epitaph (v1.9.0) came right
after: Costa asked for "Here lies Clippy. You killed him, you fuck" on
click, and that line is in the book. He clicked the grave by hand and
confirmed; the IPC path and the grave-anchored bubble were verified with
screenshots.

Kill/slap counter done (2026-08-28, v1.10.0): `slapCount`/`killCount` in
`persisted`, a dim footer row in the menu, IPC `stats` (pluralized: "1
slap, 0 kills"). Costa asked for the simple half of the IDEAS.md pitch
only — show the numbers, no placeholder lines. Verified over IPC: slaps
and kills increment, a fling counts exactly one kill (it lands in
`finishDeath()` like every other death), two `set`-triggered remounts
keep the totals, and a shell restart resets them — that's the
PersistentProperties trade, same as `deadUntil`.

Voice done (2026-08-29, v1.11.0): optional TTS, `tts` false/true/command
(see the Voice bullet above). Costa's ask was stupid/funny by default and
pluggable — extensibility, not crashing — and explicitly **no TTS engine
installed** for the first pass: the whole thing was verified engine-less.
Missing espeak-ng → one journal warning per engine, lines still display,
nothing else changes; `cat >> file` as the engine collected exactly the
displayed lines across say/talk/slapped/flung/epitaph; `sleep 30` as the
engine proved the kills (replacement line, `hide`, `set tts false`, DPMS
sleep) — and caught two real bugs: `running = false` doesn't kill the
child, and `hide` didn't stop speech. Menu "Voice" row verified by
screenshot. espeak-ng was installed and heard on 2026-08-29 ("he sounds
like a robot" — Costa, delighted); the `-v en+m3 -s 155 -p 45` tuning is
approved as-is.

Voice tuning done (2026-08-29, v1.12.0): `ttsVoice`/`ttsSpeed`/`ttsPitch`
for the built-in espeak-ng path (see the Voice bullet). Costa's ask was
"anyone can use the voice they prefer", agent-pluggable — the answer is the
same `set` surface everything else uses, one key per knob, no menu picker
(same call as `aiModel`: the names are engine-specific). Candidate defaults
were auditioned out loud (Tweaky, UniRobot, helium m3, HL announcer, then a
deep "sportscaster" batch — espeak's low-pitch register sounds terrible);
Costa kept `en+m3 -s 155 -p 45` as shipped. The voice hunt for his box ran
the same day: fish.audio and ElevenLabs were rejected mid-flight ("we do not
want cloud calls"), piper auditions crowned `en_US-ryan-high` for about ten
minutes, then "a female oniichan stupid voice, not too high" landed on
kokoro `af_heart` — until "the initial voice should be a fkin male dork"
crowned `am_adam` from a five-male audition as both the blessed default
and Costa's own `tts` — then "can we make the default voice funnier" ran
through C-3PO, "deeper", "more distorted, robotic", "higher", and settled
on ring-mod George: `bm_george` through ffmpeg (`asetrate` +15%,
`tremolo f=45`, `acrusher bits=6`, 250–3400 band). Bare setup-voice gets
that chain; a named voice comes through unprocessed; `say.py` phonemizes
`b*` voices as en-gb (George read American before that).
`scripts/setup-voice` ships the whole path: bare = the blessed robot
George (venv + ~340 MB in
`~/.local/share/kokoro-tts`, a generated `say.py` reading stdin), a name
with a dash = that piper catalog voice (`~/.local/share/piper-{tts,voices}`);
both end in `set tts` on a stdin→aplay pipeline (aplay, not pw-play —
sndfile can't read raw audio from a pipe; bit us) with a spoken hello
first. ~1.8 s per line for kokoro, model load included. Nothing is bundled
in the repo — engines are 60-340 MB, so the script downloads on demand.

Voice cloning done (2026-08-29, v1.13.0): `scripts/setup-voice --clone
<sample> [name]` gives him any voice from a 10-20 s sample. Costa's pick is
Rubick (Dota 2), cloned from a YouTube compilation he supplied; the approved
take is exaggeration 0.5, cfg 0.5, reference = seconds 2.6–22.6 of the rip,
and that exact wav is `~/.local/share/chatterbox-tts/voices/rubick.wav` —
don't regenerate it, a re-cut sounds subtly different. Engine is chatterbox
on CUDA in a uv venv (`--python 3.12`: system 3.14 has no torch wheels and
pip backtracks forever — use uv; `setuptools<81` pinned or perth's
watermarker import dies on missing pkg_resources and `from_pretrained`
throws "'NoneType' object is not callable"). Per-line spawn would reload
2 GB onto the GPU, so `speak-clone` (client, stdlib python3) talks to
`daemon.py` (venv python) over `$XDG_RUNTIME_DIR/clippy-voice.sock`; the
daemon self-starts on demand, exits after 15 idle minutes to free ~4 GB
VRAM, and lines are cached in `~/.cache/clippy-voice` by (ref, knobs,
text) — repeats instant, fresh line ~5 s warm, ~25 s cold (the bubble's
SIGTERM just skips that line's audio). TARS (Interstellar) was auditioned
and dropped — movie-scene audio is too dirty next to a voice-line
compilation. Explicitness (Costa: "be explicit in the instructions on the
UI and agent"): the menu Voice row reads "Voice · custom" whenever a
command string is set, IPC `voice` answers off with the setup-voice
pointer and appends it to the espeak-ready reply, and the README documents
every mode. ElevenLabs and fish.audio were explored and rejected mid-hunt:
no cloud calls, Costa's rule. Verdict after hearing it live: "it's fun.
not amazing" — the clone carries the accent and cadence, not the game's
filter. Don't oversell it and don't chase clone quality without a new ask.

C-3PO cloned (2026-08-29): the current voice on Costa's box, replacing the
espeak robot (`tts` was back to `true` when the ask came; Rubick's wav still
stands). The blessed default was already the C-3PO homage ("a fussy English
droid"), so the real thing was the obvious first clone. Source is a
voice-line compilation Costa supplied (youtu.be/Z_OjTojCNm0, audio rip);
the approved take is the Tatooine monologue run at seconds 26.9–46.9
("How did we get into this mess… made to suffer… what a desolate place"),
picked by transcribing the clip (throwaway faster-whisper venv — every line
in it is 3PO, that window had the quietest inter-line floor at −22 dB),
normalized +10 dB. The exact wav is
`~/.local/share/chatterbox-tts/voices/c3po.wav` — same rule as Rubick,
don't regenerate it. Verdict: "it sounds fine" — the clone carries Daniels'
accent and fret, not the metallic sheen; a gentle ffmpeg chain appended to
the `tts` string is the known fix if that ever gets asked for. Knobs
settled at exaggeration 0.6, cfg 0.7 (up from the 0.5/0.5 defaults):
Costa found the delivery slow, and the reference is 3PO at his weariest —
that window was picked for cleanliness, and the clone copies its cadence.
Both knobs push pacing faster; a knob change also re-keys the line cache,
so everything renders fresh once. A snappier fallback reference sits at
`voices/c3po-fast.wav` (36.4–47.5 s, the "had enough of you… malfunctioning
little twerp" run) — unused, swap `--ref` to it if the pace bugs him again.
The ~2 s to first audio on a novel line is warm chatterbox synthesis time,
not fixable without streaming; pre-warming the cache over the book was
offered and declined ("nah"). Nothing of this lands in the repo —
reference and setting are home-dir state.

Clone pitch knob done (2026-08-29, v1.13.1): `--pitch` on `speak-clone`
(<1 deeper, >1 lighter), an ffmpeg `aresample=48000,asetrate=48000*P,
aresample=48000,atempo=1/P` chain after synthesis — tempo preserved (Costa
already found him slow), derived from the raw cache into `{key}-p{P}.wav`
so a pitch change never touches the GPU, plays the raw file if ffmpeg
fails. Same client in the home dir and in the `setup-voice` heredoc, plus
a README tuning paragraph. The session started as "clippy has a robotic
voice, is this normal?": `tts` in shell.json had reverted to bare `true`
(espeak) with the whole clone stack intact — prime suspect is the menu's
Voice row, which toggles to `true` and forgets the custom command; still
an open papercut, offered but not asked for. The pitch audition (0.85 →
0.9 → 0.94 on C-3PO) ended sideways with "more rubick": **the current
voice on Costa's box is the Rubick clone** (`--exag 0.5 --cfg 0.5`, no
pitch flag — Rubick is deep enough on his own), C-3PO's wavs stand ready
but unused.

Cache warming done (2026-08-29, v1.14.0): `scripts/warm-voice` renders the
whole book into the clone cache, silently, over the daemon socket — no
aplay, so nothing plays while it runs. It reads the live `tts` string for
speak-clone/--ref/--exag/--cfg (bails on anything else), merges
`quotesFile`, respects `clean`, skips `{templated}` lines, skips existing
cache files, and self-starts the daemon like speak-clone does. Born from
"rubick talking is 2 seconds slow": switching --ref invalidated all 55
C-3PO-keyed lines, so every line — slap reactions worst of all, they
trail the hit by 2 s — was a first take. While a warm runs, live lines
queue behind the batch and the bubble's SIGTERM can skip them ("no sound
tho" — expected, self-heals when the warm finishes). Pitch variants are
not pre-derived on purpose: the ffmpeg step is milliseconds. Costa's box
was warmed for Rubick 0.5/0.5 the same evening.

Agent-line warming done (2026-08-29, v1.15.0): with `ai` on and a
speak-clone `tts`, each fresh batch of agent lines is pre-rendered into
the clone cache the moment it lands, so agent lines stop trailing the
bubble by the ~2 s a first take costs — they sit in `AgentBrain` up to
20 min before `take()` uses one, and that idle window is free GPU time.
Born from "the AI tts is lagging": the book warm (v1.14.0) had made every
book line instant, and the agent lines were exactly what was left.
Mechanics: `warm-voice --lines <line>...` warms explicit strings instead
of the book (same tts parse, cache key, `{`-skip, daemon self-start);
`AgentBrain` emits `linesArrived(lines)` on a successful batch; the root's
`warmAgentLines()` gates on `ttsOn` + `"speak-clone" in ttsSetting` and
runs `warmProc` fire-and-forget, parking overlap in `warmQueued` (the
ttsQueued shape). No new setting keys. A side fix in `warm-voice`:
`get` prints string values JSON-quoted, and the trailing `"` broke the
`--cfg` float parse — `setting()` now strips the quotes. Verified live:
`--lines` renders/skips/caches from the terminal, and a real claude batch
of 5 produced 5 cache wavs within ~15 s of `set ai true`, journal clean.
Session note: mid-work Costa toggled both `tts` and `ai` to false from
the menu (the Voice row still eats the custom command — open papercut);
both were left false as he set them, and re-enabling is
`set ai true` + `set tts 'exec …/speak-clone --ref …/rubick.wav
--exag 0.5 --cfg 0.5'`.

Voice toggle keeps the command (2026-08-29, v1.16.0): the menu's Voice row
(and IPC `set tts true|false`) used to write bare booleans, eating a custom
`tts` command — it took Costa's clone string three times in one day. Now
`setVoiceEnabled(on)` stashes a command string into a new `ttsSaved` key on
turn-off and restores it on turn-on; `tts true` only means espeak when
nothing is parked (`set ttsSaved unset` is the escape hatch), `set tts
unset` resets tts but keeps the stash, and an explicit command string
clears it. Both keys land in one `setSettings(map)` write (new; setSetting
delegates to it) — two sequential writes would race the remount. The menu
row reads "Voice · custom" while off-with-stash. Agent-first replies grew
with it: `set tts <speak-clone cmd>` answers with the rerun-warm-voice
reminder when the string changed, `voice` while a clone is live names the
voices dir / setup-voice / warm-voice, and while off it names the parked
command. Born from the "is it fully configurable" pre-publish audit.
Verified over IPC end to end (set clone → off → stash → true → restore,
unset keeps the stash); the menu path shares setVoiceEnabled so only the
label was eyeballed. PUBLISHING.md's version reference was refreshed at
the same time.

Discoverability papercuts closed (2026-08-29, v1.17.0): the two gaps from
the new-user audit. IPC `help` lists every verb one per line with a
half-line description and ends with the README path — the blind-agent
bootstrap quickshell's "Function not found" never gave (it also went into
the README's scripting block, first line). The menu's `Entry` grew an
optional `hint` (dim second line, fontSize−2, only sized when non-empty)
and the Voice row uses it — "better voices: scripts/setup-voice in the
plugin dir" — shown only in the `!needs && !custom` state: the espeak-only
audience that was stranded; engine-missing and custom/stashed users keep
their existing labels, no hint. No new settings keys. Verified live after
a shell restart: `help` output from the terminal, journal clean, menu
screenshot shows the hint under "Voice". PUBLISHING.md's version reference
refreshed. Note the dev symlink is back in place (the new-user clone below
is history) and `ai: true` with claude lines was live on the box during
the check.

Rubick ships as the default voice (2026-08-29, v1.18.0): bare `setup-voice`
now picks by hardware — an NVIDIA GPU with ≥6 GB total VRAM (`gpu_ok()`:
`nvidia-smi --query-gpu=memory.total`, biggest card wins) gets the shipped
Rubick clone, anything less falls back to robot George with the reason
printed, and `--robot` is the bypass Costa asked for ("ship it to the
machines who are powerful enough, but it should be something that is
bypassed"). The approved reference wav is now IN the repo at
`assets/voices/rubick.wav` (940 KB, s16le mono 24 kHz, exactly 20 s,
byte-identical to `~/.local/share/chatterbox-tts/voices/rubick.wav`) — the
shipped path `cp`s it verbatim instead of the `--clone` ffmpeg re-encode,
because a re-encode of the approved take sounds subtly different (same rule
as always: never regenerate it). Knobs stay 0.5/0.5 in the written `tts`
string. README: bare-mode paragraph rewritten, Valve credit inline ("Dota 2
audio, © Valve"), the `--clone` example renamed to glados since rubick is
no longer hypothetical, and a bridge line noting the shipped voice pays the
same chatterbox costs. Verified live on Costa's box: bare run detected the
GPU, copied the wav (cmp-identical after), spoke the hello and set the same
tts string; no-GPU and `--robot` branches exercised with stubbed
`nvidia-smi`/`omarchy-shell` binaries so the live setting stayed put. The
plugin's literal default is still `tts: false` — engines download on
demand, only the 940 KB sample rides in the repo. Session context: the day
started with "the default voice sucks" — the new-user wipe had left bare
espeak `tts: true`; the Rubick rig was restored first (set tts + warm-voice,
all 154 book lines were still cached), `ai` was left off as found.

Voice picker + agent voice surface done (2026-08-29, v1.19.0): Costa's ask
was a UI to *select* voices and "make this app amazing for an agent". The
split that shipped: switching lives in the plugin (instant, a `set tts`
write), installing stays with setup-voice (a menu tap must never start a
2 GB download). `scripts/voice-scan` (new) prints one JSON object of every
voice on disk — espeak/GPU/kokoro presence, clone wavs, piper models with
their sample rates — and feeds `voiceInv` via a Process (mount, tts
changes, menu open). On top of it: `currentVoiceId` names the live tts
value (off/robot/george/<clone>/<piper>/custom; clones keep their name
through knob changes via the --ref regex), `voiceOptions` is the picker
list (clones only when the GPU is there; "custom" appears when a hand-set
command is live or parked), and `applyVoice(name)` is the one resolver
behind both the menu and IPC — it rebuilds the exact command strings
setup-voice writes (georgeCmd/cloneCmd/piperCmd; drift just means the
picker says "custom") and parks an unrecognized custom command in
`ttsSaved` before overwriting, the v1.16.0 no-eating rule. The menu's
Voice toggle row became a `Choice` chips row (off · robot · george ·
rubick · …, the Walks/Size pattern) plus a dim setup-voice hint shown only
when nothing better than the robot is installed; ttsNeedsEngine moved into
the group label. IPC: `voices` (active + installed + how to install more +
the raw `set tts` contract) and `useVoice <name>` (agent-first replies:
"ok — the rubick clone; …warm-voice…", "george isn't installed — run
scripts/setup-voice --robot…", "unknown voice…"), both in `help`. No new
settings keys. Verified live on the box (espeak+kokoro+3 clones+1 piper):
switch to every kind byte-identical to setup-voice's strings, the
custom→stash→restore round trip, off/unknown/already replies, menu chips
by screenshot; the chip tap path shares applyVoice with the verified IPC
path. Right after shipping, Costa found only rubick answered
promptly (kokoro reloads its model per line, the c3po clones had a cold
cache; both synthesized fine from the terminal) and asked for the rest to
go — "less options. less to debug". They are PARKED, not deleted:
`~/.local/share/chatterbox-tts/voices-parked/` holds the approved c3po +
c3po-fast takes (never regenerate — move back to voices/ to re-offer),
`piper-voices-parked` and `kokoro-tts-parked` sit next to their original
dirs. The picker is inventory-driven, so moving anything back restores its
chip. His box now offers off · robot · rubick, rubick active.

New-user simulation (2026-08-29): the box left the dev loop — plugin
disabled, symlink removed, then a real `omarchy plugin add
https://github.com/CostaFot/omarchy-inappropriate-clippy --enable --yes`
clone (main == origin/main, so the same v1.16.0 code) and an `omarchy
restart shell` to zero `persisted`. The disable wiped Costa's inline
settings; the entry now carries only `tts: true` from his own menu click
(espeak robot), and restoring the dev rig is the symlink plus `set ai
true`, `set aiModel claude-sonnet-5`, `set tts 'exec
~/.local/share/chatterbox-tts/speak-clone --ref
~/.local/share/chatterbox-tts/voices/rubick.wav --exag 0.5 --cfg 0.5'`.
So the "current voice on Costa's box" notes above describe the rig, not
this moment. Note the installed dir is a real clone now — edits there
hot-reload but are NOT the checkout; dev work goes back through the
symlink. The audit itself: TTS is one click from the menu, the README
held up end to end, and two papercuts surfaced (offered, not asked for):
the menu never advertises `setup-voice` while espeak-ng is installed
(the nudge only shows when it's missing), and there is no `help` IPC
verb — a blind agent gets "Function not found" and must find the README
to learn the methods.

Audio ducking done (2026-08-29, v1.20.0): `duck` lowers everything else
while he talks, the way voice assistants do (Costa: "lower the volume of
what is currently playing so we can talk with agent", OpenWhispr named as
the reference). See the Ducking bullet above for the whole mechanism; the
short version is a pre-spawn snapshot of `pactl` sink-input volumes in
`scripts/duck` (restore-exact raw values, flock, idempotent), `startTts`
split into duck-then-`launchTts`, restore on every speech end, crash
healing at mount. pipewire-pulse never implemented PulseAudio's
`module-role-ducking`, so manual per-stream is the right primitive; the
snapshot-before-spawn trick is what makes it engine-agnostic. Verified
live on Costa's box: script round trip from the terminal (5 real streams
ducked to 30 % and restored, raw-volume fix caught by a +0.12 dB stream),
then end to end through the plugin — a pw-play tone plus six other
streams at 30 % during a spoken line, all back at 100 % after, state file
appearing and vanishing on cue, journal clean. `duck true` was left set
on his box (it's what he asked for); the voice there was bare espeak at
the time. Install-dir reality check: the plugin dir is a real v1.18 clone
carrying the v1.19 work as uncommitted changes (the v1.17 note saying the
dev symlink was back is stale) — the duck files were copied in by hand
for the live test, so dev edits in ~/Work still need that copy or a
restored symlink to reach the shell.

Agent-first ai keys (2026-08-29, v1.20.1): `set aiAgent`/`set aiModel` while
`ai` is off used to answer a bare "ok" — the one config surface that broke
the "ok — but" pattern the tts keys follow. Now both reply "ok — but ai is
off, so there are no agent lines to apply it to; set ai true first" (an
`unset` stays a plain ok). Found by an agent-exposure audit over IPC on a
fresh default install; the audit also confirmed the rest holds: `help`
lists every verb, `settings`/`get`/`set`/unknown-key replies, the duck and
tts warnings (both apparent misses were Costa switching the voice on from
the menu mid-audit), and out-of-range numbers like `restless 5` clamp at
the property binding. Same session context: the box is a real GitHub
clone of v1.20.0 again (the new-user tryout Costa asked for), so this fix
was hand-copied into the installed dir; Costa re-rigged rubick from the
picker himself and `duck true` was restored.

Poverty notice (2026-08-29, v1.20.2): setup-voice's no-GPU fallback line now
reads "no NVIDIA GPU with 6 GB to spare — you're poor. Get more RAM. Until
then, the robot it is" — Costa's ask verbatim ("tell them they are poor and
they need to get more RAM"; yes it's VRAM, the wrongness is part of the
joke). One echo, no behavior change.

Always-duck (2026-08-29, v1.21.0): the `duck` setting is gone — ducking is
always on at 30 % ("do not give option to duck other audio. ALWAYS duck
other audio", "we need to make it stupid simple"). Removed: the settings
key, the menu row, the set-reply, `duckSetting`/`duckEnabled`; `duckFactor`
is a constant 0.3, `startTts` always ducks, `voice` states it. README's
duck paragraph rewritten as a statement of character ("he considers what he
has to say more important than whatever you were listening to"). The same
session found why Costa heard nothing after enabling rubick on the fresh
install: PipeWire stream-restore had memorized 30 % for aplay — an aplay
stream had ended mid-duck during the v1.20 terminal round-trip tests, the
restore never reached it, and every later clone line started at 30 % of a
50 % sink (~−49 dB, silent for all practical purposes) with zero errors
anywhere. Diagnosed by catching the live sink-input at "Volume: mono: 30%";
fixed by pinning a live aplay stream to 100 % (which rewrites the memory).
That poisoning mode is now documented in the Ducking bullet — it can hit
any app that closes mid-duck, and there is no snapshot-side fix since a
dead stream can't be volume-set.

The poisoning turned out self-inflicted and compounding once ducking was
always-on: with back-to-back lines, each new line's snapshot caught the
PREVIOUS line's dying aplay sink-input (PipeWire teardown is async),
ducked it, lost it, and stream-restore memorized the product — 30 % → 9 %
→ ~1 %, which is exactly the "it's like 1% sound" Costa reported minutes
after the first heal (his autoduck plugin was suspected and cleared: it
only mutes browser streams, and the fingerprint was our 0.3 factor).
The fix is `duckRelease`, a 1 s Timer between speech end and `duckStop()`:
`startTts` stops it, so a line inside the window keeps the duck and
consecutive lines share one duck cycle — no re-snapshot, and by the time
a future snapshot runs the last stream is long gone. Both speech-end
paths (`ttsProc.onExited` queue-empty, and the duck's line-cancelled
branch) go through the timer. Healing a poisoned app is pinning one of
its live streams: play anything via aplay, `pactl set-sink-input-volume
<id> 100%`. Verified: three rapid `talk`s then a fresh aplay stream
starts at 100 %, duck state file clean, journal clean.

Drag chatter untangled (2026-08-29, v1.21.1): "when i drag the icon, the
voice messages interfere with each other" — overlapping voices during a
drag. Root cause was not the QML (one ttsProc, replacement kills + queues,
that held): speak-clone ended in `subprocess.run(["aplay", ...])`, so the
plugin's SIGTERM killed the python client and ORPHANED the aplay child,
which played the old line to the end while the next line's aplay started
on top — dragged lines every 3-6 s against 3-5 s Rubick lines stacked two
or three voices. Fix: `os.execvp("aplay", ...)` as speak-clone's last act,
so the process the plugin holds IS aplay by play time and the kill stops
the audio (same trick as the espeak `exec` prefix). Patched in the
setup-voice heredoc, the installed plugin's copy, and the live
~/.local/share/chatterbox-tts/speak-clone. Costa's "i guess we put more
time between them?" also honored: dragTalk is 5-9 s (was 3-6). Verified:
terminal TERM mid-line leaves no aplay, and back-to-back `talk`s over the
plugin never showed 2 concurrent aplays, journal and duck state clean.
The kokoro/piper half of the papercut was fixed right after (v1.21.2,
below).

Pipeline voices cut too (2026-08-29, v1.21.2): the kokoro and piper
command strings — setup-voice's generated CMDs and the matching
georgeCmd/piperCmd builders in Clippy.qml, kept byte-identical — now wrap
the pipeline in `trap 'kill $! 2>/dev/null' TERM; <pipeline> & wait $!`.
Why that shape: bash defers trap handling while a foreground job runs, so
a TERM on a bare pipeline waited out the whole line; backgrounded, `wait`
processes the trap at once and `$!` (the pipeline's last element) IS
aplay, so the kill stops the audio and the producer dies on its next
write via SIGPIPE. Stdin still reaches a backgrounded pipeline when it is
a pipe (verified — bash only nulls async stdin for terminals). Verified
live with the real piper venv against the parked ryan model: cut mid-line
kills aplay instantly, a clean run exits 0, no survivors; george/piper
strings byte-compared against setup-voice's build. A user whose
shell.json still carries an OLD unwrapped string just sees the picker
call it "custom" until they re-tap the chip — documented drift, nothing
breaks. README's mid-word paragraph now covers all three engine shapes
and hands hand-rolled pipelines the same wrap.

Slap keeps its SFX (2026-08-29, v1.22.0): "since we got voice, it mutes
the sound effects … i think it's funnier with SFX". Two causes, two
fixes. (1) Slapped lines are silent now: `say()` grew a 4th `silent` arg
→ `bubble.silent` (a plain property on the Bubble instance; the voice
watches the bubble, so the flag must ride on it), `syncSpeech` treats a
silent bubble as stop-speaking — the line shows, an in-flight voice line
is still cut, no duck fires. Knockout/fling deaths still speak; Costa
scoped the ask to the slap. (2) `scripts/duck` skips sink-inputs with
`node.name = "quickshell"` — our own SoundEffects were being ducked to
30 % under the voice line AND, worse, the short-lived SFX stream died
mid-duck at some point and PipeWire stream-restore memorized quickshell
at a permanent 30 % (caught live: the stream sat at 30 % with no duck
active; healed by pinning it to 100 %, which slaps now confirmed audible
— "wait slap is playng sorry"). The awk buffers each entry and flushes at
the next `Sink Input` line because node.name sits in Properties, after
Volume. Verified over IPC: slap → no aplay, no duck state, quickshell
stream untouched; talk → Brave ducked 30 % and restored exactly,
quickshell held 100 %, duck state clean, journal clean. Files hand-copied
to the installed clone (still a real clone, not the symlink).

Long lines finish (2026-08-29, v1.22.1): "if the line is too long, clippy
will cut off when saying it" — `bubbleTimer` runs at 450 ms/word (min
4 s), and its `hideBubble()` cuts the voice (that's the deliberate-hide
contract), but a clone pays ~2 s synthesis on a novel line (~11 s cold)
and speaks slower than 450 ms/word, so long lines lost the race and died
mid-sentence. Fix: the timeout — and ONLY the timeout — now waits for
the voice: `bubbleTimer.onTriggered` checks `speakingThisBubble()` (ttsOn,
not silent, `ttsLine === bubble.text`, and engine running / replacement
queued / duck snapshot in flight — `ttsLine` alone is stale after a
normal exit) and re-arms itself in 500 ms beats instead of hiding, capped
at 60 holds (30 s past the word timeout) so a hung engine can't pin him
in `talking` forever; the two arm sites (`say()`, `epitaph()`) zero
`bubbleTimer.holds`. Every deliberate hide — click dismissal, `shutUp`,
sleep, slap replacement — still cuts mid-word, untouched. No new
settings. Verified live with the Rubick clone: a 38-word novel line
(old timeout 17.1 s) took ~11.5 s synthesis + ~10.5 s playback, state
held `talking` the whole way and flipped to idle within half a second
of aplay exiting; short cached lines hide on the old schedule (the
predicate is false at trigger time); journal clean. Hand-copied to the
installed clone with the manifest bump.

First hello (2026-08-29, v1.23.0): Costa's ask — 'the very first message
should be something like "Welcome you fuck. Make sure you set me up in
options. Ask your agent eh?"'. On the very first boot after an install he
says a `firstRun` line (new quote key, in `quoteKeys` and quotes.json)
pointing at the right-click menu and the agent, then writes `greeted: true`
inline on the shell.json entry (new settings key, default false, README
row) — inline, not `persisted`, so a shell restart doesn't repeat it but
a reinstall (which strips the entry) does; `set greeted unset` re-arms it.
Mechanics: `greetTimer` (2 s, so the window is mapped) → `firstHello()`,
armed from `maybeBoot()`'s tail and from `wakeUp()`'s idle branch (where
it takes precedence over the welcomeBack line — fresh install while
locked). The pick is deterministic, not random: `pool("firstRun")[0]`,
so the nsfw line IS the greeting and under `clean` the clean variant
steps up as the first survivor. This session was the new-user simulation:
`omarchy plugin remove --yes` (also strips the inline settings — the
rubick/ai rig, noted in the session for restore), a real `omarchy plugin
add <github url> --enable --yes` clone of v1.22.1, `omarchy restart
shell` to zero `persisted`. Verified live on that clean install:
greeting on screen by screenshot (both variants — the first cut was
`randomQuoteFrom` and the camera caught the clean line, which is what
prompted the deterministic pick), `greeted: true` landing inline, a
restart with it set stays idle, journal clean. Hand-copied to the
installed clone (a real clone again — dev edits need the copy or the
symlink); repo left uncommitted.

The graveyard (2026-08-29, v1.24.0): the IDEAS.md global leaderboard, built.
Two halves. Server: new repo CostaFot/clippy-leaderboard
(~/Work/clippy-leaderboard) — Flask + psycopg2 + gunicorn cloned from
claps-api's shape (Costa's existing tiny-counter API; same Procfile, same
db() contextmanager, CREATE TABLE at boot), deployed as Railway project
`clippy-leaderboard` (Postgres via `railway add --database postgres`,
`DATABASE_URL=${{Postgres.DATABASE_URL}}` set BEFORE connecting the repo so
the first build has it, domain clippy-leaderboard-production.up.railway.app).
POST /bump takes {handle, kills, slaps} DELTAS: handles are CLAIM-FREE
(no cookies, no accounts, anti-cheat an explicit non-goal — collisions
merge, "every score was self-reported murder to begin with"), lowercased,
`[a-z0-9_.-]{1,24}`, deltas clamped 0-50 (hygiene, not anti-cheat), and the
reply carries the new totals + rank + total so the client never needs a
second GET. The one gate, Costa's ask ("basic post reqs stuff spam"): /bump
answers only a `costafot.clippy/*` User-Agent, else 403 "you are not a
paperclip" — spoofable by design, a doorman not a lock; an API key was
discussed twice and rejected as theater (anything baked into a public repo
is public; rotation would break every install). GET / is the page:
CSS-only headstones, one per handle, sqrt-scaled by kills
(0.55 + 0.45·sqrt(k)/sqrt(max), so a grinder can't flatten the page),
slaps tiebreak, rank badges on the top 3, "still breathing. coward." on
0-kill stones, top 100 + "…and N more, rotting quietly", empty board says
"Nobody has died yet. Disgraceful. Be the first." GET /api/scores?limit= and
/api/score/<handle> round out the API. Client (Clippy.qml): `leaderboard`
settings key — "" default, a handle joins; OPT-IN was the hard requirement,
nothing leaves the machine until a handle is set, and the README's "The
graveyard" section discloses exactly what does (handle + two small deltas,
nothing else) in the AI section's tone. bumpLeaderboard(0,1)/(1,0) directly
after the two persisted counter bumps in slap()/finishDeath(); the flush is
the duckProc park-don't-clobber idiom (deltas accumulate while a POST is in
flight, so a 10-slap beating coalesces into few POSTs), a failure re-adds
the sent deltas and backs off 30 s·2ⁿ capped ~16 min, lbRetry re-arms
through `asleep` instead of dropping (no curl into a lock screen, but held
deltas still flush after a long lock). Joining (or a remount while joined,
from maybeBoot) fires a zero-delta bump — legal on the server, creates the
stone immediately and fills lbCache with the rank for free. lbProbe covers
a missing curl (the espeak lesson: a Process that can't start never fires
onExited, so it must be probed and surfaced). Pending deltas die with the
shell — the tally's own documented trade. IPC: `leaderboard` verb
(off-with-join-instructions / "posting as X: #4 of 31 with …" + pending /
unreachable / no-curl suffixes, the `voice` shape), `set leaderboard`
replies (bad handle answers with the rule, a boolean is rejected as "a
handle, not a boolean", unset says the grave keeps what was posted), a
`help` line; the menu footer appends " · #4 as testcosta" from lbCache (no
settings row — free-text handle, no text input widget in the menu; IPC and
agent only, like aiModel). The curl sends `-A costafot.clippy/<manifest
version>`. Verified: the server end to end locally against a throwaway
docker Postgres (all four routes, case-folding, clamp 9999→50/-3→0,
400/404, UA 403, page renders and scales — note `app.run()` hangs under
this box's sandbox, `make_server` works; production is gunicorn, doesn't
care), and the plugin's FAILURE path live on the box: join while the
server is down → one journal warn, deltas held (including a real slap of
Costa's), backoff armed, verb honest about all of it. The happy path
followed once Railway's incident 8GL2R2U5 (deployment-init backlog, all
regions — it held both deploys QUEUED for ~75 min) drained: boot-time join
fills lbCache with the rank at mount, 3 rapid `slap` + a `kill` over IPC
landed exactly (server and verb both said #1, 1 kill, 3 slaps), the page
scaled testcosta's stone to 1.0 against two 0.55 flat-liners, journal
clean. The UA doorman verified in production: no-UA and Mozilla POSTs got
the 403, the plugin UA passed, / and /api stayed open. Two fixes came out
of the outage window: lbProc now collects stderr into the failure warn
(exit 22 alone named nothing — the whole "plugin curl fails, terminal curl
works" scare was just the edge being down/mid-swap, proven by running the
identical command under systemd-run --user), and wakeUp() re-runs
flushLeaderboard(true) — placed BEFORE the dead branch, kills matter to
the graveyard, moods don't — because a remount while locked skips
maybeBoot's flush (asleep returns first) and drops the old instance's
retry timer, leaving the leaderboard dormant till the next slap; caught
live when a `set` bounce remounted into Costa's locked session. Cleanup:
the test rows (testcosta, uatest, envtest) were DELETEd over `railway ssh
--service Postgres -- psql` (the DB is internal-only, no public proxy —
keep it that way) and the handle unset, so the board ships empty and Costa
picks his real handle himself. Files hand-copied to the installed clone.
Discoverability ("how does a user know to opt in?"): a dim menu-footer
hint under the tally — "graveyard: he can die publicly — set leaderboard
<name> (ask your agent)" — shown only while `leaderboard` is unset, the
Voice-hint stranded-audience rule; the menu can't take free text, so it
points at the agent/terminal. Verified by screenshot.

Last words finish too (2026-08-29, v1.24.1): "killing clippy the voice is
cut of a bit before clippy goes away" — the v1.22.1 wait-for-voice hold
covered `bubbleTimer` only; the two death timers still hid the bubble on
fixed clocks, and hiding the bubble is the deliberate-cut contract. So a
kill's lastWords died at `dieTimer`'s 2500 ms (the Rubick clone hadn't
finished a cached line by then, let alone a ~2 s novel-line synthesis)
and the flung line at `flingAnim`+`flingHold`'s ~2.1-3.1 s. Fix: both
timers grew the same `speakingThisBubble()` re-arm — 500 ms beats, 60-hold
cap so a hung engine can't make him unkillable — before their hide;
`kill()` zeroes `dieTimer.holds`, `flingOff()` zeroes `flingHold.holds`
AND restores `flingHold.interval = flingHoldMs`, because the imperative
re-arm overwrites that declarative binding and the next fling would have
lingered 500 ms instead of 1500. Every deliberate hide still cuts
mid-word; the fling's linger/echo run after the line ends, unchanged.
IDEAS.md was also pruned of shipped entries the same session (c914230).
Verified live over IPC with the Rubick clone: kill held `dying` ~3.5 s
until aplay exited on its own then went dead via GoodBye; fling held
through the line then ran hold+echo to `dead`; journal clean; Costa
confirmed by ear ("worked"). README: the mid-word paragraph's hide list
drops "his death" and the waits-its-turn sentence now covers last words.
Hand-copied to the installed clone.

Ideas, in rough order of payoff (a longer pitched list lives in IDEAS.md):
- Reactive lines without the agent: battery, CPU, hour of the
  day (`shell.serviceFor("omarchy.notifications")` and the agents plugin
  state are reachable from a panel — see ~/Work/omarchy-navbar-cat for how
  it listens to Hyprland/MPRIS/UPower). Or feed more of that into
  `clippy-ai`'s facts: notifications, the workspace.
- Let the agent pick the animation too (`anim` per line).
- The 15 original Clippy sounds live base64-encoded in clippy.js
  `agents/Clippy/sounds-mp3.js`; frames carry `sound` ids already. The
  `SoundEffect` plumbing from the slap is the way to play them.
- Trim the sprite atlas to the animations we use if the 42 MB texture matters.
- Quote curation — `quotes.json` is the seed, Costa hasn't gone through it yet.
