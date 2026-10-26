pragma ComponentBehavior: Bound
// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Controls.Material as M3
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: settings
    required property var bridge
    property string draftPreset: "fade"
    property int draftDuration: 220
    property string draftStackId: ""
    property int draftWidth: 400
    property int draftHeight: 240
    property string draftAnchor: "top-right"
    property int draftX: 0
    property int draftY: 0
    readonly property var anchors: ["top-left", "top-right", "bottom-left", "bottom-right"]
    readonly property var editableStacks: bridge.config.stacks.filter(stack => stack.enabled)
    property string status: ""
    property bool saving: false
    title: "Swiftly · Settings"
    width: 540
    height: 720
    minimumWidth: 540
    maximumWidth: 540
    minimumHeight: 720
    maximumHeight: 720
    flags: Qt.Dialog | Qt.FramelessWindowHint
    Shortcut { sequence: "Esc"; enabled: settings.visible; onActivated: settings.close() }
    visible: false
    color: "transparent"
    M3.Material.theme: colors.dark ? M3.Material.Dark : M3.Material.Light
    M3.Material.accent: colors.primary
    M3.Material.foreground: colors.foreground
    M3.Material.background: colors.container
    SwiftlyPalette { id: colors; theme: settings.bridge.config.theme }
    onVisibleChanged: {
        if (visible) {
            draftPreset = bridge.animationPreset;
            draftDuration = bridge.animationDuration;
            loadStack(editableStacks.length ? editableStacks[0].id : "");
            status = "";
            requestActivate();
        }
    }
    function loadStack(stackId) {
        draftStackId = stackId;
        const stack = bridge.stackFor(stackId);
        draftWidth = Math.max(120, Number((stack && stack.size || {}).width) || 340);
        draftHeight = Math.max(100, Number((stack && stack.size || {}).height) || 144);
        const position = stack && stack.position || {};
        draftAnchor = anchors.indexOf(position.anchor) >= 0 ? position.anchor : "top-right";
        draftX = Math.max(0, Number(position.x) || 0);
        draftY = Math.max(0, Number(position.y) || 0);
    }
    function apply() {
        status = "Saving…";
        saving = true;
        const stackId = draftStackId || (editableStacks.length ? editableStacks[0].id : "");
        if (!bridge.saveSettings(draftPreset, draftDuration, stackId, draftWidth, draftHeight,
                {anchor: draftAnchor, x: draftX, y: draftY})) {
            status = "Choose a widget and valid size/location.";
            saving = false;
        }
    }
    Connections {
        target: settings.bridge
        function onConfigSaved() { settings.status = "Saved"; settings.saving = false; }
        function onConfigSaveFailed(message) { settings.status = message; settings.saving = false; }
    }
    Rectangle {
        anchors.fill: parent
        radius: 32
        color: colors.surface
        border.width: 1
        border.color: colors.outline
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            RowLayout {
                spacing: 14
                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: colors.primaryContainer
                    M3.Label { anchors.centerIn: parent; text: "S"; font.pixelSize: 23; font.weight: Font.Medium; color: colors.primary }
                }
                ColumnLayout {
                    spacing: 2
                    M3.Label { objectName: "settingsHeading"; text: "Swiftly"; font.pixelSize: 28; font.weight: Font.Medium; color: colors.foreground }
                    M3.Label { text: "Appearance, size and location"; font.pixelSize: 14; color: colors.muted }
                }
                Item { Layout.fillWidth: true }
            }
            M3.ScrollView {
                id: settingsScroll
                objectName: "settingsScroll"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: settingsScroll.availableWidth
                    spacing: 16
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 142
                radius: 28
                color: colors.container
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 8
                    M3.Label { text: "Animation"; font.pixelSize: 18; font.weight: Font.Medium; color: colors.foreground }
                    M3.Label {
                        text: ({fade: "A soft crossfade between widgets", slide: "Glide from one widget to the next", zoom: "A gentle change of scale", none: "Switch immediately, without motion"})[settings.draftPreset]
                        color: colors.muted
                        font.pixelSize: 13
                    }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: ["Fade", "Slide", "Zoom", "None"]
                            delegate: M3.Button {
                                id: presetButton
                                required property int index
                                required property string modelData
                                objectName: "preset-" + index
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 44
                                leftPadding: 8
                                rightPadding: 8
                                topInset: 0
                                bottomInset: 0
                                font.pixelSize: 13
                                text: modelData
                                checkable: true
                                autoExclusive: true
                                checked: settings.draftPreset === settings.bridge.animationPresets[index]
                                M3.Material.roundedScale: M3.Material.FullScale
                                M3.Material.elevation: 0
                                M3.Material.background: checked ? colors.primaryContainer : colors.containerHigh
                                M3.Material.foreground: checked ? colors.primary : colors.muted
                                contentItem: M3.Label {
                                    text: presetButton.text
                                    font: presetButton.font
                                    color: presetButton.checked ? colors.primary : colors.muted
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                // Flat tonal surfaces also render on the software backend.
                                background: Rectangle {
                                    implicitHeight: 44
                                    radius: height / 2
                                    color: presetButton.checked ? colors.primaryContainer : colors.containerHigh
                                    border.color: presetButton.checked ? colors.primary : colors.outline
                                    border.width: 1
                                    opacity: presetButton.down ? 0.75 : 1
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                }
                                Accessible.name: modelData + " animation"
                                onClicked: settings.draftPreset = settings.bridge.animationPresets[index]
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 116
                radius: 28
                color: colors.container
                enabled: settings.draftPreset !== "none"
                opacity: enabled ? 1 : 0.45
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 4
                    RowLayout {
                        M3.Label { text: "Duration"; font.pixelSize: 18; font.weight: Font.Medium; color: colors.foreground }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            implicitWidth: durationText.implicitWidth + 24
                            implicitHeight: 28
                            radius: 14
                            color: colors.primaryContainer
                            M3.Label { id: durationText; anchors.centerIn: parent; text: settings.draftDuration + " ms"; color: colors.primary; font.pixelSize: 12 }
                        }
                    }
                    M3.Slider {
                        objectName: "animationDuration"
                        Layout.fillWidth: true
                        from: 0
                        to: 2000
                        stepSize: 20
                        value: settings.draftDuration
                        onMoved: settings.draftDuration = Math.round(value)
                        Accessible.name: "Animation duration in milliseconds"
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: settings.editableStacks.length > 1 ? 192 : 132
                radius: 28
                color: colors.container
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 8
                    M3.Label { text: "Widget size"; font.pixelSize: 18; font.weight: Font.Medium; color: colors.foreground }
                    M3.ComboBox {
                        visible: settings.editableStacks.length > 1
                        Layout.fillWidth: true
                        model: settings.editableStacks.map(stack => stack.id)
                        currentIndex: settings.editableStacks.findIndex(stack => stack.id === settings.draftStackId)
                        onActivated: index => settings.loadStack(settings.editableStacks[index].id)
                        Accessible.name: "Widget stack to resize"
                    }
                    RowLayout {
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            M3.Label { text: "Width (px)"; color: colors.muted; font.pixelSize: 13 }
                            M3.SpinBox {
                                objectName: "widgetWidth"
                                Layout.fillWidth: true
                                from: 120; to: 8192; stepSize: 10
                                editable: true
                                value: settings.draftWidth
                                onValueModified: settings.draftWidth = value
                                Accessible.name: "Widget width in pixels"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            M3.Label { text: "Height (px)"; color: colors.muted; font.pixelSize: 13 }
                            M3.SpinBox {
                                objectName: "widgetHeight"
                                Layout.fillWidth: true
                                from: 100; to: 8192; stepSize: 10
                                editable: true
                                value: settings.draftHeight
                                onValueModified: settings.draftHeight = value
                                Accessible.name: "Widget height in pixels"
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 196
                radius: 28
                color: colors.container
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 8
                    M3.Label { text: "Location"; font.pixelSize: 18; font.weight: Font.Medium; color: colors.foreground }
                    M3.ComboBox {
                        objectName: "widgetAnchor"
                        Layout.fillWidth: true
                        model: ["Top left", "Top right", "Bottom left", "Bottom right"]
                        currentIndex: settings.anchors.indexOf(settings.draftAnchor)
                        onActivated: index => settings.draftAnchor = settings.anchors[index]
                        Accessible.name: "Widget screen corner"
                    }
                    RowLayout {
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            M3.Label { text: "Horizontal inset (px)"; color: colors.muted; font.pixelSize: 13 }
                            M3.SpinBox {
                                objectName: "widgetX"
                                Layout.fillWidth: true
                                from: 0; to: 32768; stepSize: 10
                                editable: true
                                value: settings.draftX
                                onValueModified: settings.draftX = value
                                Accessible.name: "Distance from horizontal screen edge in pixels"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            M3.Label { text: "Vertical inset (px)"; color: colors.muted; font.pixelSize: 13 }
                            M3.SpinBox {
                                objectName: "widgetY"
                                Layout.fillWidth: true
                                from: 0; to: 32768; stepSize: 10
                                editable: true
                                value: settings.draftY
                                onValueModified: settings.draftY = value
                                Accessible.name: "Distance from vertical screen edge in pixels"
                            }
                        }
                    }
                }
            }
            RowLayout {
                spacing: 12
                Rectangle {
                    implicitWidth: 48; implicitHeight: 32; radius: 16
                    color: colors.primaryContainer
                    M3.Label { anchors.centerIn: parent; text: Math.round((1 - (Number(settings.bridge.config.interaction.clickEdgeStart) || 0.95)) * 100) + "%"; color: colors.primary; font.pixelSize: 12; font.weight: Font.Medium }
                }
                M3.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: "Click the right edge of a card to switch widgets."
                    color: colors.muted
                    font.pixelSize: 13
                }
            }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                M3.Label { text: settings.status; color: colors.primary; font.pixelSize: 13; Accessible.name: settings.status }
                Item { Layout.fillWidth: true }
                M3.Button {
                    id: closeButton
                    text: "Close"
                    flat: true
                    font.pixelSize: 14
                    contentItem: M3.Label { text: closeButton.text; color: colors.foreground; font: closeButton.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { implicitHeight: 40; radius: height / 2; color: closeButton.hovered || closeButton.visualFocus ? colors.containerHigh : "transparent" }
                    onClicked: settings.close()
                }
                M3.Button {
                    id: saveButton
                    objectName: "saveAnimation"
                    text: "Save changes"
                    highlighted: true
                    enabled: !settings.saving
                    M3.Material.elevation: 0
                    font.pixelSize: 14
                    contentItem: M3.Label { text: saveButton.text; color: colors.contrast; font: saveButton.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { implicitHeight: 40; radius: height / 2; color: colors.primary; opacity: !saveButton.enabled ? 0.4 : saveButton.down ? 0.8 : 1 }
                    onClicked: settings.apply()
                }
            }
        }
    }
}
