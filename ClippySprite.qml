import QtQuick
import Quickshell.Io

// Plays clippy.js frame data over the original sprite sheet. One cell per
// frame (Clippy's overlayCount is 1); a frame without `images` hides him.
// The stepper is a port of clippy.js src/animator.js _getNextAnimationFrame:
// exitBranch wins while exiting, then weighted branching, then index + 1.
Item {
  id: root

  property string assetsDir: ""
  property real size: 36

  readonly property int frameW: 124
  readonly property int frameH: 93
  readonly property real ratio: size / frameH

  implicitWidth: Math.round(frameW * ratio)
  implicitHeight: Math.round(size)

  property var animations: ({})
  readonly property bool ready: Object.keys(animations).length > 0
  readonly property var animationNames: Object.keys(animations)

  property string current: ""
  property bool playing: false
  property bool looping: false
  property bool exiting: false
  property bool hidden: true
  property var onDone: null

  property int frameIndex: -1
  property var currentFrame: null
  property var pending: null

  signal finished(string name)

  function has(name) { return animations[name] !== undefined }

  function play(name, loop, done) {
    if (!ready) { pending = { name: name, loop: loop, done: done }; return }
    if (!has(name)) {
      console.warn("clippy: unknown animation " + name)
      if (done) done()
      return
    }
    current = name
    looping = loop === true
    onDone = done || null
    exiting = false
    frameIndex = -1
    currentFrame = null
    playing = true
    tick.stop()
    step()
  }

  // Let a looping animation run out through its exitBranches.
  function exit() {
    looping = false
    exiting = true
  }

  function stop() {
    tick.stop()
    playing = false
    onDone = null
    showRest()
  }

  function showRest() {
    hidden = false
    sheet.x = 0
    sheet.y = 0
  }

  function nextIndex() {
    if (!currentFrame) return 0
    if (exiting && currentFrame.exitBranch !== undefined) return currentFrame.exitBranch
    var branching = currentFrame.branching
    if (branching && branching.branches) {
      var rnd = Math.random() * 100
      for (var i = 0; i < branching.branches.length; i++) {
        var branch = branching.branches[i]
        if (rnd <= branch.weight) return branch.frameIndex
        rnd -= branch.weight
      }
    }
    return frameIndex + 1
  }

  function step() {
    if (!playing || !has(current)) return
    var frames = animations[current].frames
    var last = frames.length - 1
    var next = Math.min(nextIndex(), last)
    frameIndex = next
    currentFrame = frames[next]
    draw(currentFrame)
    var duration = Math.max(16, Number(currentFrame.duration) || 100)
    if (next === last) {
      if (looping && !exiting) {
        currentFrame = null
        tick.interval = duration
        tick.start()
        return
      }
      playing = false
      tick.interval = duration
      tick.start()
      var name = current
      var cb = onDone
      onDone = null
      finished(name)
      if (cb) cb()
      return
    }
    tick.interval = duration
    tick.start()
  }

  function draw(frame) {
    if (!frame.images || !frame.images.length) {
      hidden = true
      return
    }
    hidden = false
    sheet.x = -frame.images[0][0]
    sheet.y = -frame.images[0][1]
  }

  Timer {
    id: tick
    repeat: false
    onTriggered: if (root.playing) root.step()
  }

  FileView {
    path: root.assetsDir + "/agent.json"
    printErrors: true
    onLoaded: {
      try {
        var data = JSON.parse(text())
        root.animations = data.animations || {}
      } catch (e) {
        console.warn("clippy: failed to parse agent.json: " + e)
        root.animations = {}
      }
    }
  }

  onReadyChanged: {
    if (!ready) return
    if (pending) {
      var p = pending
      pending = null
      play(p.name, p.loop, p.done)
    } else if (!playing) {
      showRest()
    }
  }

  Item {
    id: viewport
    width: root.frameW
    height: root.frameH
    clip: true
    scale: root.ratio
    transformOrigin: Item.TopLeft
    visible: !root.hidden

    Image {
      id: sheet
      source: root.assetsDir !== "" ? "file://" + root.assetsDir + "/map.png" : ""
      asynchronous: true
      cache: true
      smooth: true
      mipmap: true
      fillMode: Image.Pad
    }
  }
}
