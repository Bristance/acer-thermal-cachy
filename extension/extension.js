// SPDX-License-Identifier: GPL-3.0-only

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension, gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const REFRESH_SECONDS = 5;
const DEFAULT_PROFILES = [
    {id: 'quiet', label: 'Quiet', icon: 'weather-clear-night-symbolic'},
    {id: 'normal', label: 'Normal', icon: 'power-profile-balanced-symbolic'},
    {id: 'performance', label: 'Performance', icon: 'power-profile-performance-symbolic'},
    {id: 'turbo', label: 'Turbo', icon: 'utilities-system-monitor-symbolic'},
];

function profileLabel(profileId) {
    return DEFAULT_PROFILES.find(profile => profile.id === profileId)?.label ?? _('Unknown');
}

function profileIcon(profileId) {
    return DEFAULT_PROFILES.find(profile => profile.id === profileId)?.icon ?? 'power-profile-balanced-symbolic';
}

function findControlCommand() {
    const envCommand = GLib.getenv('ACER_THERMAL_CONTROL_CMD');
    if (envCommand)
        return envCommand;

    const systemCommand = '/usr/local/bin/thermal-control.sh';
    if (GLib.file_test(systemCommand, GLib.FileTest.IS_EXECUTABLE))
        return systemCommand;

    const pathCommand = GLib.find_program_in_path('thermal-control.sh');
    if (pathCommand)
        return pathCommand;

    const localCommand = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'thermal-control.sh']);
    if (GLib.file_test(localCommand, GLib.FileTest.IS_EXECUTABLE))
        return localCommand;

    return systemCommand;
}

function normalizeState(rawState) {
    const current = rawState.current ?? rawState.mode ?? 'normal';
    const profiles = Array.isArray(rawState.profiles) && rawState.profiles.length > 0
        ? rawState.profiles
        : DEFAULT_PROFILES;

    return {
        current,
        profiles: profiles.map(profile => ({
            id: profile.id,
            label: profile.label ?? profileLabel(profile.id),
            icon: profile.icon_name ?? profile.icon ?? profileIcon(profile.id),
            active: profile.id === current || profile.active === true,
        })),
    };
}

function runCommand(argv, cancellable) {
    return new Promise((resolve, reject) => {
        try {
            const proc = new Gio.Subprocess({
                argv,
                flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
            });

            proc.init(cancellable);
            proc.communicate_utf8_async(null, cancellable, (source, result) => {
                try {
                    const [, stdout, stderr] = source.communicate_utf8_finish(result);
                    if (!source.get_successful()) {
                        reject(new Error(stderr.trim() || `${argv[0]} failed`));
                        return;
                    }

                    resolve(stdout.trim());
                } catch (error) {
                    reject(error);
                }
            });
        } catch (error) {
            reject(error);
        }
    });
}

const ThermalIndicator = GObject.registerClass(
class ThermalIndicator extends PanelMenu.Button {
    _init(extension) {
        super._init(0.0, extension.metadata.name, false);

        this._extension = extension;
        this._command = findControlCommand();
        this._cancellable = new Gio.Cancellable();
        this._refreshSource = 0;
        this._state = normalizeState({});
        this._menuItems = new Map();
        this._refreshInFlight = false;

        this._box = new St.BoxLayout({
            style_class: 'panel-status-menu-box',
        });
        this._icon = new St.Icon({
            icon_name: profileIcon(this._state.current),
            style_class: 'system-status-icon',
        });
        this._label = new St.Label({
            text: profileLabel(this._state.current),
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._box.add_child(this._icon);
        this._box.add_child(this._label);
        this.add_child(this._box);

        this._buildMenu();
        this._refresh();
        this._refreshSource = GLib.timeout_add_seconds(
            GLib.PRIORITY_DEFAULT,
            REFRESH_SECONDS,
            () => {
                this._refresh();
                return GLib.SOURCE_CONTINUE;
            },
        );
    }

    destroy() {
        if (this._refreshSource) {
            GLib.source_remove(this._refreshSource);
            this._refreshSource = 0;
        }

        this._cancellable.cancel();

        super.destroy();
    }

    _buildMenu() {
        this.menu.removeAll();
        this._menuItems.clear();

        const header = new PopupMenu.PopupMenuItem(_('Acer Thermal'), {
            reactive: false,
            can_focus: false,
        });
        this.menu.addMenuItem(header);

        for (const profile of this._state.profiles) {
            const item = new PopupMenu.PopupMenuItem(profile.label);
            item.connect('activate', () => this._setProfile(profile.id));
            this.menu.addMenuItem(item);
            this._menuItems.set(profile.id, item);
        }

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        const refreshItem = new PopupMenu.PopupMenuItem(_('Refresh'));
        refreshItem.connect('activate', () => this._refresh());
        this.menu.addMenuItem(refreshItem);

        this._syncUi();
    }

    async _refresh() {
        if (this._refreshInFlight)
            return;

        this._refreshInFlight = true;
        try {
            const stdout = await runCommand([this._command, 'list', '--json'], this._cancellable);
            this._state = normalizeState(JSON.parse(stdout));
            this._buildMenu();
        } catch (error) {
            this._showError(error);
        } finally {
            this._refreshInFlight = false;
        }
    }

    async _setProfile(profileId) {
        this._setBusy(true);
        this._state = normalizeState({
            current: profileId,
            profiles: this._state.profiles,
        });
        this._syncUi();

        try {
            await runCommand([this._command, 'set', profileId], this._cancellable);
            await this._refresh();
        } catch (error) {
            this._showError(error);
        } finally {
            this._setBusy(false);
        }
    }

    _syncUi() {
        const label = profileLabel(this._state.current);
        const icon = profileIcon(this._state.current);

        this._icon.icon_name = icon;
        this._label.text = label;
        this.accessible_name = `${_('Acer Thermal')}: ${label}`;

        for (const profile of this._state.profiles) {
            const item = this._menuItems.get(profile.id);
            if (item)
                item.setOrnament(profile.id === this._state.current ? PopupMenu.Ornament.CHECK : PopupMenu.Ornament.NONE);
        }
    }

    _setBusy(isBusy) {
        this.reactive = !isBusy;
        for (const item of this._menuItems.values())
            item.setSensitive(!isBusy);
    }

    _showError(error) {
        const message = error?.message ?? String(error);
        console.error(`[acer-thermal] ${message}`);
        Main.notifyError(_('Acer Thermal'), message);
    }
});

export default class AcerThermalExtension extends Extension {
    enable() {
        this._indicator = new ThermalIndicator(this);
        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
