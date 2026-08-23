#!/usr/bin/env bash
# Web half of the dual-target test: compiles the SAME consumer.dart (with
# its conditional imports) to wasm and runs it under node against the
# module published by main.mjs. Run build.sh first if you have emcc, so the
# REAL compiled C is used; otherwise main.mjs falls back to a JS stand-in.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
dart compile wasm --enable-asserts -O0 -o build/main_dual.wasm main_dual.dart
cp main.mjs build/
cd build
node main.mjs
