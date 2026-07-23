# Acer Thermal for CachyOS KDE Plasma

This is the CachyOS/Arch KDE Plasma 6 port of the Acer thermal profile
controller. It installs a Plasma 6 panel widget that controls the same ACPI
backend used by the original COSMIC applet.

## Features

- Shows the current thermal profile in a KDE Plasma 6 panel widget
- Provides Quiet, Normal, Performance, and Turbo profile actions
- Polls the backend every five seconds
- Uses passwordless `sudo` when configured, otherwise falls back to `pkexec`
- Keeps the backend command compatible with the original applet:
  - `thermal-control.sh list --json`
  - `thermal-control.sh set <profile>`

## Requirements

- CachyOS or Arch-based KDE Plasma desktop
- KDE Plasma 6 with `kpackagetool6`
- `acpi_call` loaded and exposing `/proc/acpi/call`
- An Acer firmware method compatible with `\_SB.PC00.WMID.WMAA`
- `sudo`; `pkexec` from `polkit` is used as an interactive fallback

## CachyOS Dependencies

For the default CachyOS kernel, start with:

```sh
sudo pacman -S acpi_call
sudo modprobe acpi_call
```

For a DKMS setup or a kernel where the prebuilt module is not available:

```sh
sudo pacman -S acpi_call-dkms dkms linux-cachyos-headers
sudo modprobe acpi_call
```

If you use a different kernel, install its matching headers package instead of
`linux-cachyos-headers`.

Check the module:

```sh
lsmod | grep acpi_call
ls -l /proc/acpi/call
```

## Install

System install is recommended because passwordless profile switching requires a
root-owned backend at `/usr/local/bin/thermal-control.sh`:

```sh
./install.sh --system
```

To install and ask Plasma to place Acer Thermal directly on the panel:

```sh
./install.sh --system --add-to-panel
```

Local install is available for testing. It uses `kpackagetool6` when available,
but profile changes will prompt through `pkexec` or `sudo` unless passwordless
sudo is configured:

```sh
./install.sh --local
```

Restart Plasma Shell or log out and back in:

```sh
systemctl --user restart plasma-plasmashell.service
```

Then add the widget:

```text
Right-click panel -> Add Widgets -> Acer Thermal
```

You can also add it to the first available panel later with:

```sh
./add-to-panel.sh
```

For local package inspection/removal:

```sh
kpackagetool6 --type Plasma/Applet --show org.local.acerthermal.cachy
kpackagetool6 --type Plasma/Applet --remove org.local.acerthermal.cachy
```

## Passwordless Profile Changes

Profile changes require root because the backend writes to `/proc/acpi/call`.
To avoid a password prompt from the Plasma widget, install system-wide and add
the narrow sudoers rule:

```sh
./install.sh --system
./install-sudoers.sh
```

The sudoers rule only permits the current user to run:

```sh
sudo /usr/local/bin/thermal-control.sh set quiet
sudo /usr/local/bin/thermal-control.sh set normal
sudo /usr/local/bin/thermal-control.sh set performance
sudo /usr/local/bin/thermal-control.sh set turbo
```

Do not add a passwordless sudoers rule for
`$HOME/.local/bin/thermal-control.sh`; that path is user-writable and would be
equivalent to broad root access.

Remove the rule with:

```sh
./uninstall-sudoers.sh
```

## Troubleshooting

Run:

```sh
./diagnose.sh
```

The most common issues are:

- `/proc/acpi/call` missing: install/load `acpi_call`.
- Password prompts remain: run `./install.sh --system && ./install-sudoers.sh`.
- Widget not listed: restart Plasma Shell or log out and back in after installation.
- Widget listed but no profile changes: verify `/usr/local/bin/thermal-control.sh list --json`.

Plasma messages are visible with:

```sh
journalctl --user -f
```

## Backend

The widget discovers the backend in this order:

1. `ACER_THERMAL_CONTROL_CMD`
2. `/usr/local/bin/thermal-control.sh`
3. `thermal-control.sh` from `PATH`
4. `$HOME/.local/bin/thermal-control.sh`

The backend caches the selected mode in `/run/acer_thermal_mode`. Override
hardware-specific values with:

```sh
ACER_THERMAL_ACPI_METHOD='\\_SB.PC00.WMID.WMAA'
ACER_THERMAL_STATE_FILE=/run/acer_thermal_mode
ACER_THERMAL_DEFAULT_MODE=normal
```

Run the backend without touching hardware:

```sh
ACER_THERMAL_STATE_FILE=/tmp/acer_thermal_mode ./backend/thermal-control.sh list --json
```
