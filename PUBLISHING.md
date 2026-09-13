# Publishing to the Omarchy plugin marketplace

Written 2026-08-28. Status: **listed since 2026-08-30** (#3395,
`approved-and-verified` by HANCORE-linux; snapshot pinned at `6980662` =
v1.40.11), re-snapshotted at `d61ab1b` = v1.49.2 by **#3903**
(`approved-and-verified` 2026-09-02; see "Submission log" at the end).
v1.50.0 is released and **blocked**: **#4870** (Verify form, filed
2026-09-04 at `a544fc2`) was blocked by a maintainer on 2026-09-10 over
`scripts/setup-voice`'s unpinned package installs and unverified model
downloads (the objection and the lines it names are in the submission log
at the end; the options are COS-159 on the board). Costa closed #4870
unapproved on 2026-09-11 rather than argue it, so **nothing is under
review and there is no issue to retarget**. The fix shipped as
**v1.52.0** (released 2026-09-12, where `main` now sits): the script
neither installs nor downloads anything any more, and the same release
stopped publishing a root `AGENTS.md`. See the last two submission-log
entries for what changed and what the maintainer notes must say. That
submission is **#6429**, filed 2026-09-12 at `ff96fee`, and it was
**blocked again** on 2026-09-12 — by a maintainer comment this time,
not a label, over the *printed* install commands not carrying pinned
digests (both bots came back clean; the full wording is in the
submission log). The answer is **v1.53.0** on `next`: every printed
command pins a version, a commit and a sha256, and `setup-voice`
checks them. Since the block means there is no approval to invalidate,
the next step is a release and then **retargeting #6429's Target
commit** to it — not a new issue. `main` stays on `ff96fee` until that
release goes out.
`main` moved to **v1.50.1** on 2026-09-11 regardless, released with no
Verify issue on purpose: the badge had read "update unverified" since
v1.50.0 landed (see flow step 5), and `omarchy plugin add` clones the
default branch, so parking `main` was shipping the 4.0.3-broken v1.50.0
to every new install while protecting nothing. **v1.51.0** and
**v1.52.0** followed on 2026-09-12 on the same reasoning, and `main`
sits on v1.52.0. The listing keeps serving the `d61ab1b` (v1.49.2) snapshot and stays
"update unverified" until that release is verified. The marketplace org renamed
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
   invisible to the inspection; only pushes move HEAD. **After approval
   a push to `main` is NOT harmless either** (learned 2026-09-04): the
   snapshot pin protects installs and the reviewed code, but the
   listing's badge follows HEAD of the default branch — the catalog
   re-validates every new HEAD on its own (`upstreamObservedCommit`),
   and any HEAD newer than `verificationCommit` shows as "Update
   unverified" until the next Verify issue is approved, docs-only
   commits included (v1.50.0's docs follow-up `a544fc2` did exactly
   that). Hence the branch rule below.
   **What the badge does and does not cost** (measured 2026-09-11, in
   the marketplace's own code): `catalogVerificationFields`
   (`scripts/catalog-verification.mjs`) sets `verificationStatus:
   "unverified"` on `observedCommit !== verificationCommit`, nothing
   else — so it is binary, one unverified commit ahead reads the same as
   ten, and `verificationSnapshotStatus` stays `verified` throughout.
   And the pin does not reach installs: `omarchy plugin add <url>` is a
   plain `git clone` of the default branch
   (`/usr/share/omarchy/bin/omarchy-plugin-add:120`), no commit, so HEAD
   of `main` is what a user actually gets. Both together: once the badge
   is already unverified, holding a fix off `main` buys nothing and
   costs every new install — which is why v1.50.1 was released into
   exactly that state.
6. **`main` is the marketplace.** Local and remote `main` sit exactly on
   the last release tag and move only at release time; everything in
   between is committed on the `next` branch (pushed freely — the
   marketplace reads only the default branch). A release is: merge
   `next` into `main`, bump `manifest.json`, tag, push `main`, `gh
   release create`, then file the Verify issue at that HEAD at once.
   If a fix lands while a Verify issue is still unreviewed, prefer
   retargeting it (edit the body's Target commit) over pushing after
   approval.

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
  setup-named files at the root (`scripts/setup-voice` is opt-in and,
  since v1.52.0, installs nothing and downloads nothing — it points `tts`
  at an engine the user installed and prints the install commands when
  there isn't one; say so), no sudo, no binaries.

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
- On each release: merge `next` into `main`, bump `manifest.json`
  version, tag, push, `gh release create`, then the Verify issue with
  the full 40-char SHA — in one sitting, since the listing reads
  "Update unverified" from the push until the approval. Record the
  issue numbers here.

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
- 2026-09-04: the catalog had picked up v1.50.0 on its own
  (`upstreamValidatedCommit` = `a544fc2`, `upstreamCheckStatus: passed`)
  and the listing showed `verificationCoverage: update-unverified`. #4870
  (Verify form, "publish a newer upstream commit") filed at `a544fc2`
  (v1.50.0 + the docs-only follow-up, which is where the tag sits).
  Validation ✅, baseline 🟡 with the same four capabilities (only
  `Clippy.qml:2712` → `:2736`); answered in the thread with the
  per-capability breakdown plus the what-changed-since-v1.49.2 summary
  (the volume knobs). Same day, checking the listing showed why the
  old "pushes are harmless after approval" note was wrong (the badge
  follows HEAD — see flow step 5/6), so `main` was reset to the
  v1.50.0 tag and this entry's commit moved to the new `next` branch;
  from here on `main` moves only at release time.
- 2026-09-10: **#4870 blocked**, by HANCORE-linux as a maintainer this
  time, not a bot: "Blocked at `a544fc2…`: `scripts/setup-voice`
  installs unpinned Python packages and downloads executable model
  artifacts from mutable or unverified sources without hashes, then
  loads them locally. This leaves the optional voice setup exposed to
  upstream or package compromise." The issue carries
  `security-review-required` and stays open. This is NOT one of the four
  reviewed capabilities — the per-capability answer stands and was not
  what the block is about; it is a new objection about supply chain, and
  every line it covers is in `scripts/setup-voice` on the opt-in path
  the plugin never runs itself: `pip install kokoro-onnx` (:96),
  `pip install piper-tts` (:139), `uv pip install chatterbox-tts`
  (:180), the kokoro model `curl` from a GitHub release (:101-102), the
  piper voices `curl` from `huggingface.co/rhasspy/piper-voices` at
  `resolve/main` (:147-148), and chatterbox's `from_pretrained()` in the
  generated daemon (:275, ~3 GB from HF on its first line). No versions
  pinned, no immutable refs, no checksums.
  **COS-159** on the board holds the four ways out (pin versions +
  immutable refs + sha256; pin only; argue the scope, which already
  failed with this reviewer once; or drop the engine installs from the
  shipped script and document them) and takes the decision; whatever is
  chosen gets recorded here.
- 2026-09-11: **#4870 closed by Costa** at 00:21 UTC, unapproved — the
  labels stayed `validated` + `security-review-required` +
  `plugin-update`, so the listing is untouched at `d61ab1b` (v1.49.2).
  "i closed the submission so we will make a new one when I am happy
  everything is fixed." Consequences for whoever picks this up: nothing
  is under review, so flow step 5's push freeze does not apply (step 6's
  badge rule still does — that is why `main` stays on `a544fc2`), there
  is no Target commit to retarget, and the next marketplace step is a
  brand-new Verify issue filed at the release that fixes COS-159, with
  the supply-chain answer in its maintainer notes rather than argued
  after the fact.
- 2026-09-11: **v1.50.1 released** (merge `next` → `main`, tag, push,
  `gh release create`) with **no Verify issue** — the first release here
  that deliberately leaves the listing unverified. The reasoning is in
  flow step 5's badge note: the listing had been "update unverified"
  since v1.50.0, the badge cannot get worse, and `omarchy plugin add`
  clones the default branch, so the freeze was handing every new
  installer the build that corrupts `shell.json` under omarchy 4.0.3.
  Costa's call, asked and answered. `main` now sits on the v1.50.1 tag,
  the branch rule continues from there, and the next submission is the
  one that carries the COS-159 fix.
- 2026-09-12: **v1.51.0 released**, same shape and same reasoning as
  v1.50.1 — no Verify issue, because the badge is already unverified and
  the default branch is what a new install clones. It restores widget
  avoidance under omarchy 4.0.3 by sampling `omarchy-shell shell
  debugBarGeometry`, which is worth flagging for whoever writes the next
  maintainer notes: the verb is undocumented and read-only, and it is the
  plugin asking the shell it runs in where its own bar widgets are, not a
  new capability. Costa confirmed the behaviour by hand before the
  release (COS-162). `main` sits on the v1.51.0 tag; the COS-159
  supply-chain fix is still the condition for the next submission.

- 2026-09-12: **COS-159 answered** on `next` (v1.52.0, unreleased as this
  is written). Of the four options Costa picked the last one: drop the
  engine installs from the shipped script and document the manual steps.
  `scripts/setup-voice` now installs nothing and downloads nothing — it
  probes for an engine already on disk, writes the glue (kokoro's
  `say.py`, the clone `daemon.py` and `speak-clone`), sets `tts`, and
  when an engine or a model is missing it PRINTS the exact commands to
  stderr and exits 1. The same commands are `docs/voice.md`'s, so a user
  runs them in their own shell with their own pins and hashes. The three
  `pip`/`uv pip` lines, both model `curl` sets and chatterbox's
  `from_pretrained` fetch are gone from the executed paths; the clone
  daemon sets `HF_HUB_OFFLINE` before importing chatterbox and exits with
  a one-line reason on a cold cache, so it cannot pull ~3 GB on its own
  either. Nothing in the repo now resolves a package version or a model
  URL. **Maintainer notes for the next Verify issue should say exactly
  that**, in this order: (1) the blocked lines are gone rather than
  pinned — no unpinned install remains because no install remains; (2)
  what the script still does is local file writing plus one
  `omarchy-shell … set tts`; (3) the install commands moved to
  `docs/voice.md` and to the script's own stderr, where the user runs
  them; (4) `HF_HUB_OFFLINE` on the daemon closes the last fetch. Do not
  re-argue the four reviewed capabilities — that answer stood and was
  never what #4870 blocked on.

- 2026-09-12: **COS-160 done** on `next`, and it has to go out in the same
  release as COS-159 or the submission gets bounced twice for two
  different reasons. The tracked root `AGENTS.md` (86 KB) and `CLAUDE.md`
  are gone: the rules are a tracked `REFERENCE.md`, and the checkout keeps
  one-line untracked pointers to it, both gitignored. `omarchy plugin add`
  is a plain clone of the default branch, so before this every install
  dropped an unreviewed instruction file into
  `~/.config/omarchy/plugins/costafot.clippy/` for any agent opened in or
  above it to read. This is the same maintainer's objection that refused
  Costa's omarchy-android-dev submission (#5546, 2026-09-08, "remove
  `AGENTS.md` (and any equivalent agent-instruction file) from the
  installed/published plugin tree … then submit a newly validated
  commit"), and that fix went on to be approved — so it is pre-empted
  here rather than answered later. A symlink was tried first:
  `omarchy-plugin-validate` refuses symlinks anywhere in a plugin folder.
  **Worth one line in the next Verify issue's maintainer notes**, after
  the setup-voice points: the published tree carries no
  agent-instruction file, by the same reasoning as #5546.
  `PUBLISHING.md` stays tracked on purpose — nothing auto-reads it, and
  omarchy-android-dev ships its own.

- 2026-09-12: **v1.52.0 released** — merge `next` → `main`, tag, push,
  `gh release create`, no Verify issue yet. Third release in a row into
  an already-unverified badge, same reasoning as v1.50.1 and v1.51.0,
  but the first one that is *ready* for the submission rather than just
  better than what `main` was serving: it carries both answers a
  maintainer is now primed to look for — the setup-voice supply-chain
  fix (COS-159) and no published agent-instruction file (COS-160). The
  Verify issue at this commit is the next step and Costa's call when to
  send it; when it goes out, the notes are the two entries above, in
  that order, and COS-159 and COS-160 close with it.

- 2026-09-12: **#6429 filed** (Verify form, "publish a newer upstream
  commit") at `ff96fee` = v1.52.0, with the maintainer notes as a comment
  since the verify template has no notes field. They say, in order: the
  blocked lines are gone rather than pinned (setup-voice installs and
  downloads nothing, prints the commands instead, `docs/voice.md` carries
  them); the clone daemon's `HF_HUB_OFFLINE` closes the third fetch;
  nothing in the repo resolves a package version or a model URL; the
  published tree no longer carries a root `AGENTS.md`, volunteered
  against #5546 rather than waiting to be told; and the user-facing
  changes since v1.49.2, with v1.51.0's `debugBarGeometry` sampling
  flagged as read-only and not a new capability. The four reviewed
  capabilities were deliberately NOT re-argued — that answer stood in
  #3395 and #3903 and was never what #4870 blocked on. **`main` is frozen
  at `ff96fee` while this is open.**
  Bots, same day: validation ✅ at `ff96fee`, baseline 🟡
  review-required with **no findings** and the same four capabilities
  (`privilege`, `package-manager`, `service-management`, `installer`).
  Answered in the thread, because the capability list now needs one
  thing said out loud: the `pip install` / `sudo pacman` lines it cites
  in `scripts/setup-voice` (:89, :108, :132, :134, :169) are all inside
  `cat >&2 <<EOF` heredocs — printed text, not execution. To a maintainer
  who has just blocked this plugin over those exact lines, an unexplained
  capability list naming them again reads as nothing having changed. If
  the script is ever restructured, check what the scanner cites before
  assuming the answer still holds.

- 2026-09-13: **#6429 blocked** — HANCORE-linux, 2026-09-12T20:51Z, at
  `ff96fee`: "optional voice setup downloads executable models and
  dependencies without pinned digests, including content from mutable
  upstream locations. Bind every executed artifact to immutable identity
  and verified integrity, then revalidate." Both bots were clean
  (validation "Ready for verified update review"; baseline the usual
  amber, `"findings":[]`, the same four informational capabilities), and
  the comment landed 11 hours after the thread already explained that
  every cited line sits in a `cat >&2 <<EOF` heredoc. So it was read and
  the bar moved rather than missed: #4870 said "installs unpinned
  packages", this says "every executed artifact", which only has content
  if it covers the commands the script prints — unversioned
  `pip install kokoro-onnx`, and piper voices off `resolve/main`, the
  mutable ref the heredoc itself flagged. **Answered by pinning rather
  than arguing a second time** (v1.53.0, on `next`): exact versions for
  all three engines, the kokoro models by sha256, the piper URL at a
  commit with all 176 voices' digests in `scripts/piper-voices.sha256`,
  the chatterbox model at a revision with its five digests in the
  script — and `setup-voice` verifies each against the bytes on disk
  before it wires a voice up, so the digests are enforced and not just
  printed. The clone daemon stopped calling `from_pretrained` for the
  same reason: it now loads the pinned revision out of the cache. Next
  step is a release, then edit #6429's Target commit to it; the four
  reviewed capabilities stay un-re-argued, as in #3395 and #3903.
