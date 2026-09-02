# Publishing to the Omarchy plugin marketplace

Written 2026-08-28. Status: **listed since 2026-08-30** (#3395,
`approved-and-verified` by HANCORE-linux; snapshot pinned at `6980662` =
v1.40.11), re-snapshotted at `d61ab1b` = v1.49.2 by **#3903**
(`approved-and-verified` 2026-09-02; see "Submission log" at the end).
v1.50.0 is released but not yet on the marketplace — it needs its own
Verify issue when Costa wants it there. The marketplace org renamed
`HANCORE-linux` → `omacom` (old links redirect). Everything below is what an
agent needs to take it from here; it mirrors what was done for
`costafot.autoduck` and `costafot.yeet`.

## The flow (https://omarchyplugins.com/publish.html)

Marketplace repo: https://github.com/omacom/omarchy-plugin-marketplace
(docs there: `SUBMISSION.md`, `SECURITY.md`, `VERIFICATION.md`).

1. Repo prep: root `manifest.json` with every field, README with install
   **and remove** commands, `LICENSE`, optional root `preview.png`
   (the marketplace generates card + detail images from it itself; ≤50 MB,
   ≤40 MP). Public GitHub repo, pushed.
2. `omarchy plugin validate ~/Work/omarchy-inappropriate-clippy` — the real
   checkout, not the symlink in `~/.config/omarchy/plugins`.
3. Open the "Submit a plugin" issue form:
   https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml
   Title `[Plugin]: <name>`. Fields: repository URL, category (dropdown:
   Appearance, Desktop, Developer Tools, Hardware, Productivity, System,
   Widgets, Other), 1–3 tags (AI, Bar, Games, Hyprland, Launcher, Media,
   Power management, Quickshell, Security, System, Workspaces), optional
   suggested tag, maintainer notes, five checkboxes (all required). The
   six headings must stay in order or the bot ignores the issue.
4. Bots comment: "Marketplace validation" (structure + Quattro
   compatibility at the exact HEAD commit) and "Automated security
   baseline" (`passed` / `review-required` / `needs-fixes`). A maintainer
   then applies `approved-and-verified` and it goes live at
   `https://omarchyplugins.com/plugin.html?id=costafot.clippy`.
5. **Every later release needs its own "Verify plugin" issue** with the
   exact target SHA (template `verify-plugin.yml`, action "Verify and
   publish a newer upstream commit"). The listing is pinned to a commit;
   until you file one, new pushes show as "Update unverified".
   **Freeze pushes while a Verify issue is open**: approval requires the
   repo's default-branch HEAD to still BE the target commit —
   `assertPluginUpdateInspection` (scripts/plugin-update.mjs) throws
   `update-upstream-changed` ("The repository HEAD no longer matches the
   requested update commit") otherwise. A push mid-review means editing
   the issue body's Target commit to the new HEAD (the edit re-runs the
   bots; a comment triggers nothing) and waiting again. Local commits are
   invisible to the inspection; only pushes move HEAD. After approval,
   pushes are harmless — the snapshot is pinned.

## Prior art to copy from

- Autoduck submission: omacom/omarchy-plugin-marketplace#2272
  (Desktop; media, quickshell, bar; suggested "audio"; baseline `passed`;
  published the same day). Update: #2516 (Verify form, target commit SHA).
- Yeet submission: #2651 (Productivity; bar, quickshell, media; suggested
  "sharing"). Got `review-required` for the native-messaging host, a
  maintainer found two real bugs, fixed at a new commit and answered in
  the thread. Still open as of 2026-08-28.
- Both shipped with a `v1.0.0` GitHub release and a ~16:9 `preview.png`
  (4267×2400).
- **There is another Clippy in the queue:** #1900, "[Plugin]: Omarchy
  Clippy" (`dev.ebbo.omaclippy`, BernhardRode, submitted 2026-08-23), stuck
  at `needs-fixes` + `security-review-required` because opening it starts a
  tmux session running `claude --dangerously-skip-permissions`. Different
  id, different plugin, no collision — but say so in the maintainer notes
  before a maintainer conflates them: ours runs the user's agent one-shot
  with tools off (`--tools ""`), only with `ai: true`, and never
  persistently.
- `gh issue view <n> -R omacom/omarchy-plugin-marketplace --json body`
  gives the exact body shape; `SUBMISSION.md` there also has a
  `gh issue create` heredoc for doing it from the CLI.

