import QtQuick
import qs.Commons

// A little headstone where he died, up until the respawn. It joins the
// window's input mask only while shown, and it parks in a widget gap, so
// the sliver of bar it takes clicks from is normally empty anyway; a click
// gets you the epitaph, a right-click the menu.
Item {
  id: root

  // Sized off the sprite so it stays in proportion with him.
  property real size: 30
  property bool shown: false

  signal poked()
  signal menuWanted()

  readonly property int stoneH: Math.max(16, Math.round(size * 0.8))
  readonly property int stoneW: Math.round(stoneH * 0.78)
  readonly property int moundH: Math.max(2, Math.round(stoneH * 0.1))

  implicitWidth: Math.round(stoneW * 1.6)
  implicitHeight: stoneH + Math.round(moundH / 2)
  width: implicitWidth
  height: implicitHeight

  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 500 } }

  // The stone thuds down into the mound when it appears.
  property real drop: 0
  onShownChanged: if (shown) { thud.stop(); drop = -stoneH * 0.5; thud.start() }
  NumberAnimation {
    id: thud
    target: root
    property: "drop"
    to: 0
    duration: 450
    easing.type: Easing.OutBounce
  }

  Rectangle {
    id: stone
    x: Math.round((root.width - width) / 2)
    y: root.height - height - Math.round(root.moundH / 2) + root.drop
    width: root.stoneW
    height: root.stoneH
    topLeftRadius: width / 2
    topRightRadius: width / 2
    bottomLeftRadius: 2
    bottomRightRadius: 2
    color: Color.tooltip.background
    border.color: Color.tooltip.border
    border.width: 1

    // The engraving: the bar icon's paperclip over RIP. Squint-sized at the
    // default `size`, but so is he; it grows with him.
    Column {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: Math.round(stone.height * 0.04)
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "󰏢"
        color: Color.tooltip.text
        opacity: 0.85
        font.family: Style.font.family
        font.pixelSize: Math.max(7, Math.round(root.stoneH * 0.34))
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "RIP"
        color: Color.tooltip.text
        opacity: 0.85
        font.family: Style.font.family
        font.pixelSize: Math.max(5, Math.round(root.stoneH * 0.2))
        font.bold: true
        font.letterSpacing: 1
      }
    }
  }

  // The mound he's under.
  Rectangle {
    y: root.height - root.moundH
    width: root.width
    height: root.moundH
    radius: root.moundH / 2
    color: Color.tooltip.border
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function (mouse) {
      if (mouse.button === Qt.RightButton) root.menuWanted()
      else root.poked()
    }
  }
}
