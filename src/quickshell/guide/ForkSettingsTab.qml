import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"
GuideTab {
    id: page
    readonly property string section: rootObj.tabsModel[tabIndex] ? rootObj.tabsModel[tabIndex].key : "home"
    readonly property var details: ({
        home: ["Serpantinum Pro", "Customize the island and the desktop around it."],
        island: ["Dynamic Island", "Hover, motion and feedback on one shared surface."],
        music: ["Music", "Artwork and readability. Your player controls stay the same."],
        connectivity: ["Connectivity", "Bluetooth and network controls live in the island."],
        notifications: ["Notifications", "Island previews and a shared notification history."],
        quickactions: ["QuickActions & shelf", "Files, links and text shared with the island."],
        about: ["About Serpantinum Pro", "A desktop shell built around your Dynamic Island."]
    })
    readonly property var rows: {
        switch (section) {
        case "island": return [
            {key:"reducedMotion",title:"Reduced motion",detail:"Use immediate transitions and pause decorative animation.",fallback:false},
            {key:"cursorLocator",title:"Shake to find the pointer",detail:"Enlarge the pointer after a quick shake, then return it to normal."},
            {key:"wallpaperDepth",title:"Wallpaper depth",detail:"Subtle desktop parallax and smooth zoom when opening the launcher."},
            {key:"weatherSky",title:"Weather-adaptive sky",detail:"Clouds, sun, moon and precipitation inside the weather island."},
            {bucket:"osd",key:"showCapsLock",title:"Caps Lock feedback",detail:"Show key state inside the island."},
            {bucket:"osd",key:"showNumLock",title:"Num Lock feedback",detail:"Show key state inside the island."},
            {bucket:"osd",key:"showAirplane",title:"Airplane-mode feedback",detail:"Show radio state inside the island."}
        ];
        case "music": return [
            {key:"spotifyArtwork",title:"Full Spotify artwork",detail:"Fill the island background at the same opacity as the bar."},
            {key:"musicGlow",title:"Artwork glow for other players",detail:"Keep a soft, compact glow behind their controls."},
            {key:"artworkCrossfade",title:"Smooth artwork changes",detail:"Blend track backgrounds without a blank flash."},
            {key:"artworkContrast",title:"Adaptive text contrast",detail:"Dim brighter artwork to keep white text readable."}
        ];
        case "connectivity": return [
            {key:"bluetoothBatteries",title:"Bluetooth battery details",detail:"Show overall, left, right or case charge when reported by the device."},
            {key:"connectionAnimations",title:"Connection and scanning ripples",detail:"Animate device connections and Wi-Fi scans."}
        ];
        case "notifications": return [
            {bucket:"notifications",key:"dnd",title:"Do not disturb",detail:"Keep notifications in history without an island preview.",fallback:false},
            {key:"notificationGrouping",title:"Group notification bursts",detail:"Combine messages from the same app into one preview with a counter."},
            {bucket:"notifications",key:"sound",title:"Notification sounds",detail:"Use the notification sound already selected for your desktop."},
            {key:"lowBatteryColors",title:"Low-battery colors",detail:"Gently shift the battery indicator from green to amber and red."},
            {key:"chargingPulse",title:"Charging complete pulse",detail:"Play one green pulse when the battery reaches 100%."}
        ];
        case "quickactions": return [
            {bucket:"general",key:"quickactions",title:"Enable QuickActions",detail:"Show the floating tools and allow their shortcuts.",fallback:true},
            {key:"shelfThumbnails",title:"Rich file previews",detail:"Show cached image, video, PDF and document thumbnails."},
            {key:"shelfLanding",title:"Shelf landing animation",detail:"Gently bounce new items into place and highlight the shelf."}
        ];
        default: return [];
        }
    }
    function openIsland(kind) {
        Quickshell.execDetached(["qs","ipc","-p",Caching.qsDir+"/Shell.qml","call","main","handleCommand",kind === "bluetooth" ? "network" : "open",kind === "bluetooth" ? "network" : kind,kind === "bluetooth" ? "bluetooth" : ""]);
    }
    function navigate(key) {
        const index=rootObj.tabsModel.findIndex(item => item.key === key);
        if (index>=0) { rootObj.currentTab=index; rootObj.expandedTab=-1; rootObj.currentSubTab=-1; }
    }
    component Caption: Text { color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; wrapMode: Text.Wrap; textFormat: Text.PlainText }
    ScrollView {
        id: scroll
        anchors.fill: parent; anchors.margins: 28
        clip: true; contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth; spacing: 18
            Caption { Layout.fillWidth: true; text: page.details[page.section][0]; font.pixelSize: 30; font.bold: true }
            Caption { Layout.fillWidth: true; text: page.details[page.section][1]; font.pixelSize: 14; opacity: .65 }
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(ThemeBackend.text,.1) }
            GridLayout {
                visible: page.section === "home"; Layout.fillWidth: true; columns: width > 620 ? 2 : 1; columnSpacing: 12; rowSpacing: 12
                Repeater {
                    model: [
                        {key:"island",title:"Dynamic Island",detail:"Motion, weather and feedback"},
                        {key:"music",title:"Music",detail:"Artwork and contrast"},
                        {key:"connectivity",title:"Connectivity",detail:"Bluetooth, batteries and Wi-Fi"},
                        {key:"notifications",title:"Notifications",detail:"Grouped island previews"},
                        {key:"quickactions",title:"QuickActions & shelf",detail:"Shared files and previews"},
                        {key:"appearance",title:"Appearance",detail:"Colors, opacity and blur"}
                    ]
                    Rectangle {
                        id: card
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 100
                        radius: 18; color: Qt.alpha(ThemeBackend.primary,hover.hovered ? .17 : .08)
                        Column { anchors.fill: parent; anchors.margins: 18; spacing: 8
                            Caption { width: parent.width; text: card.modelData.title; font.pixelSize: 17; font.bold: true }
                            Caption { width: parent.width; text: card.modelData.detail; font.pixelSize: 12; opacity: .65 }
                        }
                        HoverHandler { id: hover }
                        TapHandler { onTapped: page.navigate(card.modelData.key) }
                    }
                }
            }
            NetworkAdvancedPanel { Layout.fillWidth: true; visible: page.section === "connectivity" }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: options.implicitHeight
                radius: 18; color: Qt.alpha(ThemeBackend.text,.045); visible: page.rows.length>0
                ColumnLayout {
                    id: options; width: parent.width; spacing: 0
                    Repeater {
                        model: page.rows
                        Item {
                            id: option
                            required property var modelData
                            required property int index
                            Component.onCompleted: page.rootObj.registerSearchItem({id:"fork-"+modelData.key,tab:page.section,title:modelData.title,desc:modelData.detail,target:option})
                            Component.onDestruction: page.rootObj.unregisterSearchItem("fork-"+modelData.key)
                            Layout.fillWidth: true; implicitHeight: Math.max(88,labels.implicitHeight+30)
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 16; spacing: 18
                                ColumnLayout {
                                    id: labels; Layout.fillWidth: true; spacing: 6
                                    Caption { Layout.fillWidth: true; text: option.modelData.title; font.pixelSize: 15; font.bold: true }
                                    Caption { Layout.fillWidth: true; text: option.modelData.detail; font.pixelSize: 12; opacity: .65 }
                                }
                                MaterialSwitch {
                                    checked: { const value=Config.getSetting(option.modelData.bucket || "coloros",{})[option.modelData.key]; return value===undefined ? option.modelData.fallback !== false : Boolean(value); }
                                    Accessible.name: option.modelData.title
                                    onClicked: Config.setSetting((option.modelData.bucket || "coloros")+"."+option.modelData.key,checked)
                                }
                            }
                            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 16; height: 1; visible: option.index<page.rows.length-1; color: Qt.alpha(ThemeBackend.text,.065) }
                        }
                    }
                }
            }
            Caption {
                visible: page.section === "island"; Layout.fillWidth: true; font.pixelSize: 13; opacity: .75
                text: "Super + S · Music\nSuper + C · Calendar\nSuper + B · Bluetooth\nSuper + N · Network\nSuper + D · Shelf\n\nTab / Shift+Tab move between controls. Enter or Space activates buttons; arrow keys adjust sliders. Escape closes the panel."
            }
            ColumnLayout {
                visible: page.section === "notifications"; Layout.fillWidth: true; spacing: 10
                Caption { text: "Preview duration · " + Math.round(timeout.value/1000) + " seconds"; font.pixelSize: 14 }
                Slider {
                    id: timeout; Layout.fillWidth: true; from: 2000; to: 15000; stepSize: 1000
                    value: Number(Config.getSetting("coloros",{}).notificationTimeout || 5000)
                    Accessible.name: "Island notification duration"
                    onMoved: Config.setSetting("coloros.notificationTimeout",Math.round(value))
                }
                ClickButton { buttonText: "Open notification history"; onClicked: page.openIsland("notifications") }
            }
            RowLayout {
                visible: page.section === "connectivity"; spacing: 12
                ClickButton { buttonText: "Open Bluetooth"; onClicked: page.openIsland("bluetooth") }
                ClickButton { buttonText: "Open network"; onClicked: page.openIsland("network") }
            }
            RowLayout {
                visible: page.section === "quickactions"; spacing: 12
                ClickButton { buttonText: "Open island shelf"; onClicked: page.openIsland("shelf") }
                ClickButton { buttonText: "Open QuickActions"; onClicked: Quickshell.execDetached(["qs","ipc","-p",Caching.qsDir+"/Shell.qml","call","floating","showDropShelf"]) }
            }
            ColumnLayout {
                visible: page.section === "about"; Layout.fillWidth: true; spacing: 18
                Caption { Layout.fillWidth: true; text: "A shared island for music, weather, connectivity, notifications and files. Blur and decorative motion turn off in Game Mode."; font.pixelSize: 16 }
                Caption { Layout.fillWidth: true; text: "Cursor enlargement uses hypr-dynamic-cursors, whose shake detection is inspired by KDE Plasma. Open-source credits and build details are included with the fork."; font.pixelSize: 13; opacity: .7 }
                ClickButton { buttonText: "Open project"; onClicked: Quickshell.execDetached(["xdg-open","https://github.com/laurentiu2013md-glitch/serpantinum-pro"]) }
            }
            Item { Layout.preferredHeight: 16 }
        }
    }
}
