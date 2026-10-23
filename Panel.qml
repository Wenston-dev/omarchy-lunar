import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Lunar.js" as Lunar

// The lunar calendar popup: the picked day's lunar date over a rail running
// from the last solar term to the next, then a month grid where every day
// carries its lunar day, term, or festival under the Gregorian number.
//
// Clicking a day (or walking to it with the arrow keys) picks it for the
// hero; clicking the hero goes back to today. BarWidget.qml owns the bar
// label and hands this panel the button to anchor against.
Panel {
  id: root
  moduleName: "io.github.wenston-dev.lunar"
  ipcTarget: "io.github.wenston-dev.lunar"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // ---- Today and the picked day. SystemClock keeps today honest across
  //      midnight so the outline rolls over without reopening the panel.
  property date today: new Date()
  readonly property string todayKey: Lunar.keyFor(today.getFullYear(), today.getMonth() + 1, today.getDate())

  property int pickYear: today.getFullYear()
  property int pickMonth: today.getMonth() + 1
  property int pickDay: today.getDate()
  readonly property string pickKey: Lunar.keyFor(pickYear, pickMonth, pickDay)
  readonly property bool pickingToday: pickKey === todayKey

  // The month on screen. Follows the pick, and the chevrons move it alone.
  property int viewYear: pickYear
  property int viewMonth: pickMonth

  readonly property var picked: Lunar.describe(pickYear, pickMonth, pickDay)
  readonly property var terms: Lunar.termsAround(pickYear, pickMonth, pickDay)

  // Monday unless shell.json says "weekStart": "sunday".
  readonly property int weekStart: String(setting("weekStart", "monday")).toLowerCase() === "sunday" ? 0 : 1
  readonly property var weekdays: weekStart === 0 ? [0, 1, 2, 3, 4, 5, 6] : [1, 2, 3, 4, 5, 6, 0]
  readonly property var weeks: Lunar.monthGrid(viewYear, viewMonth, weekStart, todayKey)

  readonly property var labelLocale: Qt.locale(Commons.I18n.formatLocale)
  readonly property string monthYearLabel: strings.t("panel.monthYear")
    .arg(labelLocale.standaloneMonthName(viewMonth - 1, Locale.ShortFormat))
    .arg(viewYear)

  // Guarded so the panel renders before the bar is injected.
  readonly property color contentForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accentText: Style.selectedStateColor(contentForeground, Commons.Color.accent)

  readonly property int cellWidth: Style.space(58)
  readonly property int cellHeight: Style.space(46)
  readonly property int cellSpacing: Style.space(2)
  readonly property int gridWidth: cellWidth * 7 + cellSpacing * 6

  // ---- Lifecycle (same shape as the clock panel) --------------------------
  function open() {
    refresh()
    root.controller.show()
    // Summoning by hotkey moves no pointer; a hover the bar was still
    // holding must not keep center widgets revealed behind the panel.
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
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
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    root.goToToday()
  }

  // ---- Moving around -------------------------------------------------------

  function pick(year, month, day) {
    root.pickYear = year
    root.pickMonth = month
    root.pickDay = day
    root.viewYear = year
    root.viewMonth = month
  }

  function goToToday() {
    pick(today.getFullYear(), today.getMonth() + 1, today.getDate())
  }

  function moveDay(delta) {
    var d = new Date(Date.UTC(pickYear, pickMonth - 1, pickDay + delta))
    pick(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate())
  }

  function moveMonth(delta) {
    var next = Lunar.stepMonth(viewYear, viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }

  function labelColor(cell) {
    if (!cell.inMonth) return Qt.darker(root.contentForeground, 2.2)
    if (cell.labelKind === "festival" || cell.labelKind === "term") return root.accentText
    if (cell.labelKind === "month") return root.contentForeground
    return Qt.darker(root.contentForeground, 1.6)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      var key = Lunar.keyFor(clock.date.getFullYear(), clock.date.getMonth() + 1, clock.date.getDate())
      if (key === root.todayKey) return
      var followToday = root.pickingToday
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: panel.loadedContent
    // contentWidth is the whole card: the grid, a little air for the
    // chevrons that hang off its edges, and the card's padding both sides.
    contentWidth: panel.fittedContentWidth(root.gridWidth + Style.space(24) + panel.padding * 2)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      implicitHeight: column.implicitHeight

      onMoveRequested: function(dx, dy) { root.moveDay(dx + dy * 7) }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "[") root.moveMonth(-1)
        else if (t === "]") root.moveMonth(1)
        else if (t === "t" || t === "T") root.goToToday()
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: column.width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: column
          // Never narrower than the grid, so a cramped screen scrolls the
          // last column into view instead of losing it off the edge.
          width: Math.max(scroll.width, root.gridWidth)
          spacing: Style.space(8)

          // ---- Hero: the picked day's lunar date. Clicking it while some
          //      other day is picked is the way back to today.
          Item {
            width: parent.width
            height: hero.height

            Column {
              id: hero
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(4)

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(14)

                Text {
                  id: heroLunar
                  textFormat: Text.PlainText
                  text: root.picked.lunar
                    ? root.picked.lunar.monthName + root.picked.lunar.dayName
                    : strings.t("panel.outOfRange")
                  color: heroMouse.containsMouse
                    ? Style.hoverStateColor(root.contentForeground, Commons.Color.accent)
                    : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: 46
                  font.bold: true
                }

                // The day's festivals and term, as small accent tags.
                Column {
                  anchors.verticalCenter: heroLunar.verticalCenter
                  spacing: Style.space(3)
                  visible: tagRepeater.count > 0

                  Repeater {
                    id: tagRepeater
                    model: root.picked.festivals.concat(root.picked.term !== "" ? [root.picked.term] : [])

                    Rectangle {
                      required property string modelData
                      width: tagText.implicitWidth + Style.space(12)
                      height: tagText.implicitHeight + Style.space(4)
                      radius: Style.cornerRadius
                      color: Style.hoverFillFor(root.contentForeground, Commons.Color.accent)
                      border.width: Style.spacing.hairline
                      border.color: Style.normalBorderFor(root.contentForeground, Commons.Color.accent)

                      Text {
                        id: tagText
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: modelData
                        color: root.accentText
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                      }
                    }
                  }
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.picked.lunar !== null
                textFormat: Text.PlainText
                text: root.picked.lunar
                  ? root.picked.lunar.yearName + "年 · " + root.picked.lunar.zodiac + "年 · " + root.picked.dayCycle + "日"
                  : ""
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.letterSpacing: 1
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: new Date(root.pickYear, root.pickMonth - 1, root.pickDay, 12)
                  .toLocaleDateString(root.labelLocale, strings.t("panel.dateFormat"))
                color: Qt.darker(root.contentForeground, 1.7)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

            MouseArea {
              id: heroMouse
              x: hero.x
              y: hero.y
              width: hero.width
              height: hero.height
              enabled: !root.pickingToday
              hoverEnabled: enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToToday()

              PanelToolTip {
                visible: heroMouse.containsMouse
                text: strings.t("panel.backToToday")
                fontFamily: root.contentFontFamily
              }
            }
          }

          // ---- Solar term rail: the last term on the left, the next on the
          //      right, and how far the picked day sits between them.
          Item {
            width: parent.width
            height: termBlock.y + termBlock.height
            visible: root.terms !== null

            Column {
              id: termBlock
              y: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              width: root.gridWidth
              spacing: Style.space(4)

              Item {
                width: parent.width
                height: Math.max(termFrom.implicitHeight, Style.space(10))

                Text {
                  id: termFrom
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: root.terms ? root.terms.current.name : ""
                  color: root.terms && root.terms.current.days === 0 ? root.accentText : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  id: termTo
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: root.terms ? root.terms.next.name : ""
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                }

                Rectangle {
                  anchors.left: termFrom.right
                  anchors.right: termTo.left
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(6)
                  radius: Style.cornerRadius > 0 ? height / 2 : 0
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                  Rectangle {
                    readonly property real done: root.terms
                      ? root.terms.current.days / (root.terms.current.days + root.terms.next.days)
                      : 0
                    width: Math.max(height, Math.round(parent.width * done))
                    height: parent.height
                    radius: parent.radius
                    color: root.accentText

                    Behavior on width { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
                  }
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: !root.terms ? ""
                  : root.terms.current.days === 0
                    ? strings.t("panel.termToday").arg(root.terms.current.name)
                    : strings.tn("panel.nextTerm", root.terms.next.days)
                        .arg(root.terms.next.name)
                        .arg(Commons.I18n.formatNumber(root.terms.next.days))
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }
            }
          }

          // ---- Month grid: always six rows, so the popup keeps one height.
          Item {
            width: parent.width
            height: gridColumn.y + gridColumn.height

            WheelHandler {
              onWheel: function(event) {
                // Side-scrolls report y === 0; they are not a month step.
                if (event.angleDelta.y === 0) return
                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
              }
            }

            Column {
              id: gridColumn
              y: Style.space(10)
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(3)

              Row {
                spacing: root.cellSpacing

                Repeater {
                  model: root.weekdays

                  Text {
                    required property var modelData
                    textFormat: Text.PlainText
                    width: root.cellWidth
                    height: Style.space(18)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.labelLocale.dayName(modelData, Locale.ShortFormat)
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              Repeater {
                model: root.weeks

                Row {
                  required property var modelData
                  spacing: root.cellSpacing

                  Repeater {
                    model: modelData.days

                    Rectangle {
                      id: cell
                      required property var modelData
                      readonly property bool isPicked: modelData.key === root.pickKey

                      width: root.cellWidth
                      height: root.cellHeight
                      radius: Style.cornerRadius
                      // Today is outlined; the picked day, when it is not
                      // today, takes a soft fill so the two never blur.
                      color: isPicked || cellMouse.containsMouse
                        ? Style.hoverFillFor(root.contentForeground, Commons.Color.accent)
                        : "transparent"
                      border.width: modelData.today ? Style.spacing.hairline : 0
                      border.color: Style.normalBorderFor(root.contentForeground, Commons.Color.accent)

                      Column {
                        anchors.centerIn: parent
                        spacing: Style.space(1)

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          textFormat: Text.PlainText
                          text: Commons.I18n.formatNumber(cell.modelData.day)
                          color: cell.modelData.inMonth
                            ? (cell.modelData.weekend ? Qt.darker(root.contentForeground, 1.35) : root.contentForeground)
                            : Qt.darker(root.contentForeground, 2.2)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.body
                          font.bold: cell.modelData.today
                        }

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          width: root.cellWidth - Style.space(4)
                          horizontalAlignment: Text.AlignHCenter
                          elide: Text.ElideRight
                          textFormat: Text.PlainText
                          text: cell.modelData.label
                          color: root.labelColor(cell.modelData)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                        }
                      }

                      MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(cell.modelData.year, cell.modelData.month, cell.modelData.day)
                      }
                    }
                  }
                }
              }
            }
          }

          // ---- Month stepping, spanning the grid it drives.
          Item {
            width: parent.width
            height: monthNav.height

            Item {
              id: monthNav
              anchors.horizontalCenter: parent.horizontalCenter
              width: root.gridWidth
              height: monthLabel.implicitHeight + Style.space(10)

              Text {
                id: monthLabel
                textFormat: Text.PlainText
                anchors.centerIn: parent
                width: Style.space(160)
                horizontalAlignment: Text.AlignHCenter
                text: root.monthYearLabel
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.letterSpacing: 1
              }

              PanelActionButton {
                anchors.left: parent.left
                anchors.leftMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: Commons.I18n.rightToLeft ? "󰅂" : "󰅁"
                tooltipText: strings.t("panel.previousMonth")
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(-1)
              }

              PanelActionButton {
                anchors.right: parent.right
                anchors.rightMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: Commons.I18n.rightToLeft ? "󰅁" : "󰅂"
                tooltipText: strings.t("panel.nextMonth")
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(1)
              }
            }
          }
        }
      }
    }
  }
}
