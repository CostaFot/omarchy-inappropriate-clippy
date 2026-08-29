# omarchy-inappropriate-clippy — development history

The session-by-session journal from active development (2026-08-28/29),
moved out of AGENTS.md when the plugin was finalized. Entries are in the
order they were written and record what was true at the time, so later
entries supersede earlier ones — AGENTS.md states what is current; this
file holds the why: what Costa asked for, what was tried and dropped, and
how each change was verified.

## Snapshot (2026-08-28)

Working end to end on Costa's machine: walks (parking in the gaps between
the bar's widgets), talks on a timer, left/middle click, slap (with knockout
at 10), long-press drag, fling-to-death,
right-click menu (actions + clean/sounds/restless/size), bar icon → same menu
(dimmed + "Bring him back" when dead/hidden), kill → respawn with a comeback,
snooze, sleep while locked/idle/screens-off with a welcome-back line, top and
bottom bars, IPC, settings inline on the bar-layout entry.
On GitHub at the README install URL, v1.11.0 (no tag yet). Not on the
marketplace: see `PUBLISHING.md` for the flow, prior submissions and the
gap list.

Movement is a random brain (`decide()`): idle beats 10-30 s apart, each one
turns into a walk with probability `restless` (default 0.3), walks are mostly
short hops of 80-400 px with 1 in 5 a trek anywhere. Costa wanted him mostly
still — tune, don't make him busier. Targets avoid parking on the bar's
widgets — see the widget-avoidance paragraph below.

Verified by hand (2026-08-28): click-through with a real pointer, `clean`,
and `quotesFile` (object and bare-array shapes, all three keys, bad JSON and a
missing path both fall back to the built-in book). Quotes are two books,
`book` + `extraBook`, merged per key in `pool(key)` so FileView load order
doesn't matter — an earlier version leaked the file's `quotes` into
`lastWords`/`comeback`.

## Journal

Slapping done (2026-08-28, v1.2.0): middle-click and pointer-fling, sound,
shove + wobble, knockout after `slapsToKill` (10) inside six seconds.
Middle-click used to snooze; `slap: false` restores that. Costa supplied the
three sounds.

Dragging done (2026-08-28, v1.3.0): long-press (300 ms) and carry him along
the bar, with lines on the way and on landing. Flinging (v1.4.0): let go
while moving fast and he's thrown off the bar and dies, with a `flung` line
that lingers at the edge and a falling sound. Neither is pointer-testable
from a terminal (no ydotool) — `fling left|right` over IPC covers the
throw itself; Costa verifies the grab and the release speed by hand.

Bar icon done (2026-08-28, v1.1.0): opens the same `ClippyMenu`, and is the
way back after a kill/hide. The menu is the config surface, `shell.json` the
fallback. Keep every setting a flat scalar key with a default, a README table
row, and (if it's something a user would reach for) a row in the menu. Don't
build a `barWidget.schema` unprompted.

Agent lines done (2026-08-28, v1.5.0): `ai: true` swaps the random book for
lines from the user's default coding agent about what they are doing (see
`AgentBrain.qml` above). Verified live with claude on Costa's machine, and
opencode from the terminal. Costa's question was whether Clippy could "be
powered by the user's AI agent on omarchy"; the answer is yes, via each
agent's one-shot CLI mode, not via anything Omarchy provides. Agent lines
are marked in the bubble (accent border + sparkle, see `Bubble.qml`) so
you can tell which book a line came from without the journal.

Sleeping done (2026-08-28, v1.6.0): locked / idle-screensaver / DPMS-off
pauses everything, including agent calls, and a `welcomeBack` line greets
you after a minute or more away. Costa's question was whether he fires while
the screen is off or locked; he did, ~4 agent calls an hour all night with
`ai: true`. See the `asleep` bullet above. DPMS path tested by hand; lock
and idle paths not yet.

Widget avoidance done (2026-08-28, v1.7.0): when he picks where to walk he
parks in the gaps between bar widgets (`avoidWidgets`, default true).
`shell.bar.moduleSlots` holds every widget slot across all monitors;
`occupiedIntervals()` filters by `slotScreenName(slot)` == his screen and the
shell's own visibility test (a collapsed slot keeps visible=true but drops to
0x0), maps each with `mapToItem(null, 0, 0)` — bar-window x == screen x ==
stage x, both windows anchored full-width — pads 6 px and merges; `freeGaps()`
inverts that into the positions where the whole actor fits. Sampled lazily at
pick time, never from a binding: widget widths change without signals (tray
drawer, center peeks) and `moduleSlots` is reassigned per register/unregister,
so a binding would churn. Treks pick a width-weighted random gap; hops snap to
the nearest clear position, which only ever shortens them — he pulls up beside
the clock instead of onto it. (A first cut capped the snap at 120 px so a hop
would "stay a hop"; deep-in-cluster targets stood dirty and he parked on the
workspaces within minutes. Uncapped, the snap IS the hop aesthetic.) Standing
on a widget — drag-drop, a tray drawer growing under him — raises the next
beat's walk chance to 0.8 so he steps off on his own schedule; that is the
only busier-making change. Boot and revive placement prefer a gap too
(`randomSpot()`); drags, shoves and flings still land him anywhere. Null
`shell.bar`, a shell without `moduleSlots`, or no gap he fits in all fall
back to raw targets. Verified with `restless 1` and screenshot pairs against
`omarchy-shell shell debugBarGeometry` (same coordinate space).

Tombstone done (2026-08-28, v1.8.0): every death leaves a grave until the
respawn (see `Tombstone.qml` above). Costa's worry was covering the bar; the
answer is the input mask plus gap-snapping (it rarely even overlaps).
Verified over IPC: kill mid-bar, fling off the left edge (grave nudged
right of the workspaces/media cluster), two remounts while dead, respawn
fade. The thud/bounce on appear is not pointer-verifiable from a terminal;
it's a 450 ms OutBounce on the stone. The epitaph (v1.9.0) came right
after: Costa asked for "Here lies Clippy. You killed him, you fuck" on
click, and that line is in the book. He clicked the grave by hand and
confirmed; the IPC path and the grave-anchored bubble were verified with
screenshots.

