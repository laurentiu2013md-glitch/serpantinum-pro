<div align="center">
  <a href="https://ko-fi.com/ilyamiro">
    <img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="ko-fi" />
  </a>
</div>

<div align="center">
  <img src="docs/assets/banner.png" alt="Serpantinum" width="850" />
</div>

# Serpantinum Pro

A Serpantinum fork with a bouncy Dynamic Island, compact hover panels, and a DropShelf. Based on [ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum), with its existing desktop tools and customization options.

## What’s new in Pro

- **An integrated Dynamic Island:** the center bar morphs into music, weather/calendar and Bluetooth panels within the same window.
- **A quieter desktop:** on Hyprland, the center becomes clock-only when the pointer moves below the upper 10% of the screen. Enter that zone to restore it; open controls stay usable until you leave them.
- **Playful motion with room for text:** interruptible spring transitions, stable module spacing, padded edges, coordinated widget reveal and a small pointer-boundary buffer. Reduced motion respects the system preference and a shell setting.
- **A sky that follows the weather:** animated clouds, sun/moon, rain, snow and fog inside the weather/calendar island; reduced motion pauses it and Game Mode stays plain.
- **Charging with a green wave:** a horizontal liquid animation follows the battery percentage, stays aligned with the battery pill and disappears at 100%.
- **OSDs inside the island:** volume, brightness, microphone, lock keys and airplane-mode feedback share its surface and restore the previous panel afterward.
- **Your original music player, compact:** artwork, playback controls, lyrics, EQ and audio settings remain part of the real player.
- **One shared DropShelf:** files, links and text added through the bar appear in QuickActions immediately, with previews, copy, rearrangement and removal. Hover the upper 5% of the bar’s height to reveal it. Native drag/drop preserves original files.
- **Network controls on hover:** a compact Wi-Fi/Ethernet panel shares Bluetooth’s layout, Material switch and integrated island, with scanning, saved networks and password entry.
- **One-tap Matugen light/dark mode:** a matching button beside Game Mode regenerates the palette from your wallpaper.
- **Functional Bluetooth:** power, scanning, paired/seen devices, connect/disconnect, pairing confirmation, confirmed removal, and battery values only when BlueZ exposes them. The new panel is shared with QuickActions and uses a Material 3 switch.
- **A consistent gray palette:** Matugen accents, light/dark surfaces and GTK/Qt palette synchronization. Fresh-install defaults use 50% shell background opacity; Hyprland supplies live blur. Dark-mode text is white. Nautilus follows Kitty’s background gray and opacity, with native blur normally and blur disabled in Game Mode.
- **Cleaner QuickActions corners:** rounded parent clipping and lazy-loaded modules, with state retained between visits.
- **`shellreset` for Fish and other shells:** make a private snapshot, then restore it with integrity checks, automatic backups and rollback on ordinary restore failures.

[Feature configuration, reset instructions and limitations](docs/pro-features.md)

## Previews

Upstream desktop previews; Pro additions are described above.

| | |
|---|---|
| ![Preview 1](docs/assets/previews/preview_1.png) | ![Preview 2](docs/assets/previews/preview_2.png) |
| ![Preview 3](docs/assets/previews/preview_3.png) | ![Preview 4](docs/assets/previews/preview_4.png) |

---

## Installation

