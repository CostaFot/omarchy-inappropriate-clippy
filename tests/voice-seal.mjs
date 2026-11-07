#!/usr/bin/env node
// A clone install too old to trust can't speak after the plugin mounts
// (#14282). Run: node tests/voice-seal.mjs
//
// It builds a fake HOME, so nothing here touches the real voice. The daemon
// and client are the real ones, cut out of scripts/setup-voice: v1.54.0's and
// v1.54.2's from their tags, the current pair from this tree. The launch
// string is the real cloneCmd out of Clippy.qml, and it goes through bash the
// way launchTts sends it.
//
// A stand-in listener plays the account that bound the socket first. It sits
// in a private $XDG_RUNTIME_DIR rather than at /tmp/clippy-voice.sock, which
// is shared, and it runs as us, so the peer check can't turn it away. That
// makes the first half of each case the control: every client here really
// does hand it the line until the seal runs.

import { spawn, spawnSync } from "node:child_process"
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const repo = join(dirname(fileURLToPath(import.meta.url)), "..")
const box = mkdtempSync(join(tmpdir(), "clippy-voice-seal-"))
const home = join(box, "home")
const run = join(box, "run")
const cb = join(home, ".local/share/chatterbox-tts")
const daemonPath = join(cb, "daemon.py")
const clientPath = join(cb, "speak-clone")
const sock = join(run, "clippy-voice.sock")
const heard = join(box, "heard")
const line = "a private line"

let failures = 0, passes = 0
function check(ok, what) {
  if (ok) { passes++; return }
  failures++
  console.error("FAIL: " + what)
}

function heredoc(setup, target) {
  const open = `cat > "$base/${target}" <<'PY'\n`
  const from = setup.indexOf(open)
  const to = setup.indexOf("\nPY\n", from)
  if (from < 0 || to < 0) throw new Error(`no ${target} heredoc in setup-voice`)
  return setup.slice(from + open.length, to + 1)
}
function pair(setup) {
  return { daemon: heredoc(setup, "daemon.py"), client: heredoc(setup, "speak-clone") }
}
function tagged(tag) {
  const r = spawnSync("git", ["-C", repo, "show", `${tag}:scripts/setup-voice`], { encoding: "utf8", maxBuffer: 1 << 24 })
  if (r.status !== 0) throw new Error(`needs the ${tag} tag and its history: git fetch --tags --unshallow`)
  return pair(r.stdout)
}
const v0 = tagged("v1.54.0")
const v2 = tagged("v1.54.2")
const now = pair(readFileSync(join(repo, "scripts/setup-voice"), "utf8"))

const qml = readFileSync(join(repo, "Clippy.qml"), "utf8")
const from = qml.indexOf("  function cloneNameOk(")
const to = qml.indexOf("  // The tts value, as a name")
if (from < 0 || to < from) throw new Error("the builders moved in Clippy.qml; update the markers here")
const { cloneCmd } = new Function("homeDir", qml.slice(from, to) + "\nreturn { cloneCmd }")(home)
const launch = cloneCmd("george")

const env = { HOME: home, PATH: process.env.PATH, XDG_RUNTIME_DIR: run, LC_ALL: "C.UTF-8" }
const mode = path => statSync(path).mode & 0o777
const nap = ms => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms)
const said = () => existsSync(heard) ? readFileSync(heard, "utf8") : ""
const seal = () => spawnSync(join(repo, "scripts/warm-voice"), ["--seal"], { env, encoding: "utf8" })
const speak = () => spawnSync("bash", ["-c", launch], { env, input: line + "\n", encoding: "utf8", timeout: 20000 })
function clones() {
  const r = spawnSync(join(repo, "scripts/voice-scan"), { env, encoding: "utf8" })
  return JSON.parse(r.stdout).clones
}
function install({ daemon, client }) {
  rmSync(join(home, ".local"), { recursive: true, force: true })
  rmSync(join(home, ".cache"), { recursive: true, force: true })
  rmSync(heard, { force: true })
  mkdirSync(join(cb, "voices"), { recursive: true })
  writeFileSync(join(cb, "voices/george.wav"), "RIFF")
  writeFileSync(daemonPath, daemon)
  writeFileSync(clientPath, client)
  chmodSync(daemonPath, 0o755)
  chmodSync(clientPath, 0o755)
}

const listener = `
import socket, sys
s = socket.socket(socket.AF_UNIX)
s.bind(sys.argv[1])
s.listen(8)
while True:
    c, _ = s.accept()
    data = c.makefile().readline()
    with open(sys.argv[2], "a") as f:
        f.write(data)
    c.sendall(b"err stand-in\\n")
    c.close()
`

