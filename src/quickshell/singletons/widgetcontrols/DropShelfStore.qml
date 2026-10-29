pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../../quickactions/actions/Model.js" as Model

Item {
    id: root
    property var entries: []
    property var knownUris: []
    property var lastAddedUris: []
    property double lastAddedAt: 0
    property bool initialStateLoaded: false
    signal entriesAdded(var uris)
    onEntriesChanged: {
        const uris = entries.map(e => e.uri);
        const added = uris.filter(uri => knownUris.indexOf(uri) === -1);
        knownUris = uris;
        if (initialStateLoaded && added.length) {
            lastAddedUris = added; lastAddedAt = Date.now(); entriesAdded(added);
        }
    }
    property string statusText: "Empty"
    property var pendingCandidates: []
    property var pendingLinks: []
    property var importQueue: []
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
    readonly property string ramImageDir: "/dev/shm/serpantinum-image-links-" + (Quickshell.env("USER") || "user").replace(/[^A-Za-z0-9_.-]/g,"_")
    property int importGeneration: 0
    property var ramJobs: []
    function ramAction(action, uris) {
        ramJobs = ramJobs.concat([{action:action,uris:uris || []}]);
        nextRamJob();
    }
    function nextRamJob() {
        if (ramCleaner.running || !ramJobs.length) return;
        const job=ramJobs[0];ramJobs=ramJobs.slice(1);
        ramCleaner.command=["python3",Caching.serpantinumDir + "/scripts/shelf_ram.py",job.action,JSON.stringify(job.uris)];
        ramCleaner.running=true;
    }
    Process {
        id: ramCleaner
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result=JSON.parse(text);
                    if (result.missing && result.missing.length) {
                        const filtered=root.entries.filter(item=>result.missing.indexOf(item.uri)<0);
                        if (filtered.length!==root.entries.length) { root.entries=filtered;root.updateStatus();root.persist(); }
                    }
                } catch(e) {}
            }
        }
        onExited: ramJobTimer.restart()
    }
    Timer { id: ramJobTimer; interval: 0; onTriggered: root.nextRamJob() }

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
        function clear(): void { root.clearShelf(); }
        function use(uri: string): void { root.consumeEntry(uri); }
        function status(): string { return root.statusText; }
    }

    function updateStatus() {
        statusText = entries.length === 0
            ? "Empty"
            : entries.length + (entries.length === 1 ? " item" : " items");
    }

    function loadState(text) {
        initialStateLoaded = false;
        entries = Model.parseState(text);
        ramAction("check", entries.map(item=>item.uri));
        initialStateLoaded = true;
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
        if (entries[index]) ramAction("schedule",[entries[index].uri]);
        entries = Model.removeAt(entries, index);
        lastRemovedEntry = null;
        updateStatus();
        persist();
    }

    function removeAfterDrag(uri) {
        const matches = entries.filter(function(item) { return item.uri === uri; });
        if (matches.length === 0) return;
        ramAction("schedule",[uri]);
        undoExpiry.restart();
        lastRemovedEntry = matches[0];
        entries = Model.removeUri(entries, uri);
        statusText = "Dragged out — Undo to restore";
        persist();
    }

    function undoRemove() {
        if (!lastRemovedEntry) return;
        ramAction("cancel",[lastRemovedEntry.uri]);
        undoExpiry.stop();
        entries = Model.addUrls(entries, [lastRemovedEntry.uri]);
        lastRemovedEntry = null;
        updateStatus();
        persist();
    }

    Timer { id: undoExpiry; interval: 5000; onTriggered: root.lastRemovedEntry=null }
    function consumeEntry(uri) {
        if (uri.startsWith("file://" + root.ramImageDir + "/")) root.removeAfterDrag(uri);
    }
    function openEntry(uri) {
        Quickshell.execDetached(["xdg-open",uri]); consumeEntry(uri);
    }
    function queueImport(candidates, links) {
        if (downloader.running || imageWriter.running || pendingCandidates.length) {
            importQueue=importQueue.concat([{candidates:candidates,links:links}]); statusText="Media queued"; return;
        }
        pendingCandidates=candidates;pendingLinks=links || [];candidateAttempts=0;tryNextCandidate();
    }
    Timer {
        id: nextImport; interval: 0
        onTriggered: {
            if (!root.importQueue.length) return;
            const job=root.importQueue[0];root.importQueue=root.importQueue.slice(1);root.queueImport(job.candidates,job.links);
        }
    }
    function clearShelf() {
        importGeneration++;
        pendingCandidates=[]; pendingLinks=[]; importQueue=[]; nextImport.stop(); undoExpiry.stop();
        downloader.running=false; imageWriter.running=false;
        ramAction("clear",[]);
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
            || (drop.hasHtml && /<(img|video|source)\b/i.test(String(drop.html || "")))
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
        if (Model.isWebUrl(String(value).trim())) {
            queueImport([String(value).trim()],[String(value).trim()]);return;
        }
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

        const candidates = Model.remoteImageCandidates(
            drop.urls || [],
            drop.hasText ? drop.text : "",
            drop.hasHtml ? drop.html : "",
            nativeUrl
        );
        // Firefox supplies both a URL and binary image formats. Prefer the
        // original URL so a transient/unsupported binary buffer cannot abort it.
        if (candidates.length || directLinks.length) {
            queueImport(candidates.length ? candidates : directLinks,directLinks); return;
        }
        const imageFormat = imageMimeFormat(drop.formats || []);
        if (imageFormat !== "" && !downloader.running && !imageWriter.running) {
            const payload=Model.base64FromArrayBuffer(drop.getDataAsArrayBuffer(imageFormat));
            if (payload) {
                pendingCandidates=[];pendingLinks=[];candidateAttempts=0;
                importBase64Image(imageFormat,payload);return;
            }
            statusText="Image data unavailable. Drop the image's link instead.";return;
        }

        if (drop.hasText && String(drop.text || "").trim() !== "") {
            addText(String(drop.text)); return;
        }
        statusText = "Unsupported drop: use a file, image, link, or text";
    }

    function tryNextCandidate() {
        if (candidateAttempts >= maxCandidateAttempts || pendingCandidates.length === 0) {
            const links=pendingLinks;
            root.entries=Model.addUrls(root.entries,links);
            root.persist(); root.importFinished();
            statusText=links.length ? "No downloadable media found — link kept" : "Could not download this image or video";
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
        pendingCandidates = [];pendingLinks=[];
        candidateAttempts = 0;
        nextImport.restart();
    }

    function importBase64Image(mime, base64) {
        const suffix = String(mime).split("/").pop().replace(/[^a-zA-Z0-9]/g, "") || "img";
        statusText = "Saving image…";
        imageWriter.command = [
            "bash", "-c",
            "set -e; umask 077; python3 \"$3\" ensure '[]' >/dev/null; mkdir -p -- \"$1\"; out=$(mktemp --tmpdir=\"$1\" dropshelf-XXXXXX.\"$2\"); trap 'rm -f -- \"$out\"' EXIT; base64 -d > \"$out\"; file -Lb --mime-type \"$out\" | grep -q '^image/'; trap - EXIT; printf '%s' \"$out\"",
            "serpantinum-dropshelf", root.ramImageDir, suffix, Caching.serpantinumDir + "/scripts/shelf_ram.py"
        ];
        imageWriter.generation = importGeneration;
        imageWriter.stdinEnabled = true;
        imageWriter.running = true;
        imageWriter.write(base64);
        imageWriter.stdinEnabled = false;
    }

    function startDownload(url) {
        statusText = "Downloading media to RAM…";
        downloader.command = ["python3", Caching.serpantinumDir + "/scripts/shelf_download.py", url, Model.refererFor(url)];
        downloader.generation = importGeneration;
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
        property int generation: 0
        running: false
        stdout: StdioCollector { id: downloadOutput; waitForEnd: true }
        onExited: function(exitCode) {
            const path = String(downloadOutput.text || "").trim();
            if (downloader.generation !== root.importGeneration) { if (path) root.ramAction("remove",["file://"+encodeURI(path)]); return; }
            if (exitCode !== 0 || path === "") {
                root.tryNextCandidate();
                return;
            }
            root.importFinished();
            const uri = "file://" + encodeURI(path);
            root.entries = Model.addUrls(root.entries, [uri]);
            root.statusText = "Media added in RAM";
            root.persist();
        }
    }

    Process {
        id: imageWriter
        property int generation: 0
        running: false
        stdout: StdioCollector { id: imageWriterOutput; waitForEnd: true }
        onExited: function(exitCode) {
            const path = String(imageWriterOutput.text || "").trim();
            if (imageWriter.generation !== root.importGeneration) { if (path) root.ramAction("remove",["file://"+encodeURI(path)]); return; }
            if (exitCode !== 0 || path === "") {
                root.tryNextCandidate();
                return;
            }
            root.importFinished();
            const uri = "file://" + encodeURI(path);
            root.entries = Model.addUrls(root.entries, [uri]);
            root.statusText = "Media added in RAM";
            root.persist();
        }
    }

}
