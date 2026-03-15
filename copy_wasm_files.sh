#!/bin/bash
set -euo pipefail
shopt -s nullglob
mkdir -p wasm
cp -v build/WebAssembly_Qt_6_8_3_single_threaded-Release/{checklist.*,qtloader.js,qtlogo.svg} wasm/

