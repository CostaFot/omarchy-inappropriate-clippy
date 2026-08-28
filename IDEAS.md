# Ideas

Pitched 2026-08-28, in rough order of payoff-to-effort. The tombstone was on
this list and shipped the same day (v1.8.0, epitaph v1.9.0); AGENTS.md has a
shorter, older list too.

## Talk back to him

IPC `ask "why is my build broken"` → one-shot through `scripts/clippy-ai`
with the question appended to the facts, answer lands in the bubble
(agent-dressed, sparkle and all). The prompt plumbing, the parser and
`say()` all exist — mostly a new flag on the script plus a busy-guard so it
doesn't race the cache top-up. Turns him from a heckler into an oracle who
is also a heckler. The feature people would screenshot.

## Eyes on the cursor

`hyprctl cursorpos` works (the input mask only limits *our* motion events,
not IPC). Poll it lazily while idle and play LookLeft/LookRight/LookUp
toward the pointer. Cheap, and it's the single biggest "he's alive" signal
the original had.

## Kill counter with a grudge

Done in v1.10.0, the simple half: slap/kill totals persist across remounts
and the menu shows them. The grudge half remains: expose `{kills}`/`{slaps}`
placeholders to both books, same as `{away}`. "That's the ninth time you've
murdered me. I keep a list."

## The global leaderboard

The counter (v1.10.0) keeps score locally; put it on a public webpage and
let installs compete. A tiny service on Railway (already have an account):
one POST endpoint, Postgres or SQLite on a volume, and a page ranking
handles by kills, slaps as the tiebreak. Client side is one new key — a
`leaderboard` handle, off by default, because phoning home is opt-in or
it's nothing — posting deltas as they land (curl through the same
`Process` plumbing as `clippy-ai`), so the local tally resetting with the
shell doesn't matter; the server accumulates. Anti-cheat is a lost cause —
`slap left` over IPC in a while-loop is an instant world record — and
that's fine, every score was self-reported murder to begin with. The page
wants to be a graveyard: one headstone per handle, sized by kill count.

## Window-class reactions

A step past the reactive-lines idea in AGENTS.md: a `reactions` key in
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

## Update nagging

The one thing the real Clippy would do: Omarchy knows about pending
updates, so "It looks like you have 34 pending updates. It looks like
you're ignoring them." — a fact fed to `clippy-ai`, or a book line with an
`{updates}` placeholder. Peak lore-accuracy per line of code.

## Done

- Tombstone + epitaph — a grave at the death spot, click it and he talks
  back from beyond (v1.8.0, v1.9.0).

## Decided against

- **Clipboard snooping** — on-brand for the joke, but with `ai: true` it
  means shipping clipboard contents to an LLM. A real privacy footgun even
  opt-in.
- **Walking on window title bars** — leaves the bar-anchored model
  entirely; a big rewrite for a gag the bar already delivers.
