# Changelog

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
