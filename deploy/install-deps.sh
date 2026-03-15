#!/usr/bin/env bash
# install-deps.sh — installs Qt 6 build dependencies on Raspberry Pi OS Trixie (Debian 13)
set -euo pipefail

echo "==> Updating package lists..."
sudo apt update

echo "==> Installing Qt 6 and build tools..."
sudo apt install -y \
    qt6-base-dev \
    qt6-declarative-dev \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-templates2 \
    libqt6network6 \
    qt6-l10n-tools \
    cmake \
    ninja-build \
    gcc \
    g++

echo "==> Granting $USER access to display and input devices..."
sudo usermod -aG video,input,render "$USER"

echo ""
echo "Done. Log out and back in for group changes to take effect,"
echo "then run:  deploy/setup-autostart.sh"
