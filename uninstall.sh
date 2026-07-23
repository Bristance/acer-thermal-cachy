#!/usr/bin/env bash

set -euo pipefail

PLASMOID_ID="org.local.acerthermal.cachy"
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
    local plasmoid_dir="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"
    local backend_path="${HOME}/.local/bin/${BACKEND_NAME}"

    rm -rf "$plasmoid_dir"
    rm -f "$backend_path"

    cat <<EOF
Removed local install:
  Plasma widget: $plasmoid_dir
  Backend: $backend_path
EOF
}

uninstall_system() {
    local plasmoid_dir="/usr/share/plasma/plasmoids/${PLASMOID_ID}"
    local backend_path="/usr/local/bin/${BACKEND_NAME}"

    sudo rm -rf "$plasmoid_dir"
    sudo rm -f "$backend_path"

    cat <<EOF
Removed system install:
  Plasma widget: $plasmoid_dir
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
