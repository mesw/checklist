# Checklist App

A touch-friendly step-by-step checklist app built with **Qt 6.8 / Qt Quick / C++**.
Runs natively on Raspberry Pi 4 and in any modern browser via WebAssembly.

---

## Live Demo

> 🌐 **[mesw.github.io/checklist/wasm/checklist.html](https://mesw.github.io/checklist/wasm/checklist.html)**
>
> *(Replace `mesw` with your GitHub username in your fork)*

The root URL `https://yourusername.github.io/checklist/` also works —
it redirects to `wasm/checklist.html` automatically.

---

## Host Your Own Instance on GitHub Pages

No compilation needed — the pre-built WASM binary is already in `wasm/`.
You only edit markdown files and push.

### 1 — Fork the repository

Click **Fork** on GitHub (top-right of the repo page).

### 2 — Enable GitHub Pages

In your fork: **Settings → Pages → Source → Deploy from a branch → `main` / `(root)`**

Your fork is now live at:
```
https://yourusername.github.io/checklist/wasm/checklist.html
```

### 3 — Add your own checklists

Create `.md` files in `checklists/` following the format below.
You can edit them directly in the GitHub web UI (no local tools needed).

### 4 — Update the index

After adding or removing `.md` files, regenerate `checklists/index.json`:

```bash
./generate_index.sh
```

Or if you edited via the GitHub web UI, update `index.json` manually —
it's a simple JSON array of filenames without extension, one per checklist:

```json
[
  {"name": "example", "title": "Welcome! 👋"},
  {"name": "my_checklist", "title": "My Checklist"}
]
```

### 5 — Commit and push

```bash
git add checklists/
git commit -m "add my checklists"
git push
```

The site updates within a minute. No build step, no CI.

---

## Checklist File Format

Each checklist is a single `.md` file in `checklists/`.

```markdown
# Checklist Title
Optional subtitle or description shown below the title.

## Step heading
<!-- <emoji> <timer> <auto> -->
Step body text. Supports **bold**, *italic*, and
multiple lines.

## Another step
<!-- <🔥> <300s> <auto> -->
Timer runs for 5 minutes, then auto-advances.

## Final step
<!-- <🎉> -->
No timer. Tap Finish when done.
```

**Comment tag reference** (all fields optional, order doesn't matter):

| Tag | Example | Description |
|-----|---------|-------------|
| emoji | `<🔥>` | Orbits the screen after 30 s of inactivity |
| timer | `<300s>` | Countdown duration |
| auto | `<auto>` | Advances automatically when the timer ends |

The comment line is optional. Steps without it have no timer or emoji.

---

## Repository Structure

```
checklist/
├── checklists/              ← your .md files go here
│   ├── index.json           ← list of checklists; update with generate_index.sh
│   └── example.md
├── wasm/                    ← pre-built WASM artifacts (do not edit)
│   ├── checklist.html       ← app entry point
│   ├── checklist.js
│   ├── checklist.wasm
│   └── qtloader.js
├── deploy/
│   ├── install-deps.sh      ← Raspberry Pi: install Qt + build tools
│   └── setup-autostart.sh   ← Raspberry Pi: build + systemd autostart
├── index.html               ← root redirect to wasm/checklist.html
├── generate_index.sh        ← regenerate checklists/index.json
└── CMakeLists.txt
```

---

## Deploy to Raspberry Pi

Runs full-screen directly on the framebuffer — no desktop compositor needed.

**Requirements:** Raspberry Pi 4 or 5, Raspberry Pi OS **Trixie (Debian 13)**
(Qt 6.8.x is available via `apt` on Trixie; older OS releases ship Qt 5 only).

### Step 1 — Clone the repository on the Pi

```bash
git clone https://github.com/yourusername/checklist.git
cd checklist
git submodule update --init --recursive   # emoji font
```

### Step 2 — Install build dependencies

```bash
deploy/install-deps.sh
```

This installs Qt 6, CMake, Ninja, and GCC, and adds your user to the
`video`, `input`, and `render` groups needed for direct framebuffer access.
**Log out and back in** after this step.

### Step 3 — Build and enable autostart

```bash
deploy/setup-autostart.sh
```

This script:
1. Builds a Release binary to `build/release/`
2. Copies `checklists/` next to the binary (done automatically by CMake)
3. Installs `/etc/systemd/system/checklist.service`
4. Enables the service so it starts on every boot
5. Starts it immediately

The app runs full-screen via `eglfs` (Qt's direct-to-framebuffer backend),
with no X11 or Wayland compositor required.

### Managing the service

```bash
sudo systemctl status  checklist   # check if running
sudo systemctl stop    checklist   # stop
sudo systemctl disable checklist   # remove autostart
sudo journalctl -u     checklist   # view logs
```

### Re-deploying after source changes

```bash
deploy/setup-autostart.sh   # rebuilds and restarts the service
```

---

## Native Development (Linux / WSL2)

### Recommended Stack

| Layer | Version | Notes |
|-------|---------|-------|
| Qt | **6.8.3 LTS** | Full QtQuick + QtNetwork |
| Raspberry Pi OS | **Trixie (Debian 13)** | Ships Qt 6.8.x via `apt` |
| Dev OS | **Ubuntu 24.04 LTS** | Install Qt 6.8.3 via `aqtinstall` |
| Compiler | **GCC 13** | Same ABI on both machines |

### Setup: Ubuntu 24.04 (WSL2)

```bash
sudo apt install -y cmake ninja-build gcc g++ python3-pip \
    libgl1-mesa-dev libgles2-mesa-dev libx11-dev libxkbcommon-dev

pip3 install aqtinstall
aqt install-qt linux desktop 6.8.3 gcc_64 \
    --modules qtquick qtquickcontrols2 qtimageformats \
    --outputdir ~/Qt

echo 'export CMAKE_PREFIX_PATH=~/Qt/6.8.3/gcc_64' >> ~/.bashrc && source ~/.bashrc
```

### Build & Run

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build

# Desktop / WSL with X11
./build/checklist

# Raspberry Pi headless (no desktop compositor)
./build/checklist -platform eglfs
```

---

## Rebuilding the WASM Binary (Maintainers Only)

Only needed when C++ or QML source files change. Forks never need to do this.

```bash
# 1. Install Emscripten 3.1.50 (required by Qt 6.8)
git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
~/emsdk/emsdk install 3.1.50 && ~/emsdk/emsdk activate 3.1.50
source ~/emsdk/emsdk_env.sh

# 2. Install Qt WASM
pip3 install aqtinstall
aqt install-qt linux desktop 6.8.3 wasm_singlethread \
    --modules qtquick qtquickcontrols2 qtimageformats \
    --outputdir ~/Qt

# 3. Build
cmake -B build-wasm \
    -DCMAKE_TOOLCHAIN_FILE=~/Qt/6.8.3/wasm_singlethread/lib/cmake/Qt6/qt.toolchain.cmake \
    -DQT_HOST_PATH=~/Qt/6.8.3/gcc_64 \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -G Ninja
cmake --build build-wasm

# 4. Update wasm/ and commit
cp build-wasm/checklist.html \
   build-wasm/checklist.js   \
   build-wasm/checklist.wasm \
   build-wasm/qtloader.js    \
   wasm/
git add wasm/
git commit -m "update WASM build"
git push
```

> **Why singlethread?** GitHub Pages cannot set the `COOP`/`COEP` headers
> required by multithreaded WASM. Single-thread works in all browsers.
