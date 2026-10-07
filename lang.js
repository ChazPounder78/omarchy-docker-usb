.pragma library

// UI strings for the Docker USB Passthrough plugin.

var strings = {
  tooltip: "Docker USB — click to pick devices",
  title: "DOCKER USB",
  targetLabel: "TARGET CONTAINER",
  targetHint: "Changes apply to this container",
  targetEmpty: "No containers found",
  targetEmptyDesc: "Start a docker container and refresh.",
  devicesLabel: "USB DEVICES",
  devicesHint: "Checked devices pass through",
  connectedLabel: "connected",
  absentLabel: "not connected",
  applyLabel: "Apply",
  applyingLabel: "Applying…",
  applyHint: "Restarts the target container with the checked devices.",
  refreshIcon: "\uF021",
  noDevicesTitle: "No USB devices found",
  noDevicesDesc: "Plug in a USB device and hit refresh.",
  noneChecked: "Nothing checked — container gets no USB devices.",
  appliedOk: "Applied",
  appliedFail: "Apply failed",
  shortcut: "Enter: apply \u00b7 Esc: close \u00b7 click a row: toggle"
}

function pick(lang) {
  return strings
}
