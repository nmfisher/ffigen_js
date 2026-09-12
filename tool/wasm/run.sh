#!/usr/bin/env bash
# Runs the web/Wasm TypedData.address tests: the shared contract plus
# offset-base cases, executed against the Emscripten heap under node.
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [ ! -f "$ROOT/example/build/example_lib.js" ] || \
   [ ! -f "$ROOT/example/build/example.mjs" ]; then
  (cd "$ROOT/example" && ./build.sh)
fi

cd "$ROOT"
dart compile wasm --enable-asserts tool/wasm/typed_data_address_wasm_test.dart \
  -O0 --shared-memory=100 -o example/build/typed_data_address_test.wasm

node "$ROOT/tool/wasm/main.js"
