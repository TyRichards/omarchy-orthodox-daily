import QtQuick
import qs.Commons
import qs.Ui

// Two-option segmented control, used by the calendar settings section
// (tradition: Slavic/Greek, reckoning: Julian/Gregorian).
Column {
  id: group

  property string label: ""
  property var options: []
  property string value: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal selected(string value)

  // Style.selectedStateColor() blends toward accent but stays translucent,
  // which reads fine under a small checkmark glyph elsewhere in this panel
  // but leaves a whole word too low-contrast. Use a solid accent fill for
  // the selected pill instead, with text color picked for contrast against it.
  function contrastingTextColor(bg) {
    var luminance = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
    return luminance > 0.6 ? "#151515" : "#ffffff"
  }

  spacing: Style.space(5)

  Text {
    width: parent.width
    text: group.label
    color: Qt.darker(group.foreground, 1.4)
    font.family: group.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 0
  }

  Row {
    width: parent.width
    height: Style.space(30)
    spacing: Style.space(6)

    Repeater {
      model: group.options

      Rectangle {
        id: option
        required property var modelData
        readonly property bool isSelected: modelData.value === group.value
        width: (parent.width - parent.spacing) / 2
        height: parent.height
        radius: Style.cornerRadius
        color: isSelected
          ? Color.accent
          : (optionMouse.containsMouse
            ? Style.hoverFillFor(group.foreground, Color.accent)
            : Qt.rgba(group.foreground.r, group.foreground.g, group.foreground.b, 0.045))
        border.width: Style.spacing.hairline
        border.color: isSelected
          ? Color.accent
          : Qt.rgba(group.foreground.r, group.foreground.g, group.foreground.b, 0.1)

        Text {
          anchors.centerIn: parent
          text: option.modelData.label
          color: option.isSelected ? group.contrastingTextColor(Color.accent) : Qt.darker(group.foreground, 1.3)
          font.family: group.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: option.isSelected
        }

        MouseArea {
          id: optionMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: group.selected(option.modelData.value)
        }
      }
    }
  }
}
