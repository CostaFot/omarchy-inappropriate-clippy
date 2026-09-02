# Giving him a voice

`"tts": true` and every line in the bubble is also said out loud, in the most
correctly stupid robot voice available: `espeak-ng`. It isn't installed with
the plugin — `sudo pacman -S espeak-ng` and he starts talking; without it he
stays silent and tells on himself everywhere you might look: he says so in a
bubble the moment you switch the voice on, the menu row reads "Voice ·
install espeak-ng", and for agents and scripts `voice` answers with what's
wrong and the fix, `set tts true` and a silent `say` warn in their replies,
and one line lands in the journal. Epitaphs are whispered, because he's dead.

The robot takes tuning before you replace him: `ttsVoice` is any name from
`espeak-ng --voices` (`en+f3`, `en+croak`, `en+Tweaky`, ...), `ttsSpeed` and
`ttsPitch` are espeak-ng's `-s` and `-p`. One command, from you or your agent:

```bash
omarchy-shell costafot.clippy set ttsVoice en+croak
```

Epitaphs stay whispered whatever you pick.

If you'd rather he sounded good (why?), `scripts/setup-voice` does the whole
thing locally: it installs a neural TTS into a venv, downloads what it
needs, and points `tts` at it. No cloud calls, a model on your disk, and
the espeak robot is one `set tts true` away. The scripts live in the plugin
dir — `~/.config/omarchy/plugins/costafot.clippy/scripts/` — and every
`scripts/…` below is relative to that. The modes:

```bash
scripts/setup-voice                      # bare: the shipped Rubick clone on an NVIDIA GPU with 6 GB of VRAM, robot George otherwise
scripts/setup-voice --robot              # robot George, GPU or not
scripts/setup-voice af_heart             # any kokoro voice, unprocessed (af_*, am_*, bm_*, ...)
scripts/setup-voice en_US-ryan-high      # any piper catalog voice (the dash in the name picks piper)
scripts/setup-voice --clone ~/sample.mp4 [name]                  # clone any voice from a 10-20 s sample; NVIDIA GPU
scripts/setup-voice --clone ~/scene.mp4 name --from 5:59 --to 6:12   # the same, cut out of a longer recording
scripts/warm-voice                       # re-render the book into the clone cache (after --exag/--cfg edits)
scripts/voice-scan                       # one JSON object of every voice on this machine
```

