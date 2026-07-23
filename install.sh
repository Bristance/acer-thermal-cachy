#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_ID="org.local.acerthermal.cachy"
PLASMOID_SRC="$SCRIPT_DIR/plasmoid"
BACKEND_SRC="$SCRIPT_DIR/backend/thermal-control.sh"
BACKEND_NAME="thermal-control.sh"

usage() {
    cat <<EOF
Usage:
  $(basename "$0") [--local | --system]

Options:
  --local   Install the Plasma widget into \$HOME/.local and backend into \$HOME/.local/bin (default)
  --system  Install the Plasma widget and backend system-wide using sudo

CachyOS dependencies are not installed automatically. The installer prints the
needed pacman commands for your current system state.
EOF
}

installed_with_pacman() {
    command -v pacman >/dev/null 2>&1 && pacman -Q "$1" >/dev/null 2>&1
}

install_plasmoid_files() {
    local target="$1"

    install -d "$target/contents/ui"
    install -m0644 "$PLASMOID_SRC/metadata.json" "$target/metadata.json"
    install -m0644 "$PLASMOID_SRC/contents/ui/main.qml" "$target/contents/ui/main.qml"
}

print_cachyos_dependency_status() {
    echo
    echo "CachyOS KDE dependency status:"

    if ! command -v pacman >/dev/null 2>&1; then
        echo "  pacman: not found. This installer is tuned for CachyOS/Arch."
        return
    fi

    if command -v plasmashell >/dev/null 2>&1; then
        echo "  plasmashell: $(plasmashell --version 2>/dev/null || echo found)"
    else
        echo "  plasmashell: missing"
        echo "    Install with: sudo pacman -S plasma-desktop"
    fi

    if command -v kpackagetool6 >/dev/null 2>&1; then
        echo "  kpackagetool6: found"
    else
        echo "  kpackagetool6: missing"
        echo "    Install with: sudo pacman -S kpackage"
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
    local plasmoid_dir="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"
    local bin_dir="${HOME}/.local/bin"

    if command -v kpackagetool6 >/dev/null 2>&1; then
        if kpackagetool6 --type Plasma/Applet --show "$PLASMOID_ID" >/dev/null 2>&1; then
            kpackagetool6 --type Plasma/Applet --upgrade "$PLASMOID_SRC"
        else
            kpackagetool6 --type Plasma/Applet --install "$PLASMOID_SRC"
        fi
    else
        install_plasmoid_files "$plasmoid_dir"
    fi

    install -d "$bin_dir"
    install -m0755 "$BACKEND_SRC" "$bin_dir/$BACKEND_NAME"

    cat <<EOF
Installed locally:
  Plasma widget: $PLASMOID_ID
  Backend: $bin_dir/$BACKEND_NAME
EOF
}

install_system() {
    local plasmoid_dir="/usr/share/plasma/plasmoids/${PLASMOID_ID}"

    sudo install -d "$plasmoid_dir/contents/ui"
    sudo install -m0644 "$PLASMOID_SRC/metadata.json" "$plasmoid_dir/metadata.json"
    sudo install -m0644 "$PLASMOID_SRC/contents/ui/main.qml" "$plasmoid_dir/contents/ui/main.qml"
    sudo install -Dm0755 "$BACKEND_SRC" "/usr/local/bin/$BACKEND_NAME"

    cat <<EOF
Installed system-wide:
  Plasma widget: $plasmoid_dir
  Backend: /usr/local/bin/$BACKEND_NAME
EOF
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

if [[ "$mode" == "system" ]]; then
    install_system
else
    install_local
fi

print_cachyos_dependency_status

cat <<EOF

Next steps on CachyOS KDE Plasma:
  1. Install any missing dependencies printed above.
  2. Load acpi_call if needed:
       sudo modprobe acpi_call
  3. Restart Plasma Shell or log out and back in:
       systemctl --user restart plasma-plasmashell.service
  4. Add the widget to your panel:
       Right-click panel -> Add Widgets -> Acer Thermal

Local Plasma package management:
  kpackagetool6 --type Plasma/Applet --show ${PLASMOID_ID}
  kpackagetool6 --type Plasma/Applet --remove ${PLASMOID_ID}

For passwordless profile switching with the Plasma widget:
  ./install.sh --system
  ./install-sudoers.sh

The widget looks for thermal-control.sh in:
  ACER_THERMAL_CONTROL_CMD
  /usr/local/bin/thermal-control.sh
  PATH
  \$HOME/.local/bin/thermal-control.sh
EOF
