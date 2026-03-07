import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: root
    visible: true
    width: 800
    height: 480
    title: "Checklist"

    // ── Design tokens ────────────────────────────────────────────────────
    readonly property color clrBg:        "#FAFAF7"  // warm paper
    readonly property color clrSurface:   "#FFFFFF"
    readonly property color clrInk:       "#1A1714"  // warm near-black
    readonly property color clrMuted:     "#78716C"  // warm gray
    readonly property color clrAmber:     "#D97706"  // primary accent
    readonly property color clrAmberDark: "#92400E"
    readonly property color clrGreen:     "#15803D"  // timer
    readonly property color clrGreenBg:   "#DCFCE7"
    readonly property color clrRed:       "#DC2626"  // exit / danger

    // Responsive base unit: 1% of the smaller screen dimension
    readonly property real u: Math.min(width, height) * 0.01

    color: clrBg

    // ── Fonts ────────────────────────────────────────────────────────────
    FontLoader { id: fontBody; source: "qrc:/fonts/placeholder" }  // falls back to system

    // ── Screen state ─────────────────────────────────────────────────────
    StackView {
        id: stack
        anchors.fill: parent

        initialItem: loadingComponent

        pushEnter:  Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
        pushExit:   Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
        popEnter:   Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
        popExit:    Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
    }

    Component {
        id: loadingComponent
        LoadingScreen {
            onChecklistSelected: function(path) {
                checklistManager.loadCsv(path)
                stack.push(checklistComponent)
            }
        }
    }

    Component {
        id: checklistComponent
        ChecklistScreen {
            onExitRequested: {
                checklistManager.exitList()
                stack.pop()
            }
        }
    }
}
