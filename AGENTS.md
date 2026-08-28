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
  so the usual respawn machinery applies. IPC `slap [left|right]`.
  `assets/sounds/*.wav` are mono 44.1 kHz conversions of three freesound
  mp3s Costa picked (SoundEffect wants WAV).
- `Bubble.qml` — tooltip-coloured rounded rect + wrapping text, capped at
  320 px. Two rotated-square tails: bordered one behind the body for the
  outline, borderless one on top to hide the body's border across the join.
- `quotes.json` — `{ quotes, lastWords, comeback, slapped, knockedOut }`
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

Working end to end on Costa's machine: walks, talks on a timer, left/middle
click, right-click menu (actions + clean/restless/size), bar icon → same menu
(dimmed + "Bring him back" when dead/hidden), kill → respawn with a comeback,
snooze, top and bottom bars, IPC, settings inline on the bar-layout entry.
On GitHub at the README install URL.

Movement is a random brain (`decide()`): idle beats 10-30 s apart, each one
turns into a walk with probability `restless` (default 0.3), walks are mostly
short hops of 80-400 px with 1 in 5 a trek anywhere. Costa wanted him mostly
still — tune, don't make him busier.

Verified by hand (2026-08-28): click-through with a real pointer, `clean`,
and `quotesFile` (object and bare-array shapes, all three keys, bad JSON and a
missing path both fall back to the built-in book). Quotes are two books,
`book` + `extraBook`, merged per key in `pool(key)` so FileView load order
doesn't matter — an earlier version leaked the file's `quotes` into
`lastWords`/`comeback`.

Slapping done (2026-08-28, v1.2.0): middle-click and pointer-fling, sound,
shove + wobble, escalation to a knockout. Middle-click used to snooze;
`slap: false` restores that. Costa supplied the three sounds.

Bar icon done (2026-08-28, v1.1.0): opens the same `ClippyMenu`, and is the
way back after a kill/hide. The menu is the config surface, `shell.json` the
fallback. Keep every setting a flat scalar key with a default, a README table
row, and (if it's something a user would reach for) a row in the menu. Don't
build a `barWidget.schema` unprompted.

Ideas, in rough order of payoff:
- Reactive lines: battery, CPU, pending updates, hour of day, agent usage
  (`shell.serviceFor("omarchy.notifications")` and the agents plugin state are
  reachable from a panel — see ~/Work/omarchy-navbar-cat for how it listens to
  Hyprland/MPRIS/UPower).
- The 15 original Clippy sounds live base64-encoded in clippy.js
  `agents/Clippy/sounds-mp3.js`; frames carry `sound` ids already. The
  `SoundEffect` plumbing from the slap is the way to play them.
- Trim the sprite atlas to the animations we use if the 42 MB texture matters.
- Quote curation — `quotes.json` is the seed, Costa hasn't gone through it yet.
