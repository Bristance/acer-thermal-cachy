#!/usr/bin/env bash

set -euo pipefail

PLASMOID_ID="org.local.acerthermal.cachy"

usage() {
    cat <<EOF
Usage:
  $(basename "$0")

Adds Acer Thermal to the first available KDE Plasma panel.
EOF
}

case "${1:-}" in
    "")
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

if command -v qdbus6 >/dev/null 2>&1; then
    qdbus_cmd="qdbus6"
elif command -v qdbus >/dev/null 2>&1; then
    qdbus_cmd="qdbus"
else
    cat >&2 <<'EOF'
qdbus6 was not found.

Install it on CachyOS with:
  sudo pacman -S qt6-tools
EOF
    exit 1
fi

script="$(cat <<EOF
const pluginId = "${PLASMOID_ID}";
const panelList = panels();
let alreadyPresent = false;

for (let i = 0; i < panelList.length; i++) {
    const widgetList = panelList[i].widgets();
    for (let j = 0; j < widgetList.length; j++) {
        if (widgetList[j].type === pluginId) {
            alreadyPresent = true;
        }
    }
}

if (!alreadyPresent) {
    if (panelList.length === 0) {
        const panel = new Panel();
        panel.location = "bottom";
        panel.height = 44;
        panel.addWidget(pluginId);
    } else {
        panelList[0].addWidget(pluginId);
    }
}
EOF
)"

"$qdbus_cmd" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" >/dev/null

echo "Requested Plasma panel placement for: $PLASMOID_ID"
