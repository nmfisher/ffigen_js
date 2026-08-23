#!/usr/bin/env bash
# Builds BOTH targets from the SAME C source (native/src/dual.c) and
# regenerates both binding sets from the SAME header
# (native/include/dual.h).
#
# Requirements: a C compiler (cc), libclang (for ffigen/jsgen), and - for
# the wasm half - emcc. Without emcc the Emscripten build is skipped and
# run_web.sh falls back to a JS stand-in for the module (see main.mjs);
# CI WITH emcc must run this script so the real compiled C is exercised.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build generated

# 1. Native shared library (dart:ffi target).
"${CC:-cc}" -shared -fPIC -o build/libdual.so native/src/dual.c -Inative/include

# 2. Bindings: package:ffigen (native) and jsgen (web) from the same header.
dart run ffigen --config ffi_config.yaml
dart run ../../lib/src/jsgen/executables/jsgen.dart --config js_config.yaml

# 3. Emscripten module (dart:js_interop target), with the runtime exports
#    ffigen_js needs (same flag set as the bundled example).
if command -v emcc >/dev/null 2>&1; then
  emcc --no-entry \
    -Inative/include \
    -sENVIRONMENT=shell,node \
    -sWASM_BIGINT=1 \
    -sALLOW_MEMORY_GROWTH=1 \
    -sMODULARIZE \
    -sEXPORT_NAME=dual \
    -sEXPORTED_RUNTIME_METHODS=wasmExports,wasmTable,addFunction,removeFunction,ccall,cwrap,getValue,setValue,UTF8ToString,stringToUTF8,writeArrayToMemory,lengthBytesUTF8,HEAPU8,HEAPU32,HEAPF32,stackSave,stackRestore,stackAlloc \
    -sEXPORTED_FUNCTIONS=_dualAdd,_dualPointScale,_dualGreet,_malloc,stackAlloc,_free \
    -o build/dual.js \
    native/src/dual.c
  echo "built build/dual.js (real Emscripten module)"
else
  echo "emcc not found - skipped the Emscripten build." \
       "run_web.sh will use the JS stand-in; CI must run this with emcc." >&2
fi
