import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "../"
import "../reusables"

RowLayout {
    id: bottomHeader
    required property var root
    property alias bottomSectionSwitch: bottomSectionSwitch

    Layout.fillWidth: true
    opacity: root.introEqHeader
    transform: Translate { y: root.s(12) * (1 - root.introEqHeader) }

    Switch {
        id: bottomSectionSwitch
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.s(300)
        Layout.minimumWidth: root.s(230)
        Layout.maximumWidth: root.s(300)
        implicitHeight: root.s(26)
        implicitWidth: root.s(300)
        options: [
            typeof I18n !== "undefined" ? I18n.t("music.equalizer", "Equalizer") : "Equalizer",
            "Spotify",
            typeof I18n !== "undefined" ? I18n.t("music.audio.title", "Audio") : "Audio",
            typeof I18n !== "undefined" ? I18n.t("music.lyrics", "Lyrics") : "Lyrics"
        ]
        currentIndex: 0
        accentColor: ThemeBackend.mauve || "#cba6f7"
        baseColor: Qt.alpha(ThemeBackend.surface0 || "#313244", ThemeBackend.elementOpacity)
        textColor: ThemeBackend.subtext0 || "#a6adc8"
        activeTextColor: ThemeBackend.base || "#1e1e2e"
        cornerRadius: ThemeBackend.borderRadius
        fontPixelSize: root.s(11.5)
        onCurrentIndexChanged: {
            if (root.active && !Motion.reduced && currentIndex !== root.spotifyTab) root.registerCava();
            else root.unregisterCava();
            if (currentIndex !== root.audioTab && root.audioTestRunning) {
                root.toggleAudioTest();
            }
            root.updateLyricsSubscription();
            root.toEqAnim.stop();
            root.toSpotifyAnim.stop();
            root.toAudioAnim.stop();
            root.toLyricsAnim.stop();
            root.restoreLastSavedEqualizer();
            if (currentIndex === root.lyricsTab) {
                root.toLyricsAnim.restart();
            } else if (currentIndex === root.audioTab) {
                root.toAudioAnim.restart();
                root.playAudioIntro();
            } else if (currentIndex === root.spotifyTab) {
                root.toSpotifyAnim.restart();
            } else {
                root.toEqAnim.restart();
            }
        }
        onValueChanged: (index, val) => {
            currentIndex = index;
        }
    }

    Item { Layout.fillWidth: true }

    ClickButton {
        id: audioTestBtn
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.audioTestBtnWidth * root.audioHeaderProgress
        implicitWidth: Layout.preferredWidth
        visible: root.audioHeaderProgress > 0.01
        opacity: root.audioHeaderProgress
        clip: true
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: root.s(8)
        buttonIcon: root.audioTestRunning ? "󰓛" : "󰋋"
        buttonText: root.audioTestRunning
            ? (typeof I18n !== "undefined" ? I18n.t("music.audio.stop_test", "Stop") : "Stop")
            : (typeof I18n !== "undefined" ? I18n.t("music.audio.test", "Test") : "Test")
        textFontSize: root.s(11.5)
        iconFontSize: root.s(12)
        accentColor: root.audioTestRunning
            ? (ThemeBackend.mauve || "#cba6f7")
            : (ThemeBackend.surface0 || "#313244")
        bgOpacity: ThemeBackend.elementOpacity
        textColor: root.audioTestRunning
            ? (ThemeBackend.base || "#1e1e2e")
            : (ThemeBackend.text || "#cdd6f4")
        onClicked: root.toggleAudioTest()
    }

    ClickButton {
        id: actionBtn
        visible: bottomSectionSwitch.currentIndex !== root.spotifyTab
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.actionBtnCurrentWidth
        implicitWidth: root.actionBtnCurrentWidth
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: root.s(12)
        buttonIcon: bottomSectionSwitch.currentIndex === root.lyricsTab
            ? "󰈔"
            : (bottomSectionSwitch.currentIndex === root.audioTab ? "󰑐" : "")
        buttonText: {
            if (bottomSectionSwitch.currentIndex === root.lyricsTab) {
                return typeof I18n !== "undefined" ? I18n.t("music.select_local_file", "Select file") : "Select file";
            }
            if (bottomSectionSwitch.currentIndex === root.audioTab) {
                return typeof I18n !== "undefined" ? I18n.t("music.audio.reset", "Reset") : "Reset";
            }
            return root.eqData && root.eqData.pending ? I18n.t("music.eq.apply") : I18n.t("music.eq.saved");
        }
        textFontSize: root.s(11.5)
        iconFontSize: root.s(13)
        accentColor: {
            if (bottomSectionSwitch.currentIndex !== root.equalizerTab) {
                return ThemeBackend.surface0 || "#313244";
            }
            return root.eqData && root.eqData.pending ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.surface0 || "#313244");
        }
        bgOpacity: ThemeBackend.elementOpacity
        textColor: {
            if (bottomSectionSwitch.currentIndex !== root.equalizerTab) {
                return ThemeBackend.text || "#cdd6f4";
            }
            return root.eqData && root.eqData.pending ? (ThemeBackend.base || "#1e1e2e") : (ThemeBackend.text || "#cdd6f4");
        }
        enabled: bottomSectionSwitch.currentIndex === root.lyricsTab
            ? (root.hasTargetPlayer && !Lyrics.loading)
            : (bottomSectionSwitch.currentIndex === root.audioTab
                ? (Math.abs(root.balanceSlider.value) >= 0.005 || root.eqData.mono === true || root.eqData.swap === true || String(root.eqData.dynamics || "off") !== "off")
                : true)
        opacity: bottomSectionSwitch.currentIndex === root.lyricsTab
            ? (root.hasTargetPlayer && !Lyrics.loading ? 1.0 : 0.45)
            : (bottomSectionSwitch.currentIndex === root.audioTab
                ? (enabled ? 1.0 : 0.45)
                : 1.0)
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on accentColor { ColorAnimation { duration: 320 } }
        Behavior on textColor { ColorAnimation { duration: 320 } }
        onClicked: {
            if (bottomSectionSwitch.currentIndex === root.lyricsTab) {
                root.lyricsPickerPopup.targetScreen = (root.Window && root.Window.window) ? root.Window.window.screen : null;
                root.lyricsPickerPopup.openPicker();
            } else if (bottomSectionSwitch.currentIndex === root.audioTab) {
                root.resetAudio();
            } else if (root.eqData && root.eqData.pending) {
                var temp = Object.assign({}, root.eqData);
                temp.pending = false;
                root.eqData = temp;
                root.savedEqData = Object.assign({}, temp);
                root.lastEqUpdate = Date.now();
                root.triggerEqLightning();
                root.execCmd(Caching.qsDir + "/media/equalizer.sh apply");
            }
        }
    }

    Item {
        id: presetTextContainer
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: (presetLabelText.implicitWidth + root.s(12)) * Math.max(0.0, 1.0 - root.presetSlideProgress)
        implicitWidth: Layout.preferredWidth
        visible: root.presetSlideProgress < 0.99
        opacity: Math.max(0.0, 1.0 - root.presetSlideProgress)
        clip: true

        Text {
            id: presetLabelText
            anchors.verticalCenter: parent.verticalCenter
            x: root.s(12) + (root.s(24) * root.presetSlideProgress)
            text: root.eqData && root.eqData.preset ? I18n.t("music.presets." + root.eqData.preset.toLowerCase()) : I18n.t("music.presets.flat")
            color: ThemeBackend.neutralTextColor(ThemeBackend.subtext0 || "#a6adc8")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(13)
            font.bold: true
        }
    }
}
