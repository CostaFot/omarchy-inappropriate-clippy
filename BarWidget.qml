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
// the click goes over IPC instead, the `showMenuAt` verb carrying this
// bar's x and monitor. The icon has no state of its own and shows none: it
// used to fade while he was dead or hidden, which nobody missed when the
// facade took it away (COS-157).
BarWidget {
  id: root
  moduleName: "costafot.clippy"

  readonly property var clippy: {
    var sh = bar ? bar.shell : null
    var loaders = sh ? sh.panelLoaders : null
    var loader = loaders ? loaders[moduleName] : null
    return loader && loader.item ? loader.item : null
  }

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
    tooltipText: "Inappropriate Clippy"
    onPressed: root.showMenu()
  }
}
