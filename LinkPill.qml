import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: pill

  property string label: "Open"
  property string url: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal requested(string url)

  implicitWidth: labelText.implicitWidth + Style.space(22)
  implicitHeight: Style.space(30)
  radius: Style.cornerRadius > 0 ? implicitHeight / 2 : 0
  color: mouse.containsMouse
    ? Style.hoverFillFor(foreground, Color.accent)
    : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.06)
  border.width: Style.spacing.hairline
  border.color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  Text {
    id: labelText
    anchors.centerIn: parent
    text: pill.label + "  󰏌"
    color: mouse.containsMouse
      ? Style.hoverStateColor(pill.foreground, Color.accent)
      : pill.foreground
    font.family: pill.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: pill.requested(pill.url)
  }
}
