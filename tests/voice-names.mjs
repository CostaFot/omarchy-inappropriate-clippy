#!/usr/bin/env node
// A voice file's name can't carry a command (#6429). Run: node tests/voice-names.mjs
//
// It builds a fake HOME, so nothing here touches the real voices or settings,
// and reads the real scripts/voice-scan and the real builders out of
// Clippy.qml. Three things are checked:
//
//   1. voice-scan doesn't offer a voice whose name or sample rate holds shell
//      syntax, so the picker never sees it.
//   2. The builders refuse the same names, and ttsCmdSafe turns down the
//      strings the picker saved before v1.55.2 from such a name, in settings
//      and in ttsSaved alike, while leaving safe voices and a hand-set `set
//      tts` command alone.
//   3. Each of those old strings really runs its payload when bash gets it,
//      and none of them runs it when it goes through the gate first, the way
//      launchTts does. The first half is the control: if the payloads stopped
//      being payloads, this test would otherwise pass for the wrong reason.

import { spawnSync } from "node:child_process"
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const repo = join(dirname(fileURLToPath(import.meta.url)), "..")
const box = mkdtempSync(join(tmpdir(), "clippy-voice-names-"))
const home = join(box, "home")
const bin = join(box, "bin")
const piperDir = join(home, ".local/share/piper-voices")
const voiceDir = join(home, ".local/share/chatterbox-tts/voices")
const marker = join(home, "clippy-pwned")

// The payload can't hold a slash in a filename, so it goes home and writes
// there. `home` is the fake one, and every bash below runs with it as HOME.
const payload = "cd;touch${IFS}clippy-pwned"
const hostile = [
  `x;${payload};`,
  `x&${payload}&`,
  `x|${payload}|`,
  `$(${payload})`,
  `\`${payload}\``,
  `x\n${payload}\n`,
]
const unsafeNames = [...hostile, "a b", "a\tb", "a'b", 'a"b', "a\\b", "a*b", "a?b", "a[b]", "a>b", "a<b", "a(b)", "a{b}", "~a", "a#b", "a=b", "a$b"]
const safePiper = ["en_US-ryan-high", "pt_PT-tugão-medium", "one.two-three_4"]
const safeClones = ["george", "my_voice-2"]

let failures = 0, passes = 0
function check(ok, what) {
  if (ok) { passes++; return }
  failures++
  console.error("FAIL: " + what)
}
function exe(path, body) {
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, body)
  chmodSync(path, 0o755)
}

