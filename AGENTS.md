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
  CLAUDE.md is picked up. Eight random lines from `quotes.json` (+
  `--quotes <quotesFile>`, nsfw dropped under `--clean`) go in the system
  prompt as register examples; without them the model guessed mild.
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
On GitHub at the README install URL, v1.10.0 (no tag yet). Not on the
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

Ideas, in rough order of payoff (a longer pitched list lives in IDEAS.md):
- Reactive lines without the agent: battery, CPU, pending updates, hour of
  day (`shell.serviceFor("omarchy.notifications")` and the agents plugin
  state are reachable from a panel — see ~/Work/omarchy-navbar-cat for how
  it listens to Hyprland/MPRIS/UPower). Or feed more of that into
  `clippy-ai`'s facts: pending updates, notifications, the workspace.
- Let the agent pick the animation too (`anim` per line).
- The 15 original Clippy sounds live base64-encoded in clippy.js
  `agents/Clippy/sounds-mp3.js`; frames carry `sound` ids already. The
  `SoundEffect` plumbing from the slap is the way to play them.
- Trim the sprite atlas to the animations we use if the 42 MB texture matters.
- Quote curation — `quotes.json` is the seed, Costa hasn't gone through it yet.
