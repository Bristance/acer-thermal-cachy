#!/usr/bin/env bash
# Bare-bones ACPI thermal mode switcher for Acer Swift X 14 (SFX14-71G).
# Requires the acpi_call kernel module and write access to /proc/acpi/call.

set -euo pipefail

ACPI_METHOD="${ACER_THERMAL_ACPI_METHOD:-\\_SB.PC00.WMID.WMAA}"
STATE_FILE="${ACER_THERMAL_STATE_FILE:-/run/acer_thermal_mode}"
DEFAULT_MODE="${ACER_THERMAL_DEFAULT_MODE:-normal}"

usage() {
    cat <<'EOF'
Usage:
  thermal-control.sh get
  thermal-control.sh get-json
  thermal-control.sh list
  thermal-control.sh list --json
  thermal-control.sh set {quiet|normal|performance|turbo}
EOF
}

mode_label() {
    case "${1:-}" in
        quiet) echo "Quiet" ;;
        normal) echo "Normal" ;;
        performance) echo "Performance" ;;
        turbo) echo "Turbo" ;;
        *) echo "Unknown" ;;
    esac
}

mode_icon_name() {
    case "${1:-}" in
        quiet) echo "weather-clear-night-symbolic" ;;
        normal) echo "power-profile-balanced-symbolic" ;;
        performance) echo "power-profile-performance-symbolic" ;;
        turbo) echo "utilities-system-monitor-symbolic" ;;
        *) echo "power-profile-balanced-symbolic" ;;
    esac
}

validate_mode() {
    case "${1:-}" in
        quiet|normal|performance|turbo) return 0 ;;
        *) return 1 ;;
    esac
}

json_bool() {
    if [[ "${1:-}" == "${2:-}" ]]; then
        echo true
    else
        echo false
    fi
}

read_mode() {
    local current=""
    if [[ -r "$STATE_FILE" ]]; then
        current="$(tr -d '\n' < "$STATE_FILE" 2>/dev/null || true)"
    fi

    if validate_mode "$current"; then
        printf '%s\n' "$current"
    else
        printf '%s\n' "$DEFAULT_MODE"
    fi
}

write_mode() {
    local mode="$1"
    install -m 0644 /dev/null "$STATE_FILE"
    printf '%s\n' "$mode" > "$STATE_FILE"
    chmod 0644 "$STATE_FILE"
}

print_mode_json() {
    local current label icon_name
    current="$(read_mode)"
    label="$(mode_label "$current")"
    icon_name="$(mode_icon_name "$current")"
    printf '{"mode":"%s","label":"%s","icon_name":"%s","state_source":"cache"}\n' \
        "$current" "$label" "$icon_name"
}

print_waybar_json() {
    local current label icon_name
    current="$(read_mode)"
    label="$(mode_label "$current")"
    icon_name="$(mode_icon_name "$current")"
    printf '{"text":"%s","tooltip":"Thermal Mode: %s","class":"%s","alt":"%s"}\n' \
        "$label" "$label" "$current" "$icon_name"
}

print_profiles_text() {
    cat <<'EOF'
quiet
normal
performance
turbo
EOF
}

print_profile_json() {
    local current="$1"
    local mode="$2"
    printf '  {"id":"%s","label":"%s","icon_name":"%s","active":%s}' \
        "$mode" "$(mode_label "$mode")" "$(mode_icon_name "$mode")" "$(json_bool "$current" "$mode")"
}

print_profiles_json() {
    local current
    current="$(read_mode)"
    printf '{"current":"%s","profiles":[\n' "$current"
    print_profile_json "$current" quiet
    printf ',\n'
    print_profile_json "$current" normal
    printf ',\n'
    print_profile_json "$current" performance
    printf ',\n'
    print_profile_json "$current" turbo
    printf '\n]}\n'
}

set_mode() {
    local mode="${1:-}"

    if ! validate_mode "$mode"; then
        usage >&2
        exit 1
    fi

    if [[ ! -w /proc/acpi/call ]]; then
        echo "Cannot write /proc/acpi/call. Is acpi_call loaded?" >&2
        exit 1
    fi

    case "$mode" in
        quiet)       echo "$ACPI_METHOD 1 1 {7, 0, 2, 0}" > /proc/acpi/call ;;
        normal)      echo "$ACPI_METHOD 1 1 {7, 0, 0, 0}" > /proc/acpi/call ;;
        performance) echo "$ACPI_METHOD 1 1 {7, 0, 3, 0}" > /proc/acpi/call ;;
        turbo)       echo "$ACPI_METHOD 1 1 {7, 0, 4, 0}" > /proc/acpi/call ;;
    esac

    write_mode "$mode"
}

if [[ "${1:-}" == "set" && "$EUID" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo -n "$0" "$@" 2>/dev/null && exit 0
    fi

    if command -v pkexec >/dev/null 2>&1; then
        exec pkexec "$0" "$@"
    fi

    exec sudo "$0" "$@"
fi

case "${1:-}" in
    get)
        print_mode_json
        ;;
    get-json)
        print_waybar_json
        ;;
    list)
        if [[ "${2:-}" == "--json" ]]; then
            print_profiles_json
        else
            print_profiles_text
        fi
        ;;
    set)
        set_mode "${2:-}"
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
