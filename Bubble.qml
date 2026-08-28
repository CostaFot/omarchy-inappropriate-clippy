import QtQuick
import qs.Commons

// Speech bubble with a tail pointing at Clippy. The tail is a rotated square
// drawn *behind* the body so only its outer edges (and border) show.
Item {
  id: root

  property string text: ""
  property bool shown: false
  // How long a show/hide takes. The fling stretches the hide so his last
  // word trails off after he's gone.
  property int fadeMs: 140
  property bool above: false          // bottom bar: tail on the bottom edge
  property real tailX: width / 2      // local x the tail points at
  property int maxWidth: 320
  readonly property int tailSize: 7
  readonly property int pad: 8

  signal dismissed()

  implicitWidth: body.width
  implicitHeight: body.height + tailSize
  width: implicitWidth
  height: implicitHeight
  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: root.fadeMs } }

  Text {
    id: metrics
    visible: false
    text: root.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  // Two tails: a bordered one behind the body for the outline, and a
  // borderless one on top that hides the body's border where the tail joins.
  readonly property real tailLeft: Math.round(Math.max(pad, Math.min(body.width - pad - tailSize * 2, tailX - tailSize)))

  Rectangle {
    id: tail
    z: 0
    width: root.tailSize * 2
    height: root.tailSize * 2
    rotation: 45
    x: root.tailLeft
    y: root.above ? body.height - root.tailSize : 0
    color: Color.tooltip.background
    border.color: Color.tooltip.border
    border.width: 1
    antialiasing: true
  }

  Rectangle {
    z: 2
    width: tail.width - 3
    height: tail.height - 3
    rotation: 45
    x: tail.x + 1.5
    y: tail.y + 1.5
    color: Color.tooltip.background
    antialiasing: true
  }

  Rectangle {
    id: body
    z: 1
    y: root.above ? 0 : root.tailSize
    width: label.width + root.pad * 2
    height: label.height + root.pad * 2
    radius: Math.max(2, Style.cornerRadius)
    color: Color.tooltip.background
    border.color: Color.tooltip.border
    border.width: 1

    Text {
      id: label
      x: root.pad
      y: root.pad
      width: Math.min(metrics.implicitWidth, root.maxWidth)
      wrapMode: Text.WordWrap
      text: root.text
      color: Color.tooltip.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.dismissed()
    }
  }
}
