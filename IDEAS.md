# Ideas

Pitched 2026-08-28, in rough order of payoff-to-effort. (The short list
that used to live in AGENTS.md was merged in here 2026-08-29.)

## More gags (parked from v1.42.0)

The full-screen window and the `gagDy` offset (2026-08-31) make new
stunts cheap — each is one animation on `gagDy` ending at 0. (The
**corner peek** parked here shipped in v1.44.0 as `gag peek` /
`peekChance`.)

Alternate entrances, pitched 2026-08-31 when Costa retired the skyfall
(don't re-pitch that one — he never liked the falling): the **tumble**
won and shipped as v1.45.0's `gagEntrance()`. The rest, parked — each
could join a random entrance roll rather than replace the tumble:

- ~~**The rise from the grave**~~ — built and reverted 2026-08-31
  (don't re-pitch): three jerky OutCubic pulls on gagDy from below the
  screen edge, `LookUp` looping, `Wave` on landing. Costa watched the
  forced run live and called it off — "hmm i dont like it".
- ~~**The materialize**~~ — built and reverted 2026-08-31 (don't
  re-pitch): the sheet's `Show` flicker-in under a 550 ms OutBack scale
  pop on the actor. Worked, but at bar size the whole thing is a blink
  on a 24 px sprite — Costa: "he is too small to notice the animation.
  not worth it." An entrance that reads at bar size needs travel (the
  tumble) or bulk (the peekGrown blow-up), not an in-place pop.
- **The lob** — shipped as v1.46.0's `gagLob()`: in from a side edge on
  a flat parabolic arc (up from the bottom edge on a top bar — the
  fling's revenge), 720° spin, an 82° face-plant, gets up shaking
  himself off. Coin-flipped against the tumble on revives; `gag lob`
  forces it.
- ~~**The looming shrink**~~ — built and reverted 2026-08-31 (don't
  re-pitch): materialized huge mid-screen (the peek's bulk worn as
  `actor.scale`, the Greeting flicker-in), loomed 1.5 s, shrank onto
  his bar spot. Worked mechanically, but the loom was silent — the
  comeback line only came after landing — and a giant Clippy standing
  quietly mid-screen is a special effect, not a joke. Costa: "not
  funny enough." A speaking loom (the line delivered WHILE huge, which
  needs the peek's flag-not-mood trick since say() refuses in
  "reviving") was floated but not tried; that'd be the angle if this
  territory is ever revisited. The entrance roll stays a coin flip:
  tumble or lob.

Still parked,
much bigger: **true free 2D roaming** — walking anywhere on screen would
need the six 1D avoidance functions rewritten as rect math (the
`mapToItem(null,…)` y is NOT screen y for a bottom bar), 2D drag/fling
vectors, `lastY`/`graveY` persistence, and a design answer for what a
walking paperclip mid-screen even reads as. The gag tier was chosen
instead on purpose; revisit only if a gag genuinely needs free movement.

## Talk-back leftovers

What v1.35.0's `listen`/`reply` didn't cover: a clipboard-roast verb
(`wl-paste` as the input — explicit and one-shot, unlike the
decided-against snooping) and a bindd spawning a walker/floating-terminal
prompt for typed input without a terminal. Deferred from the build:
ducking other audio while the mic records — if ever wanted, it's a
refcount on the existing `ducked`, not a second `duckRun` caller (two
independent holders re-invite the compounding-snapshot bug the 1 s
duckRelease window exists to prevent).

## The warm, observable

v1.28.0 made book warming invisible and automatic — which works, but
left it *too* invisible: when Costa asked "is it still running?" mid-warm
(2026-08-29, rubick's one-off re-key warm), the agent's only honest
answers came from counting cache files by hand and grepping the journal.
Three gaps, all cheap because warm-voice already computes everything:

- **Progress and a real ETA.** `voice` says a warm is running but not
  how far along; the "10-20 min" claim is wrong whenever most of the
  book is cached. warm-voice counts renders and skips as it goes — print
  a progress line per render, stream it into the plugin (SplitParser on
  warmBookProc instead of collecting at exit) and `voice` can say
  "pre-rendering the book: 76/150, ~3 min left".
- **The outcome, after.** Once the warm exits, `voice` goes silent about
  it — an agent can't tell "fully cached" from "never ran" from "failed
  halfway" without journalctl. The done line ("30 rendered, 126 cached,
  0 failed of 156") already exists; park it in a property and append it
  to `voice`.
- **Journal noise.** A shell restart mid-warm logs "book warm failed
  (exit 15)" with empty stderr — the superseded flag only covers
  voice-change kills, not teardown. That's exactly the line an
  investigating agent greps to. Gate the WARN on code 15 (or handle
  teardown), so the journal only warns on real failures.

Smaller, same neighborhood: while a warm runs, a live uncached line
queues behind the in-flight render, so "~2 s" is really ~2-5 s — one
clause in the `voice` reply. Deliberately not: him announcing warm
completion out loud — background plumbing shouldn't speak.

## Reactive lines without the agent

Same shape as the crash reactions (`crashed` book key, fired off the
journal stream), for battery, CPU, hour of the day:
`shell.serviceFor("omarchy.notifications")` and the agents plugin state
are reachable from a panel — see ~/Work/omarchy-navbar-cat for how it
listens to Hyprland/MPRIS/UPower. Or feed more of that into `clippy-ai`'s
facts: notifications, the workspace.

## Battery panic as behavior, not just a line

Below 10% he refuses to walk (saving energy, obviously) and plays the
concerned idle; at 5% he faints via the existing `kill()` path with a
dedicated last-words key. The state machine supports all of it — a couple
of gates plus UPower, which navbar-cat also demonstrates.

## Monitor hopping

He's pinned to one screen; let a trek occasionally target the adjacent
monitor's bar — walk off the edge, window moves screens, walk in from the
matching edge. Flings could carry across too: thrown off the left edge of
the right monitor, he lands on the left one instead of dying. More work
(the PanelWindow is per-screen), but multi-monitor is a common Omarchy
setup and it doubles his territory.

## Smaller

- Let the agent pick the animation too (`anim` per line).
- The 15 original Clippy sounds live base64-encoded in clippy.js
  `agents/Clippy/sounds-mp3.js`; frames carry `sound` ids already. The
  `SoundEffect` plumbing from the slap is the way to play them.
- Trim the sprite atlas to the animations we use if the 42 MB texture
  matters.
- Quote curation — `quotes.json` is the seed, Costa hasn't gone through
  it yet.

## Decided against

- **Ask an oracle** — a free-text question to him, answered straight.
  Scratched (2026-08-29): omarchy users already have an agent one keybind
  away, and a tool-less, fact-limited call is strictly worse than it. Only
  the bit survived — `reply` mocks questions instead of answering them.
- **Pluggable clone models** — the other half of the drop-in-voices
  pitch (shipped v1.27.0: any *engine* is now first-class in the picker
  via `~/.local/share/clippy-voices/`). Swappable neural cloners stay
  out: every one is its own venv-pinning snowflake, and
  setup-voice/daemon/speak-clone/warm-voice are chatterbox-shaped end to
  end — generalizing them is becoming a TTS package manager, against the
  "less options, less to debug" call. A weird-engine user drops a
  command file and owns the raw mode.

- **Update nagging** — the count is one `checkupdates --nocolor | wc -l`
  away (`omarchy-update-available` only covers Omarchy itself, and
  checkupdates network-syncs a temp DB, so hourly at most). Scratched
  (2026-08-29): we don't want him actually nagging. He's a heckler, not a
  chore reminder — an update nag would be *useful*, and useful is the
  wrong kind of annoying. (The welcomeBack line about pending updates
  stays: it's a gag, it checks nothing.)
- **Eyes on the cursor** — investigated (2026-08-28) and entirely doable:
  all eight Look* animations are in the atlas and return to neutral on
  their own, and a lazy `hyprctl cursorpos` poll while idle is cheap.
  Scratched anyway: a mascot that visibly tracks your pointer is annoying,
  and the tuning direction has always been "mostly still". (If ever
  revived: the Look names may be character-mirrored like the Gestures —
  crop the frames before wiring directions.)
- **Clipboard snooping** — on-brand for the joke, but with `ai: true` it
  means shipping clipboard contents to an LLM. A real privacy footgun even
  opt-in.
- **Walking on window title bars** — leaves the bar-anchored model
  entirely; a big rewrite for a gag the bar already delivers.
