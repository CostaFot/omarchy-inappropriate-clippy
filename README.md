# Inappropriate Clippy

<img src="preview.png" width="700" alt="Clippy on the bar, telling you off">

Clippy, on the [Omarchy](https://omarchy.org) bar. He walks the full width of it
— across your widgets, but parking in the gaps between them — and every few
minutes stops to tell you what he thinks of you. It's not flattering.

```bash
omarchy plugin add https://github.com/CostaFot/omarchy-inappropriate-clippy --enable
```

He's on the monitor Hyprland has focused, and follows you between screens.

## Using him

| Do | He |
|---|---|
| Nothing | paces, fidgets, and drops a line every 1.5–7 minutes |
| Left-click | says something now (or shuts up, if he's mid-sentence) |
| Middle-click | slaps him. He yelps, gets shoved along the bar, and has something to say about it |
| Fling the pointer across him | also a slap. Fast and sideways; a pointer merely passing over him on the way to the tray doesn't count |
| Hold left-click, then drag | picks him up. Put him down anywhere on the bar; he objects to the trip and to where it ends |
| Let go mid-fling | throws him off the end of the bar. He doesn't survive it, but he does get a last word in |
| Right-click | opens his menu: say something, snooze, kill him, and the common settings |
| Click his tombstone | he's dead, not quiet. An epitaph, from beyond |
| Click the paperclip on the bar | the same menu. When he's dead or hidden it says "Bring him back", which is the point of the paperclip |

Left-click the bubble to dismiss it.

Ten slaps inside six seconds and he's out cold, same as a kill; `slapsToKill`
changes the number (`0` and he takes it forever). Now and then he
slips one — one slap in ten misses, and a miss is a sidestep, a whoosh, a
gloat and no score (`dodge` sets the odds). However he goes, a
little tombstone marks the spot until he's back. The menu keeps score at
the bottom — every slap, every death (well, since the last reboot; he
forgives nothing, but the shell forgets). Snooze moved to the
menu to make room for the slap; `"slap": false` gives middle-click back to it.

He watches the crash log. A program of yours dumps core and he reacts on
the spot ("There goes brave. It fought your bullshit as long as it
could.") — read straight from systemd-coredump's journal stream, so it's
instant, needs no agent, and nothing leaves the machine. One line per
program per minute, so a crash loop doesn't turn into a monologue;
`"crashLines": false` turns it off.

He sleeps when you're away: the screen locked or off, or Omarchy's idle
screensaver up. No pacing, no lines, and no calls to your agent for an
audience of nobody. He's back the moment you are, and if you were gone more
than a minute he has something to say about it ("Welcome back, dipshit.").
If his respawn came due while you were gone, he comes back with it.

## Settings

The menu covers the common ones — clean mode, sounds, how much he walks,
size, the voice — and writes them for you. Everything else is a key on his
entry in `~/.config/omarchy/shell.json`, set from a terminal or by your
agent:

```bash
omarchy-shell costafot.clippy set clean true   # screen-share mode: drops every nsfw line
omarchy-shell costafot.clippy set respawn 0    # dead until told otherwise
omarchy-shell costafot.clippy settings         # everything, as it stands
```

Every key, with its default, is in [docs/configuration.md](docs/configuration.md).

## The rest of him

Each of these has its own page. They used to all be in here, and it got out
of hand.

- **[Lines from your AI agent](docs/ai.md)** — off by default. `"ai": true`
  and instead of the random book he writes remarks about what you are
  actually doing: your window titles, what's playing, what you've done to
  him lately, a battery about to die. Those facts go wherever your coding
  agent sends its prompts, and nowhere else; he never digs through your
  files, and never takes a screenshot unless you ask for the verdict
  ("Judge my screen"). You can talk back to him — the mic is transcribed on
  your machine, only the text goes to the agent — and `promptFile` makes him
  whoever you want.
- **[A voice](docs/voice.md)** — `"tts": true` for the espeak robot, or
  `scripts/setup-voice` for a local neural voice: the shipped clone of
  Rubick from Dota 2, a ring-modulated droid, or a clone of anyone you have
  twenty seconds of. Models on your disk, no cloud TTS, ever. Your music
  ducks while he talks.
- **[The graveyard](docs/graveyard.md)** — a public leaderboard of who has
  killed him the most. On by default and anonymous: what leaves your machine
  is one alias shared by every install (or a handle you claim) and small
  kill/slap counts, posted when you slap or kill him. Nothing else — no
  hostname, no install ID, no usage data. `set leaderboard off` and nothing
  is sent.
- **[Scripting him](docs/scripting.md)** — every verb is a plain command
  (`omarchy-shell costafot.clippy help` lists them), so they drop straight
  into Hyprland binds and Omarchy hooks. Your coding agent can run him too:
  point it at `docs/` and "snooze him for an hour" is one command away.

The same pages, rendered: https://costafot.github.io/omarchy-inappropriate-clippy/

## Notes and limitations

- Top and bottom bars only. On a vertical bar he doesn't show up.
- The bubble draws over the top of your windows. He is, after all, in the way.
- Out of the box the lines are random; he doesn't know what you did. With
  `ai` on he does, roughly.
- Clippy, the name and the artwork are Microsoft's. The sprites come from
  [clippy.js](https://github.com/clippyjs/clippy.js); the code here is MIT, the
  paperclip is not. This is a parody. It is not affiliated with, authorised by
  or endorsed by Microsoft, and it is free — nobody is making a penny out of
  their paperclip.
- The shipped clone voice is twenty seconds of Rubick from Dota 2 — Valve's
  audio, on the same parody terms.
