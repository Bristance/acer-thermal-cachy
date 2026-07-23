// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property var fallbackProfiles: [
        { id: "quiet", label: "Quiet", icon: "weather-clear-night-symbolic" },
        { id: "normal", label: "Normal", icon: "power-profile-balanced-symbolic" },
        { id: "performance", label: "Performance", icon: "power-profile-performance-symbolic" },
        { id: "turbo", label: "Turbo", icon: "utilities-system-monitor-symbolic" }
    ]

    property string currentProfile: "normal"
    property var profiles: fallbackProfiles
    property bool pending: false
    property string errorText: ""

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Acer Thermal"
    toolTipSubText: profileLabel(currentProfile)
    Plasmoid.icon: profileIcon(currentProfile)

    function quoteShell(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function commandLine(args) {
        var quotedArgs = ""
        for (var i = 0; i < args.length; i++)
            quotedArgs += " " + quoteShell(args[i])

        var command = "if [ -n \"${ACER_THERMAL_CONTROL_CMD:-}\" ]; then exec \"$ACER_THERMAL_CONTROL_CMD\"" + quotedArgs + "; fi"
        command += "; for cmd in /usr/local/bin/thermal-control.sh thermal-control.sh \"$HOME/.local/bin/thermal-control.sh\"; do"
        command += " if command -v \"$cmd\" >/dev/null 2>&1 || [ -x \"$cmd\" ]; then exec \"$cmd\"" + quotedArgs + "; fi"
        command += "; done; echo 'thermal-control.sh not found' >&2; exit 127"
        return "sh -c " + quoteShell(command)
    }

    function profileLabel(profileId) {
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i].id === profileId)
                return profiles[i].label || "Unknown"
        }

        for (var j = 0; j < fallbackProfiles.length; j++) {
            if (fallbackProfiles[j].id === profileId)
                return fallbackProfiles[j].label
        }

        return "Unknown"
    }

    function profileIcon(profileId) {
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i].id === profileId)
                return profiles[i].icon_name || profiles[i].icon || "preferences-system-power"
        }

        for (var j = 0; j < fallbackProfiles.length; j++) {
            if (fallbackProfiles[j].id === profileId)
                return fallbackProfiles[j].icon
        }

        return "preferences-system-power"
    }

    function refresh() {
        executable.connectSource(commandLine(["list", "--json"]))
    }

    function setProfile(profileId) {
        pending = true
        errorText = ""
        currentProfile = profileId
        executable.connectSource(commandLine(["set", profileId]))
    }

    function applyState(stdout) {
        var state = JSON.parse(stdout)
        currentProfile = state.current || state.mode || "normal"
        profiles = Array.isArray(state.profiles) && state.profiles.length > 0 ? state.profiles : fallbackProfiles
        errorText = ""
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)

            var stdout = String(data.stdout || "").trim()
            var stderr = String(data.stderr || "").trim()
            var exitCode = data["exit code"] || data.exitCode || 0

            if (exitCode !== 0) {
                pending = false
                errorText = stderr || "Command failed"
                return
            }

            if (sourceName.indexOf(" list ") !== -1) {
                try {
                    applyState(stdout)
                } catch (error) {
                    errorText = String(error)
                }
                pending = false
                return
            }

            refresh()
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: refresh()
    }

    compactRepresentation: MouseArea {
        id: compact
        implicitWidth: Kirigami.Units.gridUnit * 6
        implicitHeight: Kirigami.Units.gridUnit * 2
        onClicked: root.expanded = !root.expanded

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: profileIcon(currentProfile)
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            PlasmaComponents3.Label {
                text: profileLabel(currentProfile)
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: compact.width >= Kirigami.Units.gridUnit * 4
            }
        }
    }

    fullRepresentation: Item {
        implicitWidth: Kirigami.Units.gridUnit * 14
        implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: "Acer Thermal"
                font.bold: true
                Layout.fillWidth: true
            }

            Repeater {
                model: profiles

                delegate: QQC2.Button {
                    Layout.fillWidth: true
                    enabled: !pending
                    text: modelData.label + (modelData.id === currentProfile ? "  ✓" : "")
                    icon.name: modelData.icon_name || modelData.icon || profileIcon(modelData.id)
                    onClicked: setProfile(modelData.id)
                }
            }

            QQC2.Button {
                Layout.fillWidth: true
                enabled: !pending
                text: "Refresh"
                icon.name: "view-refresh"
                onClicked: refresh()
            }

            PlasmaComponents3.Label {
                text: pending ? "Applying profile..." : errorText
                color: errorText.length > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                visible: pending || errorText.length > 0
                Layout.fillWidth: true
            }
        }
    }
}
