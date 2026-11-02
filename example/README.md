# Example and regression checks

From the repository root, run:

```sh
bash example/build.sh
```

Or run `bash build.sh` from this directory. Install Dart, libclang, Emscripten
and Node 22+ first; `DART`, `EMCC` and `NODE` can select explicit executables.

The script resolves packages, runs the generator unit tests, regenerates JS
bindings from the example header and compiles the native example once. The ABI
checks run through Dart-to-JS and Dart-to-Wasm against that same native module.
The Wasm run also executes the existing struct, array, enum, BigInt, callback,
TypedData and pointer-array assertions. Failures stop the script with a nonzero
exit code. CI runs this same command.

`native/include/abi_layout.h` is shared with the parser unit tests. Generated
bindings and build output remain in the existing ignored `lib/*.g.dart` and
`build/` paths.

To regenerate the optional native Dart FFI bindings separately:

```sh
dart run ffigen --config ffi_config.yaml
```
