import QtQuick
import Quickshell
import Quickshell.Io
import "../../../core/theme"
import "../../../core/utils"

/**
 * SearchService.qml
 * Singleton for handling all search logic.
 */
pragma Singleton

Item {
    id: root

    property var actionsModel: []
    property var appsModel: []
    property var currentResults: []
    property string mode: "actions"

    // --- Actions Loader ---
    Process {
        id: actionsReader
        command: ["cat", Quickshell.env("QS_CONFIG_DIR") + "/assets/data/actions.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // Pre-process actions to ensure they have the "Rice Action" type
                    let raw = JSON.parse(this.text);
                    root.actionsModel = raw.map(a => {
                        a.type = "Rice Action";
                        return a;
                    });
                    console.log("SearchService: Loaded " + root.actionsModel.length + " actions");
                    // Default view on launch
                    if (root.mode === "actions") {
                        root.currentResults = root.actionsModel;
                    }
                } catch (e) {
                    console.error("SearchService: Failed to parse actions.json");
                }
            }
        }
    }

    // --- App Indexer ---
    Process {
        id: appFetcher
        command: ["bash", "-c", "find /usr/share/applications ~/.local/share/applications -maxdepth 2 -name '*.desktop' 2>/dev/null | xargs grep -E '^(Name|Icon|Exec|NoDisplay)='"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n");
                let appMap = {};
                for (let line of lines) {
                    let colonIdx = line.indexOf(":");
                    if (colonIdx === -1) continue;
                    let file = line.substring(0, colonIdx);
                    let content = line.substring(colonIdx + 1);
                    let equalIdx = content.indexOf("=");
                    if (equalIdx === -1) continue;
                    let key = content.substring(0, equalIdx);
                    let value = content.substring(equalIdx + 1);
                    
                    if (!appMap[file]) appMap[file] = {};
                    // Only take the first occurrence (usually the generic one before translations)
                    if (appMap[file][key] === undefined) {
                        appMap[file][key] = value.trim();
                    }
                }
                
                let apps = [];
                let seenTitles = new Set();
                for (let file in appMap) {
                    let data = appMap[file];
                    if (data.NoDisplay === "true") continue;
                    if (!data.Name || !data.Exec) continue;
                    let title = data.Name.trim();
                    if (seenTitles.has(title)) continue;
                    seenTitles.add(title);
                    
                    apps.push({
                        "title": title,
                        "icon": data.Icon ? data.Icon.trim() : "󰀻",
                        "cmd": data.Exec.split(" %")[0].replace(/'/g, "").replace(/\"/g, "").trim(),
                        "type": "Application"
                    });
                }
                root.appsModel = apps;
                console.log("SearchService: Indexed " + apps.length + " apps");
                if (root.mode === "apps") root.currentResults = apps.slice(0, 10);
            }
        }
    }

    function query(input) {
        let q_raw = (input || "").trim();
        if (q_raw === "" || q_raw === ">" || q_raw === "|") {
            root.mode = q_raw === ">" ? "actions" : (q_raw === "|" ? "math" : "apps");
            if (root.mode === "actions") root.currentResults = root.actionsModel;
            else if (root.mode === "apps") root.currentResults = root.appsModel.slice(0, 15);
            else root.currentResults = [];
            return;
        }

        if (input.startsWith(">")) {
            root.mode = "actions";
            let q = input.slice(1).toLowerCase().trim();
            root.currentResults = root.actionsModel.filter(a => a.title.toLowerCase().includes(q));
        } else if (input.startsWith("|")) {
            root.mode = "math";
            doMath(input.slice(1).trim());
        } else {
            root.mode = "apps";
            let q = input.toLowerCase().trim();
            let filtered = root.appsModel.filter(a => a.title.toLowerCase().includes(q));
            
            filtered.sort((a, b) => {
                let aStarts = a.title.toLowerCase().startsWith(q);
                let bStarts = b.title.toLowerCase().startsWith(q);
                if (aStarts && !bStarts) return -1;
                if (!aStarts && bStarts) return 1;
                return 0;
            });
            
            root.currentResults = filtered.slice(0, 15);
        }
    }

    function doMath(expression) {
        if (expression.trim().length === 0) {
            root.currentResults = [];
            return;
        }
        try {
            if (/[0-9]/.test(expression)) {
                const result = eval(expression);
                if (result !== undefined && !isNaN(result)) {
                    root.currentResults = [{
                        "title": result.toString(),
                        "type": "Calculation",
                        "cmd": "wl-copy " + result,
                        "icon": "calculator"
                    }];
                }
            }
        } catch (e) {}
    }
}
