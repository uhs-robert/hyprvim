pragma ComponentBehavior: Bound
// extras/quickshell/HyprvimWhichKey.qml
// Reference HyprVim which-key HUD for Quickshell: implements the `hyprvim_whichkey` IPC target.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var payload: ({})
    property bool wanted: false
    readonly property var items: root.payload.items || []
    readonly property var footer: root.payload.footer || []
    readonly property var theme: root.payload.theme || {}
    readonly property string position: root.payload.position || "bottom-right"
    readonly property int columns: Math.max(1, Math.min(4, root.payload.columns || 1))

    readonly property color bg: root.theme.bg_core || "#070C13"
    readonly property color border_color: root.theme.bg_border || "#5D8BBB"
    readonly property color fg: root.theme.fg || "#F7EDE1"
    readonly property color primary: root.theme.primary || "#7FA3C9"
    readonly property color secondary: root.theme.secondary || "#D6CE7C"
    readonly property color accent: root.theme.accent || "#FFA0A0"
    readonly property int font_size: parseInt(root.theme.base_font_size) || 12
    property string font_family: "monospace"

    visible: false
    screen: Quickshell.screens.find(s => s.name === root.payload.screen) || (Hyprland.focusedMonitor ? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name) : null) || null
    color: "transparent"
    exclusiveZone: 0
    anchors.top: root.position.startsWith("top")
    anchors.bottom: root.position.startsWith("bottom")
    anchors.left: root.position.endsWith("left")
    anchors.right: root.position.endsWith("right")
    margins.top: 18
    margins.bottom: 18
    margins.left: 18
    margins.right: 18
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight
    mask: Region {}
    WlrLayershell.namespace: "hyprvim-whichkey"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    IpcHandler {
        target: "hyprvim_whichkey"

        function open(path: string): void {
            root.wanted = true;
            payload_file.path = path;
            payload_file.reload();
        }

        function close(): void {
            root.wanted = false;
            root.visible = false;
        }
    }

    FileView {
        id: payload_file
        printErrors: false
        onLoaded: {
            if (!root.wanted) return;
            try {
                root.payload = JSON.parse(text());
                root.visible = root.items.length > 0;
            } catch (e) {
                console.warn("hyprvim_whichkey: invalid payload (" + e + ")");
            }
        }
    }

    Rectangle {
        id: panel
        implicitWidth: body.implicitWidth + 20
        implicitHeight: body.implicitHeight + 16
        radius: 6
        color: root.bg
        border.width: 2
        border.color: root.border_color

        ColumnLayout {
            id: body
            x: 10
            y: 8
            spacing: 6

            Text {
                text: root.payload.title || ""
                color: root.primary
                font.family: root.font_family
                font.pixelSize: root.font_size + 1
                font.bold: true
            }

            GridLayout {
                columns: root.columns
                columnSpacing: 20
                rowSpacing: 2

                Repeater {
                    model: root.items

                    RowLayout {
                        id: item_row
                        required property var modelData
                        spacing: 6

                        Text {
                            text: item_row.modelData.key
                            color: root.secondary
                            font.family: root.font_family
                            font.pixelSize: root.font_size
                            font.bold: true
                        }

                        Text {
                            text: item_row.modelData.desc
                            color: item_row.modelData.group ? root.accent : root.fg
                            font.family: root.font_family
                            font.pixelSize: root.font_size
                        }
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Repeater {
                    model: root.footer

                    Text {
                        id: footer_text
                        required property var modelData
                        text: footer_text.modelData.key + " " + footer_text.modelData.desc
                        color: root.primary
                        font.family: root.font_family
                        font.pixelSize: root.font_size - 1
                    }
                }
            }
        }
    }
}
