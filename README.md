# Docker USB Passthrough

An Omarchy bar widget that picks which USB devices a Docker container gets.

A panel lists every connected USB device with a checkbox. Check the devices you want, pick a container, and hit **Apply** — the container is recreated so that exactly the checked `--device` flags are attached. Nothing all-or-nothing, no `--privileged`.

Your selections are remembered (in `~/.local/state/omarchy/docker-usb/state.json`), so replugging the device or restarting the shell keeps your choices.

## How it works

- **Enumerates** USB devices via `sysfs` (skips hubs, root hubs, and interface nodes) and shows a friendly name for each (`lsusb`-style vendor:product plus a label if known).
- **Apply** resolves each checked device to a stable path and recreates the target container:
  - Installs a udev rule (`/etc/udev/rules.d/90-docker-usb-<vid>-<pid>.rules`) that creates `/dev/usb-<vid>-<pid>` with `0666` permissions via `pkexec` (a one-time password dialog). If you decline, the device is attached by bus path instead, with a warning that it may not survive a reboot.
  - Swaps the container atomically: the old container is renamed aside and stopped (releasing published ports), a new one is created with the checked devices, and the old is removed only on success. On failure the old container is renamed back and restarted.
  - Reconstructs the container from `docker inspect`, preserving image, command, ports, volumes, env, restart policy, networks, healthcheck, limits, etc. Containers that were stopped stay stopped.
- **Remembers** state per device (checked/name) and remembers which container is the target.

## Requirements

- [Docker Engine](https://docs.docker.com/engine/install/) (native, not Docker Desktop)
- `jq`
- `polkit` (for the `pkexec` password dialog when installing udev rules)

The container itself often needs `pcscd` (for smart-card readers like a DIGIPASS) — install it inside the container if your app expects a PC/SC device.

## Install

```
omarchy plugin add https://github.com/ChazPounder78/omarchy-docker-usb.git
omarchy plugin enable io.github.chazpounder78.docker-usb --section right
```

Then enter the widget via its app-launcher entry (`usb`, `docker-usb`, `passthrough`, …).

## Usage

1. Open the panel (click the USB icon in the bar, or launch `Docker USB`).
2. Pick a container from the **target** dropdown (from `docker ps -a`).
3. Check or uncheck the USB devices you want inside it.
4. Press **Apply** and approve the password dialog when it appears.

Devices vanish from the panel while they are unplugged. Devices you remember but can't currently resolve are skipped at apply time with a warning.

## Known limitations

- Two identical vendor:product devices are selected together (they can't be told apart by hardware ID alone).
- **Apply recreates the container** — anything not recreated exactly (e.g. `--gpus`, custom network rewiring edge cases) may be lost; you'll get a warning where the helper can tell. Docker Compose-managed containers are recreated without Compose's knowledge.
- The DIGIPASS family and similar PC/SC tokens need `pcscd` service running inside the container.

## Removal

```
omarchy plugin remove io.github.chazpounder78.docker-usb
sudo rm -f /etc/udev/rules.d/90-docker-usb-*.rules && sudo udevadm control --reload-rules
sudo rm -f /dev/usb-*-*   # or just reboot
```

## License

MIT