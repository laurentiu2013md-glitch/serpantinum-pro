// SPDX-License-Identifier: GPL-3.0-only
import QtQuick

QtObject {
    required property var theme
    readonly property bool dark: theme.mode !== "light"
    readonly property color primary: theme.accent || (dark ? "#D0BCFF" : "#6750A4")
    readonly property color contrast: primary.hslLightness > 0.6 ? "#211F26" : "#FFFFFF"
    readonly property color foreground: theme.foreground || (dark ? "#E6E0E9" : "#1D1B20")
    readonly property color muted: theme.muted || (dark ? "#CAC4D0" : "#49454F")
    readonly property color surface: dark ? "#141218" : "#FFFBFE"
    readonly property color container: dark ? "#211F26" : "#F3EDF7"
    readonly property color containerHigh: dark ? "#2B2930" : "#ECE6F0"
    readonly property color primaryContainer: Qt.tint(container, Qt.rgba(primary.r, primary.g, primary.b, 0.18))
    readonly property color outline: dark ? "#49454F" : "#CAC4D0"
}
