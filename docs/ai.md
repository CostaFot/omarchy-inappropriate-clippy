# Letting your AI agent write his lines

Turn on "Lines from claude" in the menu (or `"ai": true`) and the random book
is replaced with remarks about what you are actually doing. Every so often he
gathers the evidence: your open window titles, what's playing, what you've
done to him lately (slaps, drags, the odd murder), and anything currently
embarrassing — a dying battery, an uptime or a pacman sync measured in weeks,
a program that dumped core today, a live microphone, more than half your
agent plan gone. Plus a random few draws from the shame pool: how long since
your last pacman sync, the package count, repos in `~/Work` with uncommitted
changes (names included), your most-typed shell command, the workspace and
browser tab counts. He never digs through your folders — no Downloads
inventory, no screenshot hoard, no trash. He hands all of it to your coding
agent as text and asks for five lines in his voice, with a handful of lines
from the book (and your `quotesFile`) as examples of how far to go. They're
cached and handed out one at a time, so a click never waits on a model.

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
oddly took a minute). `clean` applies to these lines too. You can tell his
lines apart: an agent line gets the theme's accent colour on the bubble and a
little sparkle in the corner. Whenever the agent is unset, not logged in,
offline or slow, the book takes over and you won't notice, except that the
sparkle is gone.

And when you want a verdict on demand: "Judge my screen" in the menu (or
`omarchy-shell costafot.clippy look`) screenshots the monitor he is standing
on, hands the picture to the same agent, and ~10 seconds later the jab lands
in his bubble — he visibly inspects the screen while the model chews on it.
This one cites what it can actually **see** (the tab, the window, the thing
you are pretending to read), which is where the good material was all along.
The screenshot goes wherever your agent sends its prompts, same as the facts
above — but only when you ask: he never takes one on his own, not on a timer,
not ever, and the file is deleted the moment the call returns. `claude` reads
the image natively and `codex` gets it attached; any other agent gets the
file path in the prompt and does what it can with it.

And you can talk back. "Say it to his face" in the menu (or `omarchy-shell
costafot.clippy listen`) opens the microphone — he visibly leans in — and
whatever you say to him comes back as a comeback, through the same agent,
spoken in whatever voice he has. Call `listen` again to stop, or he gives up
after 15 seconds. He is combative about it: tell him to shut up and he
squares up, ask him a question and he mocks you for asking a paperclip. The
audio is transcribed **on your machine** by [voxtype](https://voxtype.io)
(which ships with Omarchy) and the recording is deleted right after — only
the transcribed text goes to your agent (with a slim cut of the usual
facts: just the focused window and what's playing), and the mic only ever opens on your
explicit gesture, same rule as the screenshot. Say nothing and he notices
that too, without spending a call on it. No mic handy? `omarchy-shell
costafot.clippy reply "your words"` is the same fight, typed. Without an
agent set he answers both with the stock sass you deserve.

Don't like who he is? `promptFile` points at a plain text file that replaces
his entire built-in prompt — the persona, the delivery, the rules, the
swearing, all of it. Your file becomes the character; the machinery stays. He
still gets the facts, still judges screenshots, still fires back when you talk
to him, and still answers in the JSON the plugin expects — but who is doing
all that is now whatever your file says. The built-in register examples step
aside too: only your own `quotesFile` lines ride along, so his old book can't
argue with whoever you turned him into. Everything else in this section
(`clean`'s example filtering, the caching, the sparkle) applies unchanged. A
path that doesn't exist falls back to the built-in gremlin, and
`omarchy-shell costafot.clippy ai` tells you which character is actually
running. Write the file as the character brief — who he is, how he talks,
what he goes after — and nothing about output: the plugin appends the facts
block, the mode framing (screenshot, their words, line count) and the JSON
contract itself, so a file that dictates a format fights the scaffold.
Fair warning: his built-in taste rules (no clock jokes, the length
cap, "never be hateful") are part of what you are replacing — your prompt,
your responsibility.

Verified with `claude` and `opencode`; `codex` and `pi` are wired the same way
but weren't run here, and the rest are best guesses from their docs. To see
what he'd send, or try an agent by hand:

```bash
cd ~/.config/omarchy/plugins/costafot.clippy
scripts/clippy-ai                          # a JSON array of lines from the default agent (--count N, default 3)
scripts/clippy-ai --agent opencode         # a specific agent; --model <name> where it takes one
scripts/clippy-ai --context                # the facts it would send (one random draw of the shame pool)
scripts/clippy-ai --prompt                 # the whole prompt, register examples and all
scripts/clippy-ai --image shot.png         # one jab about a screenshot — what `look` runs
scripts/clippy-ai --reply "make me"        # one comeback — what `listen`/`reply` run; --said <his line> is what they answered
scripts/clippy-ai --clean                  # drop the nsfw examples, the `clean` key
scripts/clippy-ai --quotes ~/mine.json     # merge a quotesFile into the examples
scripts/clippy-ai --prompt-file ~/who.txt  # your character instead of the built-in one, the `promptFile` key
scripts/clippy-ai --recent "slapped him"   # the note the plugin passes about what you did to him lately
```
