# Changelog

## v1.54.1

- The wheel locks under `scripts/pins/` carry environment markers now, so a `--require-hashes` install of kokoro or piper resolves on any Python from 3.10 up, not only the minor the lock was compiled on. Chatterbox stays a 3.12 lock: its venv is built with `--python 3.12`, and on 3.14 chatterbox-tts wants a newer torch than the daemon runs.

## v1.54.0

- The install commands `scripts/setup-voice` prints now pin every Python wheel by sha256, not just the version: `pip install --require-hashes -r scripts/pins/<engine>.txt`, one lock per engine, so a wheel the index serves that isn't the one resolved when the pin was made is refused rather than installed.
- A piper voice that isn't in the pinned catalog is no longer wired up on trust. The script stops and says where to write its two digests (`~/.local/share/piper-voices/piper-voices.sha256`) if you want to vouch for it yourself.
- He sleeps on the lock screen and under the screensaver again on omarchy 4.0.3 and later. The shell stopped telling plugins about either, so he asks it over IPC every ten seconds instead.
- Clicking the bar icon opens the menu under the icon again, on the monitor you clicked, on omarchy 4.0.3 and later; a new `showMenuAt <x> <monitor>` IPC verb carries that. The icon no longer fades while he is dead or hidden, on any version.

## v1.53.0

- Every install command `scripts/setup-voice` prints is pinned now: exact package versions, model URLs that name a commit or a release rather than a branch, and a sha256 for every file you fetch. The script checks those digests against what is actually on your disk before it points his voice at anything, so a model that is not the one this plugin ships against stops it instead of being wired up. `docs/voice.md` carries the same pins.
- The voice-clone daemon loads one pinned revision of the chatterbox model out of your Hugging Face cache, instead of whatever that repo's `main` branch points at the day you fetched it.

## v1.52.0

- `scripts/setup-voice` installs nothing and downloads nothing any more. It points him at a neural voice already on your machine, and when there isn't one it prints the exact commands and stops. Installing kokoro, piper or chatterbox is now a few commands you run yourself — `docs/voice.md` has them, with your own versions and your own hashes if you want them.
- The voice-clone daemon only ever loads its model out of your Hugging Face cache, so nothing fetches a ~3 GB model in the middle of an insult. Fetch it once with the command the script prints.

## v1.51.0

- He parks between your widgets again (`avoidWidgets`). Current Omarchy stopped telling plugins where the bar widgets are, so he now asks the bar for them directly instead. With more than one monitor he can't tell which screen a widget is on, so he keeps clear of all of them.

## v1.50.1

- Settings work again on current Omarchy. The shell changed how a plugin is handed its own configuration; he read none of it, so every setting fell back to its default, the menu and `set` looked dead, and each write overwrote the rest of your entry. If yours was emptied, Omarchy's backups are at `~/.config/omarchy/shell.json.bak.*`.
- Three things the shell no longer tells plugins, so they are off until it does: he no longer parks in the gaps between bar widgets (`avoidWidgets`), he only sleeps for the screen going off and not for the lock screen or the screensaver (`pauseWhenAway`), and the bar paperclip no longer dims when he is dead or opens the menu on the monitor you clicked.

## v1.50.0

- `soundVolume` (0–1): the slap, fall and whoosh have a level now, with a quiet · medium · full row in the menu under Sounds.
- `voiceVolume` (0–1): how loud he talks, same three chips under the Voice picker. The espeak-ng robot and clone voices honour it (an existing clone install needs one `setup-voice` rerun to refresh its client); robot George, piper and custom commands ignore it.

## v1.49.2

- A voice daemon that dies while a line waits on it (e.g. the model download failing) now reports "daemon never came up" with the crash's last log line, instead of a raw ConnectionResetError traceback — and the next line respawns it.
- A first run on a slow connection no longer hits a TimeoutError traceback at 2 minutes: it says the daemon is still downloading and keeps the download running for the next try.

## v1.49.1

- `setup-voice` now detects a broken chatterbox venv (an interrupted first install) and rebuilds it, instead of every later run failing with "daemon never came up".
- That error now includes the daemon's actual crash line instead of just pointing at the log file.

## v1.49.0

- Full-screen stage: the window covers the whole screen (still click-through except him), `size` max raised to 400.
- Gags (`gags`, default on, menu toggle): entrance stunts on respawn — the tumble and the lob — and the long drop when flung off a top bar. IPC `gag entrance|lob|peek`.
- The corner peek: occasionally hangs out of a corner at ~5× size, says a line, leaves. Slappable. `peekChance` sets the odds.
- Window reactions (`reactions`, default on, menu toggle): one-liners when you focus X, Hacker News, ChatGPT, Facebook, Instagram, TikTok, Reddit, YouTube, or Steam — plus an nsfw adult-site set (muted by `clean`). Custom targets via `quotesFile`.
- Reaction pacing keys: `reactionCooldown` (2700 s per site), `reactionGap` (600 s global), `0` disables. IPC `react <text>` forces one.
- New `slappedPeek` quote pool: short yelps for mid-peek slaps.
- Voice clone cache capped at `voiceCacheMb` (500 MB default, LRU, `0` = uncapped).
- Fixed: big/peeking Clippy was nearly unslappable; a slapped peek flashed a bubble ghost at the bar; `warm-voice` crashed on the reactions map (book prewarm was silently dead).
