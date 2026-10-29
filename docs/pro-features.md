# Serpantinum Pro: features and configuration

Pro integrates the local island/ColorOS overhaul into the actual shell source. Helper scripts ship under `src/scripts/coloros/`; no personal snapshot, notes, paired-device state, monitor identity or historical user backup is distributed.

## Island and hover controls

The center bar rests as the configured modules. Hover the clock/weather for a combined calendar/weather view, music for the compact original player, Bluetooth for the shared device panel, and Wi-Fi for the new network panel. These are expansions of the bar’s own window. Legacy music/calendar and Bluetooth entry points route into the new interface.

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

## Quick Controls, launcher and status

While the center island is compact, an iOS-inspired red ring and dot beside the clock indicate active screen recording. It follows the existing recorder PID/start state and clears after stop or process exit. The original recording face shares the same state watcher. Reduced motion and Game Mode keep the indicator static.

The top-right pulltab opens separate glass controls for Do Not Disturb, Game Mode, light/dark mode, Settings, Lock and Calculator, arranged as six buttons in one row. Wi-Fi, Bluetooth, music, battery and the focus timer remain in the center island. Each control has its own surface; there is no outer card or heading. Hover tooltips are omitted. Both panels close after the pointer stays outside for one second, and returning cancels the countdown. Active drag operations and temporary island feedback retain their own lifecycle.

The battery icon opens a wave-style status card with remaining time, live power draw, physical battery health and power profiles. Power sampling runs twice a second while the battery view is visible. If `/etc/ryzen-performance-limits.json` exists, its configured preset labels appear while the existing power-profile service applies the limits; the shell does not replace that service. The compact and expanded header show the same clock; the date lives in Calendar.

The launcher uses real applications only. Pin a row with its pin button or Ctrl+P; Ctrl+1/2/3 selects All, Favorites or Recent. QuickActions supports arrow keys to change tools, Ctrl+1–8 for direct selection, and Tab/Shift+Tab to move between controls. The calendar island shares the existing QuickActions focus timer.

Network controls show signal and link speed. Share Wi-Fi explicitly generates a private, temporary QR image for supported personal or open networks; closing the view removes it. Advanced network settings open the Connectivity page in Settings, with saved profiles, autoconnect, metering, IPv4 and labeled DNS controls using the shared Settings selectors. AdGuard DNS is prefilled when no DNS override exists; Save applies the choice. Existing custom DNS values remain visible. Saved personal Wi-Fi passwords can be revealed after root verification through PAM-backed `su`; the masked authentication field passes its value over stdin only. Revealed passwords clear after 30 seconds, on Hide, when selecting another connection, or when leaving the page.

The wallpaper picker combines photos and videos in one horizontal row. Optional wallpaper depth follows desktop pointer movement and launcher transitions; Game Mode and reduced motion suppress it.

Local `.ics` calendars in `~/.local/share/serpantinum/calendars/` and available Evolution calendar caches supply upcoming events. The calendar has no importer UI. Install the optional recurrence runtime with `src/scripts/coloros/install-calendar-runtime.sh`. For a sharper Breeze cursor with the same artwork, `src/scripts/coloros/install-breeze-vector.py` builds the vector theme and high-resolution fallback from installed KDE Breeze sources; see [cursor credits](cursor-credits.md).

## Shared DropShelf

Hover the top 5% of the **bar’s height**, not the whole screen, to reveal the shelf. Drop supported files, URLs or plain text into the bar/body or QuickActions. Both views share `DropShelfStore` and `~/.local/state/serpantinum/dropshelf/shelf.json` immediately. Text becomes a private note file. Duplicate handling, previews, copy/removal and rearrangement use the same store; original source files are not deleted. External file references still require those files to exist.

