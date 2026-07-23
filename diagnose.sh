#!/usr/bin/env bash

set -euo pipefail

PLASMOID_ID="org.local.acerthermal.cachy"
LOCAL_PLASMOID_DIR="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"
SYSTEM_PLASMOID_DIR="/usr/share/plasma/plasmoids/${PLASMOID_ID}"

section() {
    printf '\n== %s ==\n' "$1"
}

section "KDE Plasma"
if command -v plasmashell >/dev/null 2>&1; then
    plasmashell --version || true
else
    echo "plasmashell command not found"
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    section "Plasmoid registry"
    kpackagetool6 --type Plasma/Applet --show "$PLASMOID_ID" || true
else
    echo "kpackagetool6 command not found"
fi

section "Installed files"
for path in "$LOCAL_PLASMOID_DIR" "$SYSTEM_PLASMOID_DIR"; do
    if [[ -d "$path" ]]; then
        echo "Found: $path"
        find "$path" -maxdepth 3 -type f -print
        if [[ -r "$path/metadata.json" ]]; then
            echo "Metadata id:"
            grep -E '"Id"' "$path/metadata.json" || true
        fi
    else
        echo "Missing: $path"
    fi
done

section "Backend"
backend=""
if [[ -n "${ACER_THERMAL_CONTROL_CMD:-}" ]]; then
    backend="$ACER_THERMAL_CONTROL_CMD"
elif [[ -x /usr/local/bin/thermal-control.sh ]]; then
    backend="/usr/local/bin/thermal-control.sh"
elif command -v thermal-control.sh >/dev/null 2>&1; then
    backend="$(command -v thermal-control.sh)"
elif [[ -x "${HOME}/.local/bin/thermal-control.sh" ]]; then
    backend="${HOME}/.local/bin/thermal-control.sh"
fi

if [[ -z "$backend" ]]; then
    echo "thermal-control.sh not found"
else
    echo "Backend: $backend"
    "$backend" list --json || true
fi

section "acpi_call"
if [[ -e /proc/acpi/call ]]; then
    echo "/proc/acpi/call is present"
else
    echo "/proc/acpi/call is missing"
    echo "Install/load with one of:"
    echo "  sudo pacman -S acpi_call && sudo modprobe acpi_call"
    echo "  sudo pacman -S acpi_call-dkms dkms linux-cachyos-headers && sudo modprobe acpi_call"
fi

section "Passwordless sudo"
if [[ -x /usr/local/bin/thermal-control.sh ]]; then
    if sudo -n -l /usr/local/bin/thermal-control.sh set normal >/dev/null 2>&1; then
        echo "Passwordless sudo is configured for /usr/local/bin/thermal-control.sh"
    else
        echo "Passwordless sudo is not configured."
        echo "To configure it, run: ./install.sh --system && ./install-sudoers.sh"
    fi
else
    echo "/usr/local/bin/thermal-control.sh is not installed."
fi

section "Recent Plasma messages"
if command -v journalctl >/dev/null 2>&1; then
    journalctl --user -n 120 | grep -i 'acerthermal\|acer thermal\|plasmoid\|plasma' || true
else
    echo "journalctl command not found"
fi
