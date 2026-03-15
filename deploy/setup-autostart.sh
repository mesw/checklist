#!/usr/bin/env bash
# setup-autostart.sh — builds the checklist app and installs a systemd service
# that starts it automatically on boot (full-screen, no desktop compositor).
#
# Run from the repository root:
#   deploy/setup-autostart.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO_DIR/build/release"
BINARY="$BUILD_DIR/checklist"
SERVICE_NAME="checklist"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
RUN_USER="$USER"

# ── 1. Build ──────────────────────────────────────────────────────────────────
echo "==> Configuring..."
cmake -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    "$REPO_DIR"

echo "==> Building..."
cmake --build "$BUILD_DIR"

# ── 2. Install systemd service ────────────────────────────────────────────────
echo "==> Installing systemd service as $SERVICE_FILE ..."

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Checklist App
After=local-fs.target

[Service]
User=$RUN_USER
WorkingDirectory=$BUILD_DIR
ExecStart=$BINARY -platform eglfs
Restart=on-failure
RestartSec=3

# Direct framebuffer access (eglfs requires these)
Environment=QT_QPA_PLATFORM=eglfs
Environment=QT_QPA_EGLFS_ALWAYS_SET_MODE=1

# Suppress Qt's "cannot connect to X server" noise
Environment=DISPLAY=

[Install]
WantedBy=multi-user.target
EOF

# ── 3. Enable and start ───────────────────────────────────────────────────────
echo "==> Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo ""
echo "Done. The app will now start automatically on boot."
echo ""
echo "Useful commands:"
echo "  sudo systemctl status  $SERVICE_NAME   # check status"
echo "  sudo systemctl stop    $SERVICE_NAME   # stop"
echo "  sudo systemctl disable $SERVICE_NAME   # remove autostart"
echo "  sudo journalctl -u     $SERVICE_NAME   # view logs"
