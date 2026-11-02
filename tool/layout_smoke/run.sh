#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
DART="${DART:-dart}"
EMCC="${EMCC:-emcc}"
NODE="${NODE:-node}"
mkdir -p build/layout_smoke
"$DART" run bin/ffigen_js.dart --config tool/layout_smoke/js_config.yaml
"$EMCC" tool/layout_smoke/layout.c -O2 --no-entry \
  -sENVIRONMENT=node -sMODULARIZE=1 \
  '-sEXPORTED_FUNCTIONS=["_checkPadded","_checkPacked","_fillNested","_fillPacked","_fillChoice","_checkSizes"]' \
  '-sEXPORTED_RUNTIME_METHODS=["HEAPU8","getValue","setValue","stackAlloc"]' \
  -o build/layout_smoke/layout.cjs
"$DART" compile js -O2 tool/layout_smoke/main.dart -o build/layout_smoke/main.js
"$NODE" tool/layout_smoke/main.cjs
"$DART" compile wasm tool/layout_smoke/main.dart -o build/layout_smoke/main.wasm
"$NODE" tool/layout_smoke/main.mjs
