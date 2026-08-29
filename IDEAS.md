# Ideas

Pitched 2026-08-28, in rough order of payoff-to-effort. (The short list
that used to live in AGENTS.md was merged in here 2026-08-29.)

## Talk back to him

IPC `ask "why is my build broken"` → one-shot through `scripts/clippy-ai`
with the question appended to the facts, answer lands in the bubble
(agent-dressed, sparkle and all). The prompt plumbing, the parser and
`say()` all exist — mostly a new flag on the script plus a busy-guard so it
doesn't race the cache top-up. Turns him from a heckler into an oracle who
is also a heckler. The feature people would screenshot.

## Kill counter with a grudge

The tally exists (v1.10.0); the grudge half remains: expose
`{kills}`/`{slaps}` placeholders to both books, same as `{away}`. "That's
the ninth time you've murdered me. I keep a list."

## Reactive lines without the agent

Battery, CPU, hour of the day: `shell.serviceFor("omarchy.notifications")`
and the agents plugin state are reachable from a panel — see
~/Work/omarchy-navbar-cat for how it listens to Hyprland/MPRIS/UPower. Or
feed more of that into `clippy-ai`'s facts: notifications, the workspace.

## Window-class reactions

A step past the reactive-lines idea above: a `reactions` key in
quotes.json mapping window-class regex → lines, fired on Hyprland
`activewindow` (navbar-cat shows the event wiring). Steam opens → instant
mockery, no agent call, no latency. The agent path stays for the clever
stuff; this covers the obvious stuff instantly.

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
