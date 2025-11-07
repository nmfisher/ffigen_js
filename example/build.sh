mkdir -p build
dart compile wasm --enable-asserts  bin/example.dart -O0 --shared-memory=100 -v -o build/example.wasm || exit -1;
cd build
emcc --no-entry \
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
    ../native/src/example.cpp || exit -1;
cp ../native/js/main.js .
node main.js

#clang++ -dynamiclib -Inative/include -std=c++17 -o build/example.dylib native/src/example.cpp
