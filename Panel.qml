import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "lang.js" as L10n

Panel {
  id: root
  moduleName: "io.github.chazpounder78.docker-usb"
  manageIpc: false

  // Auto-close after a period with no interaction.
  readonly property int autoCloseMs: 60000

  property var anchorItem: null
  property var hostWidget: null
  property color foreground: bar ? bar.barForeground : Color.foreground
  property color background: Color.menu.background
  readonly property var strings: L10n.pick(Quickshell.env("LANG"))

  function open() { controller.show() }
  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { popoutSwitchClosing = false })
  }

  readonly property var devices: hostWidget ? hostWidget.devices : []
  readonly property var containers: hostWidget ? hostWidget.containers : []
  readonly property string target: hostWidget ? hostWidget.target : ""
  readonly property bool applying: hostWidget ? hostWidget.applying : false
  readonly property var applyResult: hostWidget ? hostWidget.applyResult : null

  function refresh() {
    if (hostWidget && typeof hostWidget.refresh === "function") hostWidget.refresh()
  }

  function toggleDevice(devVid, devPid, on, devName) {
    if (hostWidget && typeof hostWidget.rememberDevice === "function")
      hostWidget.rememberDevice(devVid, devPid, on, devName)
  }

  function selectTarget(name) {
    if (hostWidget && typeof hostWidget.setTarget === "function")
      hostWidget.setTarget(name)
  }

  function applyDevices() {
    if (root.applying) return
    idleCloseTimer.restart()
    if (hostWidget && typeof hostWidget.applyDevices === "function")
      hostWidget.applyDevices()
  }

  function rebuildModel() {
    deviceModel.clear()
    var ds = root.devices || []
    for (var i = 0; i < ds.length; i++) {
      var d = ds[i]
      deviceModel.append({
        vid: d.vid || "",
        pid: d.pid || "",
        dname: d.name || ((d.vid || "") + ":" + (d.pid || "")),
        connected: d.connected === true,
        checked: d.checked === true
      })
    }
  }

  onDevicesChanged: root.rebuildModel()

  function rebuildTargetOptions() {
    var opts = []
    var cs = root.containers || []
    for (var i = 0; i < cs.length; i++)
      opts.push({ value: cs[i].name, label: cs[i].name + "  \u00b7  " + cs[i].image })
    targetDropdown.options = opts
  }

  onContainersChanged: root.rebuildTargetOptions()

  onOpenedChanged: {
    if (!root.opened) return
    idleCloseTimer.restart()
    root.rebuildModel()
    root.rebuildTargetOptions()
    if (hostWidget && typeof hostWidget.refresh === "function")
      hostWidget.refresh()
  }

  Timer {
    id: idleCloseTimer
    interval: root.autoCloseMs
    repeat: false
    running: root.opened
    onTriggered: root.close()
  }

  readonly property int checkedConnected: {
    var n = 0
    var ds = root.devices || []
    for (var i = 0; i < ds.length; i++)
      if (ds[i].checked === true && ds[i].connected === true) n++
    return n
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: Style.space(400)
    contentHeight: Style.space(600)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: targetDropdown.popupOpen
      onActivateRequested: { idleCloseTimer.restart(); root.applyDevices() }
      onCloseRequested: root.close()

      // Pointer movement counts as activity; never steals clicks.
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: idleCloseTimer.restart()
        onWheel: idleCloseTimer.restart()
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.spacing.popupPadding
        spacing: Style.space(8)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            Layout.fillWidth: true
            text: root.strings.title
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            text: String(root.checkedConnected)
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Rectangle {
            Layout.preferredWidth: Style.spacing.controlHeight
            Layout.preferredHeight: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: refreshMouse.containsMouse
              ? Qt.alpha(root.foreground, 0.14)
              : Qt.alpha(root.foreground, 0.06)

            MouseArea {
              id: refreshMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { idleCloseTimer.restart(); root.refresh() }
            }

            Text {
              anchors.centerIn: parent
              text: root.strings.refreshIcon
              color: root.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        // ---- target container
        Text {
          Layout.fillWidth: true
          text: root.strings.targetLabel
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Dropdown {
          id: targetDropdown
          Layout.fillWidth: true
          Layout.preferredHeight: implicitHeight
          showLabel: false
          foreground: root.foreground
          fontFamily: Style.font.family
          value: root.target
          options: []
          onChanged: function(v) {
            idleCloseTimer.restart()
            if (v !== root.target) root.selectTarget(v)
          }
        }

        Text {
          Layout.fillWidth: true
          visible: root.containers.length === 0
          text: root.strings.targetEmptyDesc
          color: Qt.alpha(root.foreground, 0.54)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // ---- device list header
        Text {
          Layout.fillWidth: true
          Layout.topMargin: Style.space(4)
          text: root.strings.devicesLabel + " (" + deviceModel.count + ")"
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          ListView {
            id: deviceList
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            model: deviceModel
            spacing: Style.space(4)
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
              id: row
              property string devVid: model.vid
              property string devPid: model.pid
              property string devName: model.dname
              property bool devConnected: model.connected
              property bool devChecked: model.checked

              width: deviceList.width
              height: Style.space(46)
              radius: Style.cornerRadius
              color: rowMouse.containsMouse
                ? Qt.alpha(root.foreground, 0.10)
                : Qt.alpha(root.foreground, 0.04)

              Behavior on color { ColorAnimation { duration: 90 } }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  idleCloseTimer.restart()
                  root.toggleDevice(row.devVid, row.devPid, !row.devChecked, row.devName)
                }
              }

              // status dot
              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(8)
                height: Style.space(8)
                radius: width / 2
                color: row.devConnected
                  ? (row.devChecked ? Color.accent : Qt.alpha(root.foreground, 0.36))
                  : Qt.alpha(root.foreground, 0.18)
              }

              ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(30)
                anchors.right: toggle.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                  Layout.fillWidth: true
                  text: row.devName
                  color: row.devConnected ? root.foreground : Qt.alpha(root.foreground, 0.54)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  text: row.devVid + ":" + row.devPid +
                    (row.devConnected ? "" : " \u00b7 " + root.strings.absentLabel)
                  color: Qt.alpha(root.foreground, 0.54)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              ToggleSwitch {
                id: toggle
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                checked: row.devChecked
                foreground: root.foreground
                accent: Color.accent
                onToggled: {
                  idleCloseTimer.restart()
                  root.toggleDevice(row.devVid, row.devPid, !row.devChecked, row.devName)
                }
              }
            }
          }

          // Empty state
          ColumnLayout {
            anchors.centerIn: parent
            visible: deviceModel.count === 0
            width: parent.width

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: root.strings.noDevicesTitle
              color: Qt.alpha(root.foreground, 0.72)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              text: root.strings.noDevicesDesc
              color: Qt.alpha(root.foreground, 0.54)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
          }
        }

        // ---- apply
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.spacing.controlHeight + Style.space(8)
          Layout.topMargin: Style.space(4)
          radius: Style.cornerRadius
          color: {
            if (root.applying) return Qt.alpha(Color.accent, 0.45)
            if (!root.target) return Qt.alpha(root.foreground, 0.10)
            return Color.accent
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !root.applying && root.target !== ""
            onClicked: root.applyDevices()

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(8)

              Text {
                text: root.applying ? root.strings.applyingLabel : root.strings.applyLabel
                color: root.applying || root.target !== "" ? "#ffffff" : Qt.alpha(root.foreground, 0.54)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                visible: !root.applying && root.target !== ""
                text: root.checkedConnected > 0
                  ? "(" + root.checkedConnected + ")"
                  : "(0)"
                color: "#ffffff"
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
          }
        }

        // status line
        Text {
          Layout.fillWidth: true
          visible: !root.applying && root.applyResult !== null
          text: (root.applyResult && root.applyResult.ok ? "" : "\u2717 ") +
            (root.applyResult ? root.applyResult.message : "")
          color: root.applyResult && root.applyResult.ok
            ? Color.accent
            : Qt.alpha(root.foreground, 0.72)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          maximumLineCount: 3
        }

        // warnings
        Text {
          Layout.fillWidth: true
          visible: !root.applying && root.applyResult !== null &&
            root.applyResult.warnings && root.applyResult.warnings.length > 0
          text: (root.applyResult && root.applyResult.warnings)
            ? root.applyResult.warnings.join("\n") : ""
          color: Qt.alpha(root.foreground, 0.54)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          Layout.fillWidth: true
          visible: !root.applying && root.applyResult === null
          text: root.target === "" ? "" :
            (root.checkedConnected > 0 ? root.strings.applyHint : root.strings.noneChecked)
          color: Qt.alpha(root.foreground, 0.54)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // footer hint
        Text {
          Layout.fillWidth: true
          Layout.topMargin: Style.space(2)
          text: root.strings.shortcut
          color: Qt.alpha(root.foreground, 0.54)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  ListModel {
    id: deviceModel
  }

  Component.onCompleted: {
    root.rebuildModel()
    root.rebuildTargetOptions()
  }
}