Kill/slap counter done (2026-08-28, v1.10.0): `slapCount`/`killCount` in
`persisted`, a dim footer row in the menu, IPC `stats` (pluralized: "1
slap, 0 kills"). Costa asked for the simple half of the IDEAS.md pitch
only — show the numbers, no placeholder lines. Verified over IPC: slaps
and kills increment, a fling counts exactly one kill (it lands in
`finishDeath()` like every other death), two `set`-triggered remounts
keep the totals, and a shell restart resets them — that's the
PersistentProperties trade, same as `deadUntil`.

Voice done (2026-08-29, v1.11.0): optional TTS, `tts` false/true/command
(see the Voice bullet above). Costa's ask was stupid/funny by default and
pluggable — extensibility, not crashing — and explicitly **no TTS engine
installed** for the first pass: the whole thing was verified engine-less.
Missing espeak-ng → one journal warning per engine, lines still display,
nothing else changes; `cat >> file` as the engine collected exactly the
displayed lines across say/talk/slapped/flung/epitaph; `sleep 30` as the
engine proved the kills (replacement line, `hide`, `set tts false`, DPMS
sleep) — and caught two real bugs: `running = false` doesn't kill the
child, and `hide` didn't stop speech. Menu "Voice" row verified by
screenshot. espeak-ng was installed and heard on 2026-08-29 ("he sounds
like a robot" — Costa, delighted); the `-v en+m3 -s 155 -p 45` tuning is
approved as-is.

Voice tuning done (2026-08-29, v1.12.0): `ttsVoice`/`ttsSpeed`/`ttsPitch`
for the built-in espeak-ng path (see the Voice bullet). Costa's ask was
"anyone can use the voice they prefer", agent-pluggable — the answer is the
same `set` surface everything else uses, one key per knob, no menu picker
(same call as `aiModel`: the names are engine-specific). Candidate defaults
were auditioned out loud (Tweaky, UniRobot, helium m3, HL announcer, then a
deep "sportscaster" batch — espeak's low-pitch register sounds terrible);
Costa kept `en+m3 -s 155 -p 45` as shipped. The voice hunt for his box ran
the same day: fish.audio and ElevenLabs were rejected mid-flight ("we do not
want cloud calls"), piper auditions crowned `en_US-ryan-high` for about ten
minutes, then "a female oniichan stupid voice, not too high" landed on
kokoro `af_heart` — until "the initial voice should be a fkin male dork"
crowned `am_adam` from a five-male audition as both the blessed default
and Costa's own `tts` — then "can we make the default voice funnier" ran
through C-3PO, "deeper", "more distorted, robotic", "higher", and settled
on ring-mod George: `bm_george` through ffmpeg (`asetrate` +15%,
`tremolo f=45`, `acrusher bits=6`, 250–3400 band). Bare setup-voice gets
that chain; a named voice comes through unprocessed; `say.py` phonemizes
`b*` voices as en-gb (George read American before that).
`scripts/setup-voice` ships the whole path: bare = the blessed robot
George (venv + ~340 MB in
`~/.local/share/kokoro-tts`, a generated `say.py` reading stdin), a name
with a dash = that piper catalog voice (`~/.local/share/piper-{tts,voices}`);
both end in `set tts` on a stdin→aplay pipeline (aplay, not pw-play —
sndfile can't read raw audio from a pipe; bit us) with a spoken hello
first. ~1.8 s per line for kokoro, model load included. Nothing is bundled
in the repo — engines are 60-340 MB, so the script downloads on demand.

Voice cloning done (2026-08-29, v1.13.0): `scripts/setup-voice --clone
<sample> [name]` gives him any voice from a 10-20 s sample. Costa's pick is
Rubick (Dota 2), cloned from a YouTube compilation he supplied; the approved
take is exaggeration 0.5, cfg 0.5, reference = seconds 2.6–22.6 of the rip,
and that exact wav is `~/.local/share/chatterbox-tts/voices/rubick.wav` —
don't regenerate it, a re-cut sounds subtly different. Engine is chatterbox
on CUDA in a uv venv (`--python 3.12`: system 3.14 has no torch wheels and
pip backtracks forever — use uv; `setuptools<81` pinned or perth's
watermarker import dies on missing pkg_resources and `from_pretrained`
throws "'NoneType' object is not callable"). Per-line spawn would reload
2 GB onto the GPU, so `speak-clone` (client, stdlib python3) talks to
`daemon.py` (venv python) over `$XDG_RUNTIME_DIR/clippy-voice.sock`; the
daemon self-starts on demand, exits after 15 idle minutes to free ~4 GB
VRAM, and lines are cached in `~/.cache/clippy-voice` by (ref, knobs,
text) — repeats instant, fresh line ~5 s warm, ~25 s cold (the bubble's
SIGTERM just skips that line's audio). TARS (Interstellar) was auditioned
and dropped — movie-scene audio is too dirty next to a voice-line
compilation. Explicitness (Costa: "be explicit in the instructions on the
UI and agent"): the menu Voice row reads "Voice · custom" whenever a
command string is set, IPC `voice` answers off with the setup-voice
pointer and appends it to the espeak-ready reply, and the README documents
every mode. ElevenLabs and fish.audio were explored and rejected mid-hunt:
no cloud calls, Costa's rule. Verdict after hearing it live: "it's fun.
not amazing" — the clone carries the accent and cadence, not the game's
filter. Don't oversell it and don't chase clone quality without a new ask.

C-3PO cloned (2026-08-29): the current voice on Costa's box, replacing the
espeak robot (`tts` was back to `true` when the ask came; Rubick's wav still
stands). The blessed default was already the C-3PO homage ("a fussy English
droid"), so the real thing was the obvious first clone. Source is a
voice-line compilation Costa supplied (youtu.be/Z_OjTojCNm0, audio rip);
the approved take is the Tatooine monologue run at seconds 26.9–46.9
("How did we get into this mess… made to suffer… what a desolate place"),
picked by transcribing the clip (throwaway faster-whisper venv — every line
in it is 3PO, that window had the quietest inter-line floor at −22 dB),
normalized +10 dB. The exact wav is
`~/.local/share/chatterbox-tts/voices/c3po.wav` — same rule as Rubick,
don't regenerate it. Verdict: "it sounds fine" — the clone carries Daniels'
accent and fret, not the metallic sheen; a gentle ffmpeg chain appended to
the `tts` string is the known fix if that ever gets asked for. Knobs
settled at exaggeration 0.6, cfg 0.7 (up from the 0.5/0.5 defaults):
Costa found the delivery slow, and the reference is 3PO at his weariest —
that window was picked for cleanliness, and the clone copies its cadence.
Both knobs push pacing faster; a knob change also re-keys the line cache,
so everything renders fresh once. A snappier fallback reference sits at
`voices/c3po-fast.wav` (36.4–47.5 s, the "had enough of you… malfunctioning
little twerp" run) — unused, swap `--ref` to it if the pace bugs him again.
The ~2 s to first audio on a novel line is warm chatterbox synthesis time,
not fixable without streaming; pre-warming the cache over the book was
offered and declined ("nah"). Nothing of this lands in the repo —
reference and setting are home-dir state.

Clone pitch knob done (2026-08-29, v1.13.1): `--pitch` on `speak-clone`
(<1 deeper, >1 lighter), an ffmpeg `aresample=48000,asetrate=48000*P,
aresample=48000,atempo=1/P` chain after synthesis — tempo preserved (Costa
already found him slow), derived from the raw cache into `{key}-p{P}.wav`
so a pitch change never touches the GPU, plays the raw file if ffmpeg
fails. Same client in the home dir and in the `setup-voice` heredoc, plus
a README tuning paragraph. The session started as "clippy has a robotic
voice, is this normal?": `tts` in shell.json had reverted to bare `true`
(espeak) with the whole clone stack intact — prime suspect is the menu's
Voice row, which toggles to `true` and forgets the custom command; still
an open papercut, offered but not asked for. The pitch audition (0.85 →
0.9 → 0.94 on C-3PO) ended sideways with "more rubick": **the current
voice on Costa's box is the Rubick clone** (`--exag 0.5 --cfg 0.5`, no
pitch flag — Rubick is deep enough on his own), C-3PO's wavs stand ready
but unused.

Cache warming done (2026-08-29, v1.14.0): `scripts/warm-voice` renders the
whole book into the clone cache, silently, over the daemon socket — no
aplay, so nothing plays while it runs. It reads the live `tts` string for
speak-clone/--ref/--exag/--cfg (bails on anything else), merges
`quotesFile`, respects `clean`, skips `{templated}` lines, skips existing
cache files, and self-starts the daemon like speak-clone does. Born from
"rubick talking is 2 seconds slow": switching --ref invalidated all 55
C-3PO-keyed lines, so every line — slap reactions worst of all, they
trail the hit by 2 s — was a first take. While a warm runs, live lines
queue behind the batch and the bubble's SIGTERM can skip them ("no sound
tho" — expected, self-heals when the warm finishes). Pitch variants are
not pre-derived on purpose: the ffmpeg step is milliseconds. Costa's box
was warmed for Rubick 0.5/0.5 the same evening.

Agent-line warming done (2026-08-29, v1.15.0): with `ai` on and a
speak-clone `tts`, each fresh batch of agent lines is pre-rendered into
the clone cache the moment it lands, so agent lines stop trailing the
bubble by the ~2 s a first take costs — they sit in `AgentBrain` up to
20 min before `take()` uses one, and that idle window is free GPU time.
Born from "the AI tts is lagging": the book warm (v1.14.0) had made every
book line instant, and the agent lines were exactly what was left.
Mechanics: `warm-voice --lines <line>...` warms explicit strings instead
of the book (same tts parse, cache key, `{`-skip, daemon self-start);
`AgentBrain` emits `linesArrived(lines)` on a successful batch; the root's
`warmAgentLines()` gates on `ttsOn` + `"speak-clone" in ttsSetting` and
runs `warmProc` fire-and-forget, parking overlap in `warmQueued` (the
ttsQueued shape). No new setting keys. A side fix in `warm-voice`:
`get` prints string values JSON-quoted, and the trailing `"` broke the
`--cfg` float parse — `setting()` now strips the quotes. Verified live:
`--lines` renders/skips/caches from the terminal, and a real claude batch
of 5 produced 5 cache wavs within ~15 s of `set ai true`, journal clean.
Session note: mid-work Costa toggled both `tts` and `ai` to false from
the menu (the Voice row still eats the custom command — open papercut);
both were left false as he set them, and re-enabling is
`set ai true` + `set tts 'exec …/speak-clone --ref …/rubick.wav
--exag 0.5 --cfg 0.5'`.

Voice toggle keeps the command (2026-08-29, v1.16.0): the menu's Voice row
(and IPC `set tts true|false`) used to write bare booleans, eating a custom
`tts` command — it took Costa's clone string three times in one day. Now
`setVoiceEnabled(on)` stashes a command string into a new `ttsSaved` key on
turn-off and restores it on turn-on; `tts true` only means espeak when
nothing is parked (`set ttsSaved unset` is the escape hatch), `set tts
unset` resets tts but keeps the stash, and an explicit command string
clears it. Both keys land in one `setSettings(map)` write (new; setSetting
delegates to it) — two sequential writes would race the remount. The menu
row reads "Voice · custom" while off-with-stash. Agent-first replies grew
with it: `set tts <speak-clone cmd>` answers with the rerun-warm-voice
reminder when the string changed, `voice` while a clone is live names the
voices dir / setup-voice / warm-voice, and while off it names the parked
command. Born from the "is it fully configurable" pre-publish audit.
Verified over IPC end to end (set clone → off → stash → true → restore,
unset keeps the stash); the menu path shares setVoiceEnabled so only the
label was eyeballed. PUBLISHING.md's version reference was refreshed at
the same time.

Discoverability papercuts closed (2026-08-29, v1.17.0): the two gaps from
the new-user audit. IPC `help` lists every verb one per line with a
half-line description and ends with the README path — the blind-agent
bootstrap quickshell's "Function not found" never gave (it also went into
the README's scripting block, first line). The menu's `Entry` grew an
optional `hint` (dim second line, fontSize−2, only sized when non-empty)
and the Voice row uses it — "better voices: scripts/setup-voice in the
plugin dir" — shown only in the `!needs && !custom` state: the espeak-only
audience that was stranded; engine-missing and custom/stashed users keep
their existing labels, no hint. No new settings keys. Verified live after
a shell restart: `help` output from the terminal, journal clean, menu
screenshot shows the hint under "Voice". PUBLISHING.md's version reference
refreshed. Note the dev symlink is back in place (the new-user clone below
is history) and `ai: true` with claude lines was live on the box during
the check.

Rubick ships as the default voice (2026-08-29, v1.18.0): bare `setup-voice`
now picks by hardware — an NVIDIA GPU with ≥6 GB total VRAM (`gpu_ok()`:
`nvidia-smi --query-gpu=memory.total`, biggest card wins) gets the shipped
Rubick clone, anything less falls back to robot George with the reason
printed, and `--robot` is the bypass Costa asked for ("ship it to the
machines who are powerful enough, but it should be something that is
bypassed"). The approved reference wav is now IN the repo at
`assets/voices/rubick.wav` (940 KB, s16le mono 24 kHz, exactly 20 s,
byte-identical to `~/.local/share/chatterbox-tts/voices/rubick.wav`) — the
shipped path `cp`s it verbatim instead of the `--clone` ffmpeg re-encode,
because a re-encode of the approved take sounds subtly different (same rule
as always: never regenerate it). Knobs stay 0.5/0.5 in the written `tts`
string. README: bare-mode paragraph rewritten, Valve credit inline ("Dota 2
audio, © Valve"), the `--clone` example renamed to glados since rubick is
no longer hypothetical, and a bridge line noting the shipped voice pays the
same chatterbox costs. Verified live on Costa's box: bare run detected the
GPU, copied the wav (cmp-identical after), spoke the hello and set the same
tts string; no-GPU and `--robot` branches exercised with stubbed
`nvidia-smi`/`omarchy-shell` binaries so the live setting stayed put. The
plugin's literal default is still `tts: false` — engines download on
demand, only the 940 KB sample rides in the repo. Session context: the day
started with "the default voice sucks" — the new-user wipe had left bare
espeak `tts: true`; the Rubick rig was restored first (set tts + warm-voice,
all 154 book lines were still cached), `ai` was left off as found.

Voice picker + agent voice surface done (2026-08-29, v1.19.0): Costa's ask
was a UI to *select* voices and "make this app amazing for an agent". The
split that shipped: switching lives in the plugin (instant, a `set tts`
write), installing stays with setup-voice (a menu tap must never start a
2 GB download). `scripts/voice-scan` (new) prints one JSON object of every
voice on disk — espeak/GPU/kokoro presence, clone wavs, piper models with
their sample rates — and feeds `voiceInv` via a Process (mount, tts
changes, menu open). On top of it: `currentVoiceId` names the live tts
value (off/robot/george/<clone>/<piper>/custom; clones keep their name
through knob changes via the --ref regex), `voiceOptions` is the picker
list (clones only when the GPU is there; "custom" appears when a hand-set
command is live or parked), and `applyVoice(name)` is the one resolver
behind both the menu and IPC — it rebuilds the exact command strings
setup-voice writes (georgeCmd/cloneCmd/piperCmd; drift just means the
picker says "custom") and parks an unrecognized custom command in
`ttsSaved` before overwriting, the v1.16.0 no-eating rule. The menu's
Voice toggle row became a `Choice` chips row (off · robot · george ·
rubick · …, the Walks/Size pattern) plus a dim setup-voice hint shown only
when nothing better than the robot is installed; ttsNeedsEngine moved into
the group label. IPC: `voices` (active + installed + how to install more +
the raw `set tts` contract) and `useVoice <name>` (agent-first replies:
"ok — the rubick clone; …warm-voice…", "george isn't installed — run
scripts/setup-voice --robot…", "unknown voice…"), both in `help`. No new
settings keys. Verified live on the box (espeak+kokoro+3 clones+1 piper):
switch to every kind byte-identical to setup-voice's strings, the
custom→stash→restore round trip, off/unknown/already replies, menu chips
by screenshot; the chip tap path shares applyVoice with the verified IPC
path. Right after shipping, Costa found only rubick answered
promptly (kokoro reloads its model per line, the c3po clones had a cold
cache; both synthesized fine from the terminal) and asked for the rest to
go — "less options. less to debug". They are PARKED, not deleted:
`~/.local/share/chatterbox-tts/voices-parked/` holds the approved c3po +
c3po-fast takes (never regenerate — move back to voices/ to re-offer),
`piper-voices-parked` and `kokoro-tts-parked` sit next to their original
dirs. The picker is inventory-driven, so moving anything back restores its
chip. His box now offers off · robot · rubick, rubick active.

New-user simulation (2026-08-29): the box left the dev loop — plugin
disabled, symlink removed, then a real `omarchy plugin add
https://github.com/CostaFot/omarchy-inappropriate-clippy --enable --yes`
clone (main == origin/main, so the same v1.16.0 code) and an `omarchy
restart shell` to zero `persisted`. The disable wiped Costa's inline
settings; the entry now carries only `tts: true` from his own menu click
(espeak robot), and restoring the dev rig is the symlink plus `set ai
true`, `set aiModel claude-sonnet-5`, `set tts 'exec
~/.local/share/chatterbox-tts/speak-clone --ref
~/.local/share/chatterbox-tts/voices/rubick.wav --exag 0.5 --cfg 0.5'`.
So the "current voice on Costa's box" notes above describe the rig, not
this moment. Note the installed dir is a real clone now — edits there
hot-reload but are NOT the checkout; dev work goes back through the
symlink. The audit itself: TTS is one click from the menu, the README
held up end to end, and two papercuts surfaced (offered, not asked for):
the menu never advertises `setup-voice` while espeak-ng is installed
(the nudge only shows when it's missing), and there is no `help` IPC
verb — a blind agent gets "Function not found" and must find the README
to learn the methods.

Audio ducking done (2026-08-29, v1.20.0): `duck` lowers everything else
while he talks, the way voice assistants do (Costa: "lower the volume of
what is currently playing so we can talk with agent", OpenWhispr named as
the reference). See the Ducking bullet above for the whole mechanism; the
short version is a pre-spawn snapshot of `pactl` sink-input volumes in
`scripts/duck` (restore-exact raw values, flock, idempotent), `startTts`
split into duck-then-`launchTts`, restore on every speech end, crash
healing at mount. pipewire-pulse never implemented PulseAudio's
`module-role-ducking`, so manual per-stream is the right primitive; the
snapshot-before-spawn trick is what makes it engine-agnostic. Verified
live on Costa's box: script round trip from the terminal (5 real streams
ducked to 30 % and restored, raw-volume fix caught by a +0.12 dB stream),
then end to end through the plugin — a pw-play tone plus six other
streams at 30 % during a spoken line, all back at 100 % after, state file
appearing and vanishing on cue, journal clean. `duck true` was left set
on his box (it's what he asked for); the voice there was bare espeak at
the time. Install-dir reality check: the plugin dir is a real v1.18 clone
carrying the v1.19 work as uncommitted changes (the v1.17 note saying the
dev symlink was back is stale) — the duck files were copied in by hand
for the live test, so dev edits in ~/Work still need that copy or a
restored symlink to reach the shell.

Agent-first ai keys (2026-08-29, v1.20.1): `set aiAgent`/`set aiModel` while
`ai` is off used to answer a bare "ok" — the one config surface that broke
the "ok — but" pattern the tts keys follow. Now both reply "ok — but ai is
off, so there are no agent lines to apply it to; set ai true first" (an
`unset` stays a plain ok). Found by an agent-exposure audit over IPC on a
fresh default install; the audit also confirmed the rest holds: `help`
lists every verb, `settings`/`get`/`set`/unknown-key replies, the duck and
tts warnings (both apparent misses were Costa switching the voice on from
the menu mid-audit), and out-of-range numbers like `restless 5` clamp at
the property binding. Same session context: the box is a real GitHub
clone of v1.20.0 again (the new-user tryout Costa asked for), so this fix
was hand-copied into the installed dir; Costa re-rigged rubick from the
picker himself and `duck true` was restored.

Poverty notice (2026-08-29, v1.20.2): setup-voice's no-GPU fallback line now
reads "no NVIDIA GPU with 6 GB to spare — you're poor. Get more RAM. Until
then, the robot it is" — Costa's ask verbatim ("tell them they are poor and
they need to get more RAM"; yes it's VRAM, the wrongness is part of the
joke). One echo, no behavior change.

Always-duck (2026-08-29, v1.21.0): the `duck` setting is gone — ducking is
always on at 30 % ("do not give option to duck other audio. ALWAYS duck
other audio", "we need to make it stupid simple"). Removed: the settings
key, the menu row, the set-reply, `duckSetting`/`duckEnabled`; `duckFactor`
is a constant 0.3, `startTts` always ducks, `voice` states it. README's
duck paragraph rewritten as a statement of character ("he considers what he
has to say more important than whatever you were listening to"). The same
session found why Costa heard nothing after enabling rubick on the fresh
install: PipeWire stream-restore had memorized 30 % for aplay — an aplay
stream had ended mid-duck during the v1.20 terminal round-trip tests, the
restore never reached it, and every later clone line started at 30 % of a
50 % sink (~−49 dB, silent for all practical purposes) with zero errors
anywhere. Diagnosed by catching the live sink-input at "Volume: mono: 30%";
fixed by pinning a live aplay stream to 100 % (which rewrites the memory).
That poisoning mode is now documented in the Ducking bullet — it can hit
any app that closes mid-duck, and there is no snapshot-side fix since a
dead stream can't be volume-set.

The poisoning turned out self-inflicted and compounding once ducking was
always-on: with back-to-back lines, each new line's snapshot caught the
PREVIOUS line's dying aplay sink-input (PipeWire teardown is async),
ducked it, lost it, and stream-restore memorized the product — 30 % → 9 %
→ ~1 %, which is exactly the "it's like 1% sound" Costa reported minutes
after the first heal (his autoduck plugin was suspected and cleared: it
only mutes browser streams, and the fingerprint was our 0.3 factor).
The fix is `duckRelease`, a 1 s Timer between speech end and `duckStop()`:
`startTts` stops it, so a line inside the window keeps the duck and
consecutive lines share one duck cycle — no re-snapshot, and by the time
a future snapshot runs the last stream is long gone. Both speech-end
paths (`ttsProc.onExited` queue-empty, and the duck's line-cancelled
branch) go through the timer. Healing a poisoned app is pinning one of
its live streams: play anything via aplay, `pactl set-sink-input-volume
<id> 100%`. Verified: three rapid `talk`s then a fresh aplay stream
starts at 100 %, duck state file clean, journal clean.

Drag chatter untangled (2026-08-29, v1.21.1): "when i drag the icon, the
voice messages interfere with each other" — overlapping voices during a
drag. Root cause was not the QML (one ttsProc, replacement kills + queues,
that held): speak-clone ended in `subprocess.run(["aplay", ...])`, so the
plugin's SIGTERM killed the python client and ORPHANED the aplay child,
which played the old line to the end while the next line's aplay started
on top — dragged lines every 3-6 s against 3-5 s Rubick lines stacked two
or three voices. Fix: `os.execvp("aplay", ...)` as speak-clone's last act,
so the process the plugin holds IS aplay by play time and the kill stops
the audio (same trick as the espeak `exec` prefix). Patched in the
setup-voice heredoc, the installed plugin's copy, and the live
~/.local/share/chatterbox-tts/speak-clone. Costa's "i guess we put more
time between them?" also honored: dragTalk is 5-9 s (was 3-6). Verified:
terminal TERM mid-line leaves no aplay, and back-to-back `talk`s over the
plugin never showed 2 concurrent aplays, journal and duck state clean.
The kokoro/piper half of the papercut was fixed right after (v1.21.2,
below).

Pipeline voices cut too (2026-08-29, v1.21.2): the kokoro and piper
command strings — setup-voice's generated CMDs and the matching
georgeCmd/piperCmd builders in Clippy.qml, kept byte-identical — now wrap
the pipeline in `trap 'kill $! 2>/dev/null' TERM; <pipeline> & wait $!`.
Why that shape: bash defers trap handling while a foreground job runs, so
a TERM on a bare pipeline waited out the whole line; backgrounded, `wait`
processes the trap at once and `$!` (the pipeline's last element) IS
aplay, so the kill stops the audio and the producer dies on its next
write via SIGPIPE. Stdin still reaches a backgrounded pipeline when it is
a pipe (verified — bash only nulls async stdin for terminals). Verified
live with the real piper venv against the parked ryan model: cut mid-line
kills aplay instantly, a clean run exits 0, no survivors; george/piper
strings byte-compared against setup-voice's build. A user whose
shell.json still carries an OLD unwrapped string just sees the picker
call it "custom" until they re-tap the chip — documented drift, nothing
breaks. README's mid-word paragraph now covers all three engine shapes
and hands hand-rolled pipelines the same wrap.

Slap keeps its SFX (2026-08-29, v1.22.0): "since we got voice, it mutes
the sound effects … i think it's funnier with SFX". Two causes, two
fixes. (1) Slapped lines are silent now: `say()` grew a 4th `silent` arg
→ `bubble.silent` (a plain property on the Bubble instance; the voice
watches the bubble, so the flag must ride on it), `syncSpeech` treats a
silent bubble as stop-speaking — the line shows, an in-flight voice line
is still cut, no duck fires. Knockout/fling deaths still speak; Costa
scoped the ask to the slap. (2) `scripts/duck` skips sink-inputs with
`node.name = "quickshell"` — our own SoundEffects were being ducked to
30 % under the voice line AND, worse, the short-lived SFX stream died
mid-duck at some point and PipeWire stream-restore memorized quickshell
at a permanent 30 % (caught live: the stream sat at 30 % with no duck
active; healed by pinning it to 100 %, which slaps now confirmed audible
— "wait slap is playng sorry"). The awk buffers each entry and flushes at
the next `Sink Input` line because node.name sits in Properties, after
Volume. Verified over IPC: slap → no aplay, no duck state, quickshell
stream untouched; talk → Brave ducked 30 % and restored exactly,
quickshell held 100 %, duck state clean, journal clean. Files hand-copied
to the installed clone (still a real clone, not the symlink).

Long lines finish (2026-08-29, v1.22.1): "if the line is too long, clippy
will cut off when saying it" — `bubbleTimer` runs at 450 ms/word (min
4 s), and its `hideBubble()` cuts the voice (that's the deliberate-hide
contract), but a clone pays ~2 s synthesis on a novel line (~11 s cold)
and speaks slower than 450 ms/word, so long lines lost the race and died
mid-sentence. Fix: the timeout — and ONLY the timeout — now waits for
the voice: `bubbleTimer.onTriggered` checks `speakingThisBubble()` (ttsOn,
not silent, `ttsLine === bubble.text`, and engine running / replacement
queued / duck snapshot in flight — `ttsLine` alone is stale after a
normal exit) and re-arms itself in 500 ms beats instead of hiding, capped
at 60 holds (30 s past the word timeout) so a hung engine can't pin him
in `talking` forever; the two arm sites (`say()`, `epitaph()`) zero
`bubbleTimer.holds`. Every deliberate hide — click dismissal, `shutUp`,
sleep, slap replacement — still cuts mid-word, untouched. No new
settings. Verified live with the Rubick clone: a 38-word novel line
(old timeout 17.1 s) took ~11.5 s synthesis + ~10.5 s playback, state
held `talking` the whole way and flipped to idle within half a second
of aplay exiting; short cached lines hide on the old schedule (the
predicate is false at trigger time); journal clean. Hand-copied to the
installed clone with the manifest bump.

First hello (2026-08-29, v1.23.0): Costa's ask — 'the very first message
should be something like "Welcome you fuck. Make sure you set me up in
options. Ask your agent eh?"'. On the very first boot after an install he
says a `firstRun` line (new quote key, in `quoteKeys` and quotes.json)
pointing at the right-click menu and the agent, then writes `greeted: true`
inline on the shell.json entry (new settings key, default false, README
row) — inline, not `persisted`, so a shell restart doesn't repeat it but
a reinstall (which strips the entry) does; `set greeted unset` re-arms it.
Mechanics: `greetTimer` (2 s, so the window is mapped) → `firstHello()`,
armed from `maybeBoot()`'s tail and from `wakeUp()`'s idle branch (where
it takes precedence over the welcomeBack line — fresh install while
locked). The pick is deterministic, not random: `pool("firstRun")[0]`,
so the nsfw line IS the greeting and under `clean` the clean variant
steps up as the first survivor. This session was the new-user simulation:
`omarchy plugin remove --yes` (also strips the inline settings — the
rubick/ai rig, noted in the session for restore), a real `omarchy plugin
add <github url> --enable --yes` clone of v1.22.1, `omarchy restart
shell` to zero `persisted`. Verified live on that clean install:
greeting on screen by screenshot (both variants — the first cut was
`randomQuoteFrom` and the camera caught the clean line, which is what
prompted the deterministic pick), `greeted: true` landing inline, a
restart with it set stays idle, journal clean. Hand-copied to the
installed clone (a real clone again — dev edits need the copy or the
symlink); repo left uncommitted.

The graveyard (2026-08-29, v1.24.0): the IDEAS.md global leaderboard, built.
Two halves. Server: new repo CostaFot/clippy-leaderboard
(~/Work/clippy-leaderboard) — Flask + psycopg2 + gunicorn cloned from
claps-api's shape (Costa's existing tiny-counter API; same Procfile, same
db() contextmanager, CREATE TABLE at boot), deployed as Railway project
`clippy-leaderboard` (Postgres via `railway add --database postgres`,
`DATABASE_URL=${{Postgres.DATABASE_URL}}` set BEFORE connecting the repo so
the first build has it, domain clippy-leaderboard-production.up.railway.app).
POST /bump takes {handle, kills, slaps} DELTAS: handles are CLAIM-FREE
(no cookies, no accounts, anti-cheat an explicit non-goal — collisions
merge, "every score was self-reported murder to begin with"), lowercased,
`[a-z0-9_.-]{1,24}`, deltas clamped 0-50 (hygiene, not anti-cheat), and the
reply carries the new totals + rank + total so the client never needs a
second GET. The one gate, Costa's ask ("basic post reqs stuff spam"): /bump
answers only a `costafot.clippy/*` User-Agent, else 403 "you are not a
paperclip" — spoofable by design, a doorman not a lock; an API key was
discussed twice and rejected as theater (anything baked into a public repo
is public; rotation would break every install). GET / is the page:
CSS-only headstones, one per handle, sqrt-scaled by kills
(0.55 + 0.45·sqrt(k)/sqrt(max), so a grinder can't flatten the page),
slaps tiebreak, rank badges on the top 3, "still breathing. coward." on
0-kill stones, top 100 + "…and N more, rotting quietly", empty board says
"Nobody has died yet. Disgraceful. Be the first." GET /api/scores?limit= and
/api/score/<handle> round out the API. Client (Clippy.qml): `leaderboard`
settings key — "" default, a handle joins; OPT-IN was the hard requirement,
nothing leaves the machine until a handle is set, and the README's "The
graveyard" section discloses exactly what does (handle + two small deltas,
nothing else) in the AI section's tone. bumpLeaderboard(0,1)/(1,0) directly
after the two persisted counter bumps in slap()/finishDeath(); the flush is
the duckProc park-don't-clobber idiom (deltas accumulate while a POST is in
flight, so a 10-slap beating coalesces into few POSTs), a failure re-adds
the sent deltas and backs off 30 s·2ⁿ capped ~16 min, lbRetry re-arms
through `asleep` instead of dropping (no curl into a lock screen, but held
deltas still flush after a long lock). Joining (or a remount while joined,
from maybeBoot) fires a zero-delta bump — legal on the server, creates the
stone immediately and fills lbCache with the rank for free. lbProbe covers
a missing curl (the espeak lesson: a Process that can't start never fires
onExited, so it must be probed and surfaced). Pending deltas die with the
shell — the tally's own documented trade. IPC: `leaderboard` verb
(off-with-join-instructions / "posting as X: #4 of 31 with …" + pending /
unreachable / no-curl suffixes, the `voice` shape), `set leaderboard`
replies (bad handle answers with the rule, a boolean is rejected as "a
handle, not a boolean", unset says the grave keeps what was posted), a
`help` line; the menu footer appends " · #4 as testcosta" from lbCache (no
settings row — free-text handle, no text input widget in the menu; IPC and
agent only, like aiModel). The curl sends `-A costafot.clippy/<manifest
version>`. Verified: the server end to end locally against a throwaway
docker Postgres (all four routes, case-folding, clamp 9999→50/-3→0,
400/404, UA 403, page renders and scales — note `app.run()` hangs under
this box's sandbox, `make_server` works; production is gunicorn, doesn't
care), and the plugin's FAILURE path live on the box: join while the
server is down → one journal warn, deltas held (including a real slap of
Costa's), backoff armed, verb honest about all of it. The happy path
followed once Railway's incident 8GL2R2U5 (deployment-init backlog, all
regions — it held both deploys QUEUED for ~75 min) drained: boot-time join
fills lbCache with the rank at mount, 3 rapid `slap` + a `kill` over IPC
landed exactly (server and verb both said #1, 1 kill, 3 slaps), the page
scaled testcosta's stone to 1.0 against two 0.55 flat-liners, journal
clean. The UA doorman verified in production: no-UA and Mozilla POSTs got
the 403, the plugin UA passed, / and /api stayed open. Two fixes came out
of the outage window: lbProc now collects stderr into the failure warn
(exit 22 alone named nothing — the whole "plugin curl fails, terminal curl
works" scare was just the edge being down/mid-swap, proven by running the
identical command under systemd-run --user), and wakeUp() re-runs
flushLeaderboard(true) — placed BEFORE the dead branch, kills matter to
the graveyard, moods don't — because a remount while locked skips
maybeBoot's flush (asleep returns first) and drops the old instance's
retry timer, leaving the leaderboard dormant till the next slap; caught
live when a `set` bounce remounted into Costa's locked session. Cleanup:
the test rows (testcosta, uatest, envtest) were DELETEd over `railway ssh
--service Postgres -- psql` (the DB is internal-only, no public proxy —
keep it that way) and the handle unset, so the board ships empty and Costa
picks his real handle himself. Files hand-copied to the installed clone.
Discoverability ("how does a user know to opt in?"): a dim menu-footer
hint under the tally — "graveyard: he can die publicly — set leaderboard
<name> (ask your agent)" — shown only while `leaderboard` is unset, the
Voice-hint stranded-audience rule; the menu can't take free text, so it
points at the agent/terminal. Verified by screenshot.

Last words finish too (2026-08-29, v1.24.1): "killing clippy the voice is
cut of a bit before clippy goes away" — the v1.22.1 wait-for-voice hold
covered `bubbleTimer` only; the two death timers still hid the bubble on
fixed clocks, and hiding the bubble is the deliberate-cut contract. So a
kill's lastWords died at `dieTimer`'s 2500 ms (the Rubick clone hadn't
finished a cached line by then, let alone a ~2 s novel-line synthesis)
and the flung line at `flingAnim`+`flingHold`'s ~2.1-3.1 s. Fix: both
timers grew the same `speakingThisBubble()` re-arm — 500 ms beats, 60-hold
cap so a hung engine can't make him unkillable — before their hide;
`kill()` zeroes `dieTimer.holds`, `flingOff()` zeroes `flingHold.holds`
AND restores `flingHold.interval = flingHoldMs`, because the imperative
re-arm overwrites that declarative binding and the next fling would have
lingered 500 ms instead of 1500. Every deliberate hide still cuts
mid-word; the fling's linger/echo run after the line ends, unchanged.
IDEAS.md was also pruned of shipped entries the same session (c914230).
Verified live over IPC with the Rubick clone: kill held `dying` ~3.5 s
until aplay exited on its own then went dead via GoodBye; fling held
through the line then ran hold+echo to `dead`; journal clean; Costa
confirmed by ear ("worked"). README: the mid-word paragraph's hide list
drops "his death" and the waits-its-turn sentence now covers last words.
Hand-copied to the installed clone.

Clone tempo + pitch as settings (2026-08-29, v1.25.0): "can we speed up the
voice a little" grew into Costa's "make the speed and pitch configurable —
fun variants for free". Two new keys, `cloneTempo`/`clonePitch` (factors
around 1, clamped 0.5–2), bend any speak-clone voice. speak-clone grew
`--tempo` next to `--pitch`: asetrate*P shifts pitch AND tempo together,
one atempo of T/P lands the final tempo on T (T==P needs no atempo — that
IS the chipmunk chain — and atempo's 0.5 floor is handled by chaining 0.5
stages for extreme slowdowns); derived file `{key}[-pP][-tT].wav`, the
pitch-only name unchanged so old derivatives are reused. The knobs ride at
LAUNCH time — `launchTts()` appends `--tempo/--pitch` when either ≠ 1 and
the command contains "speak-clone" (`cloneKnobsApply`) — never into the
stored tts string, so the picker keeps naming the voice, setup-voice's
strings stay canonical, and a hand-set command already carrying the flags
is overridden (argparse keeps the last occurrence). Derivation is ffmpeg
on the cached raw take: auditioning is instant and warm-voice never needs
a rerun (agent-line warms render raw only; the bend happens at speak
time). Agent-first replies: `set` on the keys answers heard-on-next-line /
heard-once-tts-is-back-on (clone parked in ttsSaved) / "the active voice
isn't a clone" (pointing espeak users at ttsSpeed/ttsPitch), the espeak
tuning reply now points clone users here, and `voice` appends "— bent by
cloneTempo X / clonePitch Y" when non-default. No menu row — free numbers,
the aiModel rule. Verified: stub-seeded cache derivations for tempo-only,
both, pitch-only and the extreme 0.5+2.0 combo at exact expected
durations, then live over IPC — `set cloneTempo 1.1`, a real agent line
derived `{key}-t1.1.wav` at exactly raw/1.1 and played it, journal clean.
`cloneTempo 1.1` left set on Costa's box — the original ask was "a little
faster". Hand-copied to the installed clone. (The no-menu-row call lasted
one ask — v1.26.0 below added preset chips.)

Tempo/Pitch chips in the menu (2026-08-29, v1.26.0): "expose UI knobs for
the speed and pitch on the panel … as simple as possible. We don't want it
fancy" — so the v1.25.0 no-menu-row call is superseded the same day. Two
`Choice` rows under the Voice picker (the Walks/Size preset pattern, no
slider, no free numbers): Tempo slow 0.9 · normal 1 · brisk 1.1 · fast
1.25, Pitch deep 0.85 · normal 1 · light 1.15 · squeaky 1.35, each tap a
`menu.set("cloneTempo"|"clonePitch", value)` through the same chose→
setSetting path as every chip. Shown ONLY while `cloneKnobsApply` (a
speak-clone command is the live tts) — for every other voice the keys do
nothing, so the rows would be dead weight; a QtQuick Column skips
invisible children, so they collapse without a gap. An off-preset IPC
value highlights the nearest chip, the Size row's rule. Verified by
screenshot after a shell restart: rubick active shows both rows with
brisk/normal selected (cloneTempo was 1.1), `useVoice off` hides them
cleanly, rubick restored byte-identical, journal clean. Hand-copied to
the installed clone.

Keybinds in agent help (2026-08-29, v1.26.1): "do we expose a way to bind
a clippy action to a keybind easily?" — the README's scripting section
already answers it (any verb drops into a Hyprland bind, two `bindd`
examples), but `help` never said so. Costa's call: "no UI for this. only
agent help" — so one line in the `help` output, just above the README
path, with a complete copy-pasteable `bindd` example. No menu change, no
new keys. Verified live over IPC after a shell restart (the hand-copy
alone reloaded the plugin but reused the cached compile — the known
symlink gotcha applies to the real clone too when only the copy changes);
journal clean. Hand-copied to the installed clone.

Clone samples cut and levelled in the script (2026-08-29, v1.28.0): a
real run of the agent flow — "give clippy Les Grossman" from a YouTube
rip — showed what `setup-voice --clone` left to the agent: the sample
had to be cut out of the scene with ffmpeg by hand (the script only took
the first 20 s of whatever it was given), the rip was -33 LUFS and went
in quiet, and the second attempt under the same name kept replaying
lines rendered from the first (the cache was keyed by ref *path*, and
the 11 stale files had to be found by mtime and deleted). Costa's "so
the whole flow of adding a voice is possible for a user … using an AI
agent?" — yes, the README and the `voices` reply get an agent there,
but those three were traps; "yes add them". Now `--clone` takes
`--from`/`--to` (input-side `-ss`/`-to`, cap after the cut), runs the
sample through `loudnorm I=-18`, prints the cut's length with a short-
sample warning and a cap notice, and says so on a re-clone; the line
cache key in `speak-clone` gained the sample's contents hash, with
`warm-voice` sniffing the installed client for the scheme so a plugin
update can't warm into keys an old client ignores. The cost of the
re-key is one re-warm per existing clone (rubick's 430 lines are now
orphans in the cache, harmless). Not done: stripping score from under
the voice — that's demucs, another multi-GB model, and the README now
says to pick a dry stretch instead. Verified end to end by re-cloning
grossman straight from the mp4 with `--from 5:59 --to 6:12`. Hand-copied
to the installed clone.

Pre-warm on clone (2026-08-29, v1.28.0, same session): the first answer
kept warm-voice a manual follow-up — ~5 min of GPU you might not want
for a voice you may reject after two lines. Costa: "why are we not
prewarming. i dont get it" — and with the cache now keyed by the
sample's contents and never pruned, a voice warmed once stays warm
forever, so the only cost of warming a rejected voice is five idle GPU
minutes, and the cost of NOT warming is every user remembering a second
command and a slap reaction that lands late. First cut had setup-voice
nohup the warm after its `set tts`; Costa's next "so when we load a
voice? we also tell user to manually warm it?" pointed at the useVoice
reply still saying so, and at the real shape: the plugin owns it. One
trigger — the live tts becoming a speak-clone command — in
`onTtsSettingChanged` and on mount (`warmBookProc`, separate from the
agent-lines `warmProc`; a warm in flight is killed first; the command
goes over as `--tts <cmd>` so it can't race the write), which covers a
fresh clone, a picker switch, a hand-set command and a clone from
before this existed (rubick's orphaned cache) with no user knowledge —
a full cache makes it a ~0.3 s no-op per mount. setup-voice just says
it's happening; `voice` appends "pre-rendering the book" while it runs;
the useVoice/set-tts replies no longer name warm-voice; README rewritten
around it, warm-voice by hand kept for the knob change. Verified after a
shell restart: mount kicked the warm for the active voice (rubick —
Costa had switched back in the picker), `voice` showed it running,
useVoice grossman killed it and started grossman's; the first pass
logged that kill as "book warm failed (exit 15)", so a
`warmBookSuperseded` flag now turns our own SIGTERM into a plain
"superseded" log line. Left the box with grossman active and warming.

Agent guidance pass (2026-08-29, v1.28.0, same session): "yeah I did not
know it so noone will. is the agent guidance help for it clear now when
a user asks?" — read every agent-facing surface cold (help, voices,
voice, the script header) and closed three gaps: `help`'s voices line
now says it's also where you learn to add a voice ("clone anyone from a
10-20 s clip"), `voice` spells out what the running warm means (10-20
min of GPU, once per voice, automatic, usable meanwhile), and
`setup-voice` grew `-h/--help` (prints its own header) plus a guard for
unknown `--flags` — before, `setup-voice --help` fell through to kokoro
and tried to install a voice named "--help". The "~5 min" warm estimate
became "10-20 min" everywhere after measuring ~2.5 s/line with the box
otherwise busy. Verified over IPC after a shell restart; the restart
killed and re-started grossman's warm as designed.

Slap speaks after the crack (2026-08-29, v1.29.0): "we play a sound and
we don't play a voice. I think it would be way funnier if we actually
played the voice lines … after the slap sound ends" — with the caveat
"if it makes the code too difficult, we shouldn't do it". It wasn't:
the v1.22.0 silence existed because the voice's duck was crushing our
own SFX stream, and that bug has been fixed since (duck skips
node.name=quickshell), leaving pure sequencing — ~20 lines. `playOneOf`
now returns the chosen SoundEffect, the SoundBank delegate reports
`playing` dropping to `root.slapSoundDone(this)`, and slap() parks the
fx in `slapWaitFx` after its still-silent `say()`; when the finish (or
a 2 s `slapVoiceCap` — covers a stuck backend and Qt's re-play of an
already-playing effect emitting no toggle) matches the parked fx and
the bubble still shows the silent slapped line, `bubble.silent` flips
false and a new third watcher (`onSilentChanged`, same callLater
coalescing) starts the voice through syncSpeech — the
voice-watches-the-bubble invariant kept, no imperative speak call. The
guards make the edges fall out: a re-slap supersedes the parked fx, a
fling sound never matches it, a knockout (kill() before the say) fails
the mood check, a dismissed/slept bubble fails `shown`, a drag line
lands non-silent. Sounds off → the line is said non-silent and speaks
at once; tts off → identical to before. Knockout deliberately keeps
speaking lastWords over the crack — v1.22.0 scoped that as "a death,
not a slap reaction". Slapped lines were already in warm-voice's book,
so the clone answers from cache and the line lands right on the
crack's tail. bubbleTimer needed nothing: say()'s ≥4 s floor outlives
the ≤2 s wait, then the existing hold-for-voice beats take over.
Verified over IPC with the rubick clone live (drag/feel not needed —
nothing pointer-only changed): three slaps started aplay 648/1170/1082
ms after the slap, tracking each sample's length plus the duck; a
double slap 300 ms apart produced exactly one voice line at 1534 ms (an
earlier count of two turned out to be the previous line's aplay still
draining — cut by the slap as designed); slap + `shutUp` mid-crack
stayed voiceless; `slapSound false` spoke at 286 ms (duck only);
`tts false` was the old behavior and `set tts true` restored the clone
from the stash; ten fast slaps knocked him out with lastWords at 40 ms
(over the crack, unchanged) and `show` revived him. Journal clean, duck
state file gone after the lines.

Fling lines de-stretched (v1.29.1, 2026-08-29): Costa — "the rubick
voice, or any voice for that matter, does not handle well repeated
letters. like 'FUUUUUUUUUUUUUUUUUUUUUUUUUUUuuu' etc. let's make the
quotes more normal. like 'I'll be back!' etc. make them innpaprioprate
ofc". Twelve of the fifteen `flung` lines were elongation gags
(NOOO…/AAAA…/OVERRRR…) written for the bubble before any voice
existed; a clone reads them as garbage. All fifteen rewritten as
short speakable sentences, same 4-nsfw mix — "I'll be back!", "I'm a
paperclip, not a frisbee!", "Tell my stapler I loved her!", "Worst
airline ever. One star.", "See you in hell, asshole!" and friends. A
regex sweep of the whole book for repeated letters found only two
mild `dragged` stretches left ("Ohhh", "Wheeee"), trimmed to "Oh"/
"Whee"; everything else was clean. Content only — no code, no keys.
Verified: copied to the installed clone, shell restarted (which also
kicked warmBook into pre-rendering the new lines), and a new line
spoken end to end via `say "Tell my stapler I loved her!"` through
the live rubick clone — fresh cache files, journal clean. Deliberately
no IPC `fling` test: the box is joined to the leaderboard as
"costafot" and a test fling would post a real kill to the public
board.

Everyone dies on the board now (v1.30.0, 2026-08-29): Costa — "i think
we should always send kill/slap to the API. for users who have not set
anything, let's use the alias 'anonymous-clippy-abuser'. there should
be a toggle in the panel to disable. the leaderboard/counts is half the
fun and being opt in we would lack anything to show". The legality
question got answered first: one shared alias for every install means
the stored data is anonymous (no per-install ID — adding one would make
it pseudonymous and change the whole analysis), the server keeps only
handles and counts, and opt-out anonymous telemetry with disclosure is
standard open-source practice; the disclosure is the README plus the
IPC surface, deliberately NOT an in-character line (Costa: "no
incharacter discolsure. we will have the readme and will provide info
via terminal to any agent asking right"). The key's new grammar: unset
posts to the shared `anonymous-clippy-abuser` stone (the default), a
handle claims a stone, "off" is the only silence
(`leaderboardOff/Named/On` derive from `lbSetting`).
`setLeaderboardEnabled(on)` sits behind a new "Online leaderboard" ●/○
menu row ("public graveyard" was the first name; Costa, offered
variants: "'online leaderboard' sounds good") and `set leaderboard
true|false|off` — the ttsSaved idiom: off parks a named handle in
`leaderboardSaved`, on restores it; booleans, previously rejected ("a
handle, not a boolean"), now toggle. Under the toggle, a dim line gated
on it declares who it posts as — the alias by default, the handle when
named ("I think we can gate the name too under") — carrying the
claim-a-stone hint while anonymous; the old footer join nudge is gone,
its job moved up there. First deploy caught a real mount race: before shellConfig
delivers the entry, every setting reads as its default — which now
means "anonymous" — so maybeBoot's zero-delta announce posted an
anonymous bump on Costa's joined box, and the in-flight POST swallowed
the costafot announce, leaving `lbCache` on the wrong stone. Fixed with
`settingsLoaded` (entryLocation non-null) gating the flush — an "off"
that hasn't loaded yet must never leak a bump — plus `lbFlushQueued`
parking a forced flush that lands mid-POST; `onSettingsLoadedChanged`
announces the anonymous default, whose handle never fires the change
handler. Verified live over IPC through shell restarts: named mount
shows the right rank at once, off + restart posts nothing (no "off"
stone, server totals unchanged), anonymous mode announces the shared
stone (#2 of 2), toggle off/on round-trips the handle through the
stash, and the menu row screenshots with the footer rank. The AGENTS.md
design rule rewritten from "nothing leaves without opt-in" to "nothing
leaves undisclosed"; README says exactly what leaves (alias-or-handle +
two small deltas, IP seen in transit and not kept). Server untouched.

Gentler duck (v1.30.1, 2026-08-29): Costa — "ok the lowering music bit is
kinda annoying. can we lower to 80% of the volume?" `duckFactor` 0.3 →
0.8 (Clippy.qml plus the script's own fallback default), no mechanism
change. Verified live with a background tone plus real streams (Brave,
Viber, voxtype): all dipped to exactly 80% mid-line and restored to
100% with the snapshot file gone after. Mid-verification Costa felt the
duck still sounded bigger than 20% — pactl's percent is cubic, so 80%
is a −5.8 dB cut — then withdrew it ("ah no, it's ok"). README ducking
paragraph re-toned ("steps back" instead of "shuts up"), AGENTS.md
numbers updated; the old 30%→9%→1% compounding anecdote kept but dated
to the 0.3 days. Hand-copied to the installed clone.
