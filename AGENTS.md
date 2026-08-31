# omarchy-inappropriate-clippy — agent notes

Before committing, re-read this file, the README and `docs/` against what
actually changed and amend anything they now state stale — an "only" that no longer
holds, a default that moved, a path that no longer exists — then commit.

This file is the current-state reference: what the code does today and the
rules for changing it safely — the code, this file and `docs/` are the only
source of truth. The session journal (who asked for what, what was tried
and dropped, how it was verified) is the commit messages: `git log
--grep=v1.36.0` or `git log -S<symbol>` when you need the why behind a
rule here (a `HISTORY.md` used to duplicate them; removed in v1.40.3 after
an audit folded every still-true fact into this file). Future work goes in
`IDEAS.md`, never here. User docs are split
(v1.40.0): `README.md` is the pitch — the 16:9 `preview.png` as hero
(the marketplace card image, 4267×2400 like Costa's other plugins; since
v1.40.11 an AI-generated illustration — Clippy on a deckchair on a thin
bar, the `comeback` line "Reports of my death were, frankly, your fault."
in the bubble, text rendered by the generator, Lanczos-scaled from a
1376×768 Gemini output — replacing the bar-strip-on-a-gradient card;
the prompt is in the v1.40.11 commit message), install, the mouse table, a short section per
big feature (1-3 sentence paragraphs, a screenshot under
`assets/screenshots/` with a `<!-- shot: … -->` comment saying how it
was captured — 1400×260 bar-strip crops of a `grim` at monitor scale
1.6, every state driven over IPC, `omarchy-toggle-idle stay-awake` first
or he falls asleep mid-shoot, `set leaderboard off` first or the kills
post; the alt text is the line in the bubble; `slap.gif` is a trimmed
Omarchy region screen recording of three real slaps, 20 fps through
palettegen/paletteuse — and a bold **Leaves your machine:** label with bullets under it
for anything that touches the network: ai and the graveyard), an
Uninstall section, a FAQ in the shape of Costa's other extension READMEs
(bold question, one blunt answer, telemetry first) and links; key names
in README prose only where the README is handing you the command
(`set clean true`, `tts: true`, `promptFile`), the configuration table
owns the full list — and
`docs/` is the manual, one page per feature (`configuration.md` holds the
settings table, `ai.md`, `voice.md`, `graveyard.md`, `scripting.md`,
`index.md` the contents). The same files are the GitHub Pages site
(source: `/docs` on `main`, `_config.yml` picks `jekyll-theme-primer` — minimal was tried first and squeezed the settings table into a 250 px column;
no front matter needed — the Pages gem's default plugins render bare
markdown and rewrite `.md` relative links; a link from `docs/` to anything
OUTSIDE `docs/` must be an absolute GitHub URL, since Pages serves only
`/docs` and a relative `../quotes.json` 404s on the site) AND ship in the
plugin clone,
which is what keeps the agent connection: `help` ends with
`<pluginDir>/docs/`, not a README path. Marketplace state is
`PUBLISHING.md`.

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

Design rules that outrank any single feature:

- Every setting is a flat scalar key with a default in `settingDefaults`, a
  `docs/configuration.md` table row, and — only if a user would reach for it — a menu row.
  Free-text/free-number keys (`aiModel`, `leaderboard`, `cloneTempo`…) get
  no menu row or only preset chips; the menu takes no keyboard focus.
  The table is one key per row (`intervalMin`/`intervalMax` were once one
  row and an agent reading column 1 saw a non-key). Don't build a
  `barWidget.schema` or any schema-driven settings UI unprompted — the
  menu is the config surface, `shell.json` the fallback.
- Agent-first replies: an IPC `set` that can't take effect answers
  "ok — but <why>" (tts keys, ai keys, clone knobs all do); status verbs
  (`voice`, `ai`, `leaderboard`) say what's wrong and how to fix it.
  Anything broken is surfaced in the UI and to agents, not just journaled.
- Nothing leaves the machine undisclosed: `ai` is opt-in; the graveyard
  posts anonymous kill/slap deltas by default — one shared alias for every
  install, so nothing identifies anyone — with the off switch one menu tap
  (`set leaderboard off` over IPC) and the README's graveyard bullet AND
  `docs/graveyard.md` saying exactly what's sent — and that IS the whole
  disclosure: Costa's call was "no incharacter disclosure", so never a
  spoken/bubble notice, the docs plus the IPC verbs carry it; no cloud
  TTS, ever. The screen look (`look`) sends a screenshot
  to the user's agent ONLY on the explicit gesture — never on a timer,
  never from decide()/unprompted(); an unprompted screenshot would be
  surveillance, not a gag. The mic (`listen`) is under the same law:
  opens only on the explicit gesture, the audio is transcribed locally
  (voxtype) and deleted, and only the text reaches the user's own agent.
  Keep it that way.
- Keep him mostly still — tune, don't make him busier.
- Keep `help`, `docs/scripting.md`'s verb block, and the actual IPC verbs
  in sync; `help` is the blind agent's bootstrap and ends with a
  copy-pasteable Hyprland `bindd` example, the `docs/` path and the Pages
  URL. Keybinds are agent-help only ("no UI for this. only agent help") —
  no menu row, no keys shipped; that `bindd` line is the whole feature. `scripting.md` also states the reply vocabulary (`ok — but`, `not
  now`, `busy — …`, `no — <rule>`…) and `set`'s value rules
  (`parseSettingValue`) — a new reply shape or a new refusal word goes
  there too; the verifier is "every reply string named in scripting.md
  greps in Clippy.qml, every IPC function but `ping` has a line in the
  block".

## Architecture

