## 0.0.16-pre

- Makes ordinary Dart `TypedData.address` values deferred and call-scoped,
  matching their `dart:ffi` usage. Generated leaf function wrappers materialize
  them in Wasm memory, copy native writes back, and always release the call
  scope.
- Uses the Emscripten stack for small call scopes and temporary heap allocations
  for larger inputs. TypedData views sharing a backing buffer also share their
  native allocation, preserving aliases and overlapping writes.
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
