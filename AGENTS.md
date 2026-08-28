# omarchy-inappropriate-clippy — agent notes

Clippy walks the Omarchy bar and insults you. The repo root IS the plugin
(`manifest.json`, id `costafot.clippy`, `kind: "panel"`, `keepLoaded: true`,
entry `Clippy.qml`). `omarchy plugin add <repo> --enable` clones it to
`~/.config/omarchy/plugins/costafot.clippy/` and appends `{"id":"costafot.clippy"}`
to `plugins[]` in `~/.config/omarchy/shell.json`.

## Architecture

- `Clippy.qml` — root `Item` (the shell loads panels into a non-visual Loader,
  so the root must not be a window). Injected by the host: `shell`, `manifest`,
  `omarchyPath`. Nothing else — no `settings`, no `bar`. Settings are read off
  `shell.shellConfig.plugins[]` (inline keys on our entry). `opened` +
  `open()`/`close()` are the `shell summon|hide|toggle` contract. Owns:
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
    `showMenu`/`hideMenu` exist so the menu can be driven without a pointer
    (there is no ydotool on the box; that is how it was screenshotted).
  - `PersistentProperties { reloadableId: "costafotClippy" }` for `deadUntil`
    (0 alive, -1 dead until `respawn`, >0 epoch ms), `snoozedUntil`, `lastX`.
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
- `ClippyMenu.qml` — right-click menu, navbar-cat's `CatMenu` pattern: its
  own full-screen transparent `PanelWindow` (input region only while open,
  click anywhere dismisses, no keyboard focus) with a card under the actor.
  Takes `clippy` (the root Item), emits `act(name)` for actions and
  `chose(key, value)` for settings; the root maps the latter onto
  `shell.updateEntryInline(pluginId, entry)`, which rewrites shell.json and
  remounts us. Opening it freezes the walk. Meant to be reused by a future
  bar-widget icon.
- `Bubble.qml` — tooltip-coloured rounded rect + wrapping text, capped at
  320 px. Two rotated-square tails: bordered one behind the body for the
  outline, borderless one on top to hide the body's border across the join.
- `quotes.json` — `{ quotes, lastWords, comeback }`, entries
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

Working end to end on Costa's machine: walks, talks on a timer, left/middle
click, right-click menu (actions + clean/restless/size), kill → respawn with a
comeback, snooze, top and bottom bars, IPC, settings inline on the `plugins[]`
entry. On GitHub at the README install URL.

Movement is a random brain (`decide()`): idle beats 10-30 s apart, each one
turns into a walk with probability `restless` (default 0.3), walks are mostly
short hops of 80-400 px with 1 in 5 a trek anywhere. Costa wanted him mostly
still — tune, don't make him busier.

Unverified: click-through of the strip with a real pointer (mask mirrors
navbar-cat's), and `clean` / `quotesFile` end to end (trivial code, no test run).

Planned, later: a bar-widget icon that opens the same `ClippyMenu` as the
settings UI, so the menu is the config surface and `shell.json` is the
fallback. Keep every setting a flat scalar key with a default, a README table
row, and (if it's something a user would reach for) a row in the menu. Don't
build the bar widget or a settings schema unprompted.

Ideas, in rough order of payoff:
- Reactive lines: battery, CPU, pending updates, hour of day, agent usage
  (`shell.serviceFor("omarchy.notifications")` and the agents plugin state are
  reachable from a panel — see ~/Work/omarchy-navbar-cat for how it listens to
  Hyprland/MPRIS/UPower).
- The 15 original Clippy sounds live base64-encoded in clippy.js
  `agents/Clippy/sounds-mp3.js`; frames carry `sound` ids already.
- Trim the sprite atlas to the animations we use if the 42 MB texture matters.
- Quote curation — `quotes.json` is the seed, Costa hasn't gone through it yet.
