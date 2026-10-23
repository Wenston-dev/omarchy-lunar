import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Lunar.js" as Lunar

// Lunar date label for the bar: left click opens the lunar calendar, right
// click walks the label formats. On a solar term or festival the label says
// so, since that is the day it is worth glancing at.
//
// The widget root keeps the open/close/opened shape the bar's popout
// coordinator and shell.summon/hide/toggle routing look for; the panel
// itself is loaded from Panel.qml and handed the button to anchor against.
BarWidget {
  id: root
  moduleName: "io.github.wenston-dev.lunar"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property var formats: ["md", "ymd", "day"]
  readonly property string format: {
    var f = String(setting("format", "md"))
    return formats.indexOf(f) >= 0 ? f : "md"
  }

  property date today: clock.date
  readonly property var info: Lunar.describe(today.getFullYear(), today.getMonth() + 1, today.getDate())
  // The day's festival or term, if it has one.
  readonly property string occasion: info.festivals.length > 0 ? info.festivals[0] : info.term

  readonly property string displayText: {
    var lunar = info.lunar
    if (!lunar) return ""
    if (format === "day") return occasion !== "" ? occasion : lunar.dayName
    var text = lunar.monthName + lunar.dayName
    if (format === "ymd") text = lunar.yearName + lunar.zodiac + "年 " + text
    return occasion !== "" ? text + " · " + occasion : text
  }
  readonly property var verticalLines: info.lunar ? [info.lunar.monthName.replace("月", ""), info.lunar.dayName] : []

  function cycleFormat() {
    var next = formats[(formats.indexOf(format) + 1) % formats.length]
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.format = next

    // Applied locally first so the label changes on the click itself; the
    // shell.json write comes back through the bar as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // ---- Panel lifecycle ----------------------------------------------------
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity while it hands over to another popup.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  ShellIpc {
    target: "io.github.wenston-dev.lunar"

    function cycleFormat(): void { root.cycleFormat() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.displayText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: strings.t("tooltip")
    active: root.opened
    activeColor: Commons.Color.accent

    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleFormat()
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: button.fontSize * 0.85
          color: button.foreground
        }
      }
    }
  }
}
