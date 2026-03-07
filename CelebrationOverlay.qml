import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
// CelebrationOverlay
//
// Three-act celebration played within the parent's bounds:
//   Act 1 (0–720 ms)   – Checkmark draws itself
//   Act 2 (800 ms +)   – Rings burst, ribbons fall, sparks shoot
//   Act 3 (~2900 ms)   – Everything fades, finished() emitted
//
// Usage:
//   CelebrationOverlay { id: cel; anchors.fill: parent; z: 10 }
//   cel.play()
//   cel.onFinished: { … }
//
// Pi 4 budget: 18 simple Items, no shaders, no particles, no overdraw layers.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    // ── Public API ───────────────────────────────────────────────────────────
    signal finished()

    function play() {
        root.visible    = true
        overlayBg.opacity = 0.96
        checkCanvas.opacity = 1
        root.checkProgress  = 0
        checkCanvas.requestPaint()
        masterAnim.restart()
    }

    visible: false

    // ── Internal phase trigger ───────────────────────────────────────────────
    // Emitted by the master sequencer to kick off Act 2 animations in delegates
    signal _phase2()

    // ── Design tokens (fall back to ApplicationWindow if available) ──────────
    readonly property color clrBg:     "#F5F3EF"
    readonly property color clrGreen:  "#15803D"
    readonly property color clrAmber:  "#D97706"
    readonly property color clrRed:    "#DC2626"
    readonly property color clrPurple: "#7C3AED"
    readonly property color clrBlue:   "#0891B2"

    // ── Background ───────────────────────────────────────────────────────────
    Rectangle {
        id: overlayBg
        anchors.fill: parent
        color:  root.clrBg
        opacity: 0.96
    }

    // ════════════════════════════════════════════════════════════════════════
    // ACT 1 — Checkmark draws itself
    // ════════════════════════════════════════════════════════════════════════
    property real checkProgress: 0
    onCheckProgressChanged: checkCanvas.requestPaint()

    Canvas {
        id: checkCanvas
        anchors.centerIn: parent
        width:  Math.min(root.width, root.height) * 0.36
        height: width

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var w = width, h = height
            var t = root.checkProgress
            if (t <= 0) return

            // Three control points of the ✓ shape
            var p0x = w * 0.16,  p0y = h * 0.54
            var p1x = w * 0.40,  p1y = h * 0.76
            var p2x = w * 0.84,  p2y = h * 0.26

            var dx1 = p1x - p0x,  dy1 = p1y - p0y
            var dx2 = p2x - p1x,  dy2 = p2y - p1y
            var L1  = Math.sqrt(dx1*dx1 + dy1*dy1)
            var L2  = Math.sqrt(dx2*dx2 + dy2*dy2)
            var drawn = t * (L1 + L2)

            ctx.beginPath()
            ctx.strokeStyle = root.clrGreen
            ctx.lineWidth   = w * 0.09
            ctx.lineCap     = "round"
            ctx.lineJoin    = "round"

            ctx.moveTo(p0x, p0y)

            if (drawn <= L1) {
                var f1 = drawn / L1
                ctx.lineTo(p0x + f1 * dx1,  p0y + f1 * dy1)
            } else {
                ctx.lineTo(p1x, p1y)
                var f2 = (drawn - L1) / L2
                ctx.lineTo(p1x + f2 * dx2,  p1y + f2 * dy2)
            }

            ctx.stroke()
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // ACT 2-A — Rings burst from center
    // 4 concentric border-rings, staggered 120 ms apart
    // ════════════════════════════════════════════════════════════════════════
    Repeater {
        model: [
            { color: "#D97706", delay:   0, size: 0.55 },
            { color: "#15803D", delay: 120, size: 0.65 },
            { color: "#7C3AED", delay: 240, size: 0.75 },
            { color: "#D97706", delay: 360, size: 0.50 },
        ]

        delegate: Rectangle {
            id: ring
            anchors.centerIn: parent
            width:   Math.min(root.width, root.height) * modelData.size
            height:  width
            radius:  width / 2
            color:   "transparent"
            border.color: modelData.color
            border.width: Math.max(2, root.width * 0.008)

            property real sc: 0.05
            property real op: 0
            scale:   sc
            opacity: op

            SequentialAnimation {
                id: ringAnim
                running: false
                PauseAnimation { duration: modelData.delay }
                ParallelAnimation {
                    NumberAnimation {
                        target: ring; property: "sc"
                        from: 0.05; to: 2.2
                        duration: 900; easing.type: Easing.OutCubic
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: ring; property: "op"
                            from: 0.85; to: 0.85; duration: 80
                        }
                        NumberAnimation {
                            target: ring; property: "op"
                            from: 0.85; to: 0
                            duration: 820; easing.type: Easing.InCubic
                        }
                    }
                }
            }

            Connections {
                target: root
                function on_Phase2() { ringAnim.restart() }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // ACT 2-B — Confetti ribbons fall from above
    // 8 rounded rectangles, staggered starts, rotated at different angles
    // ════════════════════════════════════════════════════════════════════════
    Repeater {
        model: [
            { xf:0.08, delay: 20,  color:"#D97706", angle:-22, wf:0.040, hf:0.130 },
            { xf:0.22, delay:110,  color:"#15803D", angle: 32, wf:0.030, hf:0.110 },
            { xf:0.38, delay: 55,  color:"#DC2626", angle: -8, wf:0.050, hf:0.090 },
            { xf:0.53, delay:165,  color:"#7C3AED", angle: 18, wf:0.030, hf:0.130 },
            { xf:0.67, delay: 80,  color:"#D97706", angle:-28, wf:0.040, hf:0.100 },
            { xf:0.81, delay:200,  color:"#0891B2", angle: 12, wf:0.030, hf:0.120 },
            { xf:0.16, delay:130,  color:"#15803D", angle: 38, wf:0.040, hf:0.090 },
            { xf:0.60, delay: 65,  color:"#DC2626", angle:-14, wf:0.035, hf:0.110 },
        ]

        delegate: Item {
            id: ribbon
            width:    root.width  * modelData.wf
            height:   root.height * modelData.hf
            x:        root.width  * modelData.xf - width / 2
            y:        -height * 2                              // start above the area
            rotation: modelData.angle
            opacity:  0

            Rectangle {
                anchors.fill: parent
                radius: width * 0.35
                color:  modelData.color
            }

            SequentialAnimation {
                id: ribbonAnim
                running: false
                PauseAnimation { duration: modelData.delay }
                ParallelAnimation {
                    NumberAnimation {
                        target: ribbon; property: "y"
                        to: root.height + ribbon.height
                        duration: 1600; easing.type: Easing.InCubic
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: ribbon; property: "opacity"
                            from: 0; to: 1; duration: 150
                        }
                        PauseAnimation  { duration: 1000 }
                        NumberAnimation {
                            target: ribbon; property: "opacity"
                            from: 1; to: 0; duration: 450
                        }
                    }
                }
            }

            Connections {
                target: root
                function on_Phase2() {
                    ribbon.y       = -ribbon.height * 2
                    ribbon.opacity = 0
                    ribbonAnim.restart()
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // ACT 2-C — Sparks shoot outward from center
    // 6 elongated pills at 60° intervals (math angles 30, 90, 150, 210, 270, 330)
    // Screen Y is inverted, so endY = centerY - sin(angle)*dist
    // ════════════════════════════════════════════════════════════════════════
    Repeater {
        model: [
            { color:"#D97706", angleDeg: 30,  delay:  0 },
            { color:"#15803D", angleDeg: 90,  delay: 60 },
            { color:"#DC2626", angleDeg:150,  delay: 30 },
            { color:"#7C3AED", angleDeg:210,  delay: 80 },
            { color:"#0891B2", angleDeg:270,  delay: 20 },
            { color:"#D97706", angleDeg:330,  delay: 50 },
        ]

        delegate: Item {
            id: spark
            width:  Math.max(5,  root.width  * 0.022)
            height: Math.max(14, root.height * 0.060)

            property real rad:    modelData.angleDeg * Math.PI / 180
            property real dist:   Math.min(root.width, root.height) * 0.37
            property real startX: root.width  / 2 - width  / 2
            property real startY: root.height / 2 - height / 2
            property real endX:   startX + Math.cos(rad) * dist
            property real endY:   startY - Math.sin(rad) * dist   // invert Y

            x: startX;  y: startY
            opacity: 0

            Rectangle {
                anchors.fill: parent
                radius: width * 0.45
                color:  modelData.color
            }

            SequentialAnimation {
                id: sparkAnim
                running: false
                PauseAnimation { duration: modelData.delay }
                ParallelAnimation {
                    NumberAnimation {
                        target: spark; property: "x"
                        from: spark.startX;  to: spark.endX
                        duration: 1100;  easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: spark; property: "y"
                        from: spark.startY;  to: spark.endY
                        duration: 1100;  easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: spark; property: "rotation"
                        from: 0
                        to:   modelData.angleDeg > 180 ? -300 : 300
                        duration: 1100
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: spark; property: "opacity"
                            from: 0; to: 1; duration: 100
                        }
                        PauseAnimation  { duration: 700 }
                        NumberAnimation {
                            target: spark; property: "opacity"
                            from: 1; to: 0; duration: 300
                        }
                    }
                }
            }

            Connections {
                target: root
                function on_Phase2() {
                    spark.x        = spark.startX
                    spark.y        = spark.startY
                    spark.opacity  = 0
                    spark.rotation = 0
                    sparkAnim.restart()
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // Master sequencer
    // ════════════════════════════════════════════════════════════════════════
    SequentialAnimation {
        id: masterAnim
        running: false

        // Act 1: checkmark draws
        NumberAnimation {
            target: root; property: "checkProgress"
            from: 0; to: 1
            duration: 720; easing.type: Easing.InOutCubic
        }

        // Brief pause for the checkmark to "land"
        PauseAnimation { duration: 80 }

        // Act 2: trigger all burst animations via signal
        ScriptAction { script: root._phase2() }

        // Hold while everything plays out
        PauseAnimation { duration: 2100 }

        // Act 3: fade the overlay away
        ParallelAnimation {
            NumberAnimation {
                target: overlayBg; property: "opacity"
                to: 0; duration: 520; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: checkCanvas; property: "opacity"
                to: 0; duration: 420; easing.type: Easing.InCubic
            }
        }

        // Done — hide and notify parent
        ScriptAction {
            script: {
                root.visible = false
                root.finished()
            }
        }
    }
}
