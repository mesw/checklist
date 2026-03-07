import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal exitRequested()

    // ── Step-level mutable state ─────────────────────────────────────────────
    property int  remainingSeconds:   0
    property bool autoProceedEnabled: false

    // ── Sync state on every step change ─────────────────────────────────────
    function resetStep() {
        countdownTimer.stop()
        remainingSeconds   = checklistManager.currentTimerSecs
        autoProceedEnabled = checklistManager.currentAutoProceed
        if (remainingSeconds > 0)
            countdownTimer.start()
        orbitLayer.reset()
    }

    Connections {
        target: checklistManager
        function onCurrentIndexChanged() { root.resetStep() }
        function onListLoadedChanged()   { root.resetStep() }
    }

    Component.onCompleted: root.resetStep()

    // ── Countdown timer ──────────────────────────────────────────────────────
    Timer {
        id: countdownTimer
        interval: 1000
        repeat:   true
        onTriggered: {
            if (root.remainingSeconds > 1) {
                root.remainingSeconds--
            } else {
                root.remainingSeconds = 0
                stop()
                if (root.autoProceedEnabled) {
                    if (checklistManager.hasNext)
                        checklistManager.next()
                    else
                        celebrationOverlay.play()
                }
            }
        }
    }

    // ── Markdown → HTML helper ───────────────────────────────────────────────
    // Handles: \n (literal), <br>, **bold**, *italic*
    // Emojis pass through unchanged under Text.RichText.
    function mdToHtml(src) {
        if (!src) return ""
        var s = src
        s = s.replace(/\\n/g,         "<br>")
        s = s.replace(/<br\s*\/?>/gi, "<br>")
        s = s.replace(/\*\*([\s\S]*?)\*\*/g, "<b>$1</b>")
        s = s.replace(/\*([\s\S]*?)\*/g,     "<i>$1</i>")
        return s
    }

    // ── Background ───────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: ApplicationWindow.window.clrBg }

    // ════════════════════════════════════════════════════════════════════════
    // OUTER LAYOUT
    // ════════════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors { fill: parent; margins: ApplicationWindow.window.u * 3 }
        spacing: 0

        // ── HEADER ───────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height: ApplicationWindow.window.u * 10

            // Exit (×) button
            Rectangle {
                id: exitBtn
                width: height; height: ApplicationWindow.window.u * 8
                radius: height / 2
                color:  exitArea.containsPress ? "#FEE2E2" : "#FFF1F2"
                border.color: exitArea.containsPress
                              ? ApplicationWindow.window.clrRed : "#FECACA"
                border.width: 1
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                Text {
                    anchors.centerIn: parent
                    text: "✕"; color: ApplicationWindow.window.clrRed
                    font { pixelSize: ApplicationWindow.window.u * 3.5; weight: Font.DemiBold }
                }
                MouseArea { id: exitArea; anchors.fill: parent; onClicked: root.exitRequested() }
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            // Checklist title — small, centered between exit and step counter
            Text {
                anchors {
                    left: exitBtn.right;    leftMargin:  ApplicationWindow.window.u * 2
                    right: stepCounter.left; rightMargin: ApplicationWindow.window.u * 2
                    verticalCenter: parent.verticalCenter
                }
                text:  checklistManager.listTitle
                color: ApplicationWindow.window.clrMuted
                font {
                    pixelSize:    ApplicationWindow.window.u * 2.8
                    weight:       Font.Medium
                    letterSpacing: 0.4
                }
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // Step counter  "3 / 10"
            Row {
                id: stepCounter
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: ApplicationWindow.window.u * 0.5

                Text {
                    text: (checklistManager.currentIndex + 1).toString()
                    color: ApplicationWindow.window.clrAmber
                    font { pixelSize: ApplicationWindow.window.u * 4.5; weight: Font.Bold }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: " / "
                    color: ApplicationWindow.window.clrMuted
                    font.pixelSize: ApplicationWindow.window.u * 3.5
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: checklistManager.totalItems.toString()
                    color: ApplicationWindow.window.clrMuted
                    font { pixelSize: ApplicationWindow.window.u * 4.5; weight: Font.Medium }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Progress bar (anchored below title text)
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    left:  exitBtn.right; leftMargin:  ApplicationWindow.window.u * 3
                    right: parent.right;  rightMargin: ApplicationWindow.window.u * 0
                }
                height: ApplicationWindow.window.u * 0.7
                radius: height / 2
                color:  "#E7E5E0"

                Rectangle {
                    width: parent.width * (checklistManager.totalItems > 0
                        ? (checklistManager.currentIndex + 1) / checklistManager.totalItems : 0)
                    height: parent.height; radius: parent.radius
                    color:  ApplicationWindow.window.clrAmber
                    Behavior on width {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        // ── CONTENT AREA ─────────────────────────────────────────────────────
        // Orbit layer and celebration overlay are siblings to the content
        // ColumnLayout, layered above it via z.
        Item {
            id: contentArea
            Layout.fillWidth:  true
            Layout.fillHeight: true
            Layout.topMargin:  ApplicationWindow.window.u * 2

            // ── Content column ────────────────────────────────────────────
            ColumnLayout {
                anchors {
                    fill: parent
                    topMargin:    ApplicationWindow.window.u * 1
                    bottomMargin: ApplicationWindow.window.u * 1
                }
                spacing: ApplicationWindow.window.u * 2

                // Image (hidden when empty)
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.maximumHeight: root.height * 0.40
                    visible: checklistManager.currentImageUrl !== ""

                    Image {
                        anchors.centerIn: parent
                        width:  Math.min(parent.width, parent.height * 1.8)
                        height: parent.height
                        source: checklistManager.currentImageUrl
                        fillMode: Image.PreserveAspectFit
                        smooth: true; asynchronous: true
                        opacity: status === Image.Ready ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }

                // Step text — markdown rendered as HTML, centered
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: checklistManager.currentImageUrl === ""
                    Layout.preferredHeight: stepText.implicitHeight + ApplicationWindow.window.u * 2

                    Text {
                        id: stepText
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: checklistManager.currentImageUrl === ""
                                            ? parent.verticalCenter : undefined
                            top: checklistManager.currentImageUrl !== "" ? parent.top : undefined
                        }
                        text:       root.mdToHtml(checklistManager.currentText)
                        textFormat: Text.RichText
                        color:      ApplicationWindow.window.clrInk
                        font {
                            pixelSize: checklistManager.currentImageUrl === ""
                                       ? ApplicationWindow.window.u * 5.5
                                       : ApplicationWindow.window.u * 4.5
                            weight:       Font.Medium
                            letterSpacing: -0.3
                        }
                        wrapMode:            Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight:          1.30
                    }
                }

                // Timer badge + auto-proceed toggle (only when step has a timer)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: checklistManager.currentTimerSecs > 0
                                            ? ApplicationWindow.window.u * 12 : 0
                    visible: checklistManager.currentTimerSecs > 0

                    Row {
                        anchors.centerIn: parent
                        spacing: ApplicationWindow.window.u * 2.5

                        // ── Timer badge ────────────────────────────────────
                        Rectangle {
                            width:  timerInner.implicitWidth + ApplicationWindow.window.u * 6
                            height: ApplicationWindow.window.u * 10
                            radius: height / 2
                            color:  root.remainingSeconds > 0
                                        ? ApplicationWindow.window.clrGreenBg : "#F0EDE8"
                            border.color: root.remainingSeconds > 0
                                              ? ApplicationWindow.window.clrGreen : "#D6D3CF"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 400 } }

                            Row {
                                id: timerInner
                                anchors.centerIn: parent
                                spacing: ApplicationWindow.window.u * 1.5

                                Text {
                                    text: "⏱"
                                    font.pixelSize: ApplicationWindow.window.u * 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.remainingSeconds > 0
                                               ? ApplicationWindow.window.clrGreen
                                               : ApplicationWindow.window.clrMuted
                                }
                                Text {
                                    text: {
                                        const s = root.remainingSeconds
                                        const m = Math.floor(s / 60)
                                        const r = s % 60
                                        return m > 0
                                            ? m + ":" + (r < 10 ? "0" : "") + r
                                            : s.toString()
                                    }
                                    color: root.remainingSeconds > 0
                                               ? ApplicationWindow.window.clrGreen
                                               : ApplicationWindow.window.clrMuted
                                    font {
                                        pixelSize: ApplicationWindow.window.u * 4.5
                                        weight: Font.Bold; family: "monospace"
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }
                            }
                        }

                        // ── Auto-proceed toggle ────────────────────────────
                        // Shown only when there is a timer; user can tap to toggle.
                        Rectangle {
                            width:  autoInner.implicitWidth + ApplicationWindow.window.u * 5
                            height: ApplicationWindow.window.u * 10
                            radius: height / 2
                            color:  root.autoProceedEnabled
                                        ? ApplicationWindow.window.clrGreenBg : "#F0EDE8"
                            border.color: root.autoProceedEnabled
                                              ? ApplicationWindow.window.clrGreen : "#D6D3CF"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Row {
                                id: autoInner
                                anchors.centerIn: parent
                                spacing: ApplicationWindow.window.u * 1.5

                                // Checkbox box
                                Rectangle {
                                    id: checkBox
                                    width:  ApplicationWindow.window.u * 4.2
                                    height: width
                                    radius: ApplicationWindow.window.u * 0.9
                                    color:  root.autoProceedEnabled
                                                ? ApplicationWindow.window.clrGreen : "white"
                                    border.color: root.autoProceedEnabled
                                                      ? ApplicationWindow.window.clrGreen : "#A8A29E"
                                    border.width: Math.max(1, ApplicationWindow.window.u * 0.3)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text:    "✓"
                                        color:   "white"
                                        font {
                                            pixelSize: parent.width * 0.68
                                            weight:    Font.Bold
                                        }
                                        visible: root.autoProceedEnabled
                                    }
                                }

                                Text {
                                    text:  "auto"
                                    color: root.autoProceedEnabled
                                               ? ApplicationWindow.window.clrGreen
                                               : ApplicationWindow.window.clrMuted
                                    font { pixelSize: ApplicationWindow.window.u * 3.2; weight: Font.DemiBold }
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.autoProceedEnabled = !root.autoProceedEnabled
                            }
                        }
                    }
                }
            } // end content ColumnLayout

            // ════════════════════════════════════════════════════════════════
            // ORBITAL EMOJI LAYER
            // Sits above content (z:5), clipped to contentArea.
            // Appears 30 s after step loads; gains one extra emoji per minute.
            // Orbits clockwise on an ellipse spanning most of contentArea.
            // ════════════════════════════════════════════════════════════════
            Item {
                id: orbitLayer
                anchors.fill: parent
                z: 5

                // ── Geometry ───────────────────────────────────────────────
                readonly property real emojiPx: ApplicationWindow.window.u * 6
                readonly property real cx: width  / 2
                readonly property real cy: height / 2
                // Ellipse stays within bounds with a margin of ~1 emoji-diameter
                readonly property real rx: Math.max(0, (width  - emojiPx * 2.4) / 2)
                readonly property real ry: Math.max(0, (height - emojiPx * 2.4) / 2)

                // ── State ──────────────────────────────────────────────────
                property real orbitAngle: 0.0   // radians; increases → clockwise on screen
                property int  emojiCount: 0

                // ── Reset (called on every step change) ────────────────────
                function reset() {
                    orbitAngle = 0.0
                    emojiCount = 0
                    orbitMotionTimer.stop()
                    orbitCountTimer.stop()
                    orbitCountTimer.elapsed = 0
                    if (checklistManager.currentEmoji !== "")
                        orbitCountTimer.start()
                }

                // ── Motion: 1 revolution per 60 s at 20 fps ───────────────
                // In screen coords (y-down): x = cx + rx·cos(θ), y = cy + ry·sin(θ)
                // Increasing θ → clockwise. ✓
                Timer {
                    id: orbitMotionTimer
                    interval: 50     // 20 fps
                    repeat:   true
                    running:  orbitLayer.emojiCount > 0
                    onTriggered: {
                        orbitLayer.orbitAngle += (Math.PI * 2) / (60 * 20)
                        if (orbitLayer.orbitAngle >= Math.PI * 2)
                            orbitLayer.orbitAngle -= Math.PI * 2
                    }
                }

                // ── Count: +1 at 30 s, then +1 every 60 s ─────────────────
                Timer {
                    id: orbitCountTimer
                    interval: 1000
                    repeat:   true
                    property int elapsed: 0
                    onTriggered: {
                        elapsed++
                        if (elapsed === 30)
                            orbitLayer.emojiCount = 1
                        else if (elapsed > 30 && (elapsed - 30) % 60 === 0)
                            orbitLayer.emojiCount++
                    }
                }

                // ── Emoji delegates (max 8) ────────────────────────────────
                // Each is evenly distributed around the orbit angle.
                // When count changes, distribution adjusts on the next frame —
                // the gradual repositioning as they orbit looks natural.
                Repeater {
                    model: 8
                    delegate: Text {
                        visible:        index < orbitLayer.emojiCount
                        text:           checklistManager.currentEmoji
                        font.pixelSize: orbitLayer.emojiPx

                        // Angle for this emoji in the current formation
                        property real myAngle: orbitLayer.orbitAngle
                            + index * (Math.PI * 2 / Math.max(1, orbitLayer.emojiCount))

                        x: orbitLayer.cx + orbitLayer.rx * Math.cos(myAngle) - implicitWidth  / 2
                        y: orbitLayer.cy + orbitLayer.ry * Math.sin(myAngle) - implicitHeight / 2

                        // Gentle fade-in when a new emoji appears
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 600 } }
                    }
                }
            } // end orbitLayer

            // ── Celebration overlay (above everything in contentArea) ────────
            CelebrationOverlay {
                id: celebrationOverlay
                anchors.fill: parent
                z: 10
                onFinished: { /* user exits via ✕ when ready */ }
            }

        } // end contentArea

        // ── NAVIGATION ───────────────────────────────────────────────────────
        //
        //  Back   – visible when hasPrev  (always has a partner → always half-width)
        //  Next   – visible when  hasNext (full if alone, half if Back visible)
        //  Finish – visible when !hasNext (full if alone, half if Back visible)
        //  Next and Finish are mutually exclusive.
        //
        Item {
            Layout.fillWidth: true
            height: ApplicationWindow.window.u * 13

            Row {
                anchors.fill: parent
                spacing:      ApplicationWindow.window.u * 3

                // Back
                Rectangle {
                    visible: checklistManager.hasPrev
                    width:  (parent.width - parent.spacing) / 2
                    height: parent.height
                    radius: ApplicationWindow.window.u * 2
                    color:  backArea.containsPress ? "#E7E5E0" : "#F0EDE8"
                    border.color: backArea.containsPress ? "#A8A29E" : "#D6D3CF"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "← Back"; color: ApplicationWindow.window.clrMuted
                        font { pixelSize: ApplicationWindow.window.u * 4; weight: Font.DemiBold }
                    }
                    MouseArea {
                        id: backArea; anchors.fill: parent
                        onClicked: checklistManager.back()
                    }
                    Behavior on color { ColorAnimation { duration: 80 } }
                }

                // Next
                Rectangle {
                    visible: checklistManager.hasNext
                    width:  checklistManager.hasPrev
                            ? (parent.width - parent.spacing) / 2
                            : parent.width
                    height: parent.height
                    radius: ApplicationWindow.window.u * 2
                    color:  nextArea.containsPress
                            ? ApplicationWindow.window.clrAmberDark
                            : ApplicationWindow.window.clrAmber

                    Text {
                        anchors.centerIn: parent
                        text: "Next →"; color: "white"
                        font { pixelSize: ApplicationWindow.window.u * 4; weight: Font.Bold }
                    }
                    MouseArea {
                        id: nextArea; anchors.fill: parent
                        onClicked: checklistManager.next()
                    }
                    Behavior on color { ColorAnimation { duration: 80 } }
                }

                // Finish ✓  (last step only)
                Rectangle {
                    visible: !checklistManager.hasNext
                    width:  checklistManager.hasPrev
                            ? (parent.width - parent.spacing) / 2
                            : parent.width
                    height: parent.height
                    radius: ApplicationWindow.window.u * 2
                    color:  finishArea.containsPress ? "#166534" : "#15803D"

                    Row {
                        anchors.centerIn: parent
                        spacing: ApplicationWindow.window.u * 1.5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Finish"; color: "white"
                            font { pixelSize: ApplicationWindow.window.u * 4; weight: Font.Bold }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✓"; color: "white"
                            font { pixelSize: ApplicationWindow.window.u * 4.5; weight: Font.Bold }
                        }
                    }
                    MouseArea {
                        id: finishArea; anchors.fill: parent
                        onClicked: celebrationOverlay.play()
                    }
                    Behavior on color { ColorAnimation { duration: 80 } }
                }
            }
        }

    } // end outer ColumnLayout
}