> [!TIP]
> Use the fork installation command below for Pro. **[serpantinum.dev](https://serpantinum.dev)** documents the upstream shell; see [Pro features](docs/pro-features.md) for this fork’s additions.

> [!IMPORTANT]
> **Migrating from v1:** All previous configuration will be backed up and unused. Configuration of compositor settings such as monitors, keybinds, and autostart is now up to you, as the project migrated from being dotfiles to being a shell.

### Arch Linux, Fedora and their derivatives

For Arch-based distributions (including systemd, OpenRC, and other init systems) and for Fedora-based distributions such as Nobara and Ultramarine, run the automated installation script. It detects your distribution and uses `pacman` or `dnf`.

Use this installer:

```bash
git clone https://github.com/laurentiu2013md-glitch/serpantinum-pro.git
cd serpantinum-pro
bash install/install.sh
```

If this doesn't work, use:

```bash
curl -fsSL https://raw.githubusercontent.com/laurentiu2013md-glitch/serpantinum-pro/master/install/install.sh -o /tmp/serpantinum-pro-install.sh
REPO_SLUG=laurentiu2013md-glitch/serpantinum-pro bash /tmp/serpantinum-pro-install.sh
```

> [!NOTE]
> To update, when or if you recieve a notification about the new version being available, just run the script again and choose "update"

---

### NixOS

See the [NixOS installation guide](https://serpantinum.dev/installation/nixos) for flake setup, the NixOS and Home Manager modules, and updating.

---

## Supported compositors

The upstream shell supports Hyprland, Niri, Sway and Mango. Pro’s global pointer-zone compression and native blur rule are Hyprland-specific; the full bar remains accessible when that IPC is unavailable. The installer detects the running compositor and deploys its configuration. On Fedora, Mango is installed from the Terra repository.

---

## Running

To run the shell, launch `serpantinumd start`. After configuring it, create a private reset snapshot:

```bash
serpantinum-snapshot
shellreset --dry-run
```

Run `shellreset` to restore that snapshot, with automatic backups. The installer also provides a Fish function of the same name. Snapshot data stays on your machine.

For configuration, see the [configuration guide](https://serpantinum.dev/configure).

---

## Credits

* Special thanks to Darkall44/Qylock for providing a gorgeous material SDDM theme!

<br><br><br>

<div align="center">
  <h3>Thanks to all contributors</h3>
  <br>

  <a href="https://github.com/TheRinder2"><img src="https://avatars.githubusercontent.com/u/48689803?v=4&s=48" width="48" height="48" alt="TheRinder2"></a>
  <a href="https://github.com/bizneskind-droid"><img src="https://avatars.githubusercontent.com/u/245046997?v=4&s=48" width="48" height="48" alt="bizneskind-droid"></a>
  <a href="https://github.com/Pigeon78"><img src="https://avatars.githubusercontent.com/u/151051379?v=4&s=48" width="48" height="48" alt="Pigeon78"></a>
  <a href="https://github.com/Eduarduar"><img src="https://avatars.githubusercontent.com/u/104547727?v=4&s=48" width="48" height="48" alt="Eduarduar"></a>
  <a href="https://github.com/Spinty-dev"><img src="https://avatars.githubusercontent.com/u/123001216?v=4&s=48" width="48" height="48" alt="Spinty-dev"></a>
  <a href="https://github.com/MrDexstor"><img src="https://avatars.githubusercontent.com/u/97257847?v=4&s=48" width="48" height="48" alt="MrDexstor"></a>
  <a href="https://github.com/coloramamoe"><img src="https://avatars.githubusercontent.com/u/117035740?v=4&s=48" width="48" height="48" alt="coloramamoe"></a>
  <a href="https://github.com/Zyxilon"><img src="https://avatars.githubusercontent.com/u/234867627?v=4&s=48" width="48" height="48" alt="Zyxilon"></a>
  <a href="https://github.com/gouthamkrishnap"><img src="https://avatars.githubusercontent.com/u/224089015?v=4&s=48" width="48" height="48" alt="gouthamkrishnap"></a>
  <a href="https://github.com/Stoltembergg"><img src="https://avatars.githubusercontent.com/u/312632452?v=4&s=48" width="48" height="48" alt="Stoltembergg"></a>
  <a href="https://github.com/andckadir"><img src="https://avatars.githubusercontent.com/u/175446585?v=4&s=48" width="48" height="48" alt="andckadir"></a>
  <a href="https://github.com/ArseniiTkachuk"><img src="https://avatars.githubusercontent.com/u/257102547?v=4&s=48" width="48" height="48" alt="ArseniiTkachuk"></a>
  <a href="https://github.com/MCUxDaredevil"><img src="https://avatars.githubusercontent.com/u/59441946?v=4&s=48" width="48" height="48" alt="MCUxDaredevil"></a>
  <a href="https://github.com/MILKv2"><img src="https://avatars.githubusercontent.com/u/142674287?v=4&s=48" width="48" height="48" alt="MILKv2"></a>
  <a href="https://github.com/pedrolourencosilva"><img src="https://avatars.githubusercontent.com/u/184855780?v=4&s=48" width="48" height="48" alt="pedrolourencosilva"></a>
  <a href="https://github.com/Vaspyyy"><img src="https://avatars.githubusercontent.com/u/197029450?v=4&s=48" width="48" height="48" alt="Vaspyyy"></a>
  <a href="https://github.com/Sergi122"><img src="https://avatars.githubusercontent.com/u/171693999?v=4&s=48" width="48" height="48" alt="Sergi122"></a>
  <a href="https://github.com/Syrup5845"><img src="https://avatars.githubusercontent.com/u/310795939?v=4&s=48" width="48" height="48" alt="Syrup5845"></a>
  <a href="https://github.com/forteleaf"><img src="https://avatars.githubusercontent.com/u/14119264?v=4&s=48" width="48" height="48" alt="forteleaf"></a>
  <a href="https://github.com/kranks-uga"><img src="https://avatars.githubusercontent.com/u/179175113?v=4&s=48" width="48" height="48" alt="kranks-uga"></a>
  <a href="https://github.com/zynx-real"><img src="https://avatars.githubusercontent.com/u/320626542?v=4&s=48" width="48" height="48" alt="zynx-real"></a>
</div>

<br><br>

---

## License

Copyright (C) 2026 Illia Miroshnichenko

This project is licensed under the GNU Affero General Public License version 3, or (at your option) any later version. See the [LICENSE.md](LICENSE.md) file for the full license text.

