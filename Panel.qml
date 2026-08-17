import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Prayers.js" as Prayers

Panel {
  id: root
  moduleName: "io.github.tyrichards.orthodox-daily"
  ipcTarget: "io.github.tyrichards.orthodox-daily"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  property date today: new Date()
  readonly property string todayKey: Model.dateKey(today)
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/plugins/io.github.tyrichards.orthodox-daily/"
  readonly property string cachePath: stateDir + "daily.json"
  readonly property string checklistPath: stateDir + "checklist.json"
  readonly property string saintImageCacheDir: stateDir + "saint-images/"
  readonly property string saintImageScript: Quickshell.env("HOME")
    + "/.config/omarchy/plugins/io.github.tyrichards.orthodox-daily/OcaSaintImages.py"

  property var report: null
  property bool cacheLoaded: false
  property bool checklistLoaded: false
  property var prayerHistory: ({})
  property var storyImages: []
  property string storyImageRequestKey: ""
  property bool morningComplete: false
  property bool eveningComplete: false
  property string errorMessage: ""
  property double lastFetchMs: 0

  readonly property var fastingDisplayReport: report
  readonly property var specialFast: Model.specialFastBanner(report)
  readonly property color sourceLinkForeground: Qt.rgba(
    contentForeground.r, contentForeground.g, contentForeground.b, 0.5)
  readonly property var readings: report ? Model.gospelsFirst(report.readings) : []
  readonly property var stories: report ? Model.array(report.stories) : []
  readonly property var weekPrayers: Model.prayerWeek(today, prayerHistory)
  readonly property var feasts: report ? Model.array(report.feasts) : []
  readonly property var saints: report ? Model.array(report.saints) : []
  readonly property bool fetching: fetchProc.running

  function open() {
    root.controller.show()
    root.refresh(false)
    Qt.callLater(function() {
      if (root.opened) root.setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    root.setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh(useCache) {
    if (fetchProc.running) return

    var cacheIsFresh = report && Model.reportMatchesDate(report, today)
      && lastFetchMs > 0 && (Date.now() - lastFetchMs) < 15 * 60 * 1000
    if (useCache === false && cacheIsFresh) return

    errorMessage = ""
    fetchProc.command = ["curl", "-fsS", "--max-time", "12", Model.apiUrl(today)]
    fetchProc.running = true
  }

  function openUrl(url) {
    if (url) Qt.openUrlExternally(url)
  }

  function openOcaDay() {
    openUrl(Model.ocaReadingsUrl(today))
  }

  function refreshSaintImages() {
    if (!stories.length || saintImageProc.running) return
    var titles = stories.map(function(story) { return String(story.title || "") })
    var requestKey = todayKey + "|" + JSON.stringify(titles)
    if (requestKey === storyImageRequestKey) return

    storyImageRequestKey = requestKey
    storyImages = []
    saintImageProc.command = [
      "python3", saintImageScript,
      "--date", todayKey,
      "--cache-dir", saintImageCacheDir,
      "--titles", JSON.stringify(titles)
    ]
    saintImageProc.running = true
  }

  function storyImageSource(index) {
    var image = storyImages[index]
    return image && image.path ? "file://" + String(image.path) : ""
  }

  function saveChecklist() {
    if (!checklistLoaded) return
    checklistFile.setText(JSON.stringify({
      version: 2,
      days: prayerHistory
    }, null, 2) + "\n")
  }

  function storePrayerDay(key, day) {
    if (!key) return
    var next = {}
    Object.keys(prayerHistory || {}).forEach(function(dayKey) {
      next[dayKey] = Model.prayerForDay(prayerHistory, dayKey)
    })
    next[key] = {
      morning: day.morning === true,
      evening: day.evening === true,
      dayOnly: day.dayOnly === true
    }
    prayerHistory = next

    if (key === todayKey) {
      morningComplete = next[key].morning
      eveningComplete = next[key].evening
    }
    saveChecklist()
  }

  function setPrayerForDay(key, period, checked) {
    if (!key || (period !== "morning" && period !== "evening")) return
    var day = Model.prayerForDay(prayerHistory, key)
    day[period] = checked === true
    storePrayerDay(key, day)
  }

  function togglePrayerForDay(key, period) {
    var day = Model.prayerForDay(prayerHistory, key)
    setPrayerForDay(key, period, !day[period])
  }

  function togglePrayerDay(key) {
    if (!key || key > todayKey) return
    var day = Model.prayerForDay(prayerHistory, key)
    var complete = day.dayOnly || day.morning || day.evening
    storePrayerDay(key, complete
      ? { morning: false, evening: false, dayOnly: false }
      : { morning: false, evening: false, dayOnly: true })
  }

  function toggleMorning() {
    togglePrayerForDay(todayKey, "morning")
  }

  function toggleEvening() {
    togglePrayerForDay(todayKey, "evening")
  }

  function loadChecklist(raw) {
    prayerHistory = Model.parsePrayerHistory(raw, todayKey)
    var todayPrayers = Model.prayerForDay(prayerHistory, todayKey)
    morningComplete = todayPrayers.morning
    eveningComplete = todayPrayers.evening
    checklistLoaded = true
  }

  function handleNewDay(date) {
    var nextKey = Model.dateKey(date)
    if (nextKey === todayKey) return
    today = date
    report = null
    storyImages = []
    storyImageRequestKey = ""
    lastFetchMs = 0
    checklistLoaded = false
    checklistFile.reload()
    cacheFile.reload()
    refreshTimer.restart()
    root.refresh(true)
  }

  Process {
    id: ensureDirsProc
    command: ["mkdir", "-p", root.stateDir]
    onExited: function(exitCode) {
      cacheFile.reload()
      checklistFile.reload()
      root.refresh(true)
    }
  }

  FileView {
    id: cacheFile
    path: root.cachePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var parsed = Model.parseReport(text())
      if (!root.report && Model.reportMatchesDate(parsed, root.today)) root.report = parsed
      root.cacheLoaded = true
    }
    onLoadFailed: root.cacheLoaded = true
  }

  FileView {
    id: checklistFile
    path: root.checklistPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadChecklist(text())
    onLoadFailed: root.loadChecklist("")
  }

  Process {
    id: saintImageProc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "[]"))
          root.storyImages = Array.isArray(parsed) ? parsed : []
        } catch (error) {
          root.storyImages = []
        }
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) root.storyImageRequestKey = ""
    }
  }

  Process {
    id: fetchProc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        var parsed = Model.parseReport(raw)
        if (!Model.reportMatchesDate(parsed, root.today)) {
          if (!root.report) root.errorMessage = "Could not load today’s calendar."
          return
        }

        root.report = parsed
        root.lastFetchMs = Date.now()
        root.errorMessage = ""
        cacheFile.setText(raw + "\n")
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.report)
        root.errorMessage = "Offline — today’s calendar is not cached yet."
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.handleNewDay(date)
  }

  Timer {
    id: refreshTimer
    interval: 6 * 60 * 60 * 1000
    repeat: true
    running: true
    onTriggered: root.refresh(true)
  }

  onStoriesChanged: Qt.callLater(root.refreshSaintImages)

  Component.onCompleted: ensureDirsProc.running = true

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh(true) }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    // Follow the bar widget's actual location, like Wi-Fi and Bluetooth.
    focusTarget: keyCatcher
    // Keep the same outer width and side/bottom inset, but intentionally
    // remove the popup's top inset so the title section has no padding above.
    padding: 0
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight + Style.spacing.popupPadding)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh(true)
      }

      Flickable {
        id: dailyScroll
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.popupPadding
        anchors.rightMargin: Style.spacing.popupPadding
        anchors.bottomMargin: Style.spacing.popupPadding
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        maximumFlickVelocity: Style.space(6000)
        flickDeceleration: Style.space(1500)

        // Own the wheel stream explicitly. Without blocking, Flickable's
        // built-in wheel path can consume the event before this acceleration
        // is applied—especially for the small pixel deltas from a Magic Mouse.
        WheelHandler {
          target: null
          blocking: true
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

          onWheel: function(event) {
            var pixelWheel = event.pixelDelta.y !== 0
            var base = pixelWheel
              ? event.pixelDelta.y
              : (event.angleDelta.y / 120) * Style.space(48)
            var multiplier = pixelWheel ? 8.0 : 2.0
            var maxY = Math.max(0, dailyScroll.contentHeight - dailyScroll.height)
            dailyScroll.contentY = Math.max(0, Math.min(maxY, dailyScroll.contentY - base * multiplier))
            event.accepted = true
          }
        }

        Column {
          id: contentColumn
          width: dailyScroll.width
          // Match the Bluetooth panel's title-section rhythm, including the
          // space below the hero and around its separator.
          spacing: Style.space(14)

          // ---------- Hero: Orthodox cross · feast/status ----------
          // Keep the hero and daily-practice section flush with no gap above
          // the special-fast banner.
          Column {
            width: parent.width
            spacing: 0

          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, prayerActions.implicitHeight)

            Text {
              id: heroIcon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              anchors.verticalCenterOffset: -Style.space(2)
              text: "\u2626\uFE0E"
              color: root.contentForeground
              font.family: "Noto Sans Symbols"
              font.pixelSize: Style.font.display * 1.2
            }

            Row {
              id: prayerActions
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PRAYERS"
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }

              Column {
                spacing: Style.space(4)

                PrayerCheck {
                  iconText: ""
                  tooltipText: "Morning prayer"
                  checked: root.morningComplete
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onToggled: root.toggleMorning()
                }

                PrayerCheck {
                  iconText: ""
                  iconGap: Style.space(6)
                  tooltipText: "Evening prayer"
                  checked: root.eveningComplete
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onToggled: root.toggleEvening()
                }
              }
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: prayerActions.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: "Orthodox Christian Daily"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: Qt.formatDate(root.today, "MMMM d, yyyy").toUpperCase()
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
              }
            }
          }

          Text {
            visible: root.errorMessage !== ""
            width: parent.width
            text: root.errorMessage
            color: Color.urgent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.italic: true
            wrapMode: Text.Wrap
          }

          Column {
            id: dailyPracticeSection
            width: parent.width
            spacing: Style.space(8)

            FastBanner {
              id: specialFastBanner
              visible: root.specialFast.visible
              height: visible ? implicitHeight : 0
              width: parent.width
              implicitHeight: specialFastBannerContent.implicitHeight
                + verticalPadding * 2 + Style.space(2)
              wavyBorder: true
              iconText: ""
              title: ""
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              iconFontFamily: root.specialFast.iconFontFamily

              Row {
                id: specialFastBannerContent
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.specialFast.icon
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.specialFast.iconFontFamily || root.contentFontFamily
                  font.pixelSize: Style.font.title * 1.5
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.specialFast.title
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            Item {
              id: practiceColumns
              width: parent.width
              implicitHeight: Math.max(fastingInfoContent.implicitHeight,
                weeklyPrayerColumn.implicitHeight) + Style.space(16)
              height: implicitHeight

              Item {
                id: fastingInfoColumn
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: (parent.width - Style.space(15)) / 2

                Column {
                  id: fastingInfoContent
                  anchors.top: parent.top
                  anchors.topMargin: Style.space(8)
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: parent.width
                  spacing: Style.space(5)

                  Text {
                    width: parent.width
                    text: "FASTING RULE"
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 0
                    horizontalAlignment: Text.AlignLeft
                  }

                  FastBanner {
                    id: fastingRuleBox
                    width: parent.width
                    verticalPadding: Math.max(0,
                      Style.spacing.controlPaddingY - Style.space(3))
                    implicitHeight: fastingRuleBoxContent.implicitHeight
                      + verticalPadding * 2 + Style.space(2)
                    title: ""
                    iconText: ""
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily

                    Column {
                      id: fastingRuleBoxContent
                      anchors.centerIn: parent
                      width: parent.width - Style.spacing.controlPaddingX * 2
                      spacing: Style.space(1)

                      Row {
                        id: fastingPrimary
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Style.space(8)

                        Text {
                          id: fastingRuleIcon
                          anchors.verticalCenter: parent.verticalCenter
                          text: Model.fastingRuleIcon(root.fastingDisplayReport)
                          color: Qt.darker(root.contentForeground, 1.5)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.title * 1.5
                        }

                        Text {
                          width: Math.min(implicitWidth, Math.max(0,
                            fastingRuleBoxContent.width - fastingRuleIcon.implicitWidth
                              - fastingPrimary.spacing))
                          anchors.verticalCenter: parent.verticalCenter
                          text: root.fastingDisplayReport
                            ? Model.fastingStatus(root.fastingDisplayReport)
                            : "Loading…"
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.bodySmall
                          horizontalAlignment: Text.AlignHCenter
                          wrapMode: Text.WordWrap
                        }
                      }

                    }
                  }

                  Text {
                    visible: text !== ""
                    width: parent.width
                    text: root.fastingDisplayReport
                      ? Model.fastingTagline(root.fastingDisplayReport)
                      : ""
                    color: Qt.darker(root.contentForeground, 1.25)
                    font.family: root.contentFontFamily
                    font.pixelSize: Math.max(1, Style.font.caption - 1)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                  }
                }
              }

              Item {
                anchors.left: fastingInfoColumn.right
                anchors.leftMargin: Style.space(15)
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                Column {
                  id: weeklyPrayerColumn
                  anchors.top: parent.top
                  anchors.topMargin: Style.space(8)
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: parent.width
                  spacing: Style.space(5)

                  Text {
                    width: parent.width
                    text: "DAILY PRAYER"
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 0
                    horizontalAlignment: Text.AlignLeft
                  }

                  Row {
                    id: prayerWeekRow
                    anchors.left: parent.left
                    spacing: Style.space(8)

                    Repeater {
                      model: root.weekPrayers

                      Item {
                        required property var modelData
                        width: prayerDayColumn.implicitWidth
                        implicitHeight: prayerDayColumn.implicitHeight
                        height: implicitHeight
                        opacity: modelData.future ? 0.45 : 1.0

                        Column {
                          id: prayerDayColumn
                          anchors.horizontalCenter: parent.horizontalCenter
                          spacing: Style.space(3)

                          Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: modelData.today
                              ? root.contentForeground
                              : Qt.darker(root.contentForeground, 1.4)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }

                          Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.complete ? "" : ""
                            color: modelData.complete
                              ? Color.accent
                              : (modelData.today
                                ? root.contentForeground
                                : Qt.darker(root.contentForeground, 1.5))
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.title
                          }
                        }

                        MouseArea {
                          anchors.fill: parent
                          enabled: !modelData.future
                          hoverEnabled: enabled
                          scrollGestureEnabled: false
                          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                          onClicked: root.togglePrayerDay(modelData.key)
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          }

          Column {
            width: parent.width
            // Mirror the Scripture section with 4px from title to first row.
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "PRAYERS"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Column {
              width: parent.width
              spacing: 0

              ScriptureRow {
                width: parent.width
                iconText: ""
                title: "Trisagion"
                body: Prayers.trisagionPrayer()
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              ScriptureRow {
                width: parent.width
                iconText: ""
                title: "Morning Prayers"
                body: Prayers.morningPrayer()
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              ScriptureRow {
                width: parent.width
                iconText: ""
                title: "Before & After Meals"
                body: Prayers.mealPrayer()
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              ScriptureRow {
                width: parent.width
                iconText: ""
                title: "Evening Prayers"
                body: Prayers.eveningPrayer()
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }
            }
          }

          Column {
            width: parent.width
            // Match Wi-Fi OTHER NETWORKS: 4px from section title to first row.
            spacing: Style.space(4)

          Row {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              anchors.verticalCenter: parent.verticalCenter
              text: "SCRIPTURE"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Item {
              width: Math.max(0, parent.width - parent.children[0].implicitWidth
                - ocaReadings.implicitWidth - orthocalReadings.implicitWidth - parent.spacing * 3)
              height: 1
            }

            PanelActionButton {
              id: ocaReadings
              iconText: ""
              tooltipText: "Open OCA readings"
              foreground: root.sourceLinkForeground
              fontFamily: root.contentFontFamily
              fontSize: Style.font.title
              onClicked: root.openUrl(Model.ocaReadingsUrl(root.today))
            }

            PanelActionButton {
              id: orthocalReadings
              iconText: ""
              tooltipText: "Open Orthocal"
              foreground: root.sourceLinkForeground
              fontFamily: root.contentFontFamily
              fontSize: Style.font.title
              onClicked: root.openUrl(Model.orthocalUrl(root.today))
            }
          }

          Text {
            visible: !root.report && !root.errorMessage
            text: "Loading daily readings…"
            color: Qt.darker(root.contentForeground, 1.55)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }

          Column {
            width: parent.width
            spacing: 0

            Repeater {
              model: root.readings

              ScriptureRow {
                required property var modelData
                width: parent.width
                title: String(modelData.display || "Scripture")
                body: Model.passageText(modelData)
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }
            }
          }
          }

          Column {
            width: parent.width
            // Match Wi-Fi OTHER NETWORKS: 4px from section title to first row.
            spacing: Style.space(4)

          Row {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              anchors.verticalCenter: parent.verticalCenter
              text: "SAINTS & COMMEMORATIONS"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Item {
              width: Math.max(0, parent.width - parent.children[0].implicitWidth
                - ocaSaints.implicitWidth - orthocalSaints.implicitWidth - parent.spacing * 3)
              height: 1
            }

            PanelActionButton {
              id: ocaSaints
              iconText: ""
              tooltipText: "Open OCA lives"
              foreground: root.sourceLinkForeground
              fontFamily: root.contentFontFamily
              fontSize: Style.font.title
              onClicked: root.openUrl(Model.ocaSaintsUrl(root.today))
            }

            PanelActionButton {
              id: orthocalSaints
              iconText: ""
              tooltipText: "Open Orthocal"
              foreground: root.sourceLinkForeground
              fontFamily: root.contentFontFamily
              fontSize: Style.font.title
              onClicked: root.openUrl(Model.orthocalUrl(root.today))
            }
          }

          Text {
            visible: !root.report && !root.errorMessage
            text: "Loading saints and commemorations…"
            color: Qt.darker(root.contentForeground, 1.55)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }

          Column {
            width: parent.width
            spacing: 0

            Repeater {
              model: root.stories

              ScriptureRow {
                required property var modelData
                required property int index
                width: parent.width
                iconText: ""
                title: String(modelData.title || "Life of a saint")
                imageSource: root.storyImageSource(index)
                wrapTitle: true
                topAlignIcons: true
                topAlignTitle: true
                titleTopOffset: Style.space(2)
                arrowTopOffset: -Style.space(2)
                contentVerticalOffset: Style.space(2)
                body: Model.storyText(modelData)
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }
            }
          }
          }
        }
      }
    }
  }
}
