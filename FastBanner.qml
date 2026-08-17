import QtQuick
import qs.Commons
import qs.Ui

// Retain the Agents provider button's component, font and padding, but render
// it as a static banner using the inactive Codex button's normal border token.
Button {
  id: banner

  property string title: ""
  // Retained for the banner data contract; Button uses one family for both
  // text and icon, with font fallback handling U+2626 text presentation.
  property string iconFontFamily: ""
  property bool wavyBorder: false
  readonly property var normalBorderSpec: Border.controlSpec("normal", foreground, Color.accent)

  text: title
  enabled: false
  selected: false
  bordered: true
  color: "transparent"
  borderSpec: wavyBorder ? Border.none() : normalBorderSpec
  fontSize: Style.font.bodySmall
  verticalPadding: Style.spacing.controlPaddingY

  Canvas {
    id: wave
    anchors.fill: parent
    visible: banner.wavyBorder
    readonly property color borderColor: Border.color(banner.normalBorderSpec)
    readonly property real lineWidth: Math.max(1, Border.top(banner.normalBorderSpec)) * 2
    readonly property real amplitude: Style.space(2)
    readonly property real wavelength: Style.space(12)

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onBorderColorChanged: requestPaint()

    onPaint: {
      var context = getContext("2d")
      context.clearRect(0, 0, width, height)
      if (!visible || width <= 0 || height <= 0) return

      var inset = lineWidth / 2 + amplitude + 1
      var right = width - inset
      var bottom = height - inset
      if (right <= inset || bottom <= inset) return

      context.beginPath()
      context.strokeStyle = borderColor
      context.lineWidth = lineWidth
      context.lineJoin = "round"
      context.lineCap = "round"

      context.moveTo(inset, inset)
      for (var x = inset; x <= right; x += 1)
        context.lineTo(x, inset + amplitude * Math.sin((x - inset) * 2 * Math.PI / wavelength))
      for (var y = inset; y <= bottom; y += 1)
        context.lineTo(right - amplitude * Math.sin((y - inset) * 2 * Math.PI / wavelength), y)
      for (x = right; x >= inset; x -= 1)
        context.lineTo(x, bottom - amplitude * Math.sin((right - x) * 2 * Math.PI / wavelength))
      for (y = bottom; y >= inset; y -= 1)
        context.lineTo(inset + amplitude * Math.sin((bottom - y) * 2 * Math.PI / wavelength), y)

      context.closePath()
      context.stroke()
    }
  }
}
