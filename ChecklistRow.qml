import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: row

  property string label: ""
  property string hint: ""
  property bool checked: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal toggled()

  implicitHeight: Style.space(48)
  radius: Style.cornerRadius
  color: mouse.containsMouse
    ? Style.hoverFillFor(foreground, Color.accent)
    : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.045)
  border.width: Style.spacing.hairline
  border.color: checked
    ? Style.normalBorderFor(foreground, Color.accent)
    : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.1)

  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(14)
    anchors.rightMargin: Style.space(14)
    spacing: Style.space(12)

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(22)
      height: width
      radius: Style.cornerRadius > 0 ? 5 : 0
      color: row.checked
        ? Style.selectedStateColor(row.foreground, Color.accent)
        : "transparent"
      border.width: Style.spacing.hairline
      border.color: row.checked
        ? Style.normalBorderFor(row.foreground, Color.accent)
        : Qt.darker(row.foreground, 1.55)

      Text {
        visible: row.checked
        anchors.centerIn: parent
        text: "✓"
        color: row.foreground
        font.family: row.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        text: row.label
        color: row.checked ? Qt.darker(row.foreground, 1.45) : row.foreground
        font.family: row.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        font.strikeout: row.checked
      }

      Text {
        visible: text !== ""
        text: row.hint
        color: Qt.darker(row.foreground, 1.65)
        font.family: row.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.toggled()
  }
}
