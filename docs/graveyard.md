# The graveyard

There is a [public leaderboard](https://graveyard.costafotiadis.com)
— a graveyard, one headstone per handle, sized by how many times its owner
has killed him. Slaps are the tiebreak. By default every install posts to
one shared stone, `anonymous-clippy-abuser` — the whole nameless world
piled into a single grave. Claim a stone of your own with any handle:

```bash
omarchy-shell costafot.clippy set leaderboard yourname
```

What leaves your machine: that alias (or your handle) and small kill/slap
counts, POSTed when you slap or kill him, plus an empty POST when he starts or
wakes up, which is how he gets your rank back. The request names the plugin's
version. Nothing else — no hostname, no install ID, no cookies. The server stores only handles and
counts; like any web request it sees your IP in transit, and keeps nothing
of it. Don't want even that? The menu's "Online leaderboard" row toggles the
posting off, or:

```bash
omarchy-shell costafot.clippy set leaderboard off
```

There are no accounts: handles are first-come, never-owned, so anyone can
post as you, two people with the same name share a grave, and a while-loop
over `slap left` is an instant world record. All of that is fine. Every
score was self-reported murder to begin with. There is no delete either —
the grave keeps what you already confessed.
