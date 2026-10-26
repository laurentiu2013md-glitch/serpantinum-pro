# Serpantinum Pro: features and configuration

Pro integrates the local island/ColorOS overhaul into the actual shell source. Helper scripts ship under `src/scripts/coloros/`; no personal snapshot, notes, paired-device state, monitor identity or historical user backup is distributed.

## Island and hover controls

The center bar rests as the configured modules. Hover the clock/weather for a combined calendar/weather view, music for the compact original player, and Bluetooth for the shared device panel. These are expansions of the bar’s own window. Legacy music/calendar and Bluetooth entry points route into the new interface.

On Hyprland the center becomes clock-only below the upper 10% of the monitor. A four-logical-pixel deadband avoids repeated animation reversals at the boundary. An open panel remains expanded while being used. The helper reads native Hyprland IPC every 80ms in one process, emits only zone transitions, and refreshes monitor geometry every five seconds. No global input overlay is installed. Without supported IPC, the full bar remains available.

```json
"coloros": {
  "neutralSurfaces": true,
  "clockOnlyAway": true,
  "reducedMotion": false,
  "adaptiveBlur": false
}
```

Merge these fields into `~/.config/serpantinum/settings.json`; do not replace unrelated settings. Set `clockOnlyAway` to false to keep the full center group visible. System reduced motion is respected regardless of the local option. Island animation/spacing lives in `bar/IslandPreview.qml`, `bar/TopBar.qml` and `bar/BarModule.qml`.

## Shared DropShelf

Hover the top 5% of the **bar’s height**, not the whole screen, to reveal the shelf. Drop supported files, URLs or plain text into the bar/body or QuickActions. Both views share `DropShelfStore` and `~/.local/state/serpantinum/dropshelf/shelf.json` immediately. Text becomes a private note file. Duplicate handling, previews, copy/removal and rearrangement use the same store; original source files are not deleted. External file references still require those files to exist.

Wayland does not provide universal drag detection here: the implementation responds to actual drag entry/drop on shell surfaces.

## Bluetooth

The island and QuickActions use one real BlueZ controller and the same panel. The legacy network screen redirects Bluetooth requests and retains Wi-Fi/Ethernet. Python D-Bus and PyGObject are required (`python-dbus` / `python-gobject` on Arch, `python3-dbus` / `python3-gobject` on Fedora), alongside BlueZ and the existing Quickshell dependencies.

The persistent pairing agent presents confirmation/PIN/passkey requests instead of approving automatically. Discovery stops when appropriate. Errors are displayed; unknown battery values remain absent. A soft rfkill block can be recovered through the existing graphical Polkit agent using `pkexec --disable-internal-agent /usr/bin/rfkill unblock bluetooth`. This requires a working graphical authentication agent; no password is read in chat or stored by the helper.

## Theme and blur

Fresh installs use rounded neutral gray surfaces, 50% shell background opacity and normal blur. Existing users retain their settings through the installer’s normal merge behavior. To opt in, merge `theme.elementOpacity: 50`, `theme.blurBackground: true`, `theme.blurStyle: "blur"` and the ColorOS fields above. The supplied Hyprland config adds a native layer rule for ColorOS namespaces; existing Hyprland users should add that rule from `compositors/hyprland/config/settings.lua` without replacing their own keybindings or animation rules.

GTK3/GTK4/Qt6ct palettes are synchronized from Matugen when the palette changes. This writes user theme files and adjusts the light/dark preference. Applications may require reopening and can impose their own styling. Arbitrary application backgrounds, web content, installed fonts/icons and drawing paper are not promised identical translucent appearance. Game Mode can disable compositor blur and use opaque shell fills. Occupancy-sensitive blur has intentionally been disabled.

## Snapshots and shellreset

After configuring the installed shell:

```bash
serpantinum-snapshot
shellreset --dry-run
shellreset
```

`serpantinum-snapshot` creates a private `~/quickshellconf` with the installed shell, settings, available launchers, saved state and related Hyprland/Matugen/GTK/Qt configuration. It refuses to overwrite an existing snapshot. Rename the old directory first when deliberately refreshing a baseline. `--output PATH` selects another directory; `--home PATH` supports isolated capture/testing.

`shellreset` invokes the snapshot’s `restore.sh --all`, preserving the original full-reset behavior. It also works outside Fish through the installed executable. `SERPANTINUM_SNAPSHOT_DIR` selects another snapshot. The Fish function delegates to that executable and forwards arguments.

The snapshot’s script can be called directly for finer control:

```bash
~/quickshellconf/restore.sh --dry-run         # Core only
~/quickshellconf/restore.sh --state           # Also saved data
~/quickshellconf/restore.sh --desktop         # Also desktop/theme config
~/quickshellconf/restore.sh --all             # Everything captured
```

Selected directories are replaced, not merged: stale files move into backups. `--all` includes saved notes/shelf state and the full captured Hyprland directory, including keybindings. The running shell is not restarted. Stop it before restoring and log out/in afterward for a clean desktop reload.

SHA-256 and symlink checks happen before writes; all selected copies are staged first. Existing destinations are backed up under `~/.local/state/quickshellconf-backups/<timestamp>/home/`, with a `receipt.json` recording paths that previously existed. Ordinary replacement failures attempt rollback. Power loss or SIGKILL cannot be handled transactionally.

To undo a successful reset, stop the shell, consult the receipt, move current selected targets aside and copy their saved counterparts from `backup/home/` into place. Remove/move newly installed paths that did not previously exist. Preserve backups until the desktop works.

Snapshots contain private state and absolute paths. They are intended primarily for the original account, not public distribution. External wallpapers, downloads, fonts, packages and system Bluetooth pairing keys are not copied. Bash and Python 3.11+ are required by the snapshot tools.

## Testing and scope

The source merge retains newer fork changes outside overlapping feature hunks, including its clipboard selection/contrast fixes. Local validation covers QML lint, Python/Bash/Fish syntax and isolated snapshot/restore tests. The original live implementation was exercised on one Hyprland laptop, including native shelf dragging, saved-device Bluetooth connection, scan/power, notification actions, reduced motion and blur restoration. The merged fork is not a claim of fresh physical pairing coverage, multi-monitor hardware validation, universal compositor behavior or measured 120 FPS.

Validation for this merge: all 172 changed/added QML files parsed successfully with Qt 6.12; three isolated snapshot/reset tests passed; Python AST, Bash and Fish syntax checks passed. Tests did not replace the active desktop or start a second bar.