## What Clippy already has

- Manifest: all required fields, id `costafot.clippy`, version 1.40.10 at
  the time of writing (check `manifest.json` — this file goes stale),
  kinds `panel` + `bar-widget`. Validate passes (exit 0, silent) with the
  `docs/` folder in the tree.
- LICENSE (MIT), README, `preview.png` (4267×2400, 16:9 — since v1.40.11 an
  AI-generated deckchair illustration with the comeback line in the
  bubble, before that the bar strip on the gradient card like the other
  two plugins; also the README's hero image), `main` pushed and clean at the time of writing.
- Docs (v1.40.0): the README is the pitch — install + remove, the mouse
  table, a short section per feature with its **Leaves your machine**
  bullets and a screenshot, an uninstall section and a FAQ (v1.40.5;
  every shot including the slap gif is in) — and
  the manual is `docs/`,
  served by GitHub Pages at
  https://costafot.github.io/omarchy-inappropriate-clippy/ (source `/docs`
  on `main`, `jekyll-theme-primer`). The same folder ships in the plugin
  clone, which is what `help` points agents at. Put the URL in the
  submission's maintainer notes and in the marketplace listing's link
  field if the form has one.
- Network, for the security baseline (declare it, don't let the bot find
  it): `curl` in `scripts/fetch-assets` (dev-time, pipes into `sed | jq >
  file`, never a shell); the graveyard's `curl -X POST` from Clippy.qml
  to graveyard.costafotiadis.com (default-on, anonymous
  alias + kill/slap deltas, `set leaderboard off` silences it — the
  disclosure is the README's graveyard bullet and `docs/graveyard.md`);
  and, only with `ai: true`, `scripts/clippy-ai` running the user's own
  coding-agent CLI (`claude -p` etc.) with tools off. No install/
  setup-named files at the root (`scripts/setup-voice` is opt-in and
  downloads TTS models on demand — say so), no sudo, no binaries.

## Gaps — do these first

1. ~~**README removal line.**~~ Done in v1.40.2: `omarchy plugin remove
   costafot.clippy` sits under the install command.
2. ~~**Tag/release.**~~ Done 2026-08-30. One release per pushed version,
   never moved (v1.40.10 was moved onto each fix commit the Yeet way
   until we read the marketplace's workflows: the bots validate HEAD of
   `main` — `resolveSnapshot()` in `scripts/build-catalog.mjs` takes
   `snapshotCommit || default branch`, and a `[Plugin]:` issue has no
   snapshot commit — and approval re-inspects HEAD at approval time; the
   release is only read via `releases/latest` as the listing's link, so a
   fresh release per version keeps that link on the listed commit and
   nothing depends on the tag). The bots re-run on `issues: opened |
   edited | reopened | labeled | unlabeled` — an issue-body edit is the
   re-run button; comments and pushes trigger nothing.
3. ~~**Preview aspect.**~~ Done (2026-08-29): `preview.png` is 4267×2400
   like the other two; the 2400×260 strip is gone.
3b. **Orphan screenshots.** Five tracked files under `assets/screenshots/`
   are referenced by nothing (`line-book.png`, `line-book-2.png`,
   `menu-2.png`, `screen-look.png`, `slap-line-2.png`, 1.7 MB together)
   and ship in every plugin clone. Delete or keep — Costa's call; the
   README pass that dropped `screen-look.png` left it on purpose.
4. **Maintainer notes** (the form's free text) — say all of this:
   - Profane by default; `clean: true` (menu row "Clean") drops every line
     tagged `nsfw`. The marketplace has no content policy, but disclose it.
   - Rights. The marketplace has a `rights-request.yml` template, so
     disclose up front rather than waiting to be asked. Paste this:

     > The Clippy character, name and artwork are Microsoft's. The sprite
     > sheet and frame data come from clippy.js
     > (https://github.com/clippyjs/clippy.js), fetched by
     > `scripts/fetch-assets` and committed; clippy.js's own licence covers
     > its JavaScript only and says as much, so the artwork here is
     > unlicensed and reproduced as parody. The plugin's code and text are
     > MIT. It is free, not affiliated with or endorsed by Microsoft, and
     > the README says so. If Microsoft objects I will swap in original
     > artwork — the animation engine is atlas-agnostic, so it is a
     > one-file change — or pull the listing, whichever they prefer.

     If a maintainer pushes back, the prior art is that Microsoft has
     tolerated this for over a decade: clippy.js has hosted the same
     `map.png` publicly on GitHub since 2013, and
     `fleshywaffles.vs-code-clippy` ("Clippy", the real Clippit render as
     its icon, no LICENSE, no attribution) has been on Microsoft's own VS
     Code marketplace since 2020-03-09 with ~24k installs. Tolerance is not
     permission, and the honest answer if pressed is the offer to redraw.
   - Config writes: only its own entry in `~/.config/omarchy/shell.json` —
     settings the user picks in the menu, plus a one-time move of a
     pre-icon entry from `plugins[]` into `bar.layout.right` on mount
     (`adoptIntoBar()`). Never touches other keys or files.
   - Plays WAV sounds via QtMultimedia (stock quickshell); reads an
     optional user-supplied `quotesFile`; no external dependencies; install
     and remove via the standard `omarchy plugin add/remove` flow.
   - Docs link: https://costafot.github.io/omarchy-inappropriate-clippy/
     — the full manual (every setting, the agent/voice/graveyard pages,
     what leaves the machine and when).
   - Not #1900. One sentence: different plugin and id; the agent here is
     opt-in, one-shot, tools off — see the prior-art bullet above.
5. **Category/tags.** Desktop (same as autoduck) or Other; tags Bar +
   Quickshell (Games is a stretch); suggest "Fun" as the missing tag.

## After it's listed

- Add the marketplace URL to the README install section (autoduck's
  README does not, but it's the obvious place) and to `docs/index.md`.
- On each release: bump `manifest.json` version, tag, push, then the
  Verify issue with the full 40-char SHA. Record the issue numbers here.

## Submission log

- 2026-08-30: #3395 filed at `8abcf7f` (v1.40.8), Desktop, bar +
  quickshell, suggested "fun", maintainer notes as drafted above plus the
  "not #1900" line. Validation ✅. Security baseline 🟡 review-required:
  one finding, `curl-pipe-shell` at `scripts/setup-voice:167` (the uv
  bootstrap `curl … | sh`) — fixed in v1.40.9 (uv must come from pacman;
  the script says so and exits) — plus four informational capabilities
  (a `sudo pacman -S espeak-ng` hint string in Clippy.qml, pip/uv into
  setup-voice's own venv, read-only `systemctl --failed` in clippy-ai,
  setup-voice being an installer file) answered in the thread.
  v1.40.10 pre-empted the finding the maintainer was blocking other
  plugins on that night — `Text` elements without `textFormat` showing
  externally sourced strings — with `Text.PlainText` on all 13; issue
  edited to re-run the bots at each commit, release moved each time.
  v1.40.11 (2026-08-30) swaps `preview.png` for the AI-generated
  deckchair hero; the issue body's "The preview image is a screenshot
  of the plugin" sentence must be edited to say it is an AI illustration
  of the character under the same parody stance (that edit re-runs the
  bots on the new HEAD).
  Outcome: `approved-and-verified` 2026-08-30 by HANCORE-linux, listed at
  `6980662` (v1.40.11) — labels submission/validated/listed on the closed
  issue, the registry entry carries the four reviewed capabilities.
  Still pending from "After it's listed": the marketplace URL in README +
  docs/index.md.
- 2026-08-31: #3903 (Verify form, "publish a newer upstream commit")
  filed at `ae3e6a5` (v1.49.0). Validation ✅, baseline 🟡 with the same
  four capabilities as #3395 (no findings); answered in the thread with
  the per-capability breakdown plus a what-changed-since-v1.40.11
  summary. 2026-09-01: retargeted to `1e2bb79` (v1.49.1, the setup-voice
  self-heal fix) by editing the issue body's Target commit — the edit is
  the re-run button, a comment triggers nothing — and the bots re-ran:
  compatibility ✅ at `1e2bb79`, baseline 🟡 identical but for
  `setup-voice:174` → `:180`; noted for the maintainer in a comment.
  Later that day: v1.49.2 (speak-clone's daemon-death and slow-download
  error paths, prompted by the same reporter's next traceback) released
  and #3903 retargeted a second time to its commit, same
  edit-the-body procedure. 2026-09-02 00:26 UTC: closed
  `approved-and-verified` at the v1.49.2 commit (`d61ab1b`). The freeze
  lifted with it; v1.50.0 (volume knobs) was pushed and released later
  that day with no Verify issue filed — Costa's call ("don't make a
  verification issue yet").
