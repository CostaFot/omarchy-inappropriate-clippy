# Inappropriate Clippy

<img src="preview.png" width="700" alt="I've seen your dotfiles. I've seen things.">

Clippy as-a-plugin, on the [Omarchy](https://omarchy.org) bar. He walks, parks
between your widgets, and mouths off every few minutes.

## Install

```bash
omarchy plugin add https://github.com/CostaFot/omarchy-inappropriate-clippy --enable
```

Setting him up from a coding agent? [`docs/`](docs/index.md) has every key
and verb; `omarchy-shell costafot.clippy help` is the short list.

## (Ab)Using him

| Do | He |
|---|---|
| Nothing | paces, and drops a line every 1.5–7 minutes |
| Left-click | says something now |
| Middle-click | slap! |
| Fling the pointer across him | also a slap. Quite funnier |
| Hold left-click, then drag | picks him up. Drop him anywhere on the bar |
| Let go mid-fast-fling | throws him off the end of the bar. Fatal, but he gets a last word in |
| Right-click | the menu: say something, snooze, kill him, common settings |
| Click his tombstone | an epitaph, from beyond |
| Click the paperclip on the bar | the same menu |

Left-click the bubble to dismiss it.

### Slaps, deaths, dodges

<!-- shot: slap left over IPC, grabbed mid-wobble; a ~2 s gif of the shove + bubble (slap.gif) would replace this still -->
<img src="assets/screenshots/slap-line.png" width="700" alt="Keep going, I'm sure it fixes the build.">

Ten slaps in six seconds knocks him out. Sometimes the fucker dodges.

<!-- shot: kill over IPC, the last words before he goes -->
<img src="assets/screenshots/last-words.png" width="700" alt="Oh, you're KILLING me? Real mature.">

Either way a tombstone marks the spot until he respawns.

<!-- shot: epitaph over IPC (a click on the grave), {back} filled in -->
<img src="assets/screenshots/tombstone.png" width="700" alt="Back in 5 minutes. Start apologizing.">

### He is watching you

<!-- shot: sleep 30 & kill -SEGV $! — or say "There goes brave. It fought your bullshit as long as it could." -->
<img src="assets/screenshots/crash.png" width="700" alt="There goes brave. It fought your bullshit as long as it could.">

Reads off the local crash journal. He has an opinion.

### He sleeps when you're away

Screen locked, screen off, screensaver up.

Bonus easter egg when you are back. :)

## Settings

<!-- shot: showMenu over IPC, alive and dead; the tally and the graveyard rank at the foot -->
<img src="assets/screenshots/menu.png" width="420" alt="The right-click menu"> <img src="assets/screenshots/menu-dead.png" width="420" alt="The same menu while he is dead: one row, Bring him back">

Right-click him for the common ones: clean mode, sounds, walks, size, voice.
Everything else is a key, set from a terminal or by your agent:

```bash
omarchy-shell costafot.clippy set clean true   # screen-share mode: drops every nsfw line
omarchy-shell costafot.clippy set respawn 0    # dead until told otherwise
omarchy-shell costafot.clippy settings         # everything, as it stands
```

Every key, with its default: [docs/configuration.md](docs/configuration.md).

## The rest of him

One page each in [the manual](https://costafot.github.io/omarchy-inappropriate-clippy/),
also under `docs/`.

### [Lines from your AI agent](docs/ai.md)

Off by default. `ai: true` and the lines are about what you're actually
doing: your window titles, what's playing, what you did to him lately.

<!-- shot: talk with ai on — the sparkle in the bubble corner marks an agent line -->
<img src="assets/screenshots/ai-line-3.png" width="700" alt="You said hello, I answered, and you killed me twice tonight — that's the healthiest bond you've got.">

You can talk back, and he talks back. Ask him to judge your screen and he
finds the stupidest thing on it.

<!-- shot: reply "you're a useless piece of office stationery" over IPC -->
<img src="assets/screenshots/comeback.png" width="700" alt="Useless stationery still ranks higher than you on a leaderboard you built just to lose to me.">

<!-- shot: look over IPC, on an empty desktop -->
<img src="assets/screenshots/screen-look.png" width="700" alt="Brave crashed again and you named the folder 'scratchpad' like this was ever going somewhere.">

`promptFile` makes him whoever you want.

**Leaves your machine:**
- those facts, to your own coding agent, nowhere else
- never your files — he doesn't read them
- a screenshot only when you ask for the verdict
- the mic is transcribed locally; only the text goes out

### [A voice](docs/voice.md)

Set `tts: true` for the espeak robot.

`scripts/setup-voice` for a local neural one: the shipped Rubick clone, a ring-modulated droid, or a clone of anyone
you have twenty seconds of.

Needs a decent GPU. My 3080ti works fine with it.

### [The graveyard](docs/graveyard.md)

https://graveyard.costafotiadis.com/

A public leaderboard with how many times clippy has been killed/slapped. Half the fun of this app.

<!-- shot: the leaderboard page, headless chromium at 2x -->
<img src="assets/screenshots/graveyard.png" width="700" alt="The graveyard: one headstone per handle, sized by kills">

**Leaves your machine:**
- one alias shared by every install, or a handle you claim
- small kill/slap counts, when you slap or kill him
- no hostname, no install ID, no usage data
- `set leaderboard off` and nothing is sent

Read the source code

### [Scripting him](docs/scripting.md)

Every verb is a command (`omarchy-shell costafot.clippy help` lists
them), so they drop into Hyprland binds and Omarchy hooks.

Your coding agent can run him too. It's actually the preferred way! Tell it:

> Read `~/.config/omarchy/plugins/costafot.clippy/docs/` and run
> `omarchy-shell costafot.clippy help`.

That's it. Then ask stuff.

## Uninstall
```bash
omarchy plugin remove costafot.clippy   # when you've had enough
```

## FAQ

**Is there telemetry?**

One thing: the graveyard. Kill and slap counts under a shared alias, so
nobody knows it's you. `set leaderboard off` to disable it. That's
it — no hostname, no install ID, no usage data.

**Does he read my files?**

No. With `ai` off nothing leaves the machine. With it on, your window
titles and stuff like that go to your own coding agent. Read the source.

**Can I make him nicer?**

`set clean true` makes him SFW. `promptFile` makes him whoever
you want. 

## Notes and limitations

- Top and bottom bars only. On a vertical bar he doesn't show up.
- The bubble draws over your windows. He is, after all, in the way.
- Without `ai` the lines are random; he doesn't know what you did.
- Clippy, the name and the artwork are Microsoft's. The sprites come from
  [clippy.js](https://github.com/clippyjs/clippy.js); the code here is MIT,
  the paperclip is not. This is a parody — not affiliated with, authorised
  by or endorsed by Microsoft, and nobody is making a penny out of their
  paperclip.
- The shipped clone voice is twenty seconds of Rubick from Dota 2 — Valve's
  audio, on the same parody terms.