Bare, it checks what you're
running on: an NVIDIA GPU with 6 GB of VRAM gets the shipped voice — a
clone of Rubick the Grand Magus, built from the 20-second sample in
`assets/voices/` (Dota 2 audio, © Valve) — and anything less gets the
blessed robot,
[kokoro](https://github.com/thewh1teagle/kokoro-onnx)'s `bm_george` (~340 MB)
put through a ring-modulated robot chain: a fussy English droid, dialed in
by ear. `--robot` skips the GPU check and gets you the droid anyway. Pass a
name for any
[kokoro voice](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md)
unprocessed (`af_heart`, `am_adam`, `jf_alpha`, ...) or, with a dash in the name, any
[piper catalog](https://rhasspy.github.io/piper-samples/) voice like
`en_US-ryan-high` — a lighter engine (~60–120 MB) that sounds it.

And the fun one — give him **any voice you have a sample of**, yours
included:

```bash
scripts/setup-voice --clone ~/glados-lines.mp4 glados
scripts/setup-voice --clone ~/whole-scene.mp4 glados --from 1:33 --to 1:56
```

Ten to twenty seconds of clean speech, any format ffmpeg reads. `--from`
and `--to` (ffmpeg times: `95`, `1:35`, `0:01:35.5`) cut the sample out
of a longer recording, so a downloaded scene works as-is; it's capped at
20 s either way. The sample is loudness-normalised on the way in — a
quiet rip needs no volume prep. What does matter is what's *under* the
voice: a film mix with score and room tone under the dialogue clones
muddy, and a shouted reference gives a strained voice on every line, so
pick the driest, calmest stretch you can find. The script prints the
cut's length and warns when it's short. Re-cloning a name replaces its
sample; lines rendered from the old one are never reused (the line cache
is keyed by the sample's contents), and the book is re-rendered for the
new one like a fresh clone. Cloning uses
[chatterbox](https://github.com/resemble-ai/chatterbox), so it needs an
NVIDIA GPU, [uv](https://github.com/astral-sh/uv) (`sudo pacman -S uv` —
the script tells you and stops if it's missing, it never installs it for
you) and pulls ~8 GB on first run — the shipped Rubick is this exact
machinery pointed at a sample we picked for you, so the same costs apply.
A small daemon keeps the model warm
between lines and exits after 15 idle minutes to give your VRAM back; every
line is cached, so anything he's said before plays instantly and a fresh
line costs a few seconds of GPU. Every clone shows up by name in the
menu's Voice picker, and IPC `voice` tells your agent the whole story.
Temper your expectations: the clone gets the accent and the cadence, not
the soul. It's fun. It is not amazing.

Tuning the clone: `cloneTempo` and `clonePitch` are settings like any other,
and the menu grows Tempo and Pitch rows (slow · normal · brisk · fast,
deep · normal · light · squeaky) whenever a clone voice is the one talking.
`set cloneTempo 1.1` and he talks a little faster, pitch untouched;
`set clonePitch 0.85` and he's noticeably deeper, tempo untouched; both to
`1.2` and you've built the chipmunk. They're applied to the line cache with
ffmpeg, never the GPU, so auditioning values is instant and the warm cache
stays warm. `voiceVolume` (0–1, a Voice volume row in the menu) rides the
same step, so `set voiceVolume 0.5` is instant too; a clone installed
before v1.50.0 needs one rerun of `setup-voice` to refresh its client
first — until then the knob is ignored, not broken. The espeak-ng robot
takes the same key; robot George, piper and a custom command don't (their
commands are frozen strings — turn those down in your mixer). The synthesis itself is still tuned by editing the `tts`
string's `--exag` and `--cfg` knobs (both up = snappier delivery) — those
re-render every line, so rerun `scripts/warm-voice` after.

A fresh clone starts with an empty cache, so *every* line would cost
those few seconds — including the reaction to a slap, which would land
well after the slap. So he doesn't leave it empty: the moment a clone
becomes his voice (a new clone, a switch in the picker, a shell start)
he renders the whole book into the cache in the background, silently —
10-20 minutes of GPU for the built-in book, once per voice; `voice` says
while it's running. He's usable meanwhile, and a voice warmed once stays
warm — the cache is keyed by the sample's contents, and the book is what
it keeps: the cache is capped (500 MB — `set voiceCacheMb` changes it,
`0` uncaps) and trims least-recently-*played* lines first, so the book,
re-touched on every play and every warm, outlives agent one-offs and the
renders of a sample you've since replaced. On every later start this is a
half-second check. The same job by
hand is `scripts/warm-voice`, for after changing the delivery knobs.
Agent lines are freshly written every
time, so the cache can never have them in advance — instead the plugin
pre-renders each batch the moment it arrives (they sit unspoken for a
while first), so with `ai` on and a clone set, those don't trail the
bubble either.

Or set `tts` to any shell command yourself.
It runs through `bash -c` and gets each line on stdin, so any engine that
reads text from stdin plugs in:

```bash
omarchy-shell costafot.clippy set tts "piper --model ~/voices/en_US-lessac-medium.onnx --output-raw | aplay -q -t raw -r 22050 -f S16_LE -c 1 -"
```

A custom command ignores the three tuning keys — it's one string, it gets
stdin, you own everything. And it survives the on/off switch: toggling the
voice off (menu row or `set tts false`) parks the command in `ttsSaved`,
and toggling back on restores it — you only get the espeak robot from
`tts true` when there's nothing parked (`set ttsSaved unset` to force
that). Whatever hides the bubble — a slap, a click, a
lock — kills the voice mid-word, whichever voice is set: the espeak robot
and the clones die with their process (speak-clone becomes aplay by play
time), and the commands `setup-voice` writes for kokoro and piper wrap the
pipeline in a trap so the kill reaches their aplay too. A hand-rolled
command like the example above may finish its sentence anyway — bash sits
on signals while a foreground pipeline runs. Borrow the wrap if that
bothers you: `trap 'kill $! 2>/dev/null' TERM; <your pipeline> & wait $!`.
The bubble's own timers wait their turn, though: a long line stays on
screen until he's actually finished saying it, and his last words — a
kill, a knockout, a fling — get said in full before he goes, instead of
cutting him off mid-rant.

A hand-set command shows up in the menu as "custom". If you'd rather it
had a name — or you keep a few engines around — make it a **drop-in**:
a file at `~/.local/share/clippy-voices/<name>` whose first
non-comment, non-blank line is the command (everything above can be `#`
notes to yourself). The filename becomes the voice: it appears in the
menu's Voice picker and in `voices` by name, and `useVoice <name>`
switches to it like any other. Same raw contract as `set tts` — one
shell command, line on stdin, the trap wrap above included if you want
clean cut-offs — just with a name on it:

```bash
mkdir -p ~/.local/share/clippy-voices
cat > ~/.local/share/clippy-voices/lessac <<'EOF'
# piper lessac, hand-installed
trap 'kill $! 2>/dev/null' TERM; piper --model ~/voices/en_US-lessac-medium.onnx --output-raw | aplay -q -t raw -r 22050 -f S16_LE -c 1 - & wait $!
EOF
omarchy-shell costafot.clippy useVoice lessac
```

Running `useVoice` right on the heels of writing the file is fine — he
rescans the dir and switches the moment the scan lands. Names are
`[A-Za-z0-9_.-]`, and `off`/`robot`/`espeak`/`george`/`custom`
are taken. Drop-ins are for plugging in an engine you already run — the
clone knobs and `warm-voice` don't apply to them (those are shaped
around `speak-clone`'s cache).

When he talks, everything else steps back. The moment a line starts,
every other audio stream dips to 80% of its volume — Spotify, a browser
tab, a game, whatever's playing — and comes back the instant he's done.
Voice assistants call this ducking; he does it by default because he
considers what he has to say more important than whatever you were
listening to. The `duck` setting is the fraction the others keep:
`set duck 0.5` halves them, `set duck false` (or the menu's "Duck other
audio" row) leaves your music alone. It works with any engine, the
espeak robot and the clones alike, only touches streams that were
already playing when the line started (so his own voice is never
ducked, and neither are his own sound effects), and volumes are
snapshotted and restored exactly — if the shell dies mid-sentence, the
next mount puts them back. A slap
reaction gets both, in order: the crack plays first (at `soundVolume`), and
the moment it ends he speaks the line — the voice never talks over its
own sound effect.

Once voices are on disk, switching between them takes no terminal: the
menu's Voice row is a picker showing everything installed — off, the espeak
robot, robot george, every clone you've made, every piper model, every
drop-in file — and a tap
switches instantly. Nothing in the menu ever downloads; installing a NEW
voice is always `scripts/setup-voice`. The same picker speaks IPC for your
agent: `voices` lists what's installed and where new ones come from,
`useVoice rubick` switches (and answers with the fix when it can't —
missing engine, no GPU, unknown name). Both are fed by
`scripts/voice-scan`, one JSON object of every voice on the machine, which
your agent can also run directly.
