import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: control

  property string iconText: ""
  property string tooltipText: ""
  property bool checked: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property real iconGap: Style.spaceReal(7.5)

  signal toggled()

  // Fixed row width keeps both boxes aligned against the header's right edge.
  implicitWidth: box.width * 2 + Style.spaceReal(7.5)
  implicitHeight: box.height

  // A checkbox-sized icon slot gives both weather glyphs identical geometry,
  // regardless of their individual bearings inside the font.
  Item {
    id: iconSlot
    anchors.right: box.left
    anchors.rightMargin: control.iconGap
    anchors.verticalCenter: parent.verticalCenter
    width: box.width
    height: box.height

    Text {
      id: icon
      anchors.centerIn: parent
      text: control.iconText
      color: control.foreground
      font.family: control.fontFamily
      font.pixelSize: box.height * 0.9
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }

  Rectangle {
    id: box
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(17)
    height: width
    radius: Style.cornerRadius > 0 ? 4 : 0
    // Use the exact selected-row fill from Wi-Fi for the unchecked surface
    // and persistent border; checked still resolves to full foreground.
    readonly property color wifiSelectedColor: Style.selectedFillFor(control.foreground, Color.accent)
    color: control.checked
      ? control.foreground
      : wifiSelectedColor
    border.width: Math.max(4, Style.normalBorderWidth * 2)
    border.color: wifiSelectedColor

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: control.toggled()
  }

  PanelToolTip {
    visible: mouse.containsMouse
    text: control.tooltipText
    fontFamily: control.fontFamily
  }
}