- `Clippy.qml` — root `Item` (the shell loads panels into a non-visual
  Loader, so the root must not be a window). Injected by the host: `shell`,
  `manifest`, `omarchyPath`. Nothing else — no `settings`, no `bar`.
  Settings are inline keys on our shell.json entry, which lives in
  `bar.layout.<section>[]` (a plugin with a `bar-widget` kind is filed
  there, like omarchy.menu), not `plugins[]`; `findEntry()` reads both,
  `shell.updateEntryInline` writes to whichever it finds, and
  `setSettings(map)` batches multi-key writes into one (two sequential
  writes race the remount; `setSetting` delegates to it). An entry still
  under `plugins[]` (pre-icon install) is moved into `bar.layout.right`
  after `omarchy.tray` by `adoptIntoBar()` once, on mount, via
  `shell.mutateShellConfig` — deferred with `Qt.callLater` (the write
  lands on `shellConfig`, which the `entryLocation` binding reads —
  binding loop otherwise) and refusing to run when there is no
  `bar.layout` at all (a layout with only us would replace the bar's
  defaults). `opened` + `open()`/`close()` are the `shell
  summon|hide|toggle` contract. Owns:
  - a single `PanelWindow` on `WlrLayer.Overlay` (the bar is `Top`),
    anchored on all four sides — a full-screen transparent surface (the
    gags fall through the whole screen; it was a `barSize + 150` strip
    until v1.42.0), `ExclusionMode.Ignore`. Input `mask: Region { item:
    actor; regions: [bubble rect, tombstone rect] }` so everything except
    Clippy, his bubble and a standing grave is click-through. His feet
    line is still the bar edge: `actor.y` is one binding, feet-line `+
    gagDy` (the additive gag offset — see gags below), and `size` runs
    20-400 since the surface no longer clips him.
  - the brain: `mood` ∈ idle | walking | talking | dying | dead |
    reviving, a `brain` Timer for idle→walk decisions, `quoteTimer` for
    unprompted lines, `bubbleTimer`, `respawnTimer`, `dieTimer`. Walking
    is a `NumberAnimation` on `actor.x` at `speed` px/s with
    `IdleSideToSide` looping; the direction cue is `GestureLeft` for
    screen-right (gesture names are the character's left/right).
    `decide()`: idle beats 10-30 s apart, each turns into a walk with
    probability `restless` (0.3), walks are mostly short hops of
    80-400 px with 1 in 5 a trek anywhere.
  - widget avoidance (`avoidWidgets`, default true): walk targets park in
    the gaps between bar widgets. `occupiedIntervals()` filters
    `shell.bar.moduleSlots` by his screen and the shell's visibility test
    (a collapsed slot keeps visible=true but drops to 0x0), maps with
    `mapToItem(null, 0, 0)` (bar-window x == screen x == stage x), pads
    6 px and merges; `freeGaps(w)` inverts that into positions where a
    width-`w` thing fits. Sampled lazily at pick time, NEVER from a
    binding: widget widths change without signals and `moduleSlots` is
    reassigned per register/unregister. Treks pick a width-weighted
    random gap; hops snap to the nearest clear position, uncapped — the
    snap IS the hop aesthetic (a first cut capped the snap at 120 px so a
    hop would "stay a hop"; deep-in-cluster targets then stood dirty and he
    parked on the workspaces within minutes). Standing on a widget raises the next
    beat's walk chance to 0.8. Boot/revive placement uses `randomSpot()`
    (also gap-preferring). Null `shell.bar`, no `moduleSlots`, or no gap
    he fits in fall back to raw targets.
  - gags (`gags`, default true, v1.42.0): scripted full-screen stunts.
    All y motion in the plugin is one additive offset, `gagDy`, on the
    actor's feet-line binding (the Tombstone-thud pattern — nothing ever
    assigns `actor.y`, so the binding can't be destroyed); a gag that
    leaves the bar sets or animates `gagDy` and ends at 0, plain state,
    zeroed in `revive()`, `maybeBoot()` and `finishDeath()` — that's its
    whole lifecycle. The tumble (`gagEntrance()`, v1.45.0 — it shipped
    as the skyfall in v1.42.0, a fall in from the far screen edge; Costa
    never warmed to it and picked the tumble from a pitched set, the
    rest parked in IDEAS.md): he rolls in along the bar line from the
    nearest screen edge like a dropped coin — one `ParallelAnimation`
    (`gagAnim`: x slide + three full rotation turns, both OutCubic, so
    the roll decelerates to a stop), pivoting `transformOrigin:
    Item.Center` for the duration (the wobble's Bottom pivot would sweep
    him through the screen edge; `onStopped` restores Bottom on every
    way out, interrupts included), then rotation snaps 1080→0
    (invisible), the slap `wobble` tips him upright the way he was
    rolling, and the comeback line plays `IdleHeadScratch` (the dizzy
    button — `comeback` takes an optional anim; the sprite's onDone
    calls with no args so the plain Greeting path stays random). Never
    touches gagDy. Runs inside `mood == "reviving"` so every existing
    gate refuses for free, and rides that mood's sleep contract
    (finishes on its own, ≤1.1 s — `gagAnim.onFinished` refuses to
    flip mood to idle unless still reviving, so a mid-roll IPC kill
    keeps its death). Triggers: `revive()` rolls an entrance with
    `entranceChance` (0.35, a constant — the on/off taste call is the
    `gags` key, the odds are ours; no new timers, the mostly-still rule)
    then coin-flips tumble or lob,
    and IPC `gag entrance` forces the tumble (the slap/fling
    non-pointer-testing
    idiom; says no line on landing — the comeback book assumes a death,
    and grudge lines need kills ≥ 1 — and settles into idle via a lone
    head-scratch).
    The lob (`gagLob()`, v1.46.0 — the fling's revenge, from the parked
    entrance set): someone off-screen threw him back — linear `actor.x`
    from the nearest side edge under an arced gagDy (one SequentialAnimation
    inside `lobAnim`: OutQuad up, InQuad down — a flat parabola apexing at
    22 % of screen height on a bottom bar; on a top bar a single
    decelerating toss up from the bottom edge, gagDy pre-set to the full
    drop while he is off-stage, the peek's invisible-teleport trick, so
    the mirror of the fling's long drop), a lazy 720° Linear spin on the
    tumble's Center-pivot discipline (`lobAnim.onStopped` restores
    Bottom), then `lobSplat`: an 82° face-plant the way he was flying, a
    450 ms lie-there, an OutBack spring back up (`onStopped` zeroes
    rotation, both stages mood-guarded like the tumble's). gagDy's own
    endpoint is 0, so even a mid-air kill's abandoned flight lands the
    offset before `finishDeath()` re-zeroes it. The comeback button is
    `EmptyTrash` (the trash-shake, read as dusting himself off) — spoken
    on the organic path, wordless via IPC `gag lob` (same
    no-comeback-book reasoning as the forced tumble). `revive()` and
    `maybeBoot()` stop `lobAnim`/`lobSplat` beside `gagAnim`.
    Menu row: the "Full-screen gags"
    ●/○ toggle (v1.43.0 — it shipped row-less; Costa asked for the row).
    The fling's long drop lives in the fling bullet below.
    The corner peek (v1.44.0): he slides in from a far-edge corner
    (the two corners opposite the bar, 50/50 — a bar-edge corner would
    just read as standing at the end of the bar) to 90% visible — a
    half-in peek was mathematically unswipeable under the original
    exit-anchored swipe judge, and even 90%-in the judge stayed near
    impossible on a grown body until v1.44.1 reworked it (see the slap
    bullet) — blown up to `peekSize`
    (`spriteSize` ×5, clamped 140-400 — a constant multiplier, the
    entranceChance rule; at bar size he was an unslappable speck, Costa:
    "he is fat to small to slap!"; `peekGrown` is its own flag, not
    `peeking`, so a mid-peek death stays giant through the choreography
    and `finishDeath()` clears it like gagDy), says a `quotes`-pool
    line via `nextQuote()`, dwells while the bubble lives, slides back
    out and restores his exact bar spot. Rolled in `decide()` with
    `peekChance` (a settings key, 0.04 default, dodge-shaped reader;
    free-number → no menu row) on the existing idle beats — no new
    trigger timers (`peekDwell` is only the say-failed fallback) — and
    forced by IPC `gag peek` (which DOES speak, unlike the forced
    entrance: its line is the ordinary quotes pool). Unlike the entrance
    it can NOT ride `mood = "reviving"` — say() and slap() both refuse
    there, and the peek needs both — so `peeking` (a flag, mood stays
    idle→talking) is the truth, gating decide/unprompted/crashReact/
    grab/flingOff/look/listen/reply/gag. gagDy never animates: it's set
    to the far edge while he's fully off-stage, both legs are one
    `peekAnim` on `actor.x`, and the dwell is the bubble's lifecycle —
    `hideBubble()` and the out-leg's `done` are a two-sided rendezvous
    into exactly one `peekFinish()`, which parks in `peekGhost` (200 ms,
    re-armed until `bubble.visible` drops) while the bubble's fade is
    still running — the fade rides the actor bindings, so restoring x
    under it dragged the ghost to the bar for a blink (seen live on the
    mid-peek slap, whose line outlives the recoil). A mid-peek slap counts normally
    (tally, leaderboard, knockout window) but skips the dodge roll and
    the shove (both would write a corner x into `persisted.lastX` — the
    peek never writes lastX, `peekReturnX` is plain state) and recoils
    him out at once, the bubble riding the live bindings and speaking
    clamped at the corner, the fling pattern. The bubble flips to his
    bar side while peeking (the instance's `aboveHim` binding) —
    without the flip the vertical clamp parks it ON him at the far
    edge and the dwell is a bubble with no Clippy (seen live, top
    bar, bottom corner). A knockout/kill mid-peek
    lets him die hanging: `peekCancel(false)` keeps x/gagDy,
    `finishDeath()` zeroes gagDy and `placeGrave()` clamps — the
    fling-grave behavior, no new grave code. Sleep, remount and stage
    resize run `peekCancel(true)` (restore); a fling mid-peek is
    refused (`flingFall.from = 0` would snap gagDy out from under him).
  - `IpcHandler { target: "costafot.clippy" }` — string args only, no
    optional params. `set key value` / `get key` / `settings` are the
    config surface (keys from `settingDefaults` — keep it equal to the
    `docs/configuration.md` table; values through `parseSettingValue`:
    true/false/number/"unset"→remove/else string, written via the same
    `setSetting()` the menu uses). `show`/`hide` are the idempotent pair
    next to `toggle` (`show` = `bringBack()`, so it also revives),
    `unsnooze` next to `snooze`; `say` answers `hidden` when `opened` is
    false rather than talking into an invisible window; `showMenu`/
    `hideMenu` drive the menu without a pointer (no ydotool on the box —
    it's how menu states are screenshotted). `help` lists every verb one
    per line and ends with the bindd example + `docs/` path + Pages URL.
    Note `get`
    prints string values JSON-quoted — scripts parsing it must strip the
    quotes (warm-voice does).
  - `PersistentProperties { reloadableId: "costafotClippy" }` for
    `deadUntil` (0 alive, -1 dead until `respawn`, >0 epoch ms),
    `snoozedUntil`, `lastX`, and the tally `slapCount`/`killCount` —
    bumped in `slap()` and in `finishDeath()` (the one place every death
    path lands, so a fling is one kill and a knockout is ten slaps plus
    one kill), shown dim at the foot of the menu and by IPC `stats`.
    PersistentProperties survive remounts but not a shell restart, so
    tallies reset on reboot — a documented trade the README owns up to
    ("the shell forgets").
    `{kills}`/`{slaps}` placeholders (v1.38.0) work in ANY line via
    `fill(text)`, applied in `say()` and in the three direct
    `bubble.text` writes (`kill`, `epitaph`, `flingOff`); while `mood
    == "dying"` kills counts one more, because `finishDeath()` bumps
    after the last words are written. Grudge lines sit only in keys
    where the count is guaranteed ≥1 (lastWords, knockedOut, comeback,
    slapped, flung, epitaph) — "You've killed me 0 times" is not a
    joke. Templated lines are skipped by warm-voice, so on a clone
    they synthesize at say-time (~2-5 s), like `{away}` lines.
  - `asleep` (`pauseWhenAway`, default true): he stops while nobody can
    see him. Three sources, all bindings:
    `shell.serviceFor("omarchy.lock").locked`,
    `shell.serviceFor("omarchy.idle").idledThisCycle` (the screensaver is
    a fullscreen *window* and our layer is Overlay, so without this he'd
    walk on top of it), and `screensOff` = every non-disabled
    `Hyprland.monitors` entry has `lastIpcObject.dpmsStatus === false`.
    Hyprland has no DPMS event, so `dpmsPoll` calls
    `Hyprland.refreshMonitors()` (socket, no fork) every 10 s, 2 s while
    off, and unlock/idle-end refresh at once. `serviceFor` works as a
    binding because the shell reassigns `_services` on registration.
    `fallAsleep()` stops walk/brain/quote/bubble/drag timers, stops the
    sprite and drops the bubble (idle/walking/talking only;
    dying/reviving finish on their own); `shown` hides the window.
    `decide()`, `unprompted()`, `say()` and `maybeBoot()` gate on it;
    `respawnTimer` swallows a revive while asleep and `wakeUp()` runs it
    if `deadUntil` has passed, else `idleAnim()` + `scheduleQuote()`.
    `AgentBrain.paused` blocks `topUp()`. Waking after ≥ `welcomeAfterMs`
    (60 s) says a `welcomeBack` line 1.5 s later (`welcomeTimer`, so the
    window is mapped and the unlock has faded), `{away}` → `awayText()`
    ("47 minutes"/"3 hours"/"2 days"), and `agentBrain.remember()` gets
    "came back after N away". The DPMS path is hand-tested
    (`omarchy-brightness-display off|on`); the lock and idle paths are
    the same kind of binding but were never exercised by hand.
  - first hello: on the very first boot after an install he says the
    `firstRun` line (deterministic: `pool("firstRun")[0]`, so the nsfw
    line IS the greeting and under `clean` the clean variant is the
    first survivor), then writes `greeted: true` inline — inline, not
    `persisted`, so a shell restart doesn't repeat it but a reinstall
    (which strips the entry) does; `set greeted unset` re-arms.
    `greetTimer` (2 s, so the window is mapped) is armed from
    `maybeBoot()`'s tail and from `wakeUp()`'s idle branch, where it
    takes precedence over the welcomeBack line.
  - crash reactions (`crashLines`, default true, v1.34.0): a Process
    follows `journalctl -f -n 0 -o json` on systemd-coredump's
    MESSAGE_ID (`fc2e22bc…`) with `_UID=$(id -u)` matched inside
    journald, so every emitted line is one of the user's own dumps —
    the same stream `omarchy-crash-watch` follows for its toast, read
    directly so we don't inherit that watcher's gates (default agent
    chosen, capture toggled on). `crashReact()` prefers COREDUMP_EXE's
    basename over the 15-char-truncated COMM, skips omarchy-crash-*/
    omarchy-agent-* machinery, dedupes per program per 60 s
    (`crashLastAt`), `remember()`s the crash for the agent's --recent,
    then says a `crashed` book line with `{app}` substituted — a book
    reaction like `slapped`, instant and agent-free on purpose (the
    agent already gets crashes via clippy-ai's extremes facts).
    say()'s own gates drop it while dead/asleep; snoozed/dragging/
    looking are checked explicitly. `-n 0` means a remount or a
    quickshell crash never replays old dumps; the follower only runs
    while `crashLines` is on. Test a crash with
    `sleep 30 & kill -SEGV $!`.
- `ClippySprite.qml` — port of clippy.js `src/animator.js`. The full sheet
  is one `Image` inside a `clip: true` 124×93 viewport, translated to the
  cell (`x = -cell.x`) — the CSS background-position approach, so a frame
  change is a translation, not a texture reload. The viewport is scaled
  with `scale` from the top-left. Frame stepper: exitBranch when exiting →
  weighted `branching` (subtract-and-compare, remainder falls through to
  i+1) → i+1; clamped to the last frame; durations clamped to ≥16 ms. A
  frame with no `images` means "hidden" (GoodBye ends hidden,
  Greeting/Show start hidden). `play(name, loop, onDone)`, `exit()`,
  `stop()`, `has(name)`. **Named `ClippySprite`, not `Sprite`** — QtQuick
  ships a `Sprite` type and it wins over a sibling file; the symptom is
  "Cannot assign to non-existent property" on our properties.
- `ClippyMenu.qml` — the menu (right-click on him or the grave, or the bar
  icon), navbar-cat's `CatMenu` pattern: its own full-screen transparent
  `PanelWindow` (input region only while open, click anywhere dismisses,
  NO keyboard focus — that's a design rule, no free-text input widgets)
  with a card under `anchorPos` on `anchorScreen` (null = Clippy's
  screen). Takes `clippy` (the root Item), emits `act(name)` for actions
  and `chose(key, value)` for settings; the root maps the latter onto
  `setSetting()`. Opening it freezes the walk. When he is dead or hidden
  the action rows collapse to "Bring him back" → `act("revive")` →
  `root.bringBack()`. Rows: actions (including "Judge my screen" →
  `act("look")`, visible only while `ai` is on — without the agent the
  row would do nothing — and "Say it to his face" → `act("listen")`,
  same gate plus `voxtypeMissing === false`; its label flips to
  "Listening…"/"Thinking…" and tapping "Listening…" is the stop
  toggle); `Choice` chip rows for clean, sounds,
  restless ("Walks"), size, the Voice picker, and Tempo/Pitch presets
  (Tempo slow 0.9 · normal 1 · brisk 1.1 · fast 1.25; Pitch deep 0.85 ·
  normal 1 · light 1.15 · squeaky 1.35 — shown ONLY while
  `cloneKnobsApply`, since the keys do nothing for non-clone voices; a
  QtQuick Column skips invisible children so they collapse without a
  gap; an off-preset IPC value highlights the nearest chip, the Size
  row's rule); ●/○ `Entry` toggles for Sounds, "Full-screen gags",
  "Duck other audio" (the duck ratio itself is IPC-only) and the
  leaderboard; `Entry` rows take an optional `hint` (dim second line,
  fontSize−2, only sized when non-empty). Footer: the dim tally, "· #N
  as <handle>" from `lbCache` when joined, and stranded-audience hints
  (setup-voice under Voice only in the `!needs && !custom` state; the
  graveyard join hint only while `leaderboard` is unset).
- `BarWidget.qml` — the bar icon, `kind: "bar-widget"` on the same
  manifest (`qs.Ui` `BarWidget` + `WidgetButton`, nerd-font paperclip
  `󰏢`, dimmed when he is dead or hidden). One per monitor. No state of
  its own: it finds the panel instance through
  `bar.shell.panelLoaders["costafot.clippy"].item` and calls
  `showMenuAt(x, screen)`, so the card opens under the icon on whichever
  monitor's bar was clicked. If the panel isn't mounted it falls back to
  `bar.run("omarchy-shell costafot.clippy showMenu")`. No IpcHandler
  here — the panel owns the target.
- `Bubble.qml` — tooltip-coloured rounded rect + wrapping text, capped at
  320 px. Two rotated-square tails: bordered one behind the body for the
  outline, borderless one on top to hide the body's border across the
  join. `ai: true` (set by `say(text, anim, ai)`; `nextQuote()` tags
  agent lines) is the "this came from the agent" dress: border in
  `Color.accent` and a nf-md-creation sparkle (U+F0674, literal in the
  file) in the top-right. `silent` (4th `say()` arg) rides on the
  instance because the voice watches the bubble, not the say paths;
  slaps set it and `slapSoundDone()` clears it when the crack ends. The
  kill and fling paths write `bubble.text` directly and set `bubble.ai =
  false` first. While a grave stands the bubble anchors to it.
- `Tombstone.qml` — a headstone at the death spot while `mood == "dead"`
  (`tombstone: true`): tooltip-coloured stone, paperclip-over-RIP
  engraving, mound, OutBounce thud on appear, 500 ms fade out when
  `revive()` flips the mood. `placeGrave()` (from `finishDeath()`) snaps
  it into a widget gap via `freeGaps(w)` (the stone is narrower than
  him); a fling's grave is placed by clamping his off-stage centre to
  the stage, nudged off whatever occupies the edge. `persisted.graveX`
  (-1 = none) survives remounts. In the input mask only while shown. A
  click says an `epitaph` line (written directly to the bubble the way
  kill paths do — `say()` refuses while dead; `{back}` →
  time-to-respawn via `backText()`); right-click opens the menu anchored
  to the grave, not `actor.x` (a fling leaves that off-stage). IPC
  `epitaph` exists because pokes aren't pointer-testable.
- `AgentBrain.qml` + `scripts/clippy-ai` — lines from the user's default
  coding agent (`ai: true`, off by default). Omarchy's "default agent" is
  only a name in `~/.config/omarchy/defaults/agent` plus `omarchy-agent`
  (interactive); there is no headless API, so the script carries its own
  one-shot table mirroring `omarchy-agent`'s `case` (`claude -p --tools
  "" --setting-sources "" --system-prompt`, `codex exec -o`, `pi -p
  --no-tools`, `opencode run --pure`; `--model` mapped per agent). It
  gathers the facts itself in three tiers (v1.33.0 — the flat always-on
  list had the model doing nothing but clock/uptime/usage jokes): a core
  always sent (time, focused window, all mapped window titles, playerctl,
  the `--recent` note of slaps/drags/kills the QML side collects);
  extremes only when they fire (battery low/discharging, load > cores,
  memory ≥85%, uptime >3 days, disk ≥85%, coredumps today, failed units,
  live mic, agent usage only ≥50%); and a shame pool where each fact
  self-gates on notability (days since pacman -Syu, package/orphan
  count, dirty repos and commit drought in `~/Work`, most-typed history
  command, workspace and browser-tab counts) and `shuf -n 3` of the
  survivors go in — so `--context` is one random draw and batches don't
  converge on one stat (keep ≥7 candidates in the pool or the draw stops
  varying). The folder-rummage facts (Downloads
  count+filenames, screenshot hoard, trash, loose `$HOME` files) were
  cut in v1.37.2 — batches kept converging on file jokes; don't re-add
  facts built by listing a directory's contents. A `--reply` call thins all of it
  (v1.36.0): no time, no window list, no extremes, no usage, no shame
  pool — just the focused window and the track, the right-now facts, so
  their words are most of what the model reads (a shame draw was in the
  first cut, until a "hello" got answered from Downloads — a comeback
  that rummages folders reads as him ignoring them;
  `--reply x --context` shows the thin set).
  All handed over as text,
  tool-less, from `$TMPDIR` so no CLAUDE.md is picked up. Twelve random
  lines from `quotes.json` (+ `--quotes <quotesFile>`, nsfw dropped under
  `--clean`) go in the system prompt as register examples; the prompt
  asks for "jabs" under explicit rules (v1.36.0 — the spiral pass:
  exactly ONE fact per line as the launchpad, the joke is the
  escalation built on it, a line that reports a fact is a failure — and
  not zero facts either: fact-free lines drift into generic slop, the
  fact is the anchor;
  hunt the stupid little detail, one short sentence, no
  "champ"/Twitch-isms, the no-clock-jokes discard rule in every mode).
  The system prompt OPENS with the roleplay/consent frame ("installed
  this bit on purpose … pulling punches is breaking character" — it
  used to sit mid-prompt in `tone`; it survives `--clean`, being the
  frame, not the register), names escalation as the signature move (one
  small real thing blown wildly out of proportion until it is about
  their whole life — the Bill Burr school, still fenced: not an
  impression, no catchphrases, no crowd work — the clause names the
  delivery, not the man, because "write like Bill Burr" produces
  freakin'-Boston cosplay) and the character as a
  petty gremlin, not an assistant. Swearing is prescriptive in EVERY
  non-clean mode (v1.36.0 — it was batch-only, and sonnet stayed
  swearless even under the batch "must"): batches must land at least
  one "fuck-level, not damn-level" line, one-jab calls (look/reply)
  must carry one in their single line, both with a
  check-before-you-answer clause (that clause is what finally moved
  sonnet), and `--clean` replaces the whole tone line.
  `--prompt-file` (the `promptFile` key, v1.37.0 — expandHome'd, passed
  from all three call sites: AgentBrain batches, the look, sendReply)
  replaces the whole CHARACTER layer — the system prompt AND the
  per-mode rule lists (rules like "mock them for asking" in the user
  blocks would bleed through a gentle custom persona) — leaving only the
  scaffold: the facts block, the
  mode framing (screenshot pointer / their words / line count) and the
  JSON output contract the parser depends on. Register examples then
  come from quotesFile ONLY, under a neutral "match this register"
  framing (the built-in book would fight the custom persona); `--clean`
  still filters nsfw examples but adds no tone line — the file owns the
  tone, and the built-in taste rules (no-clock, length cap, swear
  quota) go with it, a documented trade. Unreadable or empty file →
  stderr note and the built-in prompt (the quotesFile fallback idiom) —
  and surfaced, not just journaled (v1.37.1): `promptProbe` (`[[ -r &&
  -s ]]`, mount + changes, the ttsProbe idiom) feeds `promptFileMissing`,
  the `ai` verb appends "custom prompt: <path>" (with an unreadable
  warning when so), and the `set promptFile` reply states the replace
  contract. Free-text path, so IPC/agent only — no menu row. Note a
  persona swap does NOT flush AgentBrain's cache: lines from the old
  character linger up to 20 min (flushing in onPromptFileChanged would
  fire on every mount's async settings delivery and cost a call per
  remount — the rule is remounts stay cheap).
  `--context` prints the facts, `--prompt` the whole prompt. Output is a
  JSON array parsed three ways in turn: as JSON; else every JSON string
  literal in the text (claude sometimes emits the array with no commas);
  else one per non-empty line. ~4-8 s for claude, ~16 s opencode; haiku
  is 44-63 s on the real prompt — don't suggest it. `AgentBrain` runs it
  through a `Process`, caches lines in `PersistentProperties`
  (`costafotClippyBrain` — remounts must not cost a call), expires them
  at 20 min, refills when ≤1 left with a 60 s minimum gap doubling on
  failure (cap 32 min), batch 5; `take()` returns null on anything
  wrong; `linesArrived(lines)` fires on a successful batch (voice
  warming hooks it). Root's `nextQuote()` prefers it over
  `randomQuote()` for unprompted lines, left-click, menu "Say something"
  and IPC `talk`; `slapped`/`dragged`/etc stay on the book (instant).
  IPC `ai` → `status()`. `take()` and short answers are journaled, so
  `journalctl --user -o cat | grep clippy` tells the story. The screen
  look (v1.32.0): IPC `look` / the menu's "Judge my screen" (shown only
  while `ai` is on) → `lookAtScreen()` — grims his screen to
  `$XDG_RUNTIME_DIR/clippy-look.png`, runs `clippy-ai --image <path>`
  (one jab; the prompt hunts the most absurd visible detail — "the
  stupid little detail is the kill" — and bans assistant behavior
  outright: no summarizing, no noticing like a productivity tool, no
  competence, no time/day; same register examples; claude gets
  `--tools "Read"` — its only image route, verified — codex gets `-i`,
  every other agent just gets the path in the prompt, generic
  best-effort), deletes the file when the call returns, and says the
  line agent-dressed. Async: the IPC reply is immediate ("ok — looking
  …"); while it runs `looking` gates `decide()`/`unprompted()` and he
  plays a looping CheckingSomething; failures set `lookFailed`
  (surfaced in the `ai` verb), a verdict landing on a sleeping/dead
  Clippy is dropped as stale. `aiModel`:
  unset is the agent's CLI default (for claude that's the CLI default
  model, NOT settings.json's `model` — `--setting-sources ""` isolates
  it); shown in the "Lines from <agent>" row label when set, no picker
  (names differ per agent). `set aiAgent`/`set aiModel` while
  `ai` is off answer "ok — but ai is off…"; `set promptFile` always
  answers with the replace contract, prefixed ok-but while `ai` is off. Talk-back (v1.35.0): IPC `listen`
  (toggle) / `reply <text>` and the menu's "Say it to his face" (shown
  only while `ai` is on AND voxtype exists — `voxProbe` feeds
  `voxtypeMissing`, probed on mount and menu open). `listen` records the
  mic with `timeout -s INT 15 pw-record --rate 16000 --channels 1` into
  `$XDG_RUNTIME_DIR/clippy-listen.wav` — the toggle-stop is
  `recordProc.signal(2)` and `timeout` forwards a received INT, so the
  cap and the stop are the same signal path and INT is pw-record's
  designed stop (the WAV header gets finalized; verified). The take is
  transcribed by `voxtype transcribe` in a bash chain that `rm`s the wav
  either way (voxtype's daemon/push-to-talk mode was rejected: it types
  the transcript into the focused window; the one-shot is the only usable
  route); voxtype's stdout is progress + ANSI log lines, one blank
  line, then the transcript, so the parse takes everything after the
  last blank line, ANSI-stripped. A punctuation-only transcript (whisper
  hallucinates "." on silence) gets a `heardNothing` book line and no
  agent call; a real one goes to `clippy-ai --reply <text> --said
  <bubble.text>` (his last line survives bubble hide) — one combative
  comeback, image-mode-shaped prompt (fight rules, an escalate rule —
  the comeback ends bigger and stupider than the insult started — and
  it mocks questions instead of answering: the heckler, never an
  oracle; the one-jab swear quota applies since v1.36.0, and the
  roleplay/consent framing now opens the system prompt itself), said
  agent-dressed, over the thinned reply context (focused window and
  track only — and even that rides along just ONE reply call in three,
  `RANDOM % 3` at context assembly: "ignorable" wording alone didn't
  stop the window jokes, because a fact that is always in the prompt is
  a fact the model keeps using; the skip is enforced, not hoped for.
  Fact-free calls get no context block and no facts rule at all —
  `--reply x --context` shows the live draw, usually empty). IPC `reply` enters the same back half
  (`sendReply()`) without the mic. Rules of the machinery: he never
  speaks while the mic is live (`say()` refuses on `listening` — his TTS
  must not transcribe itself; starting a listen hides the bubble first);
  a live mic dies with its context (`abortListen()` from `fallAsleep`,
  `kill`, `flingOff`, hide, `set ai false`) while an in-flight
  transcription/agent call is never killed — its result is gated on
  arrival (state re-checks + the `say()` stale-drop, the look's rule);
  `occupied` (looking || listening || replying) gates
  `decide()`/`unprompted()`/`crashReact()`; `look` and `listen` refuse
  each other as busy; failures set `replyFailed`, surfaced in `ai`. No
  `--recent` in the call (the look's feedback-loop reasoning); the
  exchange `remember()`s itself. Ai off → both verbs say a `noBrain`
  book line themselves. No new settings key — the gesture is the opt-in.
  Test without a mic: `reply "<text>"` over IPC.
- `quotes.json` — `{ quotes, lastWords, comeback, slapped, knockedOut,
  dragged, dropped, flung, crashed, welcomeBack, epitaph, firstRun,
  noBrain, heardNothing, dodged }` (the
  key list is `quoteKeys` in Clippy.qml; add there and here), entries
  `{ text, nsfw, anim? }`. `clean: true` filters `nsfw`. Content rules:
  lines must be speakable — no elongation gags or repeated letters
  ("NOOOO", "FUUUU"), clone voices read them as garbage (v1.29.1 rewrote
  every `flung` line for this; nothing enforces it) — and a count
  placeholder is phrased "kill number {kills}" / "{slaps} so far", never
  "{kills} times", which reads "1 times". `quotesFile` is
  merged in (same shape, or a bare array): quotes are two books, `book` +
  `extraBook`, merged per key in `pool(key)` so FileView load order
  doesn't matter. Bad JSON or a missing path falls back to the built-in
  book.
- `assets/clippy/{map.png,agent.json}` — from clippy.js via
  `scripts/fetch-assets` (dev-time only, results are committed). map.png
  is 3348×3162, 27×34 cells of 124×93; one 8-bit palette PNG → ~42 MB as
  an RGBA texture. Fine for a joke. `assets/sounds/*.wav` (two slaps, the
  fall, the dodge whoosh) were supplied by Costa; no licence noted —
  PUBLISHING.md's rights section covers only the artwork and the Rubick
  audio. `assets/voices/rubick.wav` — the
  shipped default clone reference (940 KB, s16le mono 24 kHz, exactly
  20 s), byte-identical to the approved take in
  `~/.local/share/chatterbox-tts/voices/rubick.wav`. Dota 2 audio,
  © Valve, credited in the README's notes and `docs/voice.md`. Never
  regenerate or re-encode it — a
  re-cut sounds subtly different; setup-voice `cp`s it verbatim.

## Slap, drag, fling (in Clippy.qml)

- Slapping: `slap(dir)` — middle-click (side hit decides direction) or a
  pointer fling across him, judged in the actor `MouseArea` (the input
  mask means motion is only reported over him): ≤200 ms, ≥60 % of his
  width capped at 100 px, mostly horizontal, ≥1.2 px/ms. Since v1.44.1
  the anchor rolls (re-anchored to the last motion event when the
  200 ms window ages out or the direction reverses — the enter-anchored
  judge made the natural aim-then-flick invisible: a pointer resting on
  him >200 ms could never slap without leaving and re-entering), and
  when the 100 px cap binds (width > ~167 px — every peek, huge `size`
  values) `judgeSwipe()` runs on every motion event, not just
  `onExited`, because a body wider than a 200 ms flick can traverse
  made the exit requirement mathematically unslappable; at bar sizes
  the exit-only judge is kept deliberately so a fast aim-and-click
  never reads as a slap, and `swipeSlapAt` (500 ms cooldown) keeps the
  rolling anchor from re-arming one swipe into two slaps.
  A `SoundEffect` per file via an `Instantiator`
  (`assets/sounds/slap-*.wav`, mono 44.1 kHz — SoundEffect wants WAV), a
  `shoveAnim` on `actor.x`, a `wobble` on `actor.rotation` (pivot
  `Item.Bottom`), then `say()` with a `slapped` line — silent while the
  crack plays (`bubble.silent`; any in-flight voice is cut), un-silenced
  by `slapSoundDone()` when the chosen SoundEffect's `playing` drops (or
  `slapVoiceCap` gives up at 2 s — keep that cap under `say()`'s 4 s
  bubble floor: nothing runs during the silent wait, so a longer cap would
  hide the bubble before the voice starts), so the voice speaks the line
  right after the SFX; identity-guarded via `slapWaitFx` (a re-slap supersedes,
  fling sounds never match) and state-guarded (a dismissed/replaced/dead
  bubble stays silent). No sound played (sounds off, fx not Ready) → the
  line is said non-silent and speaks at once. Slap timestamps in `slapTimes`;
  `slapsToKill` (10; 0 = never) inside `slapWindowMs` →
  `kill("knockedOut")`, and the knockout still speaks its lastWords — a
  death, not a slap reaction. `slap: false` restores the old
  middle-click snooze. IPC `slap left|right`. The miss (v1.39.0):
  `dodge` (0-1, default 0.1, flat — deliberately NOT scaled by the kill
  tally; "just give him a small chance") is rolled first thing in
  `slap()` after the state guards: a hit becomes `dodge(dir)` — a whoosh
  (`assets/sounds/dodge-whoosh.wav`, Costa's pick, through a third
  SoundBank; `dodgeSound` follows `slapSound` like `flingSound` does, so
  the menu's Sounds row mutes all three) instead of the crack, no
  `slapCount`, no leaderboard delta, no `slapTimes` entry (a miss can't
  add up to a knockout), a 150 ms `shoveAnim` sidestep of 1.2× his
  width the way the hand was going (flipped when the edge leaves no
  room; `shoveAnim.duration` is set per use, 380 for the hit) with no
  wobble, and a `dodged` book line that rides the same
  silent-until-the-SFX-ends path as the slapped line (`slapWaitFx` +
  `slapVoiceCap`). `slap()` returns "dodged" so IPC `slap` answers
  `dodged` instead of `ok`; `agentBrain.remember()` gets "swung at him
  and missed". `set dodge 1` is how to test it, `0`/`false` is off.
- Dragging: a 300 ms left press (`pressAndHoldInterval`) → `grab(x)`;
  `dragTo(x)` moves `actor.x` by the pointer's offset from `grabX`,
  leaning `actor.rotation` against the pull with hand-rolled smoothing
  (no `Behavior`: the slap `wobble` animates the same property);
  `drop()` on release runs `wobble` with the last velocity's sign. A
  `dragged` line on pickup and every 5-9 s (`dragTalk`), a `dropped`
  line on release. `dragging` gates `decide()`, `unprompted()`, `slap()`
  and the post-bubble reschedule. No `clicked` follows a hold, so a
  drag never fires the say-something click. `drag: false` turns it off.
- Flinging: `dragTo` keeps a smoothed pointer speed in px/ms from the
  pointer's *stage* position (so it counts while he's pinned at an
  edge). `drop()` with `|dragSpeed| ≥ flingSpeed` (1.8) and a motion
  event inside the last 100 ms → `flingOff(dir)`: mood `dying`, a
  `flung` line in the bubble (it clamps to the stage, so it stays at the
  edge he left by), `flingAnim` carries `actor.x` past the edge at ~1.4
  px/ms (600-1600 ms) and spins `rotation` 540° — and on a top bar with
  `gags` on, a parallel `flingFall` drops `gagDy` the whole screen
  (InQuad), so he plummets diagonally and the bubble rides its live
  `actor.y` binding down to the bottom corner (a bottom bar keeps the
  flat sideways exit: `flingFall.to` stays 0); when it finishes the
  bubble lingers at the edge at full opacity for `flingHoldMs` (1500,
  `flingHold`), then is hidden with `Bubble.fadeMs` stretched to
  `flingEchoMs` (1500) so it trails off, then `flingEcho` restores
  `fadeMs` and runs `finishDeath()`. `revive()` resets `rotation` and
  re-places him. The falling sound (`assets/sounds/fall-cartoon.wav`)
  plays through the same SoundBank component as the slaps; `flingSound`
  defaults to `slapSoundOn` so the menu's "Sounds" row mutes both. IPC
  `fling left|right`; `fling: false` makes a fast release a plain drop.
  Neither drag nor fling is pointer-testable from a terminal (no
  ydotool) — IPC covers the throw, a human verifies grab/release feel.

## Voice

`tts` — `false` (default) silent, `true` speaks every bubble line through
espeak-ng, a string is a user shell command (the whole contract is "line
on stdin"). Built-in voice `en+m3`, overridden to `en+whisper` while
`mood == "dead"` (epitaphs are whispered), shaped by `ttsVoice` /
`ttsSpeed` (80-450) / `ttsPitch` (0-99) — built-in only; a custom command
is one opaque string and ignores all three (clones bend via
`cloneTempo`/`clonePitch` instead).

- The hook is three handlers on the Bubble instance
  (`onShownChanged`/`onTextChanged`/`onSilentChanged` →
  `Qt.callLater(syncSpeech)`, coalescing say()'s text+shown double-fire)
  rather than calls in the say paths, so the three direct `bubble.text`
  writes (`kill`, `epitaph`, `flingOff`) are covered and every bubble
  hide cuts the voice mid-word; `fallAsleep()` hides the bubble, so
  sleep gating is free, and `onOpenedChanged` stops it on `hide`
  (close() only flips `opened`; the bubble props stay put). A silent
  bubble means stop-speaking; the slap path un-silences it when the SFX
  ends, and the flip alone starts the line.
- Process discipline: one `ttsProc` running `["bash", "-c", cmd]` with
  the line on stdin (bash always starts, so a missing engine is exit 127
  in `onExited` — a raw fail-to-start never fires `exited`). **Kills are
  `signal(15)`, never `running = false`** — that quietly leaves the
  child alive (also `Component.onDestruction: signal(15)`). A
  replacement line parks in `ttsQueued` until the old process's
  `onExited` (the SIGTERM is async). Deliberate kills clear `ttsLine`
  first so `onExited` doesn't mistake them for failures; real failures
  warn once per engine (`ttsWarned`, reset by `onTtsSettingChanged`).
  Two change handlers on purpose: inside `onTtsSettingChanged` the
  dependent `ttsOn` binding is still stale, so the turn-off kill lives
  in `onTtsOnChanged`.
- Every engine command must let that kill reach the audio player:
  `exec` is prepended to the built-in espeak command; `speak-clone`
  execvps into aplay at play time; the generated kokoro/piper pipelines
  are wrapped in `trap 'kill $! 2>/dev/null' TERM; <pipeline> & wait $!`
  (bash defers traps while a foreground job runs; backgrounded, `wait`
  processes the trap at once and `$!` IS aplay; the producer dies on
  SIGPIPE; the backgrounded pipeline still gets the line on stdin because
  bash only nulls a background job's stdin when it is a terminal — from a
  pipe it flows through). Keep the builders in Clippy.qml (`georgeCmd`/`piperCmd`/
  `cloneCmd`) byte-identical to what setup-voice writes — drift just
  makes the picker say "custom", nothing breaks. A hand-rolled pipeline
  without the wrap may finish its line; `docs/voice.md` documents the wrap.
- Missing engine is surfaced, not just journaled: `ttsProbe` (`command
  -v espeak-ng`) runs at mount, on `tts` changes and on menu open,
  feeding `ttsEngineMissing`; `ttsNeedsEngine` (false when a custom
  command is set) turns the menu group label into "install espeak-ng",
  makes him say "Install espeak-ng. I'll wait." when the voice is
  switched on engine-less, and drives the agent-first replies: `voice`
  → off / ready / "not installed — silent (fix)" / "custom command: …"
  (+ "; failing, see journal" / "; speaking"), `set tts true` and
  `say`/`talk` answer through `ipcOkVoice()`. The probe is async, so a
  `set` in the same breath as an install may still warn once.
- On/off never eats a custom command: `setVoiceEnabled(on)` (the menu
  and `set tts true|false`) stashes a command string into `ttsSaved` on
  turn-off and restores it on turn-on, both keys in one
  `setSettings(map)` write. `tts true` only means espeak when nothing is
  parked; `set tts unset` resets tts but keeps the stash; an explicit
  command string clears it; `set ttsSaved unset` is the escape hatch.
- The picker: `scripts/voice-scan` prints one JSON object of every voice
  on disk (espeak/GPU/kokoro presence, clone wavs, piper models with
  sample rates, drop-in files) and feeds `voiceInv` via a Process (mount,
  tts changes, menu open, the `voices` verb, and an unknown `useVoice`,
  which parks the name in `voicePendingApply` and applies it when the
  scan lands — so write-file-then-useVoice works in one breath; a name
  that still doesn't resolve is dropped, no retry loop).
  `currentVoiceId` names the live tts value
  (off/robot/george/<clone>/<piper>/<drop-in>/custom; clones keep their
  name through knob changes via the `--ref` regex; a drop-in is named by
  exact string match against its file's command); `voiceOptions` is the
  picker list (clones only when the GPU is there; "custom" appears when
  a hand-set command is live or parked); `applyVoice(name)` is the one
  resolver behind both the menu chips and IPC `useVoice <name>`, and
  parks an unrecognized custom command in `ttsSaved` before overwriting.
  IPC `voices` lists active + installed + how to install more + the
  drop-in dir + the raw `set tts` contract. Switching lives in the
  plugin (instant `set tts`); installing stays with setup-voice — a menu
  tap must never start a 2 GB download.
- Drop-in voices: `~/.local/share/clippy-voices/<name>` — filename is the
  picker name (`[A-Za-z0-9_.-]+`; off/robot/espeak/custom/george are
  reserved and skipped by voice-scan), the first non-comment non-blank
  line is the shell command (the raw `set tts` contract; the user owns
  the trap wrap). voice-scan JSON-escapes the command via jq and ships
  `{name, cmd}` pairs; `applyVoice` writes `cmd` verbatim, which is what
  makes the exact-match naming in `currentVoiceId` hold. Clone knobs and
  warm-voice deliberately don't extend to drop-ins (they're
  speak-clone-cache-shaped) — a drop-in containing "speak-clone" still
  gets the knobs via `cloneKnobsApply`, which is correct, not a leak.
- `scripts/setup-voice` — installs engines (nothing is bundled; 60-340
  MB downloads on demand) and ends every mode with `set tts` + a spoken
  hello, always through stdin→aplay (aplay, not pw-play — sndfile can't
  read raw audio from a pipe). Bare = hardware-picked default: an NVIDIA
  GPU with ≥6 GB total VRAM (`gpu_ok()`, biggest card) gets the shipped
  Rubick clone (`cp` of `assets/voices/rubick.wav`, knobs 0.5/0.5),
  anything less falls back to robot George with the "you're poor. Get more
  RAM" line (Costa's wording, deliberate — it's VRAM and the wrongness is
  the joke; don't accuracy-fix it); `--robot` bypasses the GPU pick. Robot
  George is kokoro `bm_george` through an ffmpeg ring-mod chain
  (`asetrate` +15 %, `tremolo f=45`, `acrusher bits=6`, 250-3400 band);
  a named piper voice (name-with-dash) comes through unprocessed;
  `say.py` phonemizes `b*` voices as en-gb. Kokoro and piper spawn
  `say.py` per line and reload the model each time (~1.8 s/line, no daemon
  unlike the clones) — that latency is why they were parked on Costa's
  box. `--clone <sample> [name]
  [--from T] [--to T]` = chatterbox voice clone from a 10-20 s sample:
  ffmpeg converts anything to mono 24 kHz, `--from`/`--to` are input-side
  `-ss`/`-to` (positions in the source), the 20 s cap applies after the
  cut, and `loudnorm I=-18` lifts quiet rips (the clone copies the
  sample's level as character; a -30 LUFS rip cloned muffled). Prints the
  cut's length, warns under 8 s or when the cap truncated an uncut
  sample, and says so on a re-clone of an existing name. The shipped
  Rubick wav is still `cp`'d verbatim, never through that pipeline.
  It does not warm the book itself — the plugin owns that (below),
  triggered by the `set tts` it ends with; the script only says so.
- Clones: chatterbox on CUDA in a uv venv (`--python 3.12` — system
  3.14 has no torch wheels; `setuptools<81` pinned or perth's
  watermarker dies on missing pkg_resources — the symptom is
  `from_pretrained` throwing "'NoneType' object is not callable"; plain
  pip on system 3.14 backtracks forever, hence uv; uv itself must come
  from pacman — setup-voice refuses without it, the `curl … | sh`
  bootstrap it used to run was the marketplace baseline's one
  `curl-pipe-shell` finding, v1.40.9). Per-line spawn would
  reload 2 GB onto the GPU, so `speak-clone` (stdlib client) talks to
  `daemon.py` (venv python) over `$XDG_RUNTIME_DIR/clippy-voice.sock`;
  the daemon self-starts on demand and exits after 15 idle minutes
  (~4 GB VRAM). Lines are cached in `~/.cache/clippy-voice` by (ref
  path, ref contents hash, knobs, text) — repeats instant, fresh line
  ~2-5 s warm, ~25 s cold. The contents hash (v1.28.0) is what makes a
  re-clone under the same name safe: before it, a re-cut sample kept
  replaying every line rendered from the old one. The daemon, as the raw
  renders' only writer, bounds it (v1.41.0): after every render and once on
  start it deletes least-recently-played `.wav`s until the dir is under the
  cap — the `voiceCacheMb` key (500; 0 = no cap), which rides into the
  daemon's environment as `CLIPPY_VOICE_CACHE_MB` via the `environment`
  property on ttsProc and both warm Processes (whichever spawns the daemon
  first wins its 15-minute lifetime, so a change applies from the next
  daemon start; the QML property sanitizes to a clean integer so a garbage
  value can never crash the daemon's `int()`, and the set reply for a
  non-number is a refusal, the duck idiom). speak-clone and warm-voice
  touch mtime on
  every hit (guarded — a file pruned in the exists/utime gap must not
  kill a warm), so a warmed book (~85 MB, ×2 with a tempo derivative) stays
  while agent one-offs and lines keyed to a superseded sample age out —
  before this the dir only grew (Costa found 1 GB: 2,461 files for a
  342-line book, five re-key waves plus every AI line ever said). The
  daemon.log is truncated per daemon start and tqdm is silenced
  (`TQDM_DISABLE`). The whole dir is still disposable.
  `--pitch`/`--tempo` derive from the cached raw take via ffmpeg
  (asetrate*P shifts pitch and tempo together, one atempo of T/P lands
  the final tempo on T; atempo's 0.5 floor handled by chaining) into
  `{key}[-pP][-tT].wav` (pitch-only name unchanged so old derivatives
  are reused); plays the raw file if ffmpeg fails.
- `cloneTempo`/`clonePitch` (factors around 1, clamped 0.5-2, default
  1): `launchTts()` appends `--tempo`/`--pitch` when either ≠ 1 and the
  command contains "speak-clone" (`cloneKnobsApply`) — never into the
  stored tts string, so the picker keeps naming the voice and
  setup-voice's strings stay canonical; argparse keeps the last
  occurrence, so a hand-set command carrying the flags is overridden.
  Menu preset chips only while `cloneKnobsApply`; free values by IPC.
  Derivation is ffmpeg on the cached raw take, so auditioning is
  instant and warming never needs a rerun for a knob change.
- `scripts/warm-voice` — renders the whole book into the clone cache,
  silently, over the daemon socket (no aplay). Reads the live `tts`
  string for speak-clone/--ref/--exag/--cfg (bails on anything else),
  merges `quotesFile`, respects `clean`, skips `{templated}` lines and
  existing cache files, self-starts the daemon. Rerun it after a `--ref`
  or exag/cfg change — those re-key the cache. The plugin runs the bare
  form itself: `warmBook()` (`warmBookProc`, separate from `warmProc` so
  a 10-20 minute book — ~2.5 s/line with the box busy — never blocks an
  agent batch) fires on mount and in
  `onTtsSettingChanged`, kills a warm in flight (it would be rendering
  the previous reference), and only spawns when the live tts contains
  "speak-clone", handing it over as `--tts <cmd>` so the warm can't
  race the settings write. A full cache makes that a ~0.3 s no-op, so
  it runs on every mount without a flag; `warmingBook` shows in `voice`.
  Costa's call: "why are we not prewarming. i dont get it" — under the
  contents-keyed, never-pruned cache a voice warmed once stays warm, so
  nothing justified a second command. Its key
  must match `speak-clone`'s byte for byte: it reads the installed
  client and falls back to the pre-v1.28.0 path-only key (with a stderr
  nudge to rerun setup-voice) if that client predates the contents
  hash, so an updated plugin never warms into keys an old client won't
  look up. `--lines <line>...`
  warms explicit strings: `AgentBrain.linesArrived` → root's
  `warmAgentLines()` (gated on `ttsOn` + `"speak-clone" in ttsSetting`)
  pre-renders each fresh agent batch fire-and-forget (`warmProc`,
  overlap parked in `warmQueued`), so agent lines don't trail the
  bubble by first-take synthesis. While a warm runs, live lines queue
  behind the batch — self-heals when it finishes.
- Long lines finish: `bubbleTimer` (450 ms/word, min 4 s), `dieTimer`
  (2500 ms) and `flingHold` each re-arm in 500 ms beats instead of
  hiding while `speakingThisBubble()` (ttsOn, not silent, `ttsLine ===
  bubble.text`, and engine running / replacement queued / duck snapshot
  in flight — `ttsLine` alone is stale after a normal exit), capped at
  60 holds so a hung engine can't pin a mood forever. `say()`/
  `epitaph()` zero `bubbleTimer.holds`, `kill()` zeroes
  `dieTimer.holds`, `flingOff()` zeroes `flingHold.holds` AND restores
  `flingHold.interval = flingHoldMs` (the imperative re-arm overwrites
  that declarative binding). Every deliberate hide — click dismissal,
  `shutUp`, sleep, slap replacement — still cuts mid-word; that's the
  contract.

## Ducking

On by default, configurable since v1.31.0 — every *other* audio stream
drops to `duck` of its volume (pipewire-pulse never implemented
PulseAudio's `module-role-ducking`, so per-stream `pactl` scaling is the
only primitive, hence `scripts/duck`; pactl's percent is cubic, so 0.8 is
a −5.8 dB cut and sounds bigger than "20 %" — noticed and accepted;
default 0.8; the original hardwired 0.3
was "kinda annoying", and "ALWAYS duck other audio" was Costa's own
rule until he asked for the setting) while he speaks and is restored
after. `duckFactor` derives from the key: false (or ≥1) means no duck
and `startTts` skips the fork entirely (`duckOn`); a duck already held
when the setting flips still gets its restore. The menu's "Duck other
audio" ●/○ row is on/off only — the ratio is IPC-only ("the ratio
should be done via terminal/agent only") — behind `setDuckEnabled(on)`,
the ttsSaved idiom a third time: off parks an explicit ratio in
`duckSaved`, on restores it; `set duck` takes booleans through the same
path, clamps numbers 0-1, clears the stash on an explicit ratio, and
refuses non-numbers.
`scripts/duck` snapshots `pactl list sink-inputs` volumes (raw values,
not the rounded percent — a 100 %+0.12 dB stream must restore exactly)
into `$XDG_RUNTIME_DIR/clippy-duck` and scales each; the snapshot is
taken BEFORE the engine spawns, so his own stream is never in it — no
name-matching, any engine works. The one name-match: sink-inputs with
`node.name = "quickshell"` are skipped — the slap/fall SoundEffects are
his audio, not "other audio" (the awk buffers each entry and flushes at
the next `Sink Input` line because node.name sits in Properties, after
Volume). Idempotent both ways under flock. QML side: `startTts` ducks
first and the launch continues from `duckProc.onExited` (`launchTts` is
the engine-spawn body); the duck is held across a replacement line;
speech end with an empty queue arms `duckRelease` (1 s) before
`duckStop()` — a line inside the window keeps the duck, so consecutive
lines share one duck cycle and never snapshot each other's dying aplay
(that compounding re-snapshot once drove remembered volumes toward
zero in the 0.3 days — 30 % → 9 % → 1 %). `duckStop()` is gated on `ducked`; a line cancelled while the
snapshot is in flight restores instead of speaking; overlapping flips
park in `duckNext`; a mount runs `duck stop` as crash healing. Known
trade-off: PipeWire stream-restore memorizes a stream's volume, so an
app whose stream ends mid-duck is remembered at 80 % and starts there
next time, silently — the heal is playing a live stream of that app and
`pactl set-sink-input-volume <id> 100%`, which rewrites the memory (no
snapshot-side fix exists — a stream that has already ended can't be
volume-set).
Orthogonal to Costa's `costafot.autoduck` plugin (mutes browser streams
only, never touches volumes); they compose.

## The graveyard (global leaderboard)

Default-on death leaderboard (anonymous; opt-out — it started opt-in;
Costa: "the leaderboard/counts is half the fun and being opt in we would
lack anything to show", and anonymous opt-out telemetry with a disclosure
is ordinary OSS practice). Server: repo `CostaFot/clippy-leaderboard`
(`~/Work/clippy-leaderboard`), Flask + psycopg2 + gunicorn on Railway
(project `clippy-leaderboard`, Postgres internal-only — no public proxy,
keep it that way; domain graveyard.costafotiadis.com, a CNAME onto the
generated clippy-leaderboard-production.up.railway.app — never delete the
generated domain, installs from before the swap (manifest ≤1.40.4) post to it). `POST /bump` takes
`{handle, kills, slaps}` DELTAS: handles are claim-free (no accounts;
collisions merge — anti-cheat is an explicit non-goal), lowercased,
`[a-z0-9_.-]{1,24}`, deltas clamped 0-50 (hygiene), reply carries new
totals + rank + total so the client never needs a second GET. The one
gate: /bump answers only a `costafot.clippy/*` User-Agent, else 403
"you are not a paperclip" — a doorman, not a lock; an API key was
rejected twice as theater (anything in a public repo is public).
`GET /` is the CSS-only headstone page (sqrt-scaled by kills, slaps
tiebreak, top 100); `GET /api/scores?limit=` and `/api/score/<handle>`
round out the API.

Client (Clippy.qml): `leaderboard` key — "" (default) posts as the
shared `anonymous-clippy-abuser` stone (`lbAnonHandle`; one alias for
every install — a per-install suffix would be a pseudonymous identifier
and change the privacy story, don't add one), a handle claims a stone,
"off" is the only silence (`leaderboardOff/Named/On` derive from
`lbSetting`); the README's graveyard bullet and `docs/graveyard.md`
say exactly what leaves the machine (alias-or-handle + two small deltas).
`setLeaderboardEnabled(on)` is the toggle behind the menu row and `set
leaderboard true|false|off` — the ttsSaved idiom: off parks a named
handle in `leaderboardSaved`, on restores it (else anonymous), one
`setSettings` write each way; `set leaderboard unset` goes anonymous
but keeps the stash, `set leaderboard <name>` clears it.
`bumpLeaderboard(0,1)/(1,0)` directly after the persisted counter bumps
in `slap()`/`finishDeath()`; the flush is the park-don't-clobber idiom
(deltas accumulate while a POST is in flight, so a beating coalesces),
a failure re-adds the sent deltas and backs off 30 s·2ⁿ capped ~16 min,
`lbRetry` re-arms through `asleep` instead of dropping (no curl into a
lock screen, but held deltas still flush after a long lock), and
`wakeUp()` re-runs `flushLeaderboard(true)` BEFORE its dead branch (a
remount while locked skips maybeBoot's flush and drops the old
instance's retry timer). A handle change, or any mount while posting, fires a
zero-delta bump — legal, creates the stone and fills `lbCache` with the
rank for free (default-on means every mount announces). The flush is
gated on `settingsLoaded` (entryLocation non-null): before shellConfig
delivers the entry every setting reads as its default, and default-on
must not post for a user whose "off" or handle simply hasn't loaded —
`onSettingsLoadedChanged` announces the anonymous default, the handle
change handler announces everything else, and a forced flush landing
while a POST is in flight parks in `lbFlushQueued` instead of being
dropped (it once left `lbCache` showing the wrong stone). `lbProbe` surfaces a missing curl (a Process that can't
start never fires onExited); `lbProc` collects stderr into the failure
warn. The curl sends `-A costafot.clippy/<manifest version>`. Pending
deltas die with the shell — the tally's own documented trade. IPC
`leaderboard` verb (off-with-instructions / "posting anonymously to the
shared … stone" / "posting as X: #4 of 31…" + pending / unreachable /
no-curl suffixes); `set leaderboard` replies state the handle rule,
take booleans as the toggle, and note off keeps what was posted (no
delete). Menu: the "Online leaderboard" ●/○ row (→ `graveyardOn` in
`onChose`) with a dim gated line under it declaring who it posts as —
the alias by default, the handle when named — plus the claim-a-stone
hint while anonymous; footer rank whenever posting; the handle itself
stays free text — IPC and agent only.

## Dev loop and gotchas

- Symlink the checkout in: `ln -s ~/Work/omarchy-inappropriate-clippy
  ~/.config/omarchy/plugins/costafot.clippy`, then `omarchy plugin
  enable costafot.clippy`. `omarchy-plugin-validate` refuses a symlinked
  plugin dir (validate the real checkout path instead); the shell itself
  is fine with it.
- The shell's `inotifywait -r` watcher does **not** follow the symlink,
  so edits don't hot-reload, and `omarchy-shell shell rescanPlugins`
  reuses the cached compile. Use `omarchy restart shell` after every QML
  change. The cached-compile gotcha also bites a real clone when files
  are only copied in: the shell logs a plugin reload but serves the old
  compile — restart the shell.
- `scripts/` (clippy-ai, voice-scan, duck, warm-voice…) are exec'd fresh
  per call — an edit needs no shell restart, only the hand-copy into the
  installed clone; the cached-compile gotcha is QML-only.
- `set` accepts out-of-range numbers silently: `set restless 5` answers
  plain `ok`, stores 5, `get` returns 5; the clamp happens only at the
  property binding (`clamp()` on size/speed/restless, `Math.max` on the
  intervals/respawn/slapsToKill). Known gap, stated in scripting.md.
- Test harnesses that worked: widget avoidance = `set restless 1` and
  screenshot pairs against `omarchy-shell shell debugBarGeometry` (same
  coordinate space as stage x); engine-less TTS = `set tts "cat >>
  /tmp/lines"` collects exactly the displayed lines, `set tts "sleep 30"`
  proves every kill path (replacement line, `hide`, `set tts false`,
  sleep) — it's what caught the `running = false` bug; setup-voice's
  no-GPU and `--robot` branches = stub `nvidia-smi` and `omarchy-shell`
  binaries on PATH; a subprocess that fails only from the shell = run the
  identical command under `systemd-run --user` (how a "plugin curl fails,
  terminal curl works" scare was proven to be the edge being down, and
  why `lbProc` collects stderr).
- Every layout-shaped write to `shell.json` (by anyone) rebuilds the
  panel Instantiator and remounts us — that's why dead/snooze/x live in
  `PersistentProperties`; keep mount cheap. An inline `set` on our own
  entry does NOT necessarily remount: the value can arrive as a live
  binding update through `shellConfig`, plain properties survive, no
  destructors run. Don't rely on a `set` to reset plain state.
- `shell.bar` is null while the bar loads and is reassigned on bar
  reload — every geometry read guards it and falls back to `Style.bar.*`.
- Every `Text` sets `textFormat: Text.PlainText` (v1.40.10) — the
  `AutoText` default renders anything that looks like HTML as markup,
  and the bubble shows agent output, crash app names and `quotesFile`
  lines while the menu footer shows the graveyard's reply. No string in
  the plugin uses markup, so it costs nothing; the marketplace's security
  review blocks on a `Text` without it. A new `Text` gets the line too.
- Never name a property on any Item-derived object after an Item
  property (`bottom`, `top`, `state`, `scale`…) — "Cannot override FINAL
  property", and the reported line can be stale when the compile is
  cached.
- IPC from a terminal is `omarchy-shell costafot.clippy <method>
  [args]` — no `ipc call` subcommand; that form prints "Target not
  found". IpcHandler has no optional params — every arg is required.
- Logs: `journalctl --user -o cat | grep -iE 'clippy|WARN.*scene'`.
- The window has been full-screen (four-anchored, Overlay) since
  v1.42.0. Watch item: a transparent Overlay surface covering the whole
  output could in principle affect Hyprland's fullscreen direct-scanout
  (games); pre-existing in kind (the strip already overlaid the bar),
  not observed, but it's the first suspect if someone reports it.
- One quickshell SIGSEGV was seen during development, right after
  "Exiting due to IPC request" while plugins were still incubating
  asynchronously — it looked like an `omarchy restart shell` landing on
  a shell that was still starting; not reproduced since.

## Machine state (Costa's box — not derivable from the repo)

- The installed plugin dir is a REAL CLONE, not the dev symlink — edits
  in `~/Work` must be hand-copied into
  `~/.config/omarchy/plugins/costafot.clippy/` (then restart the shell)
  or the symlink restored. Check which before assuming an edit is live.
- Live settings drift with use — read them (`omarchy-shell
  costafot.clippy settings`) rather than trusting notes. Last known
  (2026-08-29 evening): a `grossman` clone active (Les Grossman, Tropic
  Thunder, 5:59-6:12 of a "best moments" rip, `--exag 0.5 --cfg 0.5`),
  the picker offering off · robot · grossman · rubick.
- Approved clone references — NEVER regenerate, a re-cut sounds subtly
  different: `~/.local/share/chatterbox-tts/voices/rubick.wav` (also in
  the repo at `assets/voices/rubick.wav`, byte-identical). Parked, not
  deleted (move back to re-offer in the picker): `voices-parked/` holds
  the approved c3po + c3po-fast takes (c3po's approved knobs were `--exag
  0.6 --cfg 0.7` — 0.5/0.5 read slow, the reference is 3PO at his
  weariest; c3po-fast is the snappier alternate reference); `piper-voices-parked` and
  `kokoro-tts-parked` sit next to their original dirs (Costa: "less
  options. less to debug"). `voices/grossman.wav` is a second, unapproved
  clone reference (v1.28.0's test subject; source clip in `~/Downloads`).
- The clone line cache is `~/.cache/clippy-voice`; the daemon socket is
  `$XDG_RUNTIME_DIR/clippy-voice.sock`.
- codex and pi are installed but not logged in (401 / no key); only
  claude and opencode have actually been run through clippy-ai. The
  shell's env has the mise shims on PATH, so agent binaries resolve.
- The leaderboard DB was cleaned of test rows before launch. Costa's box
  posts as `costafot` (#1, 36 kills / 343 slaps at 2026-08-29) — so every
  IPC `slap`/`kill`/`fling` test on this machine posts REAL deltas to the
  public board; `set leaderboard off` first, or accept the inflation. The
  DB is reachable only via `railway ssh --service Postgres -- psql`.
- The talk-back bind on Costa's box is double-tap Alt: `bindings.lua`
  line ~123 binds `ALT + ALT_L`/`ALT_R` on release to
  `~/.config/hypr/double-alt.sh`, which runs the `listen` verb.

## Status

Everything above is live and verified on Costa's machine (the manifest
names the current version). On GitHub at the README install URL; Pages is
on (source `/docs` on `main`, primer theme, build confirmed live); not on
the marketplace — `PUBLISHING.md` has the flow, prior submissions and
the gap list. Future work: `IDEAS.md`. How we got here: `git log`.
