pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../../quickactions/actions/Model.js" as Model

Item {
    id: root
    property var entries: []
    property string statusText: "Drop files here"
    property var pendingCandidates: []
    property int candidateAttempts: 0
    readonly property int maxCandidateAttempts: 4
    property var lastRemovedEntry: null
    property string activeDragUri: ""
    property bool selfDrop: false

    readonly property string stateDir: {
        const configured = Quickshell.env("XDG_STATE_HOME");
        return configured && configured.length > 0
            ? configured + "/serpantinum/dropshelf"
            : (Quickshell.env("HOME") || "~") + "/.local/state/serpantinum/dropshelf";
    }
    readonly property string statePath: root.stateDir + "/shelf.json"
    readonly property string dataDir: {
        const configured = Quickshell.env("XDG_DATA_HOME");
        return configured && configured.length > 0
            ? configured + "/serpantinum/dropshelf"
            : (Quickshell.env("HOME") || "~") + "/.local/share/serpantinum/dropshelf";
    }

    IpcHandler {
        target: "dropshelf"
        function state(): string { return Model.serialize(root.entries); }
        function acceptsMime(mime: string): bool { return root.acceptsDrop({urls:[],formats:[mime],hasText:mime.indexOf("text/") === 0,text:"sample",hasHtml:false}); }
        function addFiles(urls: string): int { const before = root.entries.length; const parsed = JSON.parse(urls); root.addDrop({urls:Array.isArray(parsed) ? parsed : [parsed],formats:[],hasText:false,hasHtml:false}); return root.entries.length - before; }
        function addText(value: string): void { root.addText(value); }
        function remove(uri: string): void { const index = root.entries.findIndex(e => e.uri === uri); if (index >= 0) root.removeAt(index); }
        function move(uri: string, index: string): void { root.moveTo(uri, parseInt(index)); }
    }

    function updateStatus() {
        statusText = entries.length === 0
            ? "Drop files or images here"
            : entries.length + (entries.length === 1 ? " item" : " items");
    }

    function loadState(text) {
        entries = Model.parseState(text);
        updateStatus();
    }

    property bool writePending: false

    function persist() { saveTimer.restart(); }

    Timer {
        id: saveTimer
        interval: 40
        onTriggered: root.writeState()
    }

    function writeState() {
        if (writer.running) { writePending = true; return; }
        writePending = false;
        writer.command = [
            "bash", "-c",
            "umask 077; mkdir -p -- \"$1\" && tmp=$(mktemp \"$1/.shelf-XXXXXX\") && printf '%s' \"$2\" > \"$tmp\" && mv -- \"$tmp\" \"$3\"",
            "serpantinum-dropshelf", root.stateDir, Model.serialize(entries), root.statePath
        ];
        writer.running = true;
    }

    function removeAt(index) {
        entries = Model.removeAt(entries, index);
        lastRemovedEntry = null;
        updateStatus();
        persist();
    }

    function removeAfterDrag(uri) {
        const matches = entries.filter(function(item) { return item.uri === uri; });
        if (matches.length === 0) return;
        lastRemovedEntry = matches[0];
        entries = Model.removeUri(entries, uri);
        statusText = "Dragged out — Undo to restore";
        persist();
    }

    function undoRemove() {
        if (!lastRemovedEntry) return;
        entries = Model.addUrls(entries, [lastRemovedEntry.uri]);
        lastRemovedEntry = null;
        updateStatus();
        persist();
    }

    function clearShelf() {
        entries = [];
        lastRemovedEntry = null;
        statusText = "Shelf cleared";
        persist();
    }

    function imageMimeFormat(formats) {
        const preferred = ["image/gif", "image/webp", "image/png", "image/jpeg", "image/avif", "image/bmp"];
        for (let i = 0; i < preferred.length; i++)
            if (formats.indexOf(preferred[i]) !== -1) return preferred[i];
        return "";
    }

    function firstMimeText(drop, formats) {
        for (let i = 0; i < formats.length; i++) {
            if ((drop.formats || []).indexOf(formats[i]) === -1) continue;
            const value = String(drop.getDataAsString(formats[i]) || "").trim();
            if (value !== "") return value;
        }
        return "";
    }

    function anyTextMime(drop) {
        const formats = drop.formats || [];
        for (let i = 0; i < formats.length; i++) {
            const format = String(formats[i]);
            if (!/^text\//i.test(format) && format.toLowerCase().indexOf("url") === -1) continue;
            const value = String(drop.getDataAsString(format) || "").trim();
            if (value.indexOf("http://") !== -1 || value.indexOf("https://") !== -1)
                return value;
        }
        return "";
    }

    function acceptsDrop(drop) {
        const formats = drop.formats || [];
        return Model.localUrls(drop.urls || []).length > 0
            || Model.webUrls(drop.urls || [], drop.hasText ? drop.text : "", "").length > 0
            || (drop.hasText && String(drop.text || "").trim() !== "")
            || imageMimeFormat(formats) !== "" || formats.some(f => String(f).indexOf("moz") !== -1 || f === "DownloadURL");
    }
    function moveTo(uri, target) {
        const from = entries.findIndex(e => e.uri === uri);
        if (from < 0) return;
        const reordered = entries.slice(); const moved = reordered.splice(from, 1)[0];
        reordered.splice(Math.max(0, Math.min(target, reordered.length)), 0, moved);
        entries = reordered; selfDrop = true; updateStatus(); persist();
    }
    function copyEntry(uri) {
        const entry = entries.find(e => e.uri === uri);
        if (!entry) return;
        clipboard.command = entry.text ? ["wl-copy", entry.text] : ["wl-copy", "--type", "text/uri-list", uri + "\r\n"];
        clipboard.running = true; statusText = "Copied";
    }
    Process { id: clipboard }
    property string importedText: ""
    Process {
        id: textWriter
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (!path) return;
                const uri = "file://" + encodeURI(path);
                const next = Model.addUrls(root.entries, [uri]);
                next[next.length - 1].text = root.importedText;
                next[next.length - 1].name = root.importedText.replace(/\s+/g, " ").slice(0, 48);
                root.entries = next; root.statusText = "Text added"; root.persist();
            }
        }
    }
    function addText(value) {
        if (textWriter.running) { statusText = "Wait for the current text item"; return; }
        importedText = value;
        textWriter.command = ["python3", "-c", "import os,sys,tempfile; os.makedirs(sys.argv[1],exist_ok=True); fd,path=tempfile.mkstemp(prefix='note-',suffix='.txt',dir=sys.argv[1]); os.write(fd,sys.argv[2].encode()); os.close(fd); print(path)", dataDir, value];
        textWriter.running = true;
    }

    function addDrop(drop) {
        const urls = Model.localUrls(drop.urls || []);
        if (urls.length > 0) {
            if (activeDragUri !== "" && urls.indexOf(activeDragUri) !== -1)
                selfDrop = true;
            const next = Model.addUrls(entries, urls);
            const added = next.length - entries.length;
            entries = next;
            statusText = added > 0 ? "Added " + added + (added === 1 ? " item" : " items") : "Already on the shelf";
            persist();
            return;
        }

        if (downloader.running || imageWriter.running) {
            statusText = "Please wait for the current image";
            return;
        }

        const nativeUrl = firstMimeText(drop, [
            "application/x-moz-file-promise-url",
            "application/x-moz-url",
            "text/x-moz-url",
            "DownloadURL"
        ]) || anyTextMime(drop);

        const directLinks = Model.webUrls(
            drop.urls || [],
            drop.hasText ? drop.text : "",
            nativeUrl
        );

        pendingCandidates = Model.remoteImageCandidates(
            drop.urls || [],
            drop.hasText ? drop.text : "",
            drop.hasHtml ? drop.html : "",
            nativeUrl
        );
        candidateAttempts = 0;

        const imageFormat = imageMimeFormat(drop.formats || []);
        if (imageFormat !== "") {
            importBase64Image(imageFormat, Model.base64FromArrayBuffer(drop.getDataAsArrayBuffer(imageFormat)));
            return;
        }

        const imageCandidates = pendingCandidates.filter(function(candidate) {
            return Model.looksLikeImageSource(candidate);
        });

        if (imageCandidates.length > 0) {
            pendingCandidates = imageCandidates;
            tryNextCandidate();
            return;
        }

        if (directLinks.length > 0) {
            const next = Model.addUrls(entries, directLinks);
            const added = next.length - entries.length;
            entries = next;
            statusText = added > 0
                ? "Added " + added + (added === 1 ? " link" : " links")
                : "Already on the shelf";
            persist();
            return;
        }

        if (drop.hasText && String(drop.text || "").trim() !== "") {
            addText(String(drop.text)); return;
        }
        statusText = "Unsupported drop: use a file, image, link, or text";
    }

    function tryNextCandidate() {
        if (candidateAttempts >= maxCandidateAttempts || pendingCandidates.length === 0) {
            pendingCandidates = [];
            statusText = "Could not save that image";
            return;
        }
        const next = String(pendingCandidates.shift());
        candidateAttempts++;
        const data = Model.parseDataUri(next);
        if (data !== null) {
            importBase64Image(data.mime, data.base64);
            return;
        }
        startDownload(next);
    }

    function importFinished() {
        pendingCandidates = [];
        candidateAttempts = 0;
    }

    function importBase64Image(mime, base64) {
        const suffix = String(mime).split("/").pop().replace(/[^a-zA-Z0-9]/g, "") || "img";
        statusText = "Saving image…";
        imageWriter.command = [
            "bash", "-c",
            "set -e; umask 077; mkdir -p -- \"$1\"; out=$(mktemp --tmpdir=\"$1\" dropshelf-XXXXXX.\"$2\"); trap 'rm -f -- \"$out\"' EXIT; base64 -d > \"$out\"; file -Lb --mime-type \"$out\" | grep -q '^image/'; trap - EXIT; printf '%s' \"$out\"",
            "serpantinum-dropshelf", root.dataDir, suffix
        ];
        imageWriter.stdinEnabled = true;
        imageWriter.running = true;
        imageWriter.write(base64);
        imageWriter.stdinEnabled = false;
    }

    function startDownload(url) {
        statusText = candidateAttempts > 1 ? "Saving image… (trying another source)" : "Saving image…";
        downloader.command = [
            "bash", "-c",
            "set -e; umask 077; mkdir -p -- \"$1\"; out=$(mktemp --tmpdir=\"$1\" dropshelf-XXXXXX); trap 'rm -f -- \"$out\"' EXIT; curl -fL --max-time 30 --max-filesize 52428800 --proto '=http,https' -A 'Mozilla/5.0' -e \"$3\" -o \"$out\" -- \"$2\"; mime=$(file -Lb --mime-type \"$out\"); case \"$mime\" in image/*) ;; *) exit 65 ;; esac; ext=$(printf '%s' \"${mime#image/}\" | tr -cd 'a-zA-Z0-9'); final=\"${out}.${ext:-img}\"; mv -- \"$out\" \"$final\"; trap - EXIT; printf '%s' \"$final\"",
            "serpantinum-dropshelf", root.dataDir, url, Model.refererFor(url)
        ];
        downloader.running = true;
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: if (!writer.running && !root.writePending && !saveTimer.running) root.loadState(text())
        onLoadFailed: root.loadState("")
    }

    Process {
        id: writer
        running: false
        onExited: function(exitCode) {
            if (root.writePending || saveTimer.running) saveTimer.restart();
            else if (exitCode === 0) stateFile.reload();
            else root.statusText = "Could not save shelf";
        }
    }

    Process {
        id: downloader
        running: false
        stdout: StdioCollector { id: downloadOutput; waitForEnd: true }
        onExited: function(exitCode) {
            const path = String(downloadOutput.text || "").trim();
            if (exitCode !== 0 || path === "") {
                root.tryNextCandidate();
                return;
            }
            root.importFinished();
            const uri = "file://" + encodeURI(path);
            root.entries = Model.addUrls(root.entries, [uri]);
            root.statusText = "Image added";
            root.persist();
        }
    }

    Process {
        id: imageWriter
        running: false
        stdout: StdioCollector { id: imageWriterOutput; waitForEnd: true }
        onExited: function(exitCode) {
            const path = String(imageWriterOutput.text || "").trim();
            if (exitCode !== 0 || path === "") {
                root.tryNextCandidate();
                return;
            }
            root.importFinished();
            const uri = "file://" + encodeURI(path);
            root.entries = Model.addUrls(root.entries, [uri]);
            root.statusText = "Image added";
            root.persist();
        }
    }

}
