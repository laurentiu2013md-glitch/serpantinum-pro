pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"
Item {
    id: root
    property bool active: false
    property double started: 0
    property int seconds: 0
    readonly property string elapsed: String(Math.floor(seconds/60)).padStart(2,"0")+":"+String(seconds%60).padStart(2,"0")
    function updateElapsed() { seconds=active ? Math.max(0,Math.floor(Date.now()/1000-started)) : 0; }
    Process {
        id: watcher
        running: true
        command: ["python3",Caching.serpantinumDir+"/scripts/recording_status.py",Caching.getCacheDir("recording")]
        stdout: SplitParser {
            onRead: data=> {
                try { const result=JSON.parse(data);root.started=result.started || 0;root.active=result.active===true;root.updateElapsed(); } catch(e) {}
            }
        }
        onExited: restart.restart()
    }
    Timer { id: restart; interval: 1000; onTriggered: if (!watcher.running) watcher.running=true }
    Timer { interval: 1000; repeat: true; running: root.active; onTriggered: root.updateElapsed() }
    IpcHandler {
        target: "recording"
        function state(): string { return JSON.stringify({active:root.active,started:root.started,seconds:root.seconds,elapsed:root.elapsed}); }
    }
}
