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
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width:  ApplicationWindow.window.u * 1.2
                    height: titleText.height
                    radius: width / 2
                    color:  ApplicationWindow.window.clrAmber
                }
                Text {
                    id: titleText
                    text:  qsTr("Select a Checklist")
                    color: ApplicationWindow.window.clrInk
                    font { pixelSize: ApplicationWindow.window.u * 5.5; weight: Font.Bold; letterSpacing: -0.5 }
                }
            }

            // ── Language toggle ───────────────────────────────────────────
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: ApplicationWindow.window.u * 1

                Repeater {
                    model: [{ code: "de", label: "DE" }, { code: "en", label: "EN" }]

                    delegate: Rectangle {
                        readonly property bool active: languageManager.language === modelData.code
                        width:  langLabel.implicitWidth + ApplicationWindow.window.u * 4
                        height: ApplicationWindow.window.u * 7
                        radius: ApplicationWindow.window.u * 1.5
                        color:  active
                                    ? ApplicationWindow.window.clrAmber
                                    : (langArea.containsPress ? "#E7E5E0" : "#F0EDE8")
                        border.color: active ? "transparent" : "#D6D3CF"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            id: langLabel
                            anchors.centerIn: parent
                            text:  modelData.label
                            color: active ? "white" : ApplicationWindow.window.clrMuted
                            font { pixelSize: ApplicationWindow.window.u * 3; weight: Font.DemiBold }
                        }
                        MouseArea {
                            id: langArea
                            anchors.fill: parent
                            onClicked: languageManager.setLanguage(modelData.code)
                        }
                    }
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
                    text:  qsTr("Loading…")
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
                    text:  qsTr("No checklists found")
                    color: ApplicationWindow.window.clrMuted
                    font.pixelSize: ApplicationWindow.window.u * 4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  "➡️ " + qsTr("Add .md files to the checklists/ folder")
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
                        text:  qsTr("↺  Refresh")
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
            GridLayout {
                id: tileGrid
                anchors.fill: parent
                visible: !checklistManager.busy && checklistManager.csvFileTitles.length > 0
                columns: Math.min(checklistManager.csvFileTitles.length, 2)
                columnSpacing: ApplicationWindow.window.u * 3
                rowSpacing:    ApplicationWindow.window.u * 3

                Repeater {
                    model: checklistManager.csvFileTitles

                    delegate: Rectangle {
                        // Last item spans both columns when total count is odd
                        readonly property bool isLastOdd:
                            index === checklistManager.csvFileTitles.length - 1 &&
                            checklistManager.csvFileTitles.length % 2 === 1 &&
                            tileGrid.columns === 2

                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        Layout.columnSpan: isLastOdd ? 2 : 1

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
                            anchors {
                                left: parent.left; leftMargin: ApplicationWindow.window.u * 2
                                verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin:  ApplicationWindow.window.u * 5
                                rightMargin: ApplicationWindow.window.u * 2
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