try {
  mkdirSync(piperDir, { recursive: true })
  mkdirSync(voiceDir, { recursive: true })
  mkdirSync(bin, { recursive: true })
  exe(join(home, ".local/share/piper-tts/venv/bin/piper"), "#!/bin/bash\ncat >/dev/null\n")
  exe(join(home, ".local/share/chatterbox-tts/speak-clone"), "#!/bin/bash\ncat >/dev/null\n")
  exe(join(bin, "aplay"), "#!/bin/bash\ncat >/dev/null\n")

  const model = (name, rate) => {
    writeFileSync(join(piperDir, name + ".onnx"), "")
    writeFileSync(join(piperDir, name + ".onnx.json"), JSON.stringify({ audio: { sample_rate: rate } }))
  }
  for (const name of safePiper) model(name, 22050)
  for (const name of unsafeNames) model(name, 22050)
  model("rate-string", "22050; touch clippy-pwned")
  model("rate-fraction", 22050.5)
  model("rate-negative", -1)
  model("rate-huge", 12345678)
  model("rate-missing", null)

  for (const name of [...safeClones, ...unsafeNames, "dot.ted"]) writeFileSync(join(voiceDir, name + ".wav"), "")

  const env = { HOME: home, PATH: `${bin}:${process.env.PATH}`, LC_ALL: "C.UTF-8" }

  // 1. What the picker gets offered.
  const scan = spawnSync(join(repo, "scripts/voice-scan"), { env, encoding: "utf8" })
  let inv = null
  try { inv = JSON.parse(scan.stdout) } catch (e) { check(false, `voice-scan's output isn't JSON: ${e.message}: ${scan.stdout}`) }
  if (inv) {
    const piper = inv.piper.map(v => v.name).sort()
    check(JSON.stringify(piper) === JSON.stringify([...safePiper].sort()), `voice-scan offers these piper voices: ${JSON.stringify(piper)}`)
    check(inv.piper.every(v => v.rate === 22050), `a piper rate came through wrong: ${JSON.stringify(inv.piper)}`)
    check(JSON.stringify([...inv.clones].sort()) === JSON.stringify([...safeClones].sort()), `voice-scan offers these clones: ${JSON.stringify(inv.clones)}`)
  }

  // 2. The real builders, cut out of Clippy.qml. They are plain functions over
  // homeDir, so they run here as they are.
  const qml = readFileSync(join(repo, "Clippy.qml"), "utf8")
  const from = qml.indexOf("  function cloneNameOk(")
  const to = qml.indexOf("  // The tts value, as a name")
  if (from < 0 || to < from) throw new Error("the builders moved in Clippy.qml; update the markers here")
  const { cloneCmd, piperCmd, piperPipe, ttsCmdSafe } = new Function("homeDir",
    qml.slice(from, to) + "\nreturn { cloneCmd, piperCmd, piperPipe, ttsCmdSafe }")(home)

  for (const name of unsafeNames) {
    check(piperCmd(name, 22050) === "", `piperCmd took the name ${JSON.stringify(name)}`)
    check(piperPipe(name, 22050) === "", `piperPipe took the name ${JSON.stringify(name)}`)
    check(cloneCmd(name) === "", `cloneCmd took the name ${JSON.stringify(name)}`)
  }
  check(cloneCmd("dot.ted") === "", "cloneCmd took a dotted name")
  for (const rate of ["22050; touch x", "22050 ", "1e3", "-1", "0", "22050.5", "1234567", "", "$(id)"])
    check(piperCmd("safe-name", rate) === "", `piperCmd took the rate ${JSON.stringify(rate)}`)

  for (const name of safePiper) {
    check(piperCmd(name, 22050) !== "" && ttsCmdSafe(piperCmd(name, 22050)), `a safe piper voice was turned down: ${name}`)
    check(ttsCmdSafe(piperPipe(name, 22050)), `a safe bare piper pipeline was turned down: ${name}`)
  }
  for (const name of safeClones) {
    check(cloneCmd(name) !== "" && ttsCmdSafe(cloneCmd(name)), `a safe clone was turned down: ${name}`)
    check(ttsCmdSafe(cloneCmd(name) + " --tempo 1.1 --pitch 0.9"), `a tuned clone was turned down: ${name}`)
  }
  for (const own of [true, false, "", "exec espeak-ng -v en-gb", "foo | aplay -q", `KOKORO_VOICE=am_adam ${home}/.local/share/kokoro-tts/say.py | aplay -q -`])
    check(ttsCmdSafe(own), `a command of your own was turned down: ${JSON.stringify(own)}`)

  // A clone's knobs are the one thing past the name a string may carry, and
  // only as numbers.
  const clone = cloneCmd("george")
  for (const tail of [` --tempo 1; ${payload}`, ` --tempo $(${payload})`, ` --tempo 1 & ${payload}`, ` | ${payload}`, ` --other 1`, `\n${payload}`])
    check(!ttsCmdSafe(clone + tail), `the gate let a clone string carry ${JSON.stringify(tail)}`)

  // The strings the picker built before v1.55.2, word for word.
  const pp = `${home}/.local/share/piper-tts/venv/bin/piper -m ${home}/.local/share/piper-voices/`
  const oldBare = name => `${pp}${name}.onnx --output-raw 2>/dev/null | aplay -q -t raw -r 22050 -f S16_LE -c 1 -`
  const oldPiper = name => `trap 'kill $! 2>/dev/null' TERM; ${oldBare(name)} & wait $!`
  const oldClone = name => `exec ${home}/.local/share/chatterbox-tts/speak-clone --ref ${home}/.local/share/chatterbox-tts/voices/${name}.wav --exag 0.5 --cfg 0.5`
  const oldStrings = hostile.flatMap(name => [oldPiper(name), oldBare(name), oldClone(name)])
  for (const old of oldStrings) check(!ttsCmdSafe(old), `the gate let this through: ${JSON.stringify(old)}`)

  // 3. Bash itself. launchTts runs a string only when ttsCmdSafe says so.
  const bash = cmd => spawnSync("bash", ["-c", cmd], { env, input: "hello\n", cwd: box, timeout: 10000 })
  let live = 0
  for (const old of oldStrings) {
    rmSync(marker, { force: true })
    bash(old)
    if (existsSync(marker)) live++
    rmSync(marker, { force: true })
    if (ttsCmdSafe(old)) bash(old)
    check(!existsSync(marker), `the payload ran through the gate: ${JSON.stringify(old)}`)
  }
  check(live > 0, "no payload ran even without the gate, so this test proves nothing")
  console.log(`${failures ? "FAILED" : "ok"}: ${passes} checks passed, ${failures} failed; ${live} of ${oldStrings.length} old strings run their payload with no gate, none with it`)
} finally {
  rmSync(box, { recursive: true, force: true })
}
process.exit(failures ? 1 : 0)
