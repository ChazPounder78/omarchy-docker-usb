import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "lang.js" as L10n

BarWidget {
  id: root
  moduleName: "io.github.chazpounder78.docker-usb"

  readonly property var strings: L10n.pick(Quickshell.env("LANG"))

  property string helperPath: ""
  readonly property bool helperResolved: helperPath !== ""

  property var devices: []
  property var containers: []
  property string target: ""
  property bool probing: false

  property bool applying: false
  property var applyResult: null

  readonly property int checkedCount: {
    var n = 0
    for (var i = 0; i < devices.length; i++)
      if (devices[i].checked === true && devices[i].connected === true) n++
    return n
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function resolveHelper() { helperResolveProc.running = true }

  function probe() {
    if (probing || !root.helperResolved) return
    probing = true
    statusProc.running = true
  }

  function refresh() { probe() }

  function rememberDevice(vid, pid, on, name) {
    if (!root.helperResolved) return
    Quickshell.execDetached([root.helperPath, "check", vid, pid, on ? "on" : "off", name || ""])
    // optimistic local flip so the checkbox reacts instantly
    var arr = []
    for (var i = 0; i < root.devices.length; i++) {
      var d = Object.assign({}, root.devices[i])
      if (d.vid === vid && d.pid === pid) d.checked = on
      arr.push(d)
    }
    root.devices = arr
    refreshLater.restart()
  }

  function setTarget(name) {
    if (!root.helperResolved) return
    Quickshell.execDetached([root.helperPath, "target", name])
    root.target = name
    refreshLater.restart()
  }

  function applyDevices() {
    if (!root.helperResolved || root.applying) return
    root.applying = true
    root.applyResult = null
    applyProc.running = true
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open(); probe() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

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

  IpcHandler {
    target: root.moduleName
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function refresh() { root.refresh() }
    function apply() { root.applyDevices() }
  }

  // Locate the helper inside this plugin's own directory.
  Process {
    id: helperResolveProc
    command: ["bash", "-lc",
      'd="$HOME/.config/omarchy/plugins/io.github.chazpounder78.docker-usb"; ' +
      'if [ -x "$d/bin/docker-usb" ]; then echo "$d/bin/docker-usb"; fi']
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var p = String(text || "").trim()
        if (p && root.helperPath === "") {
          root.helperPath = p
          Qt.callLater(root.probe)
        }
      }
    }
  }

  Process {
    id: statusProc
    command: [root.helperPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "{}").trim()
        try {
          var obj = JSON.parse(raw)
          root.devices = obj.devices || []
          root.containers = obj.containers || []
          root.target = obj.target || ""
        } catch (e) { /* keep last good */ }
        root.probing = false
      }
    }
    onRunningChanged: if (!running && root.probing) root.probing = false
  }

  Process {
    id: applyProc
    command: [root.helperPath, "apply"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "{}").trim()
        try { root.applyResult = JSON.parse(raw) } catch (e) {
          root.applyResult = { ok: false, message: "Bad helper output", warnings: [] }
        }
        root.applying = false
        root.probe()
      }
    }
    onRunningChanged: if (!running && root.applying) {
      root.applying = false
      root.probe()
    }
  }

  Timer {
    id: refreshLater
    interval: 400
    repeat: false
    onTriggered: root.probe()
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: root.probe()
  }

  // Safety net: never let a failed probe block later ones.
  Timer {
    interval: 8000
    repeat: true
    running: root.probing || root.applying
    onTriggered: {
      root.probing = false
      root.applying = false
    }
  }

  Component.onCompleted: root.resolveHelper()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{F08EE}"
    tooltipText: root.checkedCount > 0
      ? strings.tooltip + " (" + root.checkedCount + ")"
      : strings.tooltip
    active: root.checkedCount > 0
    useActiveColor: true
    activeColor: Color.accent

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  // Checked-and-connected count badge.
  Rectangle {
    id: badge
    anchors.right: button.right
    anchors.top: button.top
    anchors.rightMargin: 1
    anchors.topMargin: 1
    visible: root.checkedCount > 0
    width: badgeText.implicitWidth + Style.space(6)
    height: badgeText.implicitHeight + 1
    radius: Math.min(width, height) / 2
    color: Color.accent
    z: 2

    Text {
      id: badgeText
      anchors.centerIn: parent
      text: root.checkedCount > 99 ? "99+" : String(root.checkedCount)
      color: "#ffffff"
      font.family: Style.font.family
      font.pixelSize: Math.max(7, Math.round(Style.font.caption * 0.72))
      font.bold: true
    }
  }
}
