#!/usr/bin/env bash

set -euo pipefail

SUDOERS_PATH="/etc/sudoers.d/acer-thermal-cachy"

if [[ -f "$SUDOERS_PATH" ]]; then
    sudo rm -f "$SUDOERS_PATH"
    echo "Removed sudoers rule: $SUDOERS_PATH"
else
    echo "No sudoers rule found at: $SUDOERS_PATH"
fi
