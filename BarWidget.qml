import QtQuick
import Quickshell
import qs.Ui

// The bar icon: a paperclip that opens Clippy's menu. It exists mainly so
// there is a way to bring him back after you kill him (or hide him) — the
// menu normally lives on a right-click of the actor, and a dead Clippy has
// no actor to right-click.
//
// The bar mounts one of these per monitor. Clippy himself, his menu and his
// state live in the panel (Clippy.qml), a single instance the shell keeps
// loaded. On omarchy ≤ 4.0.2 we reach it through the shell's panel loader
// table, the same object the shell routes summon/hide/toggle through. From
// 4.0.3 `bar.shell` is a capability-scoped facade with no such table, so
// the panel is out of reach and two things stand in: `isPluginOpen` on our
// own id, which the facade does allow, for the hidden dim; and the
// `showMenuAt` IPC verb, carrying this bar's x and monitor, for the click.
// Dead-state dimming has no facade route and is not attempted there.
BarWidget {
  id: root
  moduleName: "costafot.clippy"

  readonly property var clippy: {
    var sh = bar ? bar.shell : null
    var loaders = sh ? sh.panelLoaders : null
    var loader = loaders ? loaders[moduleName] : null
    return loader && loader.item ? loader.item : null
  }
  // `isPluginOpen` is a function, not a property, so nothing re-evaluates
  // when he hides; a once-a-second call is a JS call, no fork.
  property bool facadeHiding: false
  function pollOpen() {
    var sh = bar ? bar.shell : null
    if (clippy || !sh || typeof sh.isPluginOpen !== "function") { facadeHiding = false; return }
    facadeHiding = sh.isPluginOpen(moduleName) !== true
  }
  Timer {
    interval: 1000
    repeat: true
    running: !root.clippy && root.visible
    triggeredOnStart: true
    onTriggered: root.pollOpen()
  }
  readonly property bool dead: clippy ? clippy.mood === "dead" : false
  readonly property bool hiding: clippy ? clippy.opened !== true : facadeHiding

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function showMenu() {
    // The bar window spans the screen, so window x is screen x. The menu
    // goes on this bar's monitor, which need not be the one Clippy is on.
    var win = button.QsWindow.window
    var p = button.mapToItem(null, button.width / 2, 0)
    if (clippy) { clippy.showMenuAt(p.x, win ? win.screen : null); return }
    // Panel unreachable (the facade) or not mounted yet: IPC, with the same
    // two facts, so the card still lands under this icon on this screen.
    var screen = win && win.screen ? String(win.screen.name || "") : ""
    if (bar) bar.run("omarchy-shell costafot.clippy showMenuAt " + Math.round(p.x) + " " + screen)
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰏢"
    dimmed: root.dead || root.hiding
    tooltipText: root.dead ? "Clippy is dead. Bring him back?"
      : (root.hiding ? "Clippy is hiding. Bring him back?" : "Inappropriate Clippy")
    onPressed: root.showMenu()
  }
}
