pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property string fontFamily: "Adwaita Mono"
    property int borderRadius: 8
    // Compatibility token: every surface uses the radius selected in Settings.
    readonly property int clampedBorderRadius: borderRadius

    function opacityForScreen(screen) { return SurfacePolicy.occupied(screen) ? 1 : elementOpacity; }
    function surfaceColor(screen) { return Qt.alpha(base, opacityForScreen(screen)); }
    readonly property color borderColor: Qt.alpha(text, isLight ? 0.12 : 0.16)
    readonly property int smallRadius: Math.min(12, borderRadius)
    readonly property int cardRadius: Math.min(20, borderRadius)

    property real elementOpacity: 1.0
    property bool blurBackground: false
    property string blurStyle: "blur"
    readonly property real liquidGlassOpacity: 0.1
    readonly property bool glassActive: blurBackground && elementOpacity < 0.999
    readonly property bool liquidGlass: blurBackground && blurStyle === "liquid"
    // Hyprland blurs the live scene behind translucent shell surfaces.
    readonly property bool compositorBlur: blurBackground && !liquidGlass && !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    property color base: "#1e1e2e"
    readonly property bool isLight: (0.2126 * base.r + 0.7152 * base.g + 0.0722 * base.b) > 0.6
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color _text: "#cdd6f4"
    property color _subtext0: "#a6adc8"
    property color _subtext1: "#bac2de"
    readonly property color text: liquidGlass ? "#ffffff" : _text
    readonly property color subtext0: liquidGlass ? "#ffffff" : _subtext0
    readonly property color subtext1: liquidGlass ? "#ffffff" : _subtext1
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color overlay2: "#9399b2"
    property color blue: "#89b4fa"
    readonly property color primary: blue
    property color sapphire: "#74c7ec"
    property color peach: "#fab387"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"
    property color yellow: "#f9e2af"
    property color maroon: "#eba0ac"
    property color teal: "#94e2d5"

    property string configPath: Quickshell.env("QS_COLORS_JSON") ?? "~/.local/state/serpantinum/qs_colors.json"
    property string matugenConfigPath: (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") ?? "") + "/.local/state/serpantinum")) + "/qs_matugen_colors.json"

    property bool _readInProgress: false
    property var matugenColors: null
    property var _colorQueue: []
    property int colorsPerFrame: 3

    property var availableFontPaths: ({})
    property var bundledNames: []
    property string activeFontPath: ""

    FontLoader {
        id: iconFontLoader
        source: (typeof Caching !== "undefined" && Caching.serpantinumDir && Caching.serpantinumDir !== "")
            ? ("file://" + Caching.serpantinumDir + "/assets/fonts/SymbolsNerdFontMono-Regular.ttf")
            : ""
    }

    readonly property string iconFont: (iconFontLoader.status === FontLoader.Ready && iconFontLoader.name !== "")
        ? iconFontLoader.name
        : (root.fontFamily !== "" ? root.fontFamily : "sans-serif")
    readonly property bool iconFontReady: iconFontLoader.status === FontLoader.Ready

    onFontFamilyChanged: {
        root.updateActiveFontLoader();
    }

    function isMatugenTheme() {
        if (typeof Matugen !== "undefined" && typeof Matugen.isMatugenTheme === "function") {
            return Matugen.isMatugenTheme();
        }
        let themeConfig = Config.getSetting("theme", { "matugen": true, "activePreset": "Matugen" });
        if (themeConfig.matugen !== undefined) {
            return themeConfig.matugen === true;
        }
        return themeConfig.theme === "matugen"
            || themeConfig.name === "matugen"
            || themeConfig.currentTheme === "matugen"
            || themeConfig.current === "matugen"
            || themeConfig.activePreset === "Matugen"
            || themeConfig.activePreset === undefined;
    }

    function updateActiveFontLoader() {
        if (!root.fontFamily || root.fontFamily === "") return;
        let key = root.fontFamily.toLowerCase();
        let path = root.availableFontPaths ? root.availableFontPaths[key] : "";

        if (path && root.activeFontPath !== path) {
            root.activeFontPath = path;
        }
    }

    FontLoader {
        id: staticFontLoader
        source: (root.activeFontPath && root.activeFontPath !== "") ? ("file://" + root.activeFontPath) : ""
        onStatusChanged: {
            if (status === FontLoader.Ready) {
                let cur = root.fontFamily;
                root.fontFamily = "";
                root.fontFamily = cur;
            }
        }
    }

    Process {
        id: fontFetcher
        property bool forceRescan: false

        command: {
            let sys = Caching.serpantinumDir ? (Caching.serpantinumDir + "/assets/fonts") : "";
            let usr = Caching.stateDir ? (Caching.stateDir + "/fonts") : (Caching.home + "/.local/state/serpantinum/fonts");
            let cacheFile = Caching.stateDir ? (Caching.stateDir + "/fonts_cache.txt") : (Caching.home + "/.local/state/serpantinum/fonts_cache.txt");
            let force = forceRescan ? "true" : "false";

            let cmd = "CACHE=\"" + cacheFile + "\"; ";
            cmd += "if [ \"" + force + "\" = \"true\" ] || [ ! -f \"$CACHE\" ]; then ";
            cmd += "mkdir -p \"$(dirname \"$CACHE\")\"; ";
            cmd += "find ";
            if (sys !== "") cmd += "\"" + sys + "\" ";
            cmd += "\"" + usr + "\" -type f \\( -iname \"*.ttf\" -o -iname \"*.otf\" -o -iname \"*.ttc\" \\) -print0 2>/dev/null | sort -z | ";
            cmd += "xargs -0 -r fc-scan -f '%{family[0]}\\t%{style[0]}\\t%{file}\\n' 2>/dev/null | ";
            cmd += "awk -F'\\t' '{ fam=$1; stl=$2; f=$3; if (fam==\"\") { n=split(f,a,\"/\"); fam=a[n]; sub(/\\.[^.]*$/,\"\",fam) } if (stl!=\"\" && stl!=\"Regular\") print fam \" \" stl \"|\" f; else print fam \"|\" f }' ";
            cmd += "> \"$CACHE.tmp\" || true; mv \"$CACHE.tmp\" \"$CACHE\"; ";
            cmd += "fi; ";
            cmd += "cat \"$CACHE\" || true";

            return ["bash", "-c", cmd];
        }
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                fontFetcher.forceRescan = false;

                let lines = this.text.trim().split('\n');
                let newPaths = {};
                let names = [];
                let seen = new Set();

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line === "") continue;

                    let idx = line.indexOf('|');
                    if (idx !== -1) {
                        let fName = line.substring(0, idx).trim();
                        if (fName.toLowerCase().indexOf("symbols nerd font") !== -1) continue;

                        let fPath = line.substring(idx + 1).trim();
                        let key = fName.toLowerCase();

                        newPaths[key] = fPath;

                        if (!seen.has(key)) {
                            seen.add(key);
                            names.push(fName);
                        }
                    }
                }

                root.availableFontPaths = newPaths;
                root.bundledNames = names;
                root.updateActiveFontLoader();
                if (staticFontLoader.status === FontLoader.Ready) {
                    let cur = root.fontFamily;
                    root.fontFamily = "";
                    root.fontFamily = cur;
                }
            }
        }
    }

    function scanFonts() {
        fontFetcher.running = false;
        fontFetcher.forceRescan = true;
        fontFetcher.running = true;
    }

    function reloadColors() {
        if (root._readInProgress) return;
        root._readInProgress = true;
        root.updateColors();
    }

    IpcHandler {
        target: "theme"

        function reloadColors() {
            root.reloadColors();
        }
    }

    IpcHandler {
        target: "fonts"
        function rescan() {
            root.scanFonts();
        }
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            root.updateColors();
        }
        function onRawSettingsChanged() {
            const theme = Config.getSetting("theme", {});
            if (theme.borderRadius !== undefined) {
                root.borderRadius = theme.borderRadius;
            }
            root.syncElementOpacity();
        }
    }

    Connections {
        target: GameMode
        function onEnabledChanged() { root.syncElementOpacity(); }
    }

    Connections {
        target: typeof Matugen !== "undefined" ? Matugen : null
        function onGenerationFinished(success) {
            root._readInProgress = false;
            if (success) {
                themeWatcher.reload();
                matugenColorsWatcher.reload();
            }
        }
    }

    function applyMatugenColors(): bool {
        if (root.matugenColors) {
            root.applyColorObject(root.matugenColors);
            return true;
        }
        return false;
    }

    // Keep neutral and white text unchanged; render chromatic labels in pure black.
    function neutralTextColor(value) {
        const c = Qt.color(value);
        const chroma = Math.max(c.r, c.g, c.b) - Math.min(c.r, c.g, c.b);
        return chroma > 0.06 ? Qt.rgba(0, 0, 0, 1) : c;
    }

    function faded(c) {
        return Qt.alpha(c, root.elementOpacity);
    }

    function syncElementOpacity() {
        const themeConfig = Config.getSetting("theme", {});
        const pct = themeConfig.elementOpacity !== undefined ? Number(themeConfig.elementOpacity) : 100;
        root.blurBackground = !GameMode.enabled && !Caching.isStandalone && (themeConfig.blurBackground !== undefined ? Boolean(themeConfig.blurBackground) : false);
        root.blurStyle = themeConfig.blurStyle === "liquid" ? "liquid" : "blur";
        root.elementOpacity = (GameMode.enabled || Caching.isStandalone) ? 1.0 : root.liquidGlass ? root.liquidGlassOpacity : (isNaN(pct) ? 1.0 : Math.max(0, Math.min(1.0, pct / 100.0)));
    }

    function updateColors() {
        let themeConfig = Config.getSetting("theme", {});

        if (themeConfig.fontFamily !== undefined) {
            root.fontFamily = themeConfig.fontFamily;
        }
        if (themeConfig.borderRadius !== undefined) {
            root.borderRadius = themeConfig.borderRadius;
        }
        root.syncElementOpacity();

        let customColors = themeConfig.colors || themeConfig.palette || (themeConfig.base !== undefined ? themeConfig : null);

        if (root.isMatugenTheme()) {
            root.applyMatugenColors();
            let wp = themeConfig.wallpaper || Config.getSetting("wallpaper", "");
            if (!GameMode.enabled && !Caching.isStandalone && typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                Matugen.generate(wp, themeConfig.mode, themeConfig.schemeType);
            }
            root._readInProgress = false;
        } else {
            root._readInProgress = false;
            if (customColors) {
                root.applyColorObject(customColors);
                if (!GameMode.enabled && !Caching.isStandalone && typeof Matugen !== "undefined" && typeof Matugen.generateFromStatic === "function") {
                    Matugen.generateFromStatic(customColors, themeConfig.mode);
                }
            } else {
                themeWatcher.reload();
            }
        }
    }

    Process {
        id: syncDesktopPalette
        command: ["python3", Caching.serpantinumDir + "/scripts/coloros/sync-theme.py"]
    }
    Timer { id: paletteSyncDebounce; interval: 300; onTriggered: if (!syncDesktopPalette.running) syncDesktopPalette.running = true }
    function applyColorObject(c) {
        if (!c) return;
        paletteSyncDebounce.restart();

        let resolveHex = function(val) {
            if (!val) return "";
            if (typeof val === "string") return val;
            if (typeof val === "object") {
                if (val.hex) return val.hex;
                if (val.color) return val.color;
                if (val.default && val.default.hex) return val.default.hex;
            }
            return val.toString();
        };

        // Keep Matugen accents, but use coordinated neutral grays for shell surfaces.
        if (Config.getSetting("coloros", {}).neutralSurfaces !== false) {
            const rawBase = Qt.color(resolveHex(c.base) || "#252830");
            const light = (rawBase.r * 0.2126 + rawBase.g * 0.7152 + rawBase.b * 0.0722) > 0.6;
            const neutral = light
                ? {base:"#e6e8ec", mantle:"#dde0e5", crust:"#d4d8df", surface0:"#f0f1f4", surface1:"#d7dce3", surface2:"#c3cbd5", text:"#1b1f28", subtext0:"#505866", subtext1:"#3e4755"}
                : {base:"#252830", mantle:"#20232a", crust:"#191c22", surface0:"#30343e", surface1:"#3d4350", surface2:"#505967", text:"#f1f3f7", subtext0:"#bbc2cf", subtext1:"#d0d5df"};
            c = Object.assign({}, c, neutral);
        }

        let names = ["base", "mantle", "crust", "surface0", "surface1", "surface2",
                     "overlay0", "overlay1", "overlay2", "text", "subtext0", "subtext1",
                     "blue", "sapphire", "peach", "green", "red", "mauve", "pink",
                     "yellow", "maroon", "teal"];

        let queue = [];
        for (let i = 0; i < names.length; i++) {
            let hexColor = resolveHex(c[names[i]]);
            if (!hexColor) continue;
            let nextColor = Qt.color(hexColor);
            let slot = (names[i] === "text" || names[i] === "subtext0" || names[i] === "subtext1") ? "_" + names[i] : names[i];
            if (root[slot].toString() !== nextColor.toString()) {
                queue.push({ name: slot, value: nextColor });
            }
        }

        root._colorQueue = queue;
        if (queue.length > 0) {
            root._flushColorQueue();
            if (root._colorQueue.length > 0) colorStepTimer.restart();
        }
    }

    function _flushColorQueue() {
        let n = Math.min(root.colorsPerFrame, root._colorQueue.length);
        for (let i = 0; i < n; i++) {
            let item = root._colorQueue[i];
            root[item.name] = item.value;
        }
        root._colorQueue = root._colorQueue.slice(n);
    }

    FrameAnimation {
        id: colorStepTimer
        onTriggered: {
            root._flushColorQueue();
            if (root._colorQueue.length === 0) stop();
        }
    }

    FileView {
        id: matugenColorsWatcher
        path: root.matugenConfigPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let txt = text().trim();
            if (txt !== "") {
                try {
                    let c = JSON.parse(txt);
                    let target = c && c.colors ? c.colors : c;
                    if (target) {
                        root.matugenColors = target;
                        if (root.isMatugenTheme()) {
                            root.applyColorObject(target);
                        }
                    }
                } catch(e) {}
            }
        }
    }

    FileView {
        id: themeWatcher
        path: root.configPath.startsWith("~") ? (Quickshell.env("HOME") ?? "") + root.configPath.slice(1) : root.configPath
        watchChanges: false

        onLoaded: {
            root._readInProgress = false;
            let txt = text().trim();
            if (txt !== "") {
                try {
                    let c = JSON.parse(txt);
                    let target = c && c.colors ? c.colors : c;
                    if (target) {
                        if (root.isMatugenTheme()) {
                            root.matugenColors = target;
                        }
                        root.applyColorObject(target);
                    }
                } catch(e) {}
            }
        }
    }

    Component.onCompleted: {
        root._readInProgress = true;
        root.updateColors();
        root.updateActiveFontLoader();
    }
}