Image and video links download into a private `/dev/shm` directory after content verification, including extensionless URLs and media exposed by linked pages. Each download is limited to 128 MiB and available RAM; simultaneous drops queue. Sites requiring authentication or streaming extraction may need a direct media link. Ordinary pages without downloadable media remain links. Both shelf views share these entries. Opening, successfully dragging out, removing or clearing temporary media schedules deletion after five seconds; Undo cancels pending drag-out cleanup during that interval. Media previews also stay in RAM and are removed with their source. Cleanup survives shell reloads. External original files are never deleted.

Wayland does not provide universal drag detection here: the implementation responds to actual drag entry/drop on shell surfaces.

## Bluetooth

The island and QuickActions use one real BlueZ controller and the same panel. The legacy network screen redirects Bluetooth requests and retains Wi-Fi/Ethernet. Python D-Bus and PyGObject are required (`python-dbus` / `python-gobject` on Arch, `python3-dbus` / `python3-gobject` on Fedora), alongside BlueZ and the existing Quickshell dependencies.

The persistent pairing agent presents confirmation/PIN/passkey requests instead of approving automatically. Discovery stops when appropriate. Errors are displayed; unknown battery values remain absent. A soft rfkill block can be recovered through the existing graphical Polkit agent using `pkexec --disable-internal-agent /usr/bin/rfkill unblock bluetooth`. This requires a working graphical authentication agent; no password is read in chat or stored by the helper.

## Theme and blur

Appearance mode offers Light, Gray and Dark in that order. Gray uses a neutral `#808080` base, coordinated gray surfaces and dark text, preserving wallpaper accent colors and existing opacity/blur settings. The Quick Controls appearance button cycles all three modes; Settings → Appearance also provides a direct selector. GTK and Qt palettes follow the gray mode where supported.

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

## Network panel and appearance button

Hover the Wi-Fi module to open the integrated network panel. Click and legacy `network` commands also route there. It shares the same rounded parent surface, Material switch and compact row styling as Bluetooth, and is available as the Network tab in QuickActions. Native Quickshell/NetworkManager objects provide signal strength, saved and connected status, power, connection/disconnection and confirmed forgetting. Personal Wi-Fi passwords are passed through the native connection API rather than process arguments, and are cleared when submitted, canceled or the panel closes. Enterprise setup can be opened in `nmtui` through the existing terminal. Ethernet interfaces appear when available.

Scanning is enabled only while a panel is visible and stops after eight seconds or when all views close. A pending connection listens for actual success/failure and has a timeout; network-list reordering does not replace that listener. The default bar includes the Wi-Fi module; existing configurations can add `wifi` through Settings.

The battery/system menu contains a sun/moon button immediately beside Game Mode. Its active state represents dark mode. It uses the existing Matugen generator and current wallpaper (or a palette-derived static fallback), preserves unrelated settings, disables repeated requests while generating, and persists the selected mode. System reduced-motion support is unchanged.

Live checks verified the connected network, island and QuickActions loading, scan start/timeout/close behavior, and repeated command routing without disconnecting the current Wi-Fi session. The light/dark action regenerated both palettes successfully and restored the original mode. Connecting to a new SSID, password authentication, forgetting a network and physical Ethernet transitions were not exercised against live hardware during this change.

## Island motion and desktop theme refinements

Island width, expansion height and clock movement use interruptible Qt springs. Hidden center modules retain their natural measurements and full layout slots, so expansion does not stack them. Secondary labels reveal once the moving clock clears their space; opening the same panel again preserves its opacity. Extra header padding protects text during the closing rebound. The background follows the island center directly in both sizes, and classic clock/date labels share a horizontal center. Reduced motion disables spring behaviors.

The Matugen mode button has no hover tooltip. Dark-mode shell text and synchronized GTK/Qt foregrounds are white. The palette helper installs a Nautilus-scoped stylesheet, reads the background gray from `~/.config/kitty/colors.conf` and opacity from `kitty.conf` (fallback `#b3b3b3` / 50%), and keeps the terminal foreground white in dark mode. Application content and ANSI escape colors can override foreground roles. Reopen Nautilus after the stylesheet is first installed. Native `backdrop-filter` support requires a recent GTK build; verified locally with GTK 51.1 and Hyprland 0.56.2. Game Mode disables compositor blur and restores the prior blur state on exit.

