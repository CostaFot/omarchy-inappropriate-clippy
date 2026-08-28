// Clippy's menu: right-click on him, or the bar icon (BarWidget.qml).
//
// A full-screen transparent layer with a small card near the anchor. Full
// screen is what makes click-anywhere-to-dismiss work — the surface has to
// receive the click that closes it. It carries an input region only while
// open, so a closed menu is indistinguishable from not being here, and it
// never takes keyboard focus.
//
// `clippy` is the root Item of Clippy.qml. Actions go out as `act(name)`,
// setting changes as `chose(key, value)`; the owner decides what to do.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: menu

  property var clippy: null
  property bool open: false
  // X along the bar the card should sit under (screen coordinates), and the
  // monitor that is on. Null means Clippy's own; the bar icon sets it, since
  // there is a bar on every monitor and he is only on one.
  property real anchorPos: 0
  property var anchorScreen: null
  onOpenChanged: if (!open) anchorScreen = null

  signal act(string name)
  signal chose(string key, var value)

  visible: open && clippy !== null
  screen: anchorScreen ? anchorScreen : (clippy ? clippy.targetScreen : null)
  color: "transparent"

  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "costafot-clippy-menu"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors { top: true; bottom: true; left: true; right: true }

  mask: Region {
    width: menu.open ? menu.width : 0
    height: menu.open ? menu.height : 0
  }

  function pick(name) { menu.open = false; menu.act(name) }
  function set(key, value) { menu.open = false; menu.chose(key, value) }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: menu.open = false
  }

  Rectangle {
    id: card

    readonly property int pad: Style.space(10)
    readonly property int gap: Style.space(6)
    readonly property int edge: Style.space(8)
    readonly property bool underBar: menu.clippy ? menu.clippy.barBottom : false
    // Killed or hidden: the menu is how you get him back, so say so.
    readonly property bool gone: menu.open && menu.clippy
      ? (menu.clippy.mood === "dead" || menu.clippy.opened !== true) : false
    // Clear the bar or Clippy, whichever pokes out further.
    readonly property int clearance: menu.clippy ? Math.max(menu.clippy.barSize, menu.clippy.actorHeight) : 26
    readonly property int rowWidth: Style.space(270)
    readonly property real fontSize: Style.font.bodySmall
    readonly property color fill: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.10)
    readonly property color selectedFill: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.20)

    color: Color.popups.background
    border.color: Color.popups.border
    border.width: 1
    radius: Style.cornerRadius
    width: column.implicitWidth + pad * 2
    height: column.implicitHeight + pad * 2

    x: Math.max(edge, Math.min(menu.width - width - edge, menu.anchorPos - width / 2))
    y: underBar ? menu.height - height - clearance - gap : clearance + gap

    Column {
      id: column
      x: card.pad
      y: card.pad
      spacing: Style.space(2)

      Text {
        text: "Inappropriate Clippy"
        color: Color.popups.text
        opacity: 0.55
        font.family: Style.fontFamily
        font.pixelSize: card.fontSize
        bottomPadding: Style.space(4)
      }

      // One full-width tappable row. `mark` is an optional leading glyph.
      component Entry: Rectangle {
        id: row
        property string label: ""
        property string mark: ""
        property bool active: false
        signal tapped()

        width: card.rowWidth
        implicitHeight: rowText.implicitHeight + Style.space(9)
        radius: Style.cornerRadius
        color: rowHover.hovered ? card.fill : "transparent"

        Text {
          id: rowText
          x: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: (row.mark !== "" ? row.mark + " " : "") + row.label
          color: Color.popups.text
          opacity: row.active ? 1.0 : 0.75
          font.family: Style.fontFamily
          font.pixelSize: card.fontSize
        }

        HoverHandler { id: rowHover }
        TapHandler { onTapped: row.tapped() }
      }

      // A labelled group of mutually exclusive chips.
      component Choice: Item {
        id: choice
        property string label: ""
        property var options: []   // [{ label, value }]
        property int current: -1
        signal picked(var value)

        width: card.rowWidth
        implicitHeight: choiceLabel.implicitHeight + chips.implicitHeight + Style.space(10)

        Text {
          id: choiceLabel
          x: Style.space(8)
          y: Style.space(4)
          text: choice.label
          color: Color.popups.text
          opacity: 0.55
          font.family: Style.fontFamily
          font.pixelSize: card.fontSize
        }

        Flow {
          id: chips
          x: Style.space(8)
          anchors.top: choiceLabel.bottom
          anchors.topMargin: Style.space(3)
          width: parent.width - Style.space(16)
          spacing: Style.space(4)

          Repeater {
            model: choice.options
            delegate: Rectangle {
              id: chip
              required property var modelData
              required property int index
              readonly property bool selected: index === choice.current
              width: chipText.implicitWidth + Style.space(14)
              height: chipText.implicitHeight + Style.space(6)
              radius: Style.cornerRadius
              color: selected ? card.selectedFill : (chipHover.hovered ? card.fill : "transparent")
              border.width: 1
              border.color: Color.popups.border
              Text {
                id: chipText
                anchors.centerIn: parent
                text: chip.modelData.label
                color: Color.popups.text
                opacity: chip.selected ? 1.0 : 0.7
                font.family: Style.fontFamily
                font.pixelSize: card.fontSize
              }
              HoverHandler { id: chipHover }
              TapHandler { onTapped: choice.picked(chip.modelData.value) }
            }
          }
        }
      }

      component Divider: Rectangle {
        width: card.rowWidth; height: 1
        color: Color.popups.border; opacity: 0.4
      }

      // ---- actions -------------------------------------------------------
      Entry {
        visible: !card.gone
        label: menu.open && menu.clippy && menu.clippy.talking ? "Shut up" : "Say something"
        onTapped: menu.pick(menu.clippy && menu.clippy.talking ? "shutUp" : "say")
      }
      Entry {
        visible: !card.gone
        label: menu.open && menu.clippy && menu.clippy.isSnoozed() ? "Wake him up" : "Snooze for an hour"
        onTapped: menu.pick(menu.clippy && menu.clippy.isSnoozed() ? "unsnooze" : "snooze")
      }
      Entry {
        label: {
          if (card.gone) return "Bring him back"
          var s = menu.clippy ? menu.clippy.respawnSeconds : 0
          return s > 0 ? "Kill him (back in " + Math.round(s / 60) + " min)" : "Kill him"
        }
        onTapped: menu.pick(card.gone ? "revive" : "kill")
      }

      Divider {}

      // ---- settings ------------------------------------------------------
      Entry {
        readonly property bool on: menu.clippy ? menu.clippy.clean : false
        label: "Clean mode"
        mark: on ? "●" : "○"
        active: on
        onTapped: menu.set("clean", !on)
      }
      Entry {
        readonly property bool on: menu.clippy ? menu.clippy.aiEnabled : false
        readonly property string agent: menu.clippy ? menu.clippy.aiAgentName : ""
        // The model shows when one is set; unset is the agent's own default.
        readonly property string model_name: menu.clippy ? menu.clippy.aiModel : ""
        label: "Lines from " + (agent !== "" ? agent : "your AI agent") + (model_name !== "" ? " · " + model_name : "")
        mark: on ? "●" : "○"
        active: on
        onTapped: menu.set("ai", !on)
      }
      Entry {
        readonly property bool on: menu.clippy ? menu.clippy.slapSoundOn : true
        label: "Sounds"
        mark: on ? "●" : "○"
        active: on
        onTapped: menu.set("slapSound", !on)
      }
      Entry {
        readonly property bool on: menu.clippy ? menu.clippy.ttsOn : false
        readonly property bool needs: menu.clippy ? menu.clippy.ttsNeedsEngine : false
        label: needs ? "Voice · install espeak-ng" : "Voice"
        mark: on ? "●" : "○"
        active: on
        onTapped: menu.set("tts", !on)
      }
      Choice {
        label: "Walks"
        options: [
          { label: "rarely", value: 0.1 },
          { label: "sometimes", value: 0.3 },
          { label: "constantly", value: 1 }
        ]
        current: {
          var r = menu.clippy ? menu.clippy.restless : 0.3
          return r <= 0.15 ? 0 : (r < 0.6 ? 1 : 2)
        }
        onPicked: function (value) { menu.set("restless", value) }
      }
      Choice {
        label: "Size"
        options: [
          { label: "small", value: 24 },
          { label: "normal", value: 30 },
          { label: "big", value: 44 }
        ]
        current: {
          var s = menu.clippy ? menu.clippy.spriteSize : 30
          return s <= 26 ? 0 : (s <= 36 ? 1 : 2)
        }
        onPicked: function (value) { menu.set("size", value) }
      }

      Divider {}

      // The body count.
      Text {
        readonly property int slaps: menu.clippy ? menu.clippy.slapCount : 0
        readonly property int kills: menu.clippy ? menu.clippy.killCount : 0
        text: slaps + (slaps === 1 ? " slap" : " slaps") + " · " + kills + (kills === 1 ? " kill" : " kills")
        color: Color.popups.text
        opacity: 0.55
        font.family: Style.fontFamily
        font.pixelSize: card.fontSize
        topPadding: Style.space(4)
      }
    }
  }
}
