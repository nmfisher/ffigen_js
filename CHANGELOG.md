## 0.0.16-pre

- Makes ordinary Dart `TypedData.address` values deferred and call-scoped,
  matching their `dart:ffi` usage. Generated leaf function wrappers materialize
  them in Wasm memory, copy native writes back, and always release the call
  scope.
- Uses one temporary allocation per call: the Emscripten stack for scopes up to
  32 KiB (including alignment), otherwise the heap. TypedData views sharing a
  backing buffer preserve their aliases, alignment, and overlapping writes.
- Keeps structs returned by value outside the temporary scope so stack cleanup
  preserves their caller-managed lifetime.
- Honors `functions.leaf` when generating JavaScript bindings, using it to
  identify the native calls where deferred TypedData addresses are valid.
- Keeps addresses of Emscripten-backed lists and explicitly allocated pointers
  caller-owned across generated calls.
- Tracks public `malloc` results so `Pointer.free()` releases them.
- Adds `Int8List.address` support.

## 0.0.15-pre

- Fixes standalone enum emission: named enums at the translation-unit root
  were routed through the macro-deferral path and only emitted when an
  included function signature referenced their type. They now go through the
  type extractor (matching upstream `ffigen`), so enums that appear only as
  bitmask constants (no typed signature reference) are emitted as well.

## 0.0.14-pre

- Restores the generated API and output behavior from `0.0.12-pre`.
- Preserves the typed-data `.address` fixes introduced in `0.0.13-pre`,
  including support for `Int64List`.

## 0.0.13-pre

- Fixes `.address` for typed lists backed by the Emscripten heap.
- Adds typed-data address coverage to the bundled Emscripten example.
