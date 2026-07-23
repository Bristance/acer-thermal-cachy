#!/usr/bin/env bash

set -euo pipefail

EXTENSION_UUID="acer-thermal-cachy@local"
BACKEND_NAME="thermal-control.sh"

usage() {
    cat <<EOF
Usage:
  $(basename "$0") [--local | --system]

Options:
  --local   Remove files from \$HOME/.local (default)
  --system  Remove files from system locations using sudo
EOF
}

uninstall_local() {
    local extension_dir="${HOME}/.local/share/gnome-shell/extensions/${EXTENSION_UUID}"
    local backend_path="${HOME}/.local/bin/${BACKEND_NAME}"

    rm -rf "$extension_dir"
    rm -f "$backend_path"

    cat <<EOF
Removed local install:
  Extension: $extension_dir
  Backend: $backend_path
EOF
}

uninstall_system() {
    local extension_dir="/usr/share/gnome-shell/extensions/${EXTENSION_UUID}"
    local backend_path="/usr/local/bin/${BACKEND_NAME}"

    sudo rm -rf "$extension_dir"
    sudo rm -f "$backend_path"

    cat <<EOF
Removed system install:
  Extension: $extension_dir
  Backend: $backend_path
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
    uninstall_system
else
    uninstall_local
fi