Live validation covers repeated panel opening, panel switching, rapid animation reversals, clock-only restoration, and sampled header geometry during expansion/collapse. Snapshot/reset tests run against temporary homes; desktop theme generation is checked in isolation.

## Animated weather and island OSD

The weather/calendar island has a procedural sky in normal mode: drifting cloud layers, stars and a moon at night, a sun by day, and rain, snow, fog or storms selected from the current WMO weather code. The provider saves the current code, description and day/night flag, with icon/time fallbacks for older cache files. The canvas repaints at 20 Hz only while visible. System reduced motion freezes the scene; Game Mode uses the plain surface. The background uses the configured bar opacity and retains compositor blur.

Volume, brightness, microphone, Caps Lock, Num Lock and airplane-mode feedback share the island. Audio and brightness retain their real values and controls; the lock/airplane display preferences are respected. A short OSD temporarily expands the island, then restores the previous panel. While a panel is being used, the OSD appears inside it. The old standalone OSD window is no longer instantiated.

Game Mode also activates the shared reduced-motion policy: island springs, fades and bar transitions stop while compositor blur, shadows and animations are disabled. Normal mode restores the configured effects and opacity.

The moon is composited separately at 98% opacity, with a white surface, soft lunar shading and a stronger halo; the sky itself retains the configured background opacity. Thin drifting cloud bands and occasional shooting stars add depth to clear/cloudy night scenes.

The daytime sun is twice the original size and peeks beyond the right edge of the weather surface. The night moon keeps its inset position.

The charging island has a horizontal green liquid wave beneath its existing battery text. Its fill follows the displayed percentage, its bounds and corners match the battery pill, and it disappears at 100%. Unplugging, reduced motion and Game Mode stop the animation.

## Island effects and cursor locator

For Spotify, the selected track's artwork fills the entire rounded island, including its header, with blur and the configured bar opacity (50% by default). Other players retain the smaller artwork glow. It gently responds to shared Cava audio data while playing, without an additional waveform. The original player's audio, equalizer and lyrics controls remain available.

Bluetooth device connections spring the device icon and emit a ripple; the Wi-Fi header emits repeating ripples while scanning. DropShelf additions bounce into place and briefly highlight the shelf in both the island and QuickActions. Reordering existing files does not replay the landing animation.

Notification arrivals queue in the island instead of opening a separate popup window. They remain in notification history after the preview expires, and explicit Dismiss removes them. Existing notification actions and Do Not Disturb are respected. Hovering holds an arrival open. While using a panel, the arrival appears inline.

