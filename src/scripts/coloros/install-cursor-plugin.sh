#!/usr/bin/env bash
set -euo pipefail
# The plugin hooks compositor internals; never build a random moving revision.
plugin_pin=5a224284872208b5324759d535d65061043725de
expected_hyprland=efb50993780079460b0cbed1363e2166a2de1d9f
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for dependency in git clang++ make pkg-config python3 rg; do
    command -v "$dependency" >/dev/null || { printf 'Missing build dependency: %s\n' "$dependency" >&2; exit 1; }
done
[[ $(pkg-config --modversion hyprland) == 0.56.2 ]] || { printf 'This pinned cursor plugin requires Hyprland 0.56.2 headers.\n' >&2; exit 1; }
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    installed_commit=$(hyprctl -j version | python3 -c 'import sys,json; print(json.load(sys.stdin)["commit"])')
    [[ "$installed_commit" == "$expected_hyprland" ]] || { printf 'Running Hyprland does not match this pinned plugin.\n' >&2; exit 1; }
fi
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/serpantinum-cursor.XXXXXX")
trap 'rm -rf -- "$build_dir"' EXIT
git -C "$build_dir" init -q
git -C "$build_dir" remote add origin https://github.com/VirtCode/hypr-dynamic-cursors.git
git -C "$build_dir" fetch --depth 1 origin "$plugin_pin"
git -C "$build_dir" checkout --detach FETCH_HEAD
make -C "$build_dir" -j2 CXX=clang++ EXTRA_CXXFLAGS='-O2 -march=x86-64-v3'
plugin_dir="$HOME/.local/lib/serpantinum"
mkdir -p -- "$plugin_dir" "$HOME/.config/hypr/config"
# Replace atomically: an already loaded library keeps its original inode.
install -m755 "$build_dir/out/dynamic-cursors.so" "$plugin_dir/dynamic-cursors.so.new"
mv -- "$plugin_dir/dynamic-cursors.so.new" "$plugin_dir/dynamic-cursors.so"
install -m644 "$build_dir/LICENSE.md" "$plugin_dir/dynamic-cursors.LICENSE.md"
install -m644 "$script_dir/island-cursor.lua" "$HOME/.config/hypr/config/island-cursor.lua"
config="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$config" ]] && ! rg -qF 'require("config/island-cursor")' "$config"; then
    printf '\nrequire("config/island-cursor")\n' >> "$config"
fi
printf 'Installed KDE-inspired cursor enlargement for Hyprland 0.56.2. Reload Hyprland to enable it.\n'
