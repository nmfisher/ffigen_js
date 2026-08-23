// The thermion_dart / reactphysics3d_dart pattern: ONE import for consumers;
// the build picks native dart:ffi bindings or JS-interop bindings. The
// default (first, unconditional) URI is the native side; the conditions
// select per platform:
//   - dart:ffi platform (VM/AOT native)   -> dual_bindings_ffi.g.dart
//   - dart:js_interop platform (wasm/web) -> dual_bindings_js.g.dart
//
// Both files are generated from the SAME header (native/include/dual.h);
// see ffi_config.yaml and js_config.yaml.
//
// Note: the analyzer resolves this export to its DEFAULT (native) branch,
// so code that is web-only should import dual_bindings_js.g.dart directly
// (see api_web.dart). At compile time the conditions are evaluated for the
// real target, which is what routes each build in this smoke test's
// consumer chain (api.dart).
export '../generated/dual_bindings_ffi.g.dart'
    if (dart.library.ffi) '../generated/dual_bindings_ffi.g.dart'
    if (dart.library.js_interop) '../generated/dual_bindings_js.g.dart';
