import QtQuick
import Quickshell
import Quickshell.Io
import "widgets"
import "bar" as BarWindows
import "quickactions/actions" as QuickActionTools

ShellRoot {
    id: shell
    readonly property bool gameMode: GameMode.enabled
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool quickactionsEnabled: Config.getSetting("general", {}).quickactions !== false
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false

    // Keep the shared timer available when the QuickActions UI is disabled.
    Loader {
        active: !shell.gameMode && (shell.performanceMode || !shell.quickactionsEnabled)
        visible: false
        sourceComponent: QuickActionTools.Timer {}
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    LazyLoader {
        id: screenshotLoader
        ScreenshotOverlay {}
    }

    function ensureScreenshotOverlay() {
        if (gameMode) return null;
        if (!screenshotLoader.item) screenshotLoader.active = true;
        return screenshotLoader.item;
    }

    IpcHandler {
        target: "screenshotOverlay"

        function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.toggleOverlay(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function deactivate(): void {
            if (screenshotLoader.item) screenshotLoader.item.deactivate();
        }
    }

    IpcHandler {
        target: "coloros"
        function status(): string {
            return JSON.stringify({opacity:ThemeBackend.elementOpacity,blur:ThemeBackend.blurBackground,compositorBlur:ThemeBackend.compositorBlur,
                gameMode:GameMode.enabled,reducedMotion:Motion.reduced,adaptiveBlur:SurfacePolicy.enabled,
                light:ThemeBackend.isLight,text:ThemeBackend.text.toString(),subtext0:ThemeBackend.subtext0.toString(),subtext1:ThemeBackend.subtext1.toString(),neutralText:ThemeBackend.neutralTextColor("#725188").toString(),surface:ThemeBackend.base.toString(),accent:ThemeBackend.mauve.toString()});
        }
    }
    Main {}
    Bar {}
    BarWindows.ControlCenterWindow {}
    Lock {}
    Loader { active: !shell.gameMode; sourceComponent: WidgetRedactor {} }
    Loader { active: !shell.gameMode; sourceComponent: LockRedactor {} }

    Launcher {}
    Loader { active: !shell.gameMode; sourceComponent: Clipboard {} }

    Polkit {}
    Loader { active: !shell.gameMode; sourceComponent: WellbeingLimitOverlay {} }
    PopoutManager {}

    Loader {
        active: !shell.gameMode && dockEnabled
        sourceComponent: Dock {}
    }

    Loader {
        active: !shell.gameMode && !performanceMode
        sourceComponent: Idle {}
    }
    Variants {
        model: (shell.gameMode || performanceMode) ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: shell.gameMode || !performanceMode
        sourceComponent: WallpaperEngine {}
    }
    Loader {
        active: shell.gameMode || (!performanceMode && quickactionsEnabled)
        sourceComponent: Floating {}
    }

    Component.onCompleted: {
        Qt.application.organization = "serpantinum";
        Qt.application.domain = "serpantinum.org";
        Qt.application.name = "serpantinum";
        if (!gameMode) {
            FirstLaunch.checkFirstLaunch();
            SysNotif.checkBattery();
        }
        GameMode.reapply();
    }

    Timer {
        interval: 1500
        running: shell.gameMode
        onTriggered: gc()
    }
}
