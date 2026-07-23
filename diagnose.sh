#!/usr/bin/env bash

set -euo pipefail

EXTENSION_UUID="acer-thermal-cachy@local"
LOCAL_EXTENSION_DIR="${HOME}/.local/share/gnome-shell/extensions/${EXTENSION_UUID}"
SYSTEM_EXTENSION_DIR="/usr/share/gnome-shell/extensions/${EXTENSION_UUID}"

section() {
    printf '\n== %s ==\n' "$1"
}

section "GNOME"
if command -v gnome-shell >/dev/null 2>&1; then
    gnome-shell --version
else
    echo "gnome-shell command not found"
fi

if command -v gnome-extensions >/dev/null 2>&1; then
    section "Extension state"
    gnome-extensions info "$EXTENSION_UUID" || true
else
    echo "gnome-extensions command not found"
fi

section "Installed files"
for path in "$LOCAL_EXTENSION_DIR" "$SYSTEM_EXTENSION_DIR"; do
    if [[ -d "$path" ]]; then
        echo "Found: $path"
        find "$path" -maxdepth 1 -type f -print
        if [[ -r "$path/metadata.json" ]]; then
            echo "Metadata shell-version:"
            grep -E '"shell-version"' "$path/metadata.json" || true
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

section "Passwordless sudo"
if [[ -x /usr/local/bin/thermal-control.sh ]]; then
    if sudo -n -l /usr/local/bin/thermal-control.sh set normal >/dev/null 2>&1; then
        echo "Passwordless sudo is configured for /usr/local/bin/thermal-control.sh"
    else
        echo "Passwordless sudo is not configured, or acpi_call is unavailable."
        echo "To configure it, run: ./install.sh --system && ./install-sudoers.sh"
    fi
else
    echo "/usr/local/bin/thermal-control.sh is not installed."
fi

section "Recent GNOME Shell messages"
if command -v journalctl >/dev/null 2>&1; then
    journalctl --user -n 80 /usr/bin/gnome-shell | grep -i 'acer-thermal\|extension' || true
else
    echo "journalctl command not found"
fi
