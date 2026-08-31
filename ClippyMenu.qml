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
        textFormat: Text.PlainText
        text: "Inappropriate Clippy"
        color: Color.popups.text
        opacity: 0.55
        font.family: Style.fontFamily
        font.pixelSize: card.fontSize
        bottomPadding: Style.space(4)
      }

      // One full-width tappable row. `mark` is an optional leading glyph,
      // `hint` an optional dim second line (the Voice row's setup-voice nudge).
      component Entry: Rectangle {
        id: row
        property string label: ""
        property string mark: ""
        property string hint: ""
        property bool active: false
        signal tapped()

        width: card.rowWidth
        implicitHeight: rowLines.implicitHeight + Style.space(9)
        radius: Style.cornerRadius
        color: rowHover.hovered ? card.fill : "transparent"

        Column {
          id: rowLines
          x: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            textFormat: Text.PlainText
            text: (row.mark !== "" ? row.mark + " " : "") + row.label
            color: Color.popups.text
            opacity: row.active ? 1.0 : 0.75
            font.family: Style.fontFamily
            font.pixelSize: card.fontSize
          }
          Text {
            textFormat: Text.PlainText
            visible: row.hint !== ""
            text: row.hint
            color: Color.popups.text
            opacity: 0.45
            font.family: Style.fontFamily
            font.pixelSize: card.fontSize - 2
          }
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
          textFormat: Text.PlainText
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
                textFormat: Text.PlainText
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
      // Only while the agent lines are on — the look runs through the
      // agent, so without it the row would do nothing.
      Entry {
        visible: !card.gone && menu.clippy && menu.clippy.aiEnabled === true
        label: menu.clippy && menu.clippy.looking ? "Judging…" : "Judge my screen"
        onTapped: menu.pick("look")
      }
      // Same gate plus working ears — without voxtype the row would do
      // nothing (reply-by-text stays IPC-only: the menu takes no keyboard
      // focus, by design rule). Tapping "Listening…" is the stop toggle.
      Entry {
        visible: !card.gone && menu.clippy && menu.clippy.aiEnabled === true
                 && menu.clippy.voxtypeMissing === false
        label: menu.clippy && menu.clippy.listening ? "Listening…"
             : menu.clippy && menu.clippy.replying ? "Thinking…"
             : "Say it to his face"
        onTapped: menu.pick("listen")
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
        readonly property bool on: menu.clippy ? menu.clippy.gagsEnabled : true
        label: "Full-screen gags"
        mark: on ? "●" : "○"
        active: on
        onTapped: menu.set("gags", !on)
      }
      // On/off only — the ratio is set duck <0-1> by IPC, no chips
      // ("the ratio should be done via terminal/agent only").
      Entry {
        readonly property bool on: menu.clippy ? menu.clippy.duckOn : true
        label: "Duck other audio"
        mark: on ? "●" : "○"
        active: on
        onTapped: menu.set("duckOn", !on)
      }
      Entry {
        readonly property bool on: menu.clippy ? menu.clippy.leaderboardOn : true
        label: "Online leaderboard"
        mark: on ? "●" : "○"
        active: on
        onTapped: menu.set("graveyardOn", !on)
      }
      // The toggle gates the name: while posting, say who as — the shared
      // alias by default — and (anonymous only, the stranded-audience rule)
      // how to claim a stone. The menu can't take a free-text handle, so it
      // points at the agent/terminal.
      Text {
        textFormat: Text.PlainText
        visible: menu.clippy ? menu.clippy.leaderboardOn : false
        text: menu.clippy && menu.clippy.leaderboardNamed
          ? "as " + menu.clippy.leaderboardHandle
          : "as " + (menu.clippy ? menu.clippy.lbAnonHandle : "") + " — set leaderboard <name> to claim a stone (ask your agent)"
        width: card.rowWidth
        wrapMode: Text.WordWrap
        color: Color.popups.text
        opacity: 0.45
        font.family: Style.fontFamily
        font.pixelSize: card.fontSize - 2
        leftPadding: Style.space(8)
        rightPadding: Style.space(8)
        bottomPadding: Style.space(3)
      }
      // The voice picker: every voice already on disk, as chips — a tap is an
      // instant `set tts` write (applyVoice, same resolver as IPC useVoice).
      // Installing NEW voices stays with scripts/setup-voice; a menu tap
      // must never start a 2 GB download.
      Choice {
        label: menu.open && menu.clippy && menu.clippy.ttsNeedsEngine
          ? "Voice · the robot needs espeak-ng" : "Voice"
        options: menu.open && menu.clippy
          ? menu.clippy.voiceOptions.map(function (v) { return { label: v, value: v } }) : []
        current: menu.open && menu.clippy
          ? menu.clippy.voiceOptions.indexOf(menu.clippy.currentVoiceId) : -1
        onPicked: function (value) { menu.set("voice", value) }
      }
      Text {
        textFormat: Text.PlainText
        // The robot chips are the floor — tell the audience that has nothing
        // better installed where the real voices come from.
        readonly property var inv: menu.open && menu.clippy ? menu.clippy.voiceInv : null
        visible: inv !== null && !(inv.kokoro || (inv.gpu && inv.clones.length > 0) || inv.piper.length > 0)
        text: "better voices: scripts/setup-voice in the plugin dir"
        color: Color.popups.text
        opacity: 0.45
        font.family: Style.fontFamily
        font.pixelSize: card.fontSize - 2
        leftPadding: Style.space(8)
        bottomPadding: Style.space(3)
      }
      // The clone bend (v1.26.0): cloneTempo/clonePitch as preset chips.
      // Only while a speak-clone voice is the one talking — for every other
      // voice the keys do nothing, so the rows would be dead weight. An
      // off-preset value set over IPC just highlights the nearest chip,
      // the Size row's rule.
      Choice {
        visible: menu.open && menu.clippy ? menu.clippy.cloneKnobsApply : false
        label: "Tempo"
        options: [
          { label: "slow", value: 0.9 },
          { label: "normal", value: 1 },
          { label: "brisk", value: 1.1 },
          { label: "fast", value: 1.25 }
        ]
        current: {
          var t = menu.clippy ? menu.clippy.cloneTempo : 1
          return t <= 0.95 ? 0 : (t < 1.05 ? 1 : (t < 1.18 ? 2 : 3))
        }
        onPicked: function (value) { menu.set("cloneTempo", value) }
      }
      Choice {
        visible: menu.open && menu.clippy ? menu.clippy.cloneKnobsApply : false
        label: "Pitch"
        options: [
          { label: "deep", value: 0.85 },
          { label: "normal", value: 1 },
          { label: "light", value: 1.15 },
          { label: "squeaky", value: 1.35 }
        ]
        current: {
          var p = menu.clippy ? menu.clippy.clonePitch : 1
          return p <= 0.92 ? 0 : (p < 1.07 ? 1 : (p < 1.25 ? 2 : 3))
        }
        onPicked: function (value) { menu.set("clonePitch", value) }
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

      // The body count, plus the graveyard rank when he's on the board.
      Text {
        textFormat: Text.PlainText
        readonly property int slaps: menu.clippy ? menu.clippy.slapCount : 0
        readonly property int kills: menu.clippy ? menu.clippy.killCount : 0
        readonly property var lb: menu.clippy ? menu.clippy.lbCache : null
        text: slaps + (slaps === 1 ? " slap" : " slaps") + " · " + kills + (kills === 1 ? " kill" : " kills")
          + (lb && lb.rank ? " · #" + lb.rank + " as " + lb.handle : "")
        color: Color.popups.text
        opacity: 0.55
        font.family: Style.fontFamily
        font.pixelSize: card.fontSize
        topPadding: Style.space(4)
      }

    }
  }
}
