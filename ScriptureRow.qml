import QtQuick
import qs.Commons
import qs.Ui

// Collapsed chrome mirrors Bluetooth's AVAILABLE device rows: leading glyph,
// one line of text, trailing action. The passage expands beneath that row.
CursorSurface {
  id: row

  property string iconText: ""
  property string title: "Scripture"
  property string body: ""
  property string imageSource: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property real iconFontSize: Style.font.title
  property bool wrapTitle: false
  property bool topAlignIcons: false
  property bool topAlignTitle: false
  property real titleTopOffset: 0
  property real arrowTopOffset: 0
  property real contentVerticalOffset: 0
  property bool expandable: true
  property bool expanded: false
  readonly property real verticalPadding: Math.max(0,
    Style.spacing.rowPaddingX / 2 - Style.space(4))

  hasCursor: expandable && rowMouse.containsMouse
  current: expandable && expanded
  fill: Style.hoverFillFor(foreground, Color.accent)
  currentFill: Style.selectedFillFor(foreground, Color.accent)

  implicitHeight: rowColumn.implicitHeight + verticalPadding * 2

  Column {
    id: rowColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: row.verticalPadding + row.contentVerticalOffset
    spacing: row.expandable && row.expanded ? Style.space(10) : 0

    Item {
      id: rowContent
      width: parent.width
      implicitHeight: Math.max(scriptureIcon.implicitHeight, scriptureTitle.implicitHeight,
        row.expandable ? expandArrow.implicitHeight : 0)

      Text {
        id: scriptureIcon
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.top: row.topAlignIcons ? parent.top : undefined
        anchors.verticalCenter: row.topAlignIcons ? undefined : parent.verticalCenter
        text: row.iconText
        // Match an available/disconnected Bluetooth device icon's color and
        // Wi-Fi OTHER NETWORKS' leading signal icon size.
        color: Qt.darker(row.foreground, 1.5)
        font.family: row.fontFamily
        font.pixelSize: row.iconFontSize
      }

      Text {
        id: scriptureTitle
        anchors.left: scriptureIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: row.expandable ? expandArrow.left : parent.right
        anchors.rightMargin: row.expandable ? Style.space(8) : Style.space(10)
        anchors.top: row.topAlignTitle ? parent.top : undefined
        anchors.topMargin: row.topAlignTitle ? row.titleTopOffset : 0
        anchors.verticalCenter: row.topAlignTitle ? undefined : parent.verticalCenter
        text: row.title
        color: row.foreground
        font.family: row.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: row.wrapTitle ? Text.WordWrap : Text.NoWrap
        elide: row.wrapTitle ? Text.ElideNone : Text.ElideRight
      }

      Text {
        id: expandArrow
        visible: row.expandable
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.top: row.topAlignIcons ? parent.top : undefined
        anchors.topMargin: row.topAlignIcons ? row.arrowTopOffset : 0
        anchors.verticalCenter: row.topAlignIcons ? undefined : parent.verticalCenter
        text: row.expanded ? "󰅀" : "󰅂"
        color: Qt.darker(row.foreground, 1.35)
        font.family: row.fontFamily
        // Match Wi-Fi OTHER NETWORKS' trailing lock indicator.
        font.pixelSize: Style.font.subtitle + Style.space(3)
      }
    }

    Rectangle {
      id: storyImageFrame
      readonly property real framePadding: Style.space(6)
      readonly property real maxImageWidth: parent.width - Style.space(56)
      readonly property real maxImageHeight: Style.space(190)
      readonly property real aspectRatio: storyImage.sourceSize.height > 0
        ? storyImage.sourceSize.width / storyImage.sourceSize.height
        : 0.7
      readonly property real imageWidth: Math.min(maxImageWidth, maxImageHeight * aspectRatio)
      readonly property real imageHeight: imageWidth / aspectRatio

      visible: row.expandable && row.expanded && row.imageSource !== ""
        && storyImage.status !== Image.Error
      width: imageWidth + framePadding * 2
      height: visible ? imageHeight + framePadding * 2 : 0
      anchors.horizontalCenter: parent.horizontalCenter
      color: "transparent"
      border.width: Math.max(1, Style.normalBorderWidth)
      border.color: Qt.darker(row.foreground, 1.5)
      radius: Style.cornerRadius

      Image {
        id: storyImage
        anchors.centerIn: parent
        width: storyImageFrame.imageWidth
        height: storyImageFrame.imageHeight
        source: row.imageSource
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
      }
    }

    Text {
      visible: row.expandable && row.expanded
      width: parent.width - Style.space(20)
      leftPadding: Style.space(25)
      rightPadding: Style.space(25)
      topPadding: Style.space(15)
      bottomPadding: Style.space(15)
      text: row.body || "No text available."
      color: Qt.darker(row.foreground, 1.12)
      font.family: row.fontFamily
      font.pixelSize: Style.font.bodySmall
      lineHeight: 1.25
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    // Let wheel and two-finger gestures pass through to the panel Flickable.
    scrollGestureEnabled: false
    cursorShape: row.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (row.expandable) row.expanded = !row.expanded
  }
}
