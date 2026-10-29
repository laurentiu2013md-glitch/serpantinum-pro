import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
RowLayout {
    spacing: 12
    ControlRoundButton { glyph: ""; label: "Do not disturb"; selected: Config.getSetting("notifications",{}).dnd === true; onClicked: Config.setSetting("notifications.dnd",!selected) }
    ControlRoundButton { glyph: "󰊴"; label: "Game Mode"; selected: GameMode.enabled; onClicked: GameMode.toggle() }
    ControlRoundButton { glyph: ThemeBackend.isGray ? "󰔎" : ThemeBackend.isLight ? "󰖙" : "󰖔"; label: "Appearance: " + (Config.getSetting("theme",{}).mode || "dark") + "; cycle light, gray, dark"; selected: !ThemeBackend.isLight; enabled: !Matugen.isRunning; onClicked: Matugen.toggleMode() }
    ControlRoundButton { glyph: ""; label: "Settings"; onClicked: { ControlCenterController.close(); Quickshell.execDetached(["serpantinum","settings"]); } }
    ControlRoundButton { glyph: ""; label: "Calculator"; onClicked: { ControlCenterController.close(); FloatingController.toggleCalculator(null); } }
    ControlRoundButton { glyph: ""; label: "Lock"; onClicked: { ControlCenterController.close(); Quickshell.execDetached(["serpantinum","lock"]); } }
}
