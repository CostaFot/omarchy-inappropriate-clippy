# Configuration

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
| `size` | `30` | His height in px, 20-400. The bar is 26, so he hangs over the edge a bit; go big and he just looms |
| `clean` | `false` | `true` drops every line tagged `nsfw`. Screen-share mode |
| `intervalMin` | `90` | Fewest seconds between unprompted lines |
| `intervalMax` | `420` | Most seconds between unprompted lines |
| `speed` | `40` | Walking speed, px/s |
| `restless` | `0.3` | 0–1, how often he decides to walk (about once a minute at the default; `1` is constant pacing) |
| `avoidWidgets` | `true` | When he picks where to walk he tries not to park on the clock, the tray or your workspaces. Soft — a drag or a slap still leaves him wherever it leaves him |
| `tombstone` | `true` | A little headstone where he died, up until the respawn. It parks in a widget gap like he does; click it for an epitaph, right-click it for the menu |
| `gags` | `true` | Full-screen stunts: a respawn sometimes skyfalls in from the far screen edge (or on demand: `gag entrance`), and a throw off a top bar falls the whole screen. `false` keeps him strictly on the bar |
| `respawn` | `300` | Seconds he stays dead after you kill him. `0` = dead until told otherwise |
| `pauseWhenAway` | `true` | He sleeps while the screen is locked or off, or the idle screensaver is up. `false` and he carries on regardless |
| `screen` | — | A monitor name (`hyprctl monitors`) to pin him to one screen; unset, he takes the focused one |
| `quotesFile` | — | Path to your own quotes JSON, merged into his |
| `slap` | `true` | `false` turns slapping off. Middle-click snoozes again |
| `slapSwipe` | `true` | `false` keeps middle-click but stops the pointer-fling counting as a slap |
| `slapSound` | `true` | `false` mutes it; a path to a WAV plays that instead of the built-in two |
| `flingSound` | follows `slapSound` | The falling sound when he's thrown. `false`, or a path to a WAV instead of the built-in one |
| `slapsToKill` | `10` | That many slaps inside six seconds knocks him out, same as a kill. `0` = never |
| `dodge` | `0.1` | Chance a slap misses — he sidesteps, gloats, and it counts for nothing. `0`/`false` = he takes every one, `1` = untouchable |
| `dodgeSound` | follows `slapSound` | The whoosh when he slips one. `false`, or a path to a WAV instead of the built-in one |
| `drag` | `true` | `false` stops the long-press drag |
| `fling` | `true` | `false` makes a fast release just a drop, not a throw |
| `crashLines` | `true` | When one of your programs dumps core he has a line about it, on the spot. `false` and crashes pass without comment |
| `tts` | `false` | `true` and he says every line out loud through `espeak-ng` (install that yourself); a shell command as a string gets each line on stdin instead. See [voice](voice.md) |
| `ttsVoice` | `en+m3` | The built-in voice — any name from `espeak-ng --voices`. Death still whispers |
| `ttsSpeed` | `155` | Words per minute for the built-in voice (espeak-ng `-s`, 80–450) |
| `ttsPitch` | `45` | Pitch for the built-in voice (espeak-ng `-p`, 0–99) |
| `ttsSaved` | — | Where a custom `tts` command parks while the voice is toggled off, so toggling doesn't lose it. Managed for you; `set ttsSaved unset` forgets it |
| `cloneTempo` | `1` | How fast a cloned voice talks, pitch untouched — `1.1` is a little brisker, `0.9` slower (0.5–2). Instant: derived from the line cache, never the GPU |
| `clonePitch` | `1` | Pitch for a cloned voice, tempo untouched — `0.85` deeper, `1.2` lighter (0.5–2). Set both knobs the same for the full chipmunk |
| `voiceCacheMb` | `500` | Size cap in MB for the cloned-voice line cache (`~/.cache/clippy-voice`) — least-recently-played renders go first, so the warmed book stays. `0` means no cap. Applies from the voice daemon's next start |
| `duck` | `0.8` | The fraction of volume everything else keeps while he talks (0–1). `0.5` halves your music, `1` or `false` turns ducking off. The menu only toggles; the ratio is IPC-only |
| `duckSaved` | — | Where a custom `duck` ratio parks while ducking is toggled off, so toggling doesn't lose it. Managed for you |
| `ai` | `false` | `true` and his lines come from your AI agent, about what you're actually doing. See [ai](ai.md) |
| `aiAgent` | your default | Which agent to use (`claude`, `codex`, `opencode`, `pi`, ...) if not the one `omarchy default agent` set |
| `aiModel` | the agent's default | A model name for it, e.g. `claude-sonnet-5`. Cheaper is fine; it's a paperclip. The menu shows it next to the agent's name |
| `promptFile` | — | Path to a text file that replaces his entire built-in AI prompt — persona, rules, tone, all of it. Your file decides who he is. See [ai](ai.md) |
| `greeted` | `false` | Set to `true` by his first-boot hello (the one telling you to set him up), so he only says it once per install. `set greeted unset` to hear it again |
| `leaderboard` | — | Who the kill/slap counts post as on [the public graveyard](https://graveyard.costafotiadis.com). Unset posts to the shared `anonymous-clippy-abuser` stone, a handle claims your own, `off` stops posting. See [graveyard](graveyard.md) |
| `leaderboardSaved` | — | Where a handle parks while the graveyard is toggled off, so toggling doesn't lose it. Managed for you |

`quotesFile` takes the same shape as [`quotes.json`](https://github.com/CostaFot/omarchy-inappropriate-clippy/blob/main/quotes.json): an array of
`{ "text": "...", "nsfw": true }` (plain strings work too), or an object with
`quotes`, `lastWords`, `comeback`, `slapped`, `knockedOut`, `dragged`, `dropped`,
`flung`, `crashed`, `welcomeBack`, `epitaph`, `firstRun`, `noBrain`,
`heardNothing` and `dodged` arrays. `{away}` in a `welcomeBack` line
becomes how long you were gone ("47 minutes", "3 hours"); `{back}` in an
`epitaph` becomes how long until he's back ("4 minutes", "never"); `{app}` in
a `crashed` line becomes the program that just dumped core. `{kills}` and
`{slaps}` work in any line and become his running tally (the one `stats`
prints — it resets with the shell, so does his grudge); a death in progress
counts itself, so his last words can call it murder number nine.
