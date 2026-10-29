pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"
Item {
    id: root
    property var paths: ({})
    property var kinds: ({})
    property var queue: []
    property string current: ""
    function request(uri) {
        if (uri.startsWith("file:///dev/shm/serpantinum-image-links-") && !/\.(mp4|webm|mov|mkv|avi|ogv)(?:[?#]|$)/i.test(uri)) {
            paths=Object.assign({},paths,{[uri]:uri});return;
        }
        if (!uri.startsWith("file://") || paths[uri] !== undefined || queue.indexOf(uri) !== -1 || current === uri) return;
        queue = queue.concat([uri]); next();
    }
    function next() {
        if (worker.running || !queue.length) return;
        current = queue[0]; queue = queue.slice(1);
        worker.command = ["python3", Caching.serpantinumDir + "/scripts/shelf_thumbnail.py", current]; worker.running = true;
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try { const data=JSON.parse(text); root.paths=Object.assign({},root.paths,{[data.uri]:data.path}); root.kinds=Object.assign({},root.kinds,{[data.uri]:data.kind}); } catch(error) {}
            }
        }
        onExited: { root.current = ""; advance.restart(); }
    }
    Timer { id: advance; interval: 0; onTriggered: root.next() }
}
