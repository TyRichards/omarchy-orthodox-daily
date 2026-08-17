import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: card

  property string title: ""
  property string subtitle: ""
  property string body: ""
  property string externalUrl: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property bool expanded: false

  signal externalRequested(string url)

  implicitHeight: content.implicitHeight + Style.space(24)
  radius: Style.cornerRadius
  color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
  border.width: Style.spacing.hairline
  border.color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.1)

  Column {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: card.expanded ? Style.space(12) : 0

    Item {
      width: parent.width
      height: Math.max(titleColumn.implicitHeight, Style.space(28))

      Column {
        id: titleColumn
        anchors.left: parent.left
        anchors.right: actions.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)

        Text {
          width: parent.width
          text: card.title
          color: card.foreground
          font.family: card.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          wrapMode: Text.Wrap
        }

        Text {
          visible: text !== ""
          width: parent.width
          text: card.subtitle
          color: Qt.darker(card.foreground, 1.55)
          font.family: card.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }
      }

      Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Rectangle {
          visible: card.externalUrl !== ""
          width: Style.space(28)
          height: Style.space(28)
          radius: Style.cornerRadius
          color: externalMouse.containsMouse
            ? Style.hoverFillFor(card.foreground, Color.accent)
            : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰏌"
            color: externalMouse.containsMouse
              ? Style.hoverStateColor(card.foreground, Color.accent)
              : Qt.darker(card.foreground, 1.35)
            font.family: card.fontFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: externalMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.externalRequested(card.externalUrl)
          }

          PanelToolTip {
            visible: externalMouse.containsMouse
            text: "Open in browser"
            fontFamily: card.fontFamily
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: card.expanded ? "󰅀" : "󰅂"
          color: Qt.darker(card.foreground, 1.35)
          font.family: card.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      MouseArea {
        anchors.left: parent.left
        anchors.right: actions.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.expanded = !card.expanded
      }
    }

    Text {
      visible: card.expanded
      width: parent.width
      text: card.body || "No text available."
      color: Qt.darker(card.foreground, 1.12)
      font.family: card.fontFamily
      font.pixelSize: Style.font.bodySmall
      lineHeight: 1.25
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }
  }
}
