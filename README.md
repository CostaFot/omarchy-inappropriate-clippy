# Inappropriate Clippy

<img src="preview.png" width="700" alt="Clippy on the bar, telling you off">

Clippy, on the [Omarchy](https://omarchy.org) bar. He walks the full width of it,
over whatever widgets are in the way, and every few minutes stops to tell you
what he thinks of you. It's not flattering.

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
| Right-click | opens his menu: say something, snooze, kill him, and the settings below |
| Click the paperclip on the bar | the same menu. When he's dead or hidden it says "Bring him back", which is the point of the paperclip |

Left-click the bubble to dismiss it.

Ten slaps inside six seconds and he's out cold, same as a kill; `slapsToKill`
below changes the number (`0` and he takes it forever). Snooze moved to the
menu to make room for the slap; `"slap": false` gives middle-click back to it.

## Configuration

The menu covers the common ones (clean mode, sounds, how much he walks, size) and
writes them for you. Everything goes on his entry in
`~/.config/omarchy/shell.json`. He has a bar icon, so that entry lives in the
bar layout with the other widgets. All optional.

```json
"bar": {
  "layout": {
    "right": [
      { "id": "costafot.clippy", "size": 30, "clean": false, "intervalMin": 90, "intervalMax": 420 }
    ]
  }
}
```

The paperclip moves like any widget: `omarchy bar move costafot.clippy --section left`.
Installs from before it existed have the entry under `plugins`; he moves it
into the bar himself, settings and all.

| Key | Default | What |
|---|---|---|
| `size` | `30` | His height in px. The bar is 26, so he hangs over the edge a bit |
| `clean` | `false` | `true` drops every line tagged `nsfw`. Screen-share mode |
| `intervalMin` / `intervalMax` | `90` / `420` | Seconds between unprompted lines |
| `speed` | `40` | Walking speed, px/s |
| `restless` | `0.3` | 0–1, how often he decides to walk (about once a minute at the default; `1` is constant pacing) |
| `respawn` | `300` | Seconds he stays dead after you kill him. `0` = dead until told otherwise |
| `screen` | focused | A monitor name (`hyprctl monitors`) to pin him to one screen |
| `quotesFile` | — | Path to your own quotes JSON, merged into his |
| `slap` | `true` | `false` turns slapping off. Middle-click snoozes again |
| `slapSwipe` | `true` | `false` keeps middle-click but stops the pointer-fling counting as a slap |
| `slapSound` | `true` | `false` mutes it; a path to a WAV plays that instead of the built-in three |
| `flingSound` | follows `slapSound` | The falling sound when he's thrown. `false`, or a path to a WAV instead of the built-in two |
| `slapsToKill` | `10` | That many slaps inside six seconds knocks him out, same as a kill. `0` = never |
| `drag` | `true` | `false` stops the long-press drag |
| `fling` | `true` | `false` makes a fast release just a drop, not a throw |
| `ai` | `false` | `true` and his lines come from your AI agent, about what you're actually doing. See below |
| `aiAgent` | your default | Which agent to use (`claude`, `codex`, `opencode`, `pi`, ...) if not the one `omarchy default agent` set |
| `aiModel` | the agent's default | A model name for it, e.g. `claude-sonnet-5`. Cheaper is fine; it's a paperclip |

`quotesFile` takes the same shape as [`quotes.json`](quotes.json): an array of
`{ "text": "...", "nsfw": true }` (plain strings work too), or an object with
`quotes`, `lastWords`, `comeback`, `slapped`, `knockedOut`, `dragged`, `dropped`
and `flung` arrays.

## Letting your AI agent write his lines

Turn on "Lines from claude" in the menu (or `"ai": true`) and the random book
is replaced with remarks about what you are actually doing. Every so often he
looks at the focused window, how many windows are open, the battery, the load,
the uptime, what's playing, the hour, how much of your agent plan you've burned
this week, and what you've done to him lately (slaps, drags, the odd murder),
and asks your coding agent for five lines in his voice, with a handful of
lines from the book (and your `quotesFile`) as examples of how far to go.
They're cached and handed out one at a time, so a click never waits on a model.

The agent is whichever `omarchy default agent` picked, run the way `omarchy
agent prompt` runs it but in its one-shot mode with tools off: it gets the
facts as text and can only answer. Nothing on your machine is touched. It does
mean the window title and the rest of that list are sent wherever that agent
sends its prompts, and every batch spends a little of your plan: one small
call every 15 minutes or so at the default pace, more if you keep clicking
him, never more than one a minute. It runs on the agent's default model
unless `aiModel` says otherwise. For claude that is the CLI's default (opus),
not the `model` in your `settings.json`, because the call runs with your
settings off so it doesn't load your CLAUDE.md and hooks. A smaller model
does the job fine (`claude-sonnet-5` answered in 4 s, same as opus; haiku 4.5
oddly took a minute). `clean` applies to these lines too. Whenever the agent
is unset, not logged in, offline or slow, the book takes over and you won't
notice.

Verified with `claude` and `opencode`; `codex` and `pi` are wired the same way
but weren't run here, and the rest are best guesses from their docs. To see
what he'd send, or try an agent by hand:

```bash
~/.config/omarchy/plugins/costafot.clippy/scripts/clippy-ai --context
~/.config/omarchy/plugins/costafot.clippy/scripts/clippy-ai --prompt
~/.config/omarchy/plugins/costafot.clippy/scripts/clippy-ai --agent opencode
```

## Scripting him

```bash
omarchy-shell costafot.clippy say "Another theme. That'll fix it."
omarchy-shell costafot.clippy talk       # a line of his own, what a click does
omarchy-shell costafot.clippy shutUp
omarchy-shell costafot.clippy snooze 30  # unsnooze wakes him early
omarchy-shell costafot.clippy slap left   # or right: the way he flies
omarchy-shell costafot.clippy fling left  # off that end of the bar; fatal
omarchy-shell costafot.clippy kill
omarchy-shell costafot.clippy respawn
omarchy-shell costafot.clippy hide        # show brings him back, from hidden or dead
omarchy-shell costafot.clippy toggle
omarchy-shell costafot.clippy showMenu  # the menu; hideMenu closes it
omarchy-shell costafot.clippy state      # idle | walking | talking | dying | dead | snoozed | hidden
omarchy-shell costafot.clippy ai         # off, or "claude: 2 cached (40s old), last call 41s ago"
omarchy-shell costafot.clippy set clean true   # any key from the table; "unset" puts the default back
omarchy-shell costafot.clippy get clean        # the value in effect, as JSON
omarchy-shell costafot.clippy settings         # all of them
```

That is also enough for your coding agent to run him: point it at this file
(`~/.config/omarchy/plugins/costafot.clippy/README.md`) and "make Clippy
clean, I'm sharing my screen" or "snooze him for an hour" is one command
away. `set` writes the key to `shell.json` for you, same as the menu does.
Replies come back on stdout (`ok`, `not now`, `hidden`...), and
`qs ipc -n -p "$OMARCHY_PATH/shell" show` lists every method with its arguments.

`say` works from anywhere, so an Omarchy hook can feed him lines:

```bash
# ~/.config/omarchy/hooks/theme-set.d/clippy
omarchy-shell -q costafot.clippy say "Oh good, another theme. That'll fix it."
```

## Notes and limitations

- Top and bottom bars only. On a vertical bar he doesn't show up.
- The bubble draws over the top of your windows. He is, after all, in the way.
- Out of the box the lines are random; he doesn't know what you did. With
  `ai` on he does, roughly.
- Clippy, the name and the artwork are Microsoft's. The sprites come from
  [clippy.js](https://github.com/clippyjs/clippy.js); the code here is MIT, the
  paperclip is not.
