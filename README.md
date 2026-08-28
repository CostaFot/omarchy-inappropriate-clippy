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
| Right-click | opens his menu: say something, snooze, kill him, and the settings below |
| Click the paperclip on the bar | the same menu. When he's dead or hidden it says "Bring him back", which is the point of the paperclip |

Left-click the bubble to dismiss it.

Five slaps inside six seconds knocks him out: same as killing him, back after
`respawn` seconds or the paperclip. Snooze moved to the menu to make room for
the slap; `"slap": false` gives middle-click back to it.

## Configuration

The menu covers the common ones (clean mode, slap sound, how much he walks, size) and
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
| `slapsToKill` | `5` | Slaps within six seconds before he's knocked out. `0` means he takes it forever |

`quotesFile` takes the same shape as [`quotes.json`](quotes.json): an array of
`{ "text": "...", "nsfw": true }` (plain strings work too), or an object with
`quotes`, `lastWords`, `comeback`, `slapped` and `knockedOut` arrays.

## Scripting him

```bash
omarchy-shell costafot.clippy say "Another theme. That'll fix it."
omarchy-shell costafot.clippy shutUp
omarchy-shell costafot.clippy snooze 30
omarchy-shell costafot.clippy slap left   # or right: the way he flies
omarchy-shell costafot.clippy kill
omarchy-shell costafot.clippy respawn
omarchy-shell costafot.clippy toggle
omarchy-shell costafot.clippy showMenu  # the menu; hideMenu closes it
omarchy-shell costafot.clippy state      # idle | walking | talking | dying | dead | snoozed | hidden
```

`say` works from anywhere, so an Omarchy hook can feed him lines:

```bash
# ~/.config/omarchy/hooks/theme-set.d/clippy
omarchy-shell -q costafot.clippy say "Oh good, another theme. That'll fix it."
```

## Notes and limitations

- Top and bottom bars only. On a vertical bar he doesn't show up.
- The bubble draws over the top of your windows. He is, after all, in the way.
- The lines are random; he doesn't actually know what you did. Yet.
- Clippy, the name and the artwork are Microsoft's. The sprites come from
  [clippy.js](https://github.com/clippyjs/clippy.js); the code here is MIT, the
  paperclip is not.
