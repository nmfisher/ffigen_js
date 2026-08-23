# Dual-target smoke test (native dart:ffi + web dart:js_interop)

This is the integration test the rest of the suite does not cover: ONE C
source compiled to BOTH targets, bindings generated for both, and a SINGLE
conditional-import consumer that runs the same code on either one. It is
the pattern thermion_dart and reactphysics3d_dart ship to their users:

```
lib/bindings.dart:
export '../generated/dual_bindings_ffi.g.dart'
    if (dart.library.ffi) '../generated/dual_bindings_ffi.g.dart'
    if (dart.library.js_interop) '../generated/dual_bindings_js.g.dart';
```

## Layout

- `native/include/dual.h`, `native/src/dual.c` - the fixture. Three
  functions (`dualAdd`, `dualPointScale`, `dualGreet`) and one struct
  (`DualPoint`). C identifiers are camelCase/PascalCase so ffigen (native)
  and jsgen (web) emit identical Dart names with no rename config.
- `ffi_config.yaml` -> package:ffigen -> `generated/dual_bindings_ffi.g.dart`
  (constructible `DualNativeLibrary(DynamicLibrary)` wrapper).
- `js_config.yaml` -> jsgen -> `generated/dual_bindings_js.g.dart`, with
  `ffi-native: asset-id: dual` (the module name baked into `initBindings`).
  Both generated files are committed so the tests run without libclang.
- `lib/bindings.dart` - the conditional export above (the thermion/rp3d
  pattern; the first, unconditional URI is the native default).
- `lib/api.dart` - a second conditional export picking the per-target
  adapter, so `consumer.dart` can stay byte-identical across targets.
- `lib/api_native.dart` - opens `build/libdual.so` via `DynamicLibrary`,
  struct fields through `.ref`, strings through `package:ffi`.
- `lib/api_web.dart` - `GeneratedBindings.initBindings()` (baked asset-id
  `dual`), struct fields through the generated getters/setters, strings
  through the instance-scoped ffigen_js helpers.
- `lib/consumer.dart` - THE consumer: `runDualTargetChecks()` asserts
  add(20,22)==42, point (1.5, 3.25) scaled by 2 == (3.0, 6.5) through C,
  and a string round-trip. Run verbatim on both targets.

Both halves of the conditional import are compile-time exclusive, so each
run also proves the routing: on the VM `dart.library.ffi` selects the
dart:ffi file (and the ffigen_js import in the other branch is never
compiled - it cannot even load on the VM test platform); under
`dart compile wasm` `dart.library.js_interop` selects the JS file (and the
`dart:ffi`/`dart:io` adapter cannot compile there).

## Running

Native half (any machine with a C compiler):

```sh
dart test test/dual_target_native_test.dart   # builds libdual.so if missing
```

Web half (node; emcc optional - see below):

```sh
tool/dual_target_smoke/run_web.sh
# DUAL TARGET SMOKE OK (web): add=42 point=(3.0, 6.5) greet="hello, dual-target!"
```

Everything (build both targets + regenerate bindings + native lib):

```sh
tool/dual_target_smoke/build.sh
```

## What CI confirms

`main.mjs` falls back to a JS stand-in when `build/dual.js` is absent, so
a machine without `emcc` still prints `SMOKE OK` without ever running the
compiled C. CI therefore must (and `.github/workflows/ci.yml` does):

1. install emcc (mymindstorm/setup-emsdk, pinned to 3.1.73),
2. run `tool/dual_target_smoke/build.sh` (compiles `dual.c` with emcc into
   `build/dual.js`, with the runtime exports ffigen_js needs),
3. run `tool/dual_target_smoke/run_web.sh`, and FAIL unless the log says
   `main.mjs: using REAL Emscripten module (build/dual.js)` and never
   mentions the `JS STAND-IN`, and
4. run `dart test` (native half).

Verified end to end locally with emcc 3.1.73: the real-module run prints
the same `add=42 point=(3.0, 6.5) greet="hello, dual-target!"` as the
stand-in run did, so the stand-in was faithful - but only the emcc run
actually executed the compiled C.

## Mapping to thermion / reactphysics3d_dart

Identical idea at package scale: one `bindings.dart` conditional export per
package, native side resolving a `DynamicLibrary` (or `@Native` asset),
web side initializing the JS module from the page-published global via the
`ffi-native: asset-id:` config. The per-module work in PR #3 (per-file
`GeneratedBindings.instance`, `NativeLibrary.init`/`byName`) is what lets
the two packages coexist on the web side - see
`tool/multi_module_smoke` for the two-module isolation test.
