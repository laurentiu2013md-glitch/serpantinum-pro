pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"
Item {
    id: root
    property var events: []
    property string error: ""
    property int calendars: 0
    function refresh() { run("list", ""); }
    function importCalendar(url) { run("import", url); }
    function run(action, path) {
        if (worker.running) return;
        worker.command = [Caching.serpantinumDir + "/../calendar-runtime/bin/python", Caching.serpantinumDir + "/scripts/calendar_events.py", action, path];
        worker.running = true;
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try { const data=JSON.parse(text); root.events=data.events || []; root.error=data.error || ""; root.calendars=data.calendars || 0; }
                catch(e) { root.error="Calendar reader unavailable"; }
            }
        }
    }
    Timer { interval: 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
