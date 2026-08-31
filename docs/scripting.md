# Scripting him

```bash
omarchy-shell costafot.clippy help       # every verb, one per line — start here
omarchy-shell costafot.clippy say "Another theme. That'll fix it."
omarchy-shell costafot.clippy talk       # a line of his own, what a click does
omarchy-shell costafot.clippy look       # screenshots his screen; the agent's verdict lands in his bubble (needs ai on)
omarchy-shell costafot.clippy listen     # toggles the mic; he transcribes you locally and the agent's comeback lands in his bubble (needs ai on)
omarchy-shell costafot.clippy reply "make me"  # the typed version of listen — same comeback, no mic
omarchy-shell costafot.clippy shutUp
omarchy-shell costafot.clippy snooze 30  # unsnooze wakes him early
omarchy-shell costafot.clippy slap left   # or right: the way he flies
omarchy-shell costafot.clippy fling left  # off that end of the bar; fatal
omarchy-shell costafot.clippy kill
omarchy-shell costafot.clippy respawn
omarchy-shell costafot.clippy gag entrance  # the skyfall: in from the far screen edge, bounced onto the bar
omarchy-shell costafot.clippy gag peek      # in from a far screen corner, huge, one line, back out (slappable meanwhile)
omarchy-shell costafot.clippy epitaph     # poke the grave while he's dead: an epitaph in the bubble
omarchy-shell costafot.clippy unsnooze    # wakes him early
omarchy-shell costafot.clippy hide
omarchy-shell costafot.clippy show        # brings him back, from hidden or dead
omarchy-shell costafot.clippy toggle
omarchy-shell costafot.clippy showMenu    # the menu, no pointer needed
omarchy-shell costafot.clippy hideMenu
omarchy-shell costafot.clippy state      # idle | walking | talking | peeking | dying | dead | snoozed | hidden | asleep
omarchy-shell costafot.clippy ai         # off, or "claude: 2 cached (40s old), last call 41s ago"
omarchy-shell costafot.clippy voice      # off, "espeak-ng: ready", "espeak-ng: not installed — silent (...)", or the custom command
omarchy-shell costafot.clippy voices     # every voice installed on this machine, and where new ones come from
omarchy-shell costafot.clippy useVoice rubick  # switch to any installed voice by name
omarchy-shell costafot.clippy stats      # the lifetime tally: "34 slaps, 5 kills"
omarchy-shell costafot.clippy leaderboard  # "posting anonymously to the shared ... stone", "posting as costa: #4 of 31 ...", or off
omarchy-shell costafot.clippy set clean true   # any key from configuration.md; "unset" puts the default back
omarchy-shell costafot.clippy get clean        # the value in effect, as JSON
omarchy-shell costafot.clippy settings         # all of them
```

That is also enough for your coding agent to run him: point it at this
folder (`~/.config/omarchy/plugins/costafot.clippy/docs/` — this file is
the verbs, [configuration.md](configuration.md) is every key) and "make
Clippy clean, I'm sharing my screen" or "snooze him for an hour" is one
command away. An agent that has never seen these files can bootstrap from
`help` alone: it lists every verb, ends with the path to this folder, and
`voice`, `ai` and the `set` replies say what's wrong and how to fix it.
`set` writes the key to `shell.json` for you, same as the menu does.

Every argument is required and is one string — quote anything with spaces
(`set tts "piper ... | aplay ..."` is one argument). `set` reads the value
by shape: `true`/`false` become booleans, a number becomes a number,
`unset` (or `default`, or an empty string) removes the key so the default
comes back, anything else is stored as a string. A number outside a key's
range is stored as given and answered `ok` — the clamp happens where the
value is used, so `set restless 5` behaves as `1` while `get` still says
`5`. `get` prints the value in effect as JSON, so a string comes back
quoted.

Every verb answers one line on stdout. `ok` means it happened; `ok — <note>`
adds what happens next ("looking; the verdict lands in his bubble in ~10 s",
"posting as costa"); `ok — but <why>` means the write landed but won't be
felt yet ("ai is off, so there are no agent lines to apply it to"). The
refusals name the state: `not now` (mid-animation, dragging, snoozed),
`hidden`, `asleep`, `dead — …`, `off — …` (the feature is off, with the key
that turns it on), `already`, `alive`, `dying`/`reviving`, `busy — …` (a
look or a comeback in flight), `not snoozed`, `no grave`, `no ears — …`
(no voxtype). `gag` answers `no such gag — the set: <names>` for a stunt
it doesn't know. `slap` answers `ok`, `dodged`, `not now` or `off`; `toggle`
answers `shown` or `hidden`; `state` answers one of its nine words;
`kill`, `shutUp`, `snooze`, `showMenu` and `hideMenu` always answer `ok`.
`set` and `get` answer `unknown key <k>; one of …` for a key that isn't in
[configuration.md](configuration.md), `no — <the rule>` for a value that
doesn't fit (`duck` outside 0–1, a handle with capitals, a `voiceCacheMb`
that isn't a number of MB), and `can't write
shell.json` when the write fails. `qs ipc -n -p "$OMARCHY_PATH/shell" show`
lists every method with its arguments.

Omarchy is keyboard-first and these are plain commands, so any of them
drops straight into a Hyprland bind:

```conf
# ~/.config/hypr/bindings.conf
bindd = SUPER SHIFT C, C, Toggle Clippy, exec, omarchy-shell costafot.clippy toggle
bindd = SUPER SHIFT C, T, Clippy talks, exec, omarchy-shell costafot.clippy talk
bindd = SUPER SHIFT C, J, Clippy judges the screen, exec, omarchy-shell costafot.clippy look
bindd = SUPER SHIFT C, V, Talk back to Clippy, exec, omarchy-shell costafot.clippy listen
```

Or push-to-talk — `listen` is a toggle, so a press bind and a release bind
make hold-to-record:

```conf
bindd  = SUPER SHIFT C, V, Clippy listens, exec, omarchy-shell costafot.clippy listen
bindrd = SUPER SHIFT C, V, Clippy stops listening, exec, omarchy-shell costafot.clippy listen
```

`say` works from anywhere, so an Omarchy hook can feed him lines:

```bash
# ~/.config/omarchy/hooks/theme-set.d/clippy
omarchy-shell -q costafot.clippy say "Oh good, another theme. That'll fix it."
```
