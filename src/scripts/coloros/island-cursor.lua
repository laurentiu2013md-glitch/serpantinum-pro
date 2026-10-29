-- KDE-inspired native cursor rendering, pinned to this Hyprland ABI.
local plugin_path = os.getenv("HOME") .. "/.local/lib/serpantinum/dynamic-cursors.so"
local file = io.open(plugin_path, "rb")
if file then
    file:close()
    local loaded = false
    for _, plugin in ipairs(hl.get_loaded_plugins()) do
        if plugin.name == "dynamic-cursors" then loaded = true end
    end
    -- Register on every reload; the compositor reconciles this list each time.
    hl.plugin.load(plugin_path)
    if not loaded then return end
    local enabled = true
    local state = io.open(os.getenv("HOME") .. "/.local/state/serpantinum/game-mode.json", "r")
    if state then enabled = not state:read("*a"):match('"enabled"%s*:%s*true'); state:close() end
    hl.config({plugin = {dynamic_cursors = {
        enabled = enabled, mode = "none",
        shake = {enabled = true, base = 3.0, speed = 0.6, limit = 4.5, timeout = 2000, ipc = true},
        hyprcursor = {fallback = "clientside", resolution = 144, nearest = 0},
    }}})
end
