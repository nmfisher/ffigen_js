# Multi-module smoke test

Runs the ffigen_js runtime under `dart compile wasm` + node against two
*fake* Emscripten modules (`main.mjs`), each with its own buffer, stack and
heap. Because both stacks start at the same offset, allocating in both
modules produces the SAME numeric address in two separate heaps - the test
writes different data there through each module and requires each library to
read back only its own bytes.

Covers:

- `NativeLibrary.init` first-wins default policy and per-name idempotency
- `NativeLibrary.byName` (and its `StateError` for unregistered names)
- `setDefault` ignoring a later, different-module claim
- the legacy `NativeLibrary.instance =` setter still switching deliberately
- instance-scoped helpers (`toNativeUtf8`, `utf8ToString`, `makeFloat32List`,
  `makeUint8List`, `malloc`/`free` with double-free safety) staying isolated
  per module

Run from this directory (adjust `ffigen_js` path in `pubspec.yaml` if needed):

```sh
dart pub get
dart compile wasm --enable-asserts -O0 -o smoke.wasm multi_module_smoke.dart
node main.mjs   # expect: SMOKE OK
```
