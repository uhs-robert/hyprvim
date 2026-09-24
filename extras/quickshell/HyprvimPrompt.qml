pragma ComponentBehavior: Bound
// extras/quickshell/HyprvimPrompt.qml
// Reference HyprVim prompt bar for Quickshell: implements the `hyprvim_prompt` IPC target.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var spec: ({})
    // True from open until the callback is dispatched; HyprVim waits for exactly one dispatch per spec.
    property bool session: false
    readonly property bool is_output: root.spec.kind === "output"
    readonly property var theme: root.spec.theme || {}

    readonly property color bg: root.theme.bg_core || "#070C13"
    readonly property color border_color: root.theme.bg_border || "#5D8BBB"
    readonly property color fg: root.theme.fg || "#F7EDE1"
    readonly property color muted: root.theme.info || "#B0C8DE"
    readonly property color primary: root.theme.primary || "#7FA3C9"
    readonly property color secondary: root.theme.secondary || "#D6CE7C"
    readonly property color selection: Qt.alpha(root.primary, 0.25)
    readonly property int font_size: parseInt(root.theme.base_font_size) || 12
    property string font_family: "monospace"
    readonly property real row_height: root.font_size + 12

    // Tab cycling previews candidates in the line; the menu keeps ranking what was typed before it.
    property var cycle_base: null
    property int selected: -1
    property bool menu_hidden: false
    property bool applying: false
    property int history_index: -1
    property string draft: ""
    property var source_cache: ({})
    property var shell_items: null

    readonly property string query_text: root.cycle_base !== null ? root.cycle_base : input.text
    readonly property var ctx: root.context_of(root.query_text)
    readonly property var arg_spec: root.ctx.kind === "arg" ? root.arg_spec_for(root.ctx.cmd, root.ctx.pos) : null
    readonly property var items: root.candidates(root.ctx, root.source_cache, root.shell_items)
    readonly property bool menu_shown: !root.is_output && !root.menu_hidden && root.items.length > 0 && (root.query_text !== "" || root.cycle_base !== null)
    readonly property real screen_height: root.screen ? root.screen.height : 1080

    screen: {
        const mon = Hyprland.focusedMonitor;
        return (mon && Quickshell.screens.find(s => s.name === mon.name)) || null;
    }
    visible: false
    color: "transparent"
    exclusiveZone: 0
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: panel.height
    WlrLayershell.namespace: "hyprvim-prompt"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onCtxChanged: root.request_sources()
    // A config reload mid-prompt must still answer, or HyprVim never restores the mode.
    Component.onDestruction: root.finish(null)

    IpcHandler {
        target: "hyprvim_prompt"

        // Returns "ok" once shown; HyprVim falls back to its terminal bar on anything else.
        function open(path: string): string {
            if (root.session) root.finish(null);
            spec_file.path = path;
            let parsed;
            try {
                parsed = JSON.parse(spec_file.text());
            } catch (e) {
                return "invalid";
            }
            if (!parsed || !parsed.callback) return "invalid";
            root.spec = parsed;
            root.session = true;
            root.cycle_base = null;
            root.selected = -1;
            root.menu_hidden = false;
            root.history_index = -1;
            root.source_cache = {};
            root.shell_items = null;
            output_file.path = parsed.kind === "output" ? parsed.output_path : "";
            output.text = parsed.kind === "output" ? (output_file.text() || "").slice(0, 100000) : "";
            root.set_text(parsed.text || "");
            root.visible = true;
            if (root.is_output) output_view.forceActiveFocus();
            else input.forceActiveFocus();
            return "ok";
        }

        function close(): void {
            root.finish(null);
        }
    }

    FileView {
        id: spec_file
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: output_file
        blockLoading: true
        printErrors: false
    }

    Process {
        id: source_proc
        property string key: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, root.source_cache);
                next[source_proc.key] = root.parse_source(text);
                root.source_cache = next;
            }
        }
    }

    Process {
        id: shell_proc
        stdout: StdioCollector {
            onStreamFinished: root.shell_items = text.split("\n").filter(l => l !== "").map(l => ({ label: l, desc: "", insert: l + " " }))
        }
    }

    // Writes the line to result_path (nothing on cancel), then dispatches the callback.
    function finish(result) {
        if (!root.session) return;
        root.session = false;
        root.visible = false;
        if (result !== null && root.spec.result_path)
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\"; exec hyprctl dispatch \"$3\"", "sh", result, root.spec.result_path, root.spec.callback]);
        else
            Quickshell.execDetached(["hyprctl", "dispatch", root.spec.callback]);
    }

    function set_text(text) {
        root.applying = true;
        input.text = text;
        input.cursorPosition = text.length;
        root.applying = false;
    }

    function context_of(line) {
        let head = "";
        let seg = line;
        if (root.spec.chain && !/^(?:!|silent\s+!|%?s\/)/.test(line)) {
            const cut = line.lastIndexOf("|");
            if (cut >= 0) {
                const rest = line.slice(cut + 1);
                const lead = rest.match(/^\s*/)[0];
                head = line.slice(0, cut + 1) + lead;
                seg = rest.slice(lead.length);
            }
        }
        const shell = seg.match(/^((?:silent\s+)?!)(\S*)$/);
        if (shell) return root.spec.shell_source ? { kind: "shell", head: head + shell[1], cur: shell[2] } : { kind: "none" };
        if (/^(?:silent\s+)?!/.test(seg) || /^%?s\//.test(seg)) return { kind: "none" };
        const space = seg.indexOf(" ");
        if (space < 0) return { kind: "command", head: head, cur: seg };
        const words = seg.slice(space + 1).split(/\s+/).filter(w => w !== "");
        const trailing = /\s$/.test(seg);
        const cur = trailing ? "" : words[words.length - 1] || "";
        const pos = trailing ? words.length + 1 : words.length;
        return { kind: "arg", head: head + seg.slice(0, seg.length - cur.length), cmd: seg.slice(0, space), pos: pos, cur: cur, prev: words.slice(0, pos - 1).join(" ") };
    }

    function canonical(cmd) {
        if ((root.spec.args || {})[cmd]) return cmd;
        const entry = (root.spec.completions || []).find(c => (c.aliases || []).indexOf(cmd) >= 0);
        return entry ? entry.name : cmd;
    }

    function arg_spec_for(cmd, pos) {
        const positions = (root.spec.args || {})[root.canonical(cmd)];
        return positions && pos >= 1 && pos <= positions.length ? positions[pos - 1] : null;
    }

    function request_sources() {
        if (!root.session) return;
        if (root.ctx.kind === "shell" && root.shell_items === null && !shell_proc.running) {
            shell_proc.command = ["bash", "-c", root.spec.shell_source];
            shell_proc.running = true;
        }
        const spec = root.arg_spec;
        if (!spec || !spec.source || source_proc.running) return;
        const key = root.canonical(root.ctx.cmd) + "|" + root.ctx.pos + "|" + root.ctx.prev;
        if (root.source_cache[key] !== undefined) return;
        source_proc.key = key;
        source_proc.environment = { HV_ARGS: root.ctx.prev };
        source_proc.command = ["bash", "-c", spec.source];
        source_proc.running = true;
    }

    function parse_source(text) {
        return text.split("\n").map(l => l.split("\t")).filter(f => f[0].trim() !== "").map(f => ({ label: f[0].trim(), desc: f[1] || "", insert: (f[2] || f[0].trim()) + " " }));
    }

    // Name prefix, then name substring, then alias, then description matches, like the terminal bar.
    function rank(list, query) {
        const q = query.toLowerCase();
        const scored = [];
        for (const item of list) {
            const name = item.label.toLowerCase();
            let r = q === "" ? 1 : name.startsWith(q) ? 0 : name.indexOf(q) >= 0 ? 1 : (item.aliases || []).join(" ").toLowerCase().indexOf(q) >= 0 ? 2 : item.desc.toLowerCase().indexOf(q) >= 0 ? 3 : -1;
            if (r >= 0) scored.push({ item: item, r: r });
        }
        scored.sort((a, b) => a.r - b.r);
        return scored.slice(0, 200).map(s => s.item);
    }

    function candidates(ctx, cache, shell_items) {
        if (!root.session || root.is_output) return [];
        if (ctx.kind === "command")
            return root.rank((root.spec.completions || []).map(c => ({ label: c.name, desc: c.desc || "", aliases: c.aliases || [], insert: c.name + (c.takes_args ? " " : "") })), ctx.cur);
        if (ctx.kind === "shell")
            return (shell_items || []).filter(i => i.label.startsWith(ctx.cur)).slice(0, 200);
        const spec = ctx.kind === "arg" ? root.arg_spec_for(ctx.cmd, ctx.pos) : null;
        if (!spec) return [];
        const values = (spec.values || []).map(v => ({ label: v[0], desc: v[1] || "", insert: v[0] + " " }));
        return root.rank(values.concat(cache[root.canonical(ctx.cmd) + "|" + ctx.pos + "|" + ctx.prev] || []), ctx.cur);
    }

    function cycle(delta) {
        const n = root.items.length;
        if (n === 0) return;
        if (root.cycle_base === null && n === 1) {
            root.set_text(root.ctx.head + root.items[0].insert);
            return;
        }
        if (root.cycle_base === null) {
            root.cycle_base = input.text;
            root.selected = delta > 0 ? 0 : n - 1;
        } else {
            root.selected = ((root.selected + delta) % n + n) % n;
        }
        root.menu_hidden = false;
        root.set_text(root.ctx.head + root.items[root.selected].insert);
    }

    function recall(delta) {
        const history = root.spec.history || [];
        if (history.length === 0) return;
        if (root.history_index === -1) {
            if (delta > 0) return;
            root.draft = input.text;
            root.history_index = history.length;
        }
        const next = root.history_index + delta;
        if (next < 0) return;
        root.cycle_base = null;
        root.selected = -1;
        root.menu_hidden = true;
        root.history_index = next >= history.length ? -1 : next;
        root.set_text(next >= history.length ? root.draft : history[next]);
    }

    Rectangle {
        id: panel
        width: parent.width
        height: (root.is_output ? output_label.height + output_view.height + 24 : input_row.height + (hint.visible ? hint.height + 4 : 0) + (menu.visible ? menu.height + 4 : 0) + 16) + 2
        color: root.bg

        Rectangle {
            width: parent.width
            height: 2
            color: root.border_color
        }

        ListView {
            id: menu
            x: 10
            y: 10
            width: parent.width - 20
            height: Math.min(root.items.length, Math.floor(root.screen_height * 0.35 / root.row_height)) * root.row_height
            visible: root.menu_shown
            clip: true
            model: root.menu_shown ? root.items.length : 0
            currentIndex: root.selected
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                id: row
                required property int index
                readonly property var item: root.items[row.index] || ({ label: "", desc: "" })
                width: menu.width
                height: root.row_height
                color: row.index === root.selected ? root.selection : "transparent"

                Text {
                    id: row_label
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(160, menu.width * 0.3)
                    elide: Text.ElideRight
                    text: row.item.label
                    color: row.index === root.selected ? root.secondary : root.fg
                    font.family: root.font_family
                    font.pixelSize: root.font_size
                }

                Text {
                    anchors.left: row_label.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.item.desc
                    color: root.muted
                    font.family: root.font_family
                    font.pixelSize: root.font_size - 1
                }
            }
        }

        Text {
            id: hint
            x: 10
            anchors.bottom: input_row.top
            anchors.bottomMargin: 4
            visible: !root.is_output && !!root.arg_spec && !!root.arg_spec.hint
            text: root.arg_spec && root.arg_spec.hint ? root.ctx.cmd + " arg " + root.ctx.pos + ": " + root.arg_spec.hint : ""
            color: root.muted
            font.family: root.font_family
            font.pixelSize: root.font_size - 1
        }

        Row {
            id: input_row
            x: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: parent.width - 20
            height: root.row_height
            visible: !root.is_output
            spacing: 4

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: root.spec.label || ""
                color: root.primary
                font.family: root.font_family
                font.pixelSize: root.font_size
                font.bold: true
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: input_row.width - label.width - 4
                color: root.fg
                font.family: root.font_family
                font.pixelSize: root.font_size
                onTextChanged: {
                    if (root.applying) return;
                    root.cycle_base = null;
                    root.selected = -1;
                    root.menu_hidden = false;
                    root.history_index = -1;
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const k = event.key;
                    if (k === Qt.Key_Return || k === Qt.Key_Enter) root.finish(input.text);
                    else if (k === Qt.Key_Escape && root.menu_shown) root.menu_hidden = true;
                    else if (k === Qt.Key_Escape) root.finish(null);
                    else if (k === Qt.Key_Tab) root.cycle(1);
                    else if (k === Qt.Key_Backtab) root.cycle(-1);
                    else if (k === Qt.Key_Up || (ctrl && k === Qt.Key_P)) root.recall(-1);
                    else if (k === Qt.Key_Down || (ctrl && k === Qt.Key_N)) root.recall(1);
                    else return;
                    event.accepted = true;
                }
            }
        }

        Text {
            id: output_label
            x: 10
            y: 10
            visible: root.is_output
            text: (root.spec.label || "") + (root.spec.text || "") + "   (Esc/q/Enter close, j/k scroll)"
            color: root.primary
            font.family: root.font_family
            font.pixelSize: root.font_size
            font.bold: true
        }

        Flickable {
            id: output_view
            x: 10
            y: output_label.y + output_label.height + 6
            width: parent.width - 20
            height: Math.min(output.implicitHeight, root.screen_height * 0.45)
            visible: root.is_output
            clip: true
            contentHeight: output.implicitHeight

            Keys.onPressed: event => {
                const k = event.key;
                const step = root.font_size + 4;
                const max = Math.max(0, output_view.contentHeight - output_view.height);
                if (k === Qt.Key_Escape || k === Qt.Key_Q || k === Qt.Key_Return || k === Qt.Key_Enter) root.finish(null);
                else if (k === Qt.Key_J || k === Qt.Key_Down) output_view.contentY = Math.min(max, output_view.contentY + step);
                else if (k === Qt.Key_K || k === Qt.Key_Up) output_view.contentY = Math.max(0, output_view.contentY - step);
                else return;
                event.accepted = true;
            }

            Text {
                id: output
                width: output_view.width
                textFormat: Text.PlainText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: root.fg
                font.family: root.font_family
                font.pixelSize: root.font_size - 1
            }
        }
    }
}
