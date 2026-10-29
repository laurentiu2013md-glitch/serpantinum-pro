import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../"
import "../reusables"
import "SpotifyMini.js" as SpotifyMini

Item {
    id: spotifyView
    required property var root
    objectName: "spotifyMiniBrowser"
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: parent.width
    x: root.bottomSectionSwitch.currentIndex === root.spotifyTab ? 0
        : (root.bottomSectionSwitch.currentIndex < root.spotifyTab ? parent.width + root.s(24) : -parent.width - root.s(24))
    opacity: root.bottomSectionSwitch.currentIndex === root.spotifyTab ? 1 : 0
    visible: opacity > 0
    clip: true
    Behavior on x { NumberAnimation { duration: Motion.duration(420); easing.type: Easing.OutQuart } }
    Behavior on opacity { NumberAnimation { duration: Motion.duration(320); easing.type: Easing.OutCubic } }

    property var profile: SpotifyMini.defaults()
    readonly property var player: SpotifyMini.selectPlayer(Mpris.players.values, profile.preferredClient)
    readonly property bool clientDetected: player !== null
    readonly property bool selected: root.active && root.bottomSectionSwitch.currentIndex === root.spotifyTab
    property bool connected: false
    property bool busy: false
    property bool loaded: false
    property string mode: "library"
    property string collectionUri: ""
    property string collectionTitle: ""
    property string message: ""
    property var items: []
    property var previousPage: null
    property int nextOffset: 0
    property bool hasMore: false
    property int generation: 0
    property var pendingRequest: null

    FileView {
        path: Quickshell.env("HOME") + "/.config/serpantinum/spotify-mini.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: spotifyView.profile = SpotifyMini.parseProfile(text())
        onLoadFailed: spotifyView.profile = SpotifyMini.defaults()
    }

    function send(path, body, callback) {
        if (!profile.bridgeUrl || !profile.bridgeToken) return;
        const xhr = new XMLHttpRequest();
        xhr.open(body ? "POST" : "GET", profile.bridgeUrl + path, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("X-Island-Token", profile.bridgeToken);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            let response = {};
            try { response = JSON.parse(xhr.responseText); } catch (_) {}
            callback(xhr.status >= 200 && xhr.status < 300, response);
        };
        xhr.send(body ? JSON.stringify(body) : "");
        return xhr;
    }

    function checkConnection() {
        if (!selected || !clientDetected) return;
        send("/status", null, function(ok, data) {
            if (!spotifyView.clientDetected) return;
            spotifyView.connected = ok && data.connected === true;
            if (spotifyView.connected && !spotifyView.loaded && !spotifyView.busy && spotifyView.mode === "library") spotifyView.showLibrary();
        });
    }

    function load(action, args, append) {
        if (!clientDetected) return;
        const current = ++generation;
        if (pendingRequest) pendingRequest.abort();
        busy = true;
        message = "";
        args.limit = profile.pageSize;
        pendingRequest = send("/command", {action:action,args:args}, function(ok, data) {
            if (current !== spotifyView.generation || !spotifyView.clientDetected) return;
            spotifyView.busy = false;
            spotifyView.pendingRequest = null;
            if (!ok || data.error || !data.result) {
                spotifyView.message = "Couldn’t load your music. Try again.";
                if (!ok) spotifyView.connected = false;
                return;
            }
            const result = data.result;
            spotifyView.connected = true;
            spotifyView.items = append ? spotifyView.items.concat(result.items || []) : (result.items || []);
            spotifyView.nextOffset = result.nextOffset || 0;
            spotifyView.hasMore = result.hasMore === true;
            spotifyView.loaded = true;
            if (!append) musicGrid.positionViewAtBeginning();
        });
    }

    function showLibrary() {
        mode = "library";
        collectionUri = collectionTitle = "";
        previousPage = null;
        load("library", {offset:0}, false);
    }

    function showSearch() {
        ++generation;
        if (pendingRequest) pendingRequest.abort();
        pendingRequest = null;
        busy = false;
        mode = "search";
        collectionUri = collectionTitle = "";
        previousPage = null;
        items = [];
        message = "";
        hasMore = false;
        Qt.callLater(function() { searchInput.forceActiveFocus(); });
    }

    function search(query) {
        mode = "search";
        searchInput.text = query;
        collectionUri = collectionTitle = "";
        if (!String(query).trim()) { items = []; return; }
        load("search", {query:query,offset:0}, false);
    }

    function openItem(item) {
        if (busy || !item) return;
        if (item.type === "track") { play(item.uri); return; }
        previousPage = {mode:mode,items:items,nextOffset:nextOffset,hasMore:hasMore,query:searchInput.text};
        mode = "tracks";
        collectionUri = item.uri;
        collectionTitle = item.title;
        items = [];
        load("tracks", {uri:item.uri,offset:0}, false);
    }

    function goBack() {
        ++generation;
        if (pendingRequest) pendingRequest.abort();
        pendingRequest = null;
        busy = false;
        if (!previousPage) { showLibrary(); return; }
        mode = previousPage.mode;
        items = previousPage.items;
        nextOffset = previousPage.nextOffset;
        hasMore = previousPage.hasMore;
        searchInput.text = previousPage.query;
        previousPage = null;
        collectionUri = collectionTitle = message = "";
    }

    function play(uri) {
        if (!clientDetected) return;
        send("/command", {action:"play",args:{uri:uri}}, function(ok, data) {
            if (!spotifyView.clientDetected) return;
            spotifyView.message = ok && !data.error ? "" : "Couldn’t play this item. Try again.";
        });
    }

    function retry() {
        if (mode === "library") showLibrary();
        else if (mode === "search") search(searchInput.text);
        else load("tracks", {uri:collectionUri,offset:0}, false);
    }

    onSelectedChanged: if (selected) checkConnection()
    onProfileChanged: if (selected) checkConnection()
    onPlayerChanged: {
        if (!clientDetected) {
            ++generation;
            if (pendingRequest) pendingRequest.abort();
            pendingRequest = null;
            items = [];
            previousPage = null;
            busy = connected = loaded = false;
            message = collectionUri = collectionTitle = "";
            mode = "library";
        } else if (selected) checkConnection();
    }
    Timer {
        interval: 3000
        repeat: true
        running: spotifyView.selected && spotifyView.clientDetected && !spotifyView.connected
        onTriggered: spotifyView.checkConnection()
    }

    Text {
        anchors.centerIn: parent
        visible: !spotifyView.clientDetected
        text: "no client detected"
        font.family: ThemeBackend.fontFamily
        font.pixelSize: root.s(12)
        font.weight: Font.DemiBold
        color: ThemeBackend.neutralTextColor(ThemeBackend.subtext0)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.s(8)
        visible: spotifyView.clientDetected

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(28)
            spacing: root.s(7)
            IconButton {
                objectName: "spotifyBack"
                visible: spotifyView.mode === "tracks"
                Layout.preferredWidth: root.s(28)
                Layout.preferredHeight: root.s(28)
                buttonIcon: "󰁍"
                iconFontSize: root.s(14)
                cornerRadius: ThemeBackend.borderRadius
                accentColor: ThemeBackend.surface0
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.text
                onClicked: spotifyView.goBack()
            }
            Switch {
                visible: spotifyView.mode !== "tracks"
                Layout.preferredWidth: root.s(140)
                Layout.preferredHeight: root.s(26)
                options: ["Library", "Search"]
                currentIndex: spotifyView.mode === "search" ? 1 : 0
                fontPixelSize: root.s(11)
                cornerRadius: ThemeBackend.borderRadius
                accentColor: ThemeBackend.mauve
                baseColor: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
                textColor: ThemeBackend.subtext0
                activeTextColor: ThemeBackend.base
                onValueChanged: (index, value) => {
                    if (index === 0) spotifyView.showLibrary();
                    else spotifyView.showSearch();
                }
            }
            TextField {
                id: searchInput
                objectName: "spotifySearch"
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(28)
                visible: spotifyView.mode === "search"
                placeholderText: "Songs, playlists, albums…"
                placeholderTextColor: ThemeBackend.neutralTextColor(ThemeBackend.subtext0)
                color: ThemeBackend.neutralTextColor(ThemeBackend.text)
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(11)
                selectByMouse: true
                leftPadding: root.s(9)
                rightPadding: root.s(9)
                background: Rectangle {
                    radius: ThemeBackend.borderRadius
                    color: ThemeBackend.liquidGlass ? "transparent" : Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
                    GlassFill { anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: 0.3 }
                }
                onAccepted: spotifyView.search(text)
            }
            Text {
                Layout.fillWidth: true
                visible: spotifyView.mode === "tracks"
                text: spotifyView.collectionTitle
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(12)
                font.bold: true
                color: ThemeBackend.neutralTextColor(ThemeBackend.text)
                elide: Text.ElideRight
            }
            Item { Layout.fillWidth: true; visible: spotifyView.mode === "library" }
            IconButton {
                objectName: "spotifyPlayCollection"
                visible: spotifyView.mode === "tracks"
                enabled: !spotifyView.busy
                Layout.preferredWidth: root.s(28)
                Layout.preferredHeight: root.s(28)
                buttonIcon: "󰐊"
                iconFontSize: root.s(13)
                cornerRadius: ThemeBackend.borderRadius
                accentColor: ThemeBackend.surface0
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.text
                onClicked: spotifyView.play(spotifyView.collectionUri)
            }
            IconButton {
                objectName: "spotifyRefresh"
                enabled: !spotifyView.busy
                Layout.preferredWidth: root.s(28)
                Layout.preferredHeight: root.s(28)
                buttonIcon: "󰑐"
                iconFontSize: root.s(13)
                cornerRadius: ThemeBackend.borderRadius
                accentColor: ThemeBackend.surface0
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.text
                onClicked: spotifyView.retry()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            GridView {
                id: musicGrid
                objectName: "spotifyArtworkGrid"
                anchors.fill: parent
                readonly property real cardGap: root.s(10)
                cellWidth: Math.floor(width / 3)
                cellHeight: Math.round((cellWidth - cardGap) * 1.45) + cardGap
                model: spotifyView.items
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                delegate: Item {
                    id: musicCard
                    required property var modelData
                    required property int index
                    objectName: "spotifyCard-" + index
                    width: musicGrid.cellWidth
                    height: musicGrid.cellHeight
                    activeFocusOnTab: true
                    enabled: !spotifyView.busy && modelData.playable !== false
                    opacity: enabled ? 1 : 0.5
                    Keys.onReturnPressed: spotifyView.openItem(modelData)
                    Keys.onEnterPressed: spotifyView.openItem(modelData)

                    Rectangle {
                        id: cardSurface
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - musicGrid.cardGap
                        height: width * 1.45
                        radius: ThemeBackend.borderRadius
                        color: ThemeBackend.liquidGlass ? "transparent" : Qt.alpha(ThemeBackend.surface0, hovered.hovered ? 0.75 : ThemeBackend.elementOpacity)
                        GlassFill {
                            anchors.fill: parent
                            radius: parent.radius
                            tintColor: ThemeBackend.surface0
                            tintAmount: hovered.hovered ? 0.45 : 0.25
                        }
                        HoverHandler { id: hovered }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: spotifyView.openItem(musicCard.modelData)
                        }
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: root.s(9)
                            spacing: root.s(5)
                            ClippingRectangle {
                                id: cardArtwork
                                visible: spotifyView.profile.showArtwork
                                Layout.fillWidth: true
                                Layout.preferredHeight: width
                                radius: ThemeBackend.smallRadius
                                color: Qt.alpha(ThemeBackend.surface1, 0.35)
                                Image {
                                    id: coverArt
                                    anchors.fill: parent
                                    source: musicCard.modelData.artwork || ""
                                    sourceSize: Qt.size(256,256)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: coverArt.status !== Image.Ready
                                    text: musicCard.modelData.type === "collection" ? "󰋑" : (musicCard.modelData.type === "track" ? "󰎈" : "󰲸")
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(44)
                                    color: ThemeBackend.neutralTextColor(ThemeBackend.subtext0)
                                }
                                IconButton {
                                    objectName: "spotifyPlayItem-" + musicCard.index
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: root.s(6)
                                    width: root.s(32)
                                    height: root.s(32)
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰐊"
                                    iconFontSize: root.s(14)
                                    accentColor: ThemeBackend.surface0
                                    bgOpacity: ThemeBackend.elementOpacity
                                    textColor: ThemeBackend.text
                                    onClicked: spotifyView.play(musicCard.modelData.uri)
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: musicCard.modelData.title
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(13)
                                font.bold: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: ThemeBackend.neutralTextColor(ThemeBackend.text)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: musicCard.modelData.subtitle || ""
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(10.5)
                                elide: Text.ElideRight
                                color: ThemeBackend.neutralTextColor(ThemeBackend.subtext0)
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }
                footer: ClickButton {
                    width: musicGrid.width
                    height: visible ? root.s(27) : 0
                    visible: spotifyView.hasMore
                    enabled: !spotifyView.busy
                    buttonText: "Load more"
                    textFontSize: root.s(10)
                    onClicked: spotifyView.load(spotifyView.mode === "tracks" ? "tracks" : "library", {uri:spotifyView.collectionUri,offset:spotifyView.nextOffset}, true)
                }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - root.s(20)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: spotifyView.items.length === 0
                text: spotifyView.message || (spotifyView.busy ? "Loading…" : (!spotifyView.connected ? "Connecting to Spotify…" : (spotifyView.mode === "search" ? "Search for songs, playlists, or albums" : "No songs here yet")))
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(12)
                font.weight: Font.DemiBold
                color: ThemeBackend.neutralTextColor(ThemeBackend.subtext0)
            }
        }
        Text {
            Layout.fillWidth: true
            visible: spotifyView.message !== "" && spotifyView.items.length > 0
            text: spotifyView.message
            elide: Text.ElideRight
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(10)
            color: ThemeBackend.neutralTextColor(ThemeBackend.subtext0)
        }
    }
}
