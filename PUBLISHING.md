# Publishing to the Omarchy plugin marketplace

Written 2026-08-28. Status: **not submitted yet.** Everything below is what an
agent needs to take it from here; it mirrors what was done for
`costafot.autoduck` and `costafot.yeet`.

## The flow (https://omarchyplugins.com/publish.html)

Marketplace repo: https://github.com/HANCORE-linux/omarchy-plugin-marketplace
(docs there: `SUBMISSION.md`, `SECURITY.md`, `VERIFICATION.md`).

1. Repo prep: root `manifest.json` with every field, README with install
   **and remove** commands, `LICENSE`, optional root `preview.png`
   (the marketplace generates card + detail images from it itself; ≤50 MB,
   ≤40 MP). Public GitHub repo, pushed.
2. `omarchy plugin validate ~/Work/omarchy-inappropriate-clippy` — the real
   checkout, not the symlink in `~/.config/omarchy/plugins`.
3. Open the "Submit a plugin" issue form:
   https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml
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

## Prior art to copy from

- Autoduck submission: HANCORE-linux/omarchy-plugin-marketplace#2272
  (Desktop; media, quickshell, bar; suggested "audio"; baseline `passed`;
  published the same day). Update: #2516 (Verify form, target commit SHA).
- Yeet submission: #2651 (Productivity; bar, quickshell, media; suggested
  "sharing"). Got `review-required` for the native-messaging host, a
  maintainer found two real bugs, fixed at a new commit and answered in
  the thread. Still open as of 2026-08-28.
- Both shipped with a `v1.0.0` GitHub release and a ~16:9 `preview.png`
  (4267×2400).
- `gh issue view <n> -R HANCORE-linux/omarchy-plugin-marketplace --json body`
  gives the exact body shape; `SUBMISSION.md` there also has a
  `gh issue create` heredoc for doing it from the CLI.

## What Clippy already has

- Manifest: all required fields, id `costafot.clippy`, version 1.40.5 at
  the time of writing (check `manifest.json` — this file goes stale),
  kinds `panel` + `bar-widget`. Validate passes (exit 0, silent) with the
  `docs/` folder in the tree.
- LICENSE (MIT), README, `preview.png` (4267×2400, 16:9 — the bar strip
  on the gradient card, same treatment as the other two plugins; also the
  README's hero image), `main` pushed and clean at the time of writing.
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
2. **Tag/release.** Repo has zero tags although the manifest says 1.4.0.
   Not required by the marketplace, but both others had `v1.0.0` at
   submission. Tag the submitted commit (`git tag v1.4.0` or whatever the
   manifest says then; `gh release create`). Pushing/tagging is Costa's
   call — prepare, don't push, unless asked.
3. **Preview aspect.** Done (2026-08-29): `preview.png` is 4267×2400 like the
   other two; the 2400×260 strip is gone.
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
5. **Category/tags.** Desktop (same as autoduck) or Other; tags Bar +
   Quickshell (Games is a stretch); suggest "Fun" as the missing tag.

## After it's listed

- Add the marketplace URL to the README install section (autoduck's
  README does not, but it's the obvious place) and to `docs/index.md`.
- On each release: bump `manifest.json` version, tag, push, then the
  Verify issue with the full 40-char SHA. Record the issue numbers here.
