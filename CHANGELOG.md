# Changelog

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
