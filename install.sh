#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSION_UUID="acer-thermal-cachy@local"
BACKEND_SRC="$SCRIPT_DIR/backend/thermal-control.sh"
BACKEND_NAME="thermal-control.sh"

usage() {
    cat <<EOF_USAGE
Usage:
  $(basename "$0") [--local | --system]

Options:
  --local   Install the GNOME extension into \$HOME/.local and backend into \$HOME/.local/bin (default)
  --system  Install the GNOME extension and backend system-wide using sudo

CachyOS dependencies are not installed automatically. The installer prints the
needed pacman commands for your current system state.
EOF_USAGE
}

install_extension_files() {
    local target="$1"
    local extension_src="$2"

    install -d "$target"
    install -m0644 "$extension_src/metadata.json" "$target/metadata.json"
    install -m0644 "$extension_src/extension.js" "$target/extension.js"
}

detect_gnome_major() {
    if ! command -v gnome-shell >/dev/null 2>&1; then
        echo ""
        return
    fi

    gnome-shell --version | sed -E 's/.* ([0-9]+)(\.[0-9]+)*/\1/'
}

select_extension_src() {
    local major
    major="$(detect_gnome_major)"

    case "$major" in
        42|43|44)
            echo "$SCRIPT_DIR/extension-legacy"
            ;;
        ""|*[!0-9]*)
            echo "$SCRIPT_DIR/extension"
            ;;
        *)
            echo "$SCRIPT_DIR/extension"
            ;;
    esac
}

installed_with_pacman() {
    command -v pacman >/dev/null 2>&1 && pacman -Q "$1" >/dev/null 2>&1
}

print_cachyos_dependency_status() {
    echo
    echo "CachyOS dependency status:"

    if ! command -v pacman >/dev/null 2>&1; then
        echo "  pacman: not found. This installer is tuned for CachyOS/Arch."
        return
    fi

    if command -v gnome-shell >/dev/null 2>&1; then
        echo "  GNOME Shell: $(gnome-shell --version)"
    else
        echo "  GNOME Shell: missing"
        echo "    Install with: sudo pacman -S gnome-shell gnome-shell-extensions"
    fi

    if command -v gnome-extensions >/dev/null 2>&1; then
        echo "  gnome-extensions: found"
    else
        echo "  gnome-extensions: missing"
        echo "    Install with: sudo pacman -S gnome-shell-extensions"
    fi

    if installed_with_pacman acpi_call || installed_with_pacman acpi_call-dkms; then
        echo "  acpi_call package: installed"
    else
        echo "  acpi_call package: missing"
        echo "    CachyOS kernel option: sudo pacman -S acpi_call"
        echo "    DKMS option: sudo pacman -S acpi_call-dkms dkms linux-cachyos-headers"
    fi

    if [[ -e /proc/acpi/call ]]; then
        echo "  /proc/acpi/call: present"
    else
        echo "  /proc/acpi/call: missing"
        echo "    Load module with: sudo modprobe acpi_call"
    fi

    if command -v pkexec >/dev/null 2>&1; then
        echo "  pkexec: found"
    else
        echo "  pkexec: missing"
        echo "    Install with: sudo pacman -S polkit"
    fi
}

install_local() {
    local extension_dir="${HOME}/.local/share/gnome-shell/extensions/${EXTENSION_UUID}"
    local bin_dir="${HOME}/.local/bin"
    local extension_src="$1"

    install_extension_files "$extension_dir" "$extension_src"
    install -d "$bin_dir"
    install -m0755 "$BACKEND_SRC" "$bin_dir/$BACKEND_NAME"

    cat <<EOF_LOCAL
Installed locally:
  Extension: $extension_dir
  Source: $extension_src
  Backend: $bin_dir/$BACKEND_NAME
EOF_LOCAL
}

install_system() {
    local extension_dir="/usr/share/gnome-shell/extensions/${EXTENSION_UUID}"
    local extension_src="$1"

    sudo install -d "$extension_dir"
    sudo install -m0644 "$extension_src/metadata.json" "$extension_dir/metadata.json"
    sudo install -m0644 "$extension_src/extension.js" "$extension_dir/extension.js"
    sudo install -Dm0755 "$BACKEND_SRC" "/usr/local/bin/$BACKEND_NAME"

    cat <<EOF_SYSTEM
Installed system-wide:
  Extension: $extension_dir
  Source: $extension_src
  Backend: /usr/local/bin/$BACKEND_NAME
EOF_SYSTEM
}

mode="local"

case "${1:-}" in
    "")
        ;;
    --local)
        mode="local"
        ;;
    --system)
        mode="system"
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac

extension_src="$(select_extension_src)"

if [[ "$mode" == "system" ]]; then
    install_system "$extension_src"
else
    install_local "$extension_src"
fi

print_cachyos_dependency_status

cat <<EOF_NEXT

Next steps on CachyOS GNOME:
  1. Install any missing dependencies printed above.
  2. Load acpi_call if needed:
       sudo modprobe acpi_call
  3. Restart GNOME Shell or log out and back in.
  4. Enable the extension:
       gnome-extensions enable ${EXTENSION_UUID}
  5. Confirm GNOME loaded it:
       gnome-extensions info ${EXTENSION_UUID}

For passwordless profile switching with the GNOME extension:
  ./install.sh --system
  ./install-sudoers.sh

Detected extension source:
  $extension_src

The extension looks for thermal-control.sh in:
  ACER_THERMAL_CONTROL_CMD
  /usr/local/bin/thermal-control.sh
  PATH
  \$HOME/.local/bin/thermal-control.sh
EOF_NEXT
