// Target-agnostic facade over the generated bindings. The per-target files
// adapt the (necessarily different) binding styles - a constructible
// DualNativeLibrary(DynamicLibrary) wrapper on native, top-level functions
// plus ffigen_js helpers on web - into one identical surface for
// consumer.dart.
export 'api_native.dart'
    if (dart.library.ffi) 'api_native.dart'
    if (dart.library.js_interop) 'api_web.dart';
