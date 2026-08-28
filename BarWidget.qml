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
// loaded; we reach it through the shell's panel loader table, the same
// object the shell routes summon/hide/toggle through.
BarWidget {
  id: root
  moduleName: "costafot.clippy"

  readonly property var clippy: {
    var sh = bar ? bar.shell : null
    var loaders = sh ? sh.panelLoaders : null
    var loader = loaders ? loaders[moduleName] : null
    return loader && loader.item ? loader.item : null
  }
  readonly property bool dead: clippy ? clippy.mood === "dead" : false
  readonly property bool hiding: clippy ? clippy.opened !== true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function showMenu() {
    if (!clippy) {
      // Panel not mounted yet. IPC still works; it anchors under the actor.
      if (bar) bar.run("omarchy-shell costafot.clippy showMenu")
      return
    }
    // The bar window spans the screen, so window x is screen x. The menu
    // goes on this bar's monitor, which need not be the one Clippy is on.
    var win = button.QsWindow.window
    var p = button.mapToItem(null, button.width / 2, 0)
    clippy.showMenuAt(p.x, win ? win.screen : null)
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
