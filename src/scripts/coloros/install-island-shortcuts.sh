#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config="$HOME/.config/hypr/hyprland.lua"
[[ -f "$config" ]] || { printf 'A Hyprland Lua configuration is required.\n' >&2; exit 1; }
mkdir -p -- "$HOME/.config/hypr/config"
module="$HOME/.config/hypr/config/island-shortcuts.lua"
if [[ -f "$module" ]] && ! cmp -s "$module" "$script_dir/island-shortcuts.lua"; then
    cp -p -- "$module" "$module.backup-$(date +%Y%m%d-%H%M%S)"
fi
install -m644 "$script_dir/island-shortcuts.lua" "$module"
if ! grep -qF 'require("config/island-shortcuts")' "$config"; then
    printf '\nrequire("config/island-shortcuts")\n' >> "$config"
fi
printf 'Installed Super+S/C/B/N/D island shortcuts. Clipboard and system use Super+Shift+C/B; launcher uses Super+X. Reload Hyprland to apply.\n'
