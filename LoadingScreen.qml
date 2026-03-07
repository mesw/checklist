import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal checklistSelected(string path)

    Rectangle { anchors.fill: parent; color: ApplicationWindow.window.clrBg }

    ColumnLayout {
        anchors { fill: parent; margins: ApplicationWindow.window.u * 4 }
        spacing: ApplicationWindow.window.u * 3

        // ── Title row ────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height: titleText.height

            Row {
                spacing: ApplicationWindow.window.u * 2

                Rectangle {
                    width:  ApplicationWindow.window.u * 1.2
                    height: titleText.height
                    radius: width / 2
                    color:  ApplicationWindow.window.clrAmber
                }
                Text {
                    id: titleText
                    text:  "Select a Checklist"
                    color: ApplicationWindow.window.clrInk
                    font { pixelSize: ApplicationWindow.window.u * 5.5; weight: Font.Bold; letterSpacing: -0.5 }
                }
            }
        }

        // ── Content area ─────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Busy / loading state ──────────────────────────────────────
            Column {
                anchors.centerIn: parent
                spacing: ApplicationWindow.window.u * 3
                visible: checklistManager.busy

                BusyIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    running: checklistManager.busy
                    width:  ApplicationWindow.window.u * 10
                    height: width
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  "Loading…"
                    color: ApplicationWindow.window.clrMuted
                    font.pixelSize: ApplicationWindow.window.u * 3.5
                }
            }

            // ── Empty state ───────────────────────────────────────────────
            Column {
                anchors.centerIn: parent
                spacing: ApplicationWindow.window.u * 2
                visible: !checklistManager.busy && checklistManager.csvFilePaths.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  "No checklists found"
                    color: ApplicationWindow.window.clrMuted
                    font.pixelSize: ApplicationWindow.window.u * 4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  "➡️ Add .csv files to the checklists/ folder"
                    color: ApplicationWindow.window.clrMuted
                    font.pixelSize: ApplicationWindow.window.u * 3
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:  refreshLbl.implicitWidth + ApplicationWindow.window.u * 8
                    height: ApplicationWindow.window.u * 9
                    radius: ApplicationWindow.window.u * 2
                    color:  refreshArea.containsPress
                                ? ApplicationWindow.window.clrAmberDark
                                : ApplicationWindow.window.clrAmber

                    Text {
                        id: refreshLbl
                        anchors.centerIn: parent
                        text:  "↺  Refresh"
                        color: "white"
                        font { pixelSize: ApplicationWindow.window.u * 3.5; weight: Font.DemiBold }
                    }
                    MouseArea {
                        id: refreshArea; anchors.fill: parent
                        onClicked: checklistManager.refreshCsvList()
                    }
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            // ── Tile grid ─────────────────────────────────────────────────
            ScrollView {
                anchors.fill: parent
                visible: !checklistManager.busy && checklistManager.csvFilePaths.length > 0
                clip: true

                Flow {
                    width: parent.width
                    spacing: ApplicationWindow.window.u * 3

                    Repeater {
                        model: checklistManager.csvFileNames

                        delegate: Rectangle {
                            // Fit up to 3 tiles per row with gutters
                            readonly property int cols: Math.min(checklistManager.csvFileNames.length, 3)
                            width:  (root.width
                                     - ApplicationWindow.window.u * 8
                                     - ApplicationWindow.window.u * 3 * (cols - 1)) / cols
                            height: ApplicationWindow.window.u * 18
                            radius: ApplicationWindow.window.u * 2.5
                            color:  tileArea.containsPress
                                        ? ApplicationWindow.window.clrAmber
                                        : ApplicationWindow.window.clrSurface

                            // Left accent stripe
                            Rectangle {
                                width:  ApplicationWindow.window.u * 0.8
                                height: parent.height * 0.5
                                radius: width / 2
                                color:  tileArea.containsPress ? "white" : ApplicationWindow.window.clrAmber
                                anchors { left: parent.left; leftMargin: ApplicationWindow.window.u * 2; verticalCenter: parent.verticalCenter }
                            }

                            Text {
                                anchors {
                                    left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                    leftMargin: ApplicationWindow.window.u * 5; rightMargin: ApplicationWindow.window.u * 2
                                }
                                text:  modelData
                                color: tileArea.containsPress ? "white" : ApplicationWindow.window.clrInk
                                font { pixelSize: ApplicationWindow.window.u * 4; weight: Font.DemiBold }
                                elide: Text.ElideRight; wrapMode: Text.WordWrap; maximumLineCount: 3
                            }

                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: "transparent"
                                border.color: tileArea.containsPress ? "transparent" : "#E7E5E0"
                                border.width: 1
                            }

                            MouseArea {
                                id: tileArea; anchors.fill: parent
                                onClicked: root.checklistSelected(checklistManager.csvFilePaths[index])
                            }
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                    }
                }
            }
        }
    }
}