let stand = null
try {
  mkdirSync(run, { recursive: true, mode: 0o700 })
  mkdirSync(home, { recursive: true })
  stand = spawn("python3", ["-c", listener, sock, heard], { stdio: "ignore" })
  for (let i = 0; i < 100 && !existsSync(sock); i++) nap(50)
  if (!existsSync(sock)) throw new Error("the stand-in listener never bound")

  // The two facts the finding rests on, read off the real v1.54.0 client.
  check(v0.client.includes('os.environ.get("XDG_RUNTIME_DIR", "/tmp")'), "the v1.54.0 client lost its /tmp fallback, so this isn't the client in the finding")
  check(!v0.client.includes("SO_PEERCRED"), "the v1.54.0 client has a peer check, so this isn't the client in the finding")
  check(!now.client.includes('"/tmp"') && now.client.includes("SO_PEERCRED"), "the current client went back to /tmp or dropped its peer check")

  const cases = [
    ["a v1.54.0 install", v0, true],
    ["a v1.54.2 install", v2, true],
    ["a v1.54.0 client beside a current daemon", { daemon: now.daemon, client: v0.client }, true],
    ["a v1.54.2 client beside a current daemon", { daemon: now.daemon, client: v2.client }, true],
    ["a current client beside a v1.54.0 daemon", { daemon: v0.daemon, client: now.client }, true],
    ["a current install", now, false],
  ]
  for (const [name, files, stale] of cases) {
    install(files)
    speak()
    const before = said()
    check(before.includes(line) && before.includes("george.wav"), `control: ${name} never reached the listener: ${JSON.stringify(before)}`)
    check(clones().includes("george"), `control: ${name} wasn't offered before the seal`)

    const r = seal()
    check(r.status === (stale ? 1 : 0), `${name}: seal exited ${r.status}: ${r.stderr}`)
    check(stale === r.stderr.includes("rerun scripts/setup-voice --clone"), `${name}: seal said ${JSON.stringify(r.stderr)}`)
    for (const path of [daemonPath, clientPath])
      check(mode(path) === (stale ? 0o644 : 0o755), `${name}: ${path} is ${mode(path).toString(8)}`)

    const after = speak()
    if (stale) {
      check(after.status === 126, `${name}: bash exited ${after.status} after the seal: ${after.stderr}`)
      check(said() === before, `${name}: the listener heard more after the seal`)
      check(clones().length === 0, `${name}: still offered after the seal`)
      const warm = spawnSync(join(repo, "scripts/warm-voice"), ["--tts", launch], { env, encoding: "utf8", timeout: 20000 })
      check(warm.status === 1 && warm.stderr.includes("rerun scripts/setup-voice --clone"), `${name}: warm-voice exited ${warm.status}: ${warm.stderr}`)
      check(said() === before, `${name}: warm-voice reached the listener`)
      check(seal().status === 1, `${name}: a second mount lost the refusal`)

      // What a setup-voice rerun does to the two files.
      writeFileSync(daemonPath, now.daemon)
      writeFileSync(clientPath, now.client)
      chmodSync(daemonPath, 0o755)
      chmodSync(clientPath, 0o755)
      check(seal().status === 0 && mode(clientPath) === 0o755, `${name}: a rerun didn't lift the seal`)
      check(clones().includes("george"), `${name}: a rerun didn't bring the clone back`)
    } else {
      check(said().length > before.length, `${name}: the seal stopped a current client`)
      check(clones().includes("george"), `${name}: the seal hid a current clone`)
    }
  }

  // A stray byte can't crash the check and leave the client runnable.
  install(now)
  writeFileSync(clientPath, Buffer.concat([Buffer.from(v0.client), Buffer.from([0xff, 0x0a])]))
  check(seal().status === 1 && mode(clientPath) === 0o644, "a client that isn't valid UTF-8 was left runnable")

  // Half an install: the client alone, then no install at all.
  install(v0)
  rmSync(daemonPath)
  check(seal().status === 1 && mode(clientPath) === 0o644, "a stale client with no daemon was left runnable")
  check(!existsSync(daemonPath), "the seal made a daemon out of nothing")
  rmSync(join(home, ".local"), { recursive: true, force: true })
  const none = seal()
  check(none.status === 0 && !existsSync(cb), `no clone install: seal exited ${none.status}: ${none.stderr}`)

  console.log(`${failures ? "FAILED" : "ok"}: ${passes} checks passed, ${failures} failed; ${cases.filter(c => c[2]).length} stale installs stopped, 1 current left alone`)
} finally {
  if (stand) stand.kill("SIGKILL")
  rmSync(box, { recursive: true, force: true })
}
process.exit(failures ? 1 : 0)
