#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
DART="${DART:-dart}"
EMCC="${EMCC:-emcc}"
NODE="${NODE:-node}"

# One command runs generator tests and all example integration checks.
(cd ..; "$DART" pub get; "$DART" test)
"$DART" pub get
mkdir -p build
"$DART" run ../lib/src/jsgen/executables/jsgen.dart --config js_config.yaml
"$DART" compile js -O2 bin/abi_layout_js.dart -o build/abi_layout.dart.js
"$DART" compile wasm --enable-asserts bin/example.dart -O0 --shared-memory=100 -o build/example.wasm
cd build
"$EMCC" --no-entry -O2 \
    -lembind \
    -I../native/include \
    -sENVIRONMENT=shell,node \
    -sWASM_BIGINT=1 \
    -sALLOW_MEMORY_GROWTH=0 \
    -sIMPORTED_MEMORY \
    -sALLOW_TABLE_GROWTH=1 \
    -sEXPORT_NAME=example \
    -sMODULARIZE \
    -sEXPORTED_RUNTIME_METHODS=wasmExports,wasmTable,addFunction,removeFunction,ccall,cwrap,allocate,intArrayFromString,intArrayToString,getValue,setValue,UTF8ToString,stringToUTF8,writeArrayToMemory,lengthBytesUTF8,HEAPU8,stackSave,stackRestore \
    -sEXPORTED_FUNCTIONS=_malloc,stackAlloc,_free \
    -sFULL_ES3 \
    -o example_lib.js \
    ../native/src/example.cpp
cp ../native/js/main.js .
"$NODE" main.js --js
"$NODE" main.js
