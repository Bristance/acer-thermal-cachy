#!/usr/bin/env bash

set -euo pipefail

SUDOERS_PATH="/etc/sudoers.d/acer-thermal-cachy"
BACKEND_PATH="/usr/local/bin/thermal-control.sh"

usage() {
    cat <<EOF
Usage:
  $(basename "$0") [--user USER]

Options:
  --user USER  Grant passwordless thermal profile changes to USER.
               Defaults to the user that invoked sudo, or \$USER.

This installs a sudoers rule for:
  $BACKEND_PATH set {quiet|normal|performance|turbo}

The backend must be installed system-wide and owned by root:
  ./install.sh --system
EOF
}

target_user="${SUDO_USER:-${USER:-}}"

case "${1:-}" in
    "")
        ;;
    --user)
        target_user="${2:-}"
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

if [[ -z "$target_user" ]]; then
    echo "Could not determine target user. Pass --user USER." >&2
    exit 1
fi

if [[ ! "$target_user" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "Refusing unsafe sudoers username: $target_user" >&2
    exit 1
fi

if ! id "$target_user" >/dev/null 2>&1; then
    echo "User does not exist: $target_user" >&2
    exit 1
fi

if [[ ! -f "$BACKEND_PATH" ]]; then
    cat >&2 <<EOF
Missing $BACKEND_PATH.

Install the backend system-wide first:
  ./install.sh --system
EOF
    exit 1
fi

owner="$(stat -c '%U:%G' "$BACKEND_PATH")"
mode="$(stat -c '%a' "$BACKEND_PATH")"

if [[ "$owner" != "root:root" ]]; then
    echo "Refusing to create sudoers rule for non-root-owned backend: $owner" >&2
    exit 1
fi

case "$mode" in
    755|555|750|550)
        ;;
    *)
        echo "Refusing unexpected backend mode $mode for $BACKEND_PATH" >&2
        exit 1
        ;;
esac

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

cat > "$tmp_file" <<EOF
# Allow Acer Thermal CachyOS Plasma widget to change only known thermal profiles.
Cmnd_Alias ACER_THERMAL_PROFILE = \\
    $BACKEND_PATH set quiet, \\
    $BACKEND_PATH set normal, \\
    $BACKEND_PATH set performance, \\
    $BACKEND_PATH set turbo

$target_user ALL=(root) NOPASSWD: ACER_THERMAL_PROFILE
EOF

sudo visudo -cf "$tmp_file"
sudo install -o root -g root -m 0440 "$tmp_file" "$SUDOERS_PATH"

cat <<EOF
Installed sudoers rule:
  $SUDOERS_PATH

$target_user can now run these without a password:
  sudo $BACKEND_PATH set quiet
  sudo $BACKEND_PATH set normal
  sudo $BACKEND_PATH set performance
  sudo $BACKEND_PATH set turbo
EOF