On Hyprland, shake the pointer back and forth to enlarge the actual rendered cursor, including application-provided cursor images. A pinned build of [hypr-dynamic-cursors](https://github.com/VirtCode/hypr-dynamic-cursors) provides the KDE-inspired native rendering path: 3× initial magnification, up to 4.5× during continued shaking, a two-second hold, and a smooth return. Tilt and stretch modes are disabled. Reduced motion, the cursor-locator switch, and Game Mode disable the effect. The zone helper only controls the plugin and reads its scale events; it no longer changes cursor theme sizes.

## Focused fork settings and previews

Settings now opens to a Serpantinum Pro overview, with dedicated Dynamic Island, Music, Connectivity, Notifications and QuickActions pages. Appearance, bar layout/modules, desktop/display/lock-screen, launcher and capture controls remain available. Dock, standalone OSD placement, the old welcome page, desktop-widget configuration, Wellbeing and disabled Idle pages are removed from navigation and search. Useful lock-key and airplane OSD preferences live under Dynamic Island. All new switches write the same saved configuration used by the running shell.

Spotify backgrounds crossfade after the next image has loaded. Bright artwork gets a stronger dark scrim while the artwork itself retains the configured bar opacity. Music controls and the removed extra waveform are unchanged. Notification bursts from the same app within two seconds share one preview and counter; every message remains in history, and the newest notification supplies its actions. The charging pill emits one green pulse on a real transition to 100%, then hides its charging wave. Opening the shell while already full does not trigger a completion pulse.

Bluetooth shows individual battery components only when BlueZ exposes them; otherwise it shows the overall battery or “Battery not reported.” The shell does not invent left/right/case percentages. Shelf previews cover images, video frames, PDF first pages, text, DOCX and ODT files. Conversion is queued, cached by file metadata and bounded by size and timeouts; remote URLs are never fetched for previews, and originals are not modified.

### Native cursor build

Run `src/scripts/coloros/install-cursor-plugin.sh` to reproduce the local cursor setup. It requires matching Hyprland 0.56.2 headers, clang++, make, pkg-config, git and Python. It pins upstream commit `5a224284872208b5324759d535d65061043725de`, builds with x86-64-v3, preserves the MIT license, installs in `~/.local/lib/serpantinum`, and adds a guarded Lua loader. The plugin checks the compositor ABI; rebuild for another Hyprland version instead of reusing this binary. No compositor restart or replacement is needed for this setup.

## Keyboard access and battery colors


Super+S opens music, Super+C calendar, Super+B Bluetooth, Super+N network, and Super+D the shared shelf. Repeating the same shortcut closes its panel. Tab and Shift+Tab stay within visible enabled controls; Enter/Space activates buttons and arrows adjust focused sliders. Escape or Super+Escape closes the island and releases keyboard focus. Shelf tiles support Enter to open, Ctrl+C to copy and Delete to remove the shelf entry while preserving the original file. Hover-opened panels do not take keyboard focus. Clipboard history uses Super+V (Super+Shift+C remains available); system uses Super+Shift+B, and the launcher uses Super+X. Super+V reuses the existing cliphist history, search and pins rather than opening the volume menu. Use `src/scripts/coloros/install-island-shortcuts.sh` to install the Lua bindings on another machine.

While discharging, a subtle battery accent appears below 40%, moving from green through amber toward red as charge falls. The percentage text remains white. Colors and emphasis ease over 650 ms and change immediately with reduced motion or Game Mode. Charging retains the existing green wave and completion pulse. The new behavior can be disabled with Low-battery colors in Notifications settings.

QuickActions supports all four arrow keys to switch tools, Enter to expand or collapse, and Escape to go back. Arrow navigation wraps and respects active text editing.

## Live Liquid Glass and wallpaper blur

Appearance’s Background blur uses Hyprland’s native compositor blur in regular mode, with a wallpaper-backed fallback on other compositors. Liquid Glass adds live window content beneath the glass, edge refraction, restrained color separation and pointer-responsive highlights. It uses native Hyprland toplevel capture, without recording the shell itself or writing captured content to disk. Unsupported capture falls back to wallpaper.

Only windows intersecting visible glass are sampled, at up to 30 frames per second, with half-resolution textures shared within each shell window. Capture streams stay alive across geometry polls; large glass surfaces use stronger frosting for readability. Reduced motion uses a still captured frame. Game Mode stops capture and removes blur and glass. Both styles honor the opacity slider. Playback buttons use rounded, thin fills over the parent glass, avoiding doubled refraction and heavy shadows. This follows [Apple’s material guidance](https://developer.apple.com/design/human-interface-guidelines/materials) for controls placed on glass. The Linux shader is an approximation of Apple’s material.

## Upstream synchronization (2026-10-29)

Merged upstream through `a62f825`, retaining Pro's island, shared RAM shelf, custom settings, gray mode, power profiles, clipboard shortcut, recording marker, blur/effects policy and live Spotify integration. Compatible updates include lazy emoji loading, desktop-keyword search, bounded image decoding, idle settings-tab release, shared keyboard-layout watching, hidden-ticker reductions, lazy wallpaper preview players, network-device selection fixes, DDC detection, clipboard watcher cleanup and thin QuickActions edge triggers. Pro keeps its resident shared timer, spring animations, recording-state API and low-memory launcher while incorporating these changes.
