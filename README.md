# Acer Thermal for CachyOS GNOME

This is the CachyOS/Arch GNOME port of the Acer thermal profile controller. It
adds a visible Acer Thermal item to the GNOME top bar and uses the same ACPI
backend approach as the original COSMIC applet.

## Features

- Shows the current thermal profile in the GNOME top bar
- Provides Quiet, Normal, Performance, and Turbo profile actions
- Supports GNOME Shell 42-44 with a legacy extension and GNOME Shell 45-50 with the modern extension API
- Polls the backend every five seconds
- Uses passwordless `sudo` when configured, otherwise falls back to `pkexec`
- Keeps the backend command compatible with the original applet:
  - `thermal-control.sh list --json`
  - `thermal-control.sh set <profile>`

## Requirements

- CachyOS or Arch-based GNOME desktop
- GNOME Shell 42 or newer, including GNOME Shell 50.x
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

Local install is available for testing, but profile changes will prompt through
`pkexec` or `sudo`:

```sh
./install.sh --local
```

After installing, restart GNOME Shell or log out and back in, then enable:

```sh
gnome-extensions enable acer-thermal-cachy@local
gnome-extensions info acer-thermal-cachy@local
```

Click the thermal profile label in the top bar. It appears as `Quiet`, `Normal`,
`Performance`, or `Turbo` with a small status icon.

## Passwordless Profile Changes

Profile changes require root because the backend writes to `/proc/acpi/call`.
To avoid a password prompt from the GNOME extension, install system-wide and add
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

- `State: OUT OF DATE`: installed metadata does not include your GNOME Shell major version.
- `/proc/acpi/call` missing: install/load `acpi_call`.
- Password prompts remain: run `./install.sh --system && ./install-sudoers.sh`.
- No top-bar item: restart GNOME Shell or log out and back in after installation.

GNOME Shell extension errors are visible with:

```sh
journalctl --user -f /usr/bin/gnome-shell
```

## Backend

The extension discovers the backend in this order:

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
