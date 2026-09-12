## 0.0.16-pre

- Keeps `Pointer<T>` as an integer-backed extension type and generated functions
  as direct calls with unchanged `Pointer<T>` parameters.
- Adds `withNativeBuffers([data], () { nativeFunction(data.address, length); })`.
  On native it simply executes the callback: built-in `dart:ffi` leaf calls
  receive original TypedData storage without native allocation or copying.
- On web the explicit scope copies ordinary Dart buffers into one temporary
  block, copies writes back, and cleans up in `finally`. Blocks up to 32 KiB use
  the Emscripten stack; larger blocks use the heap. `.address` returns a real
  pointer inside a registered scope and otherwise rejects ordinary Dart lists.
- Preserves aliases and alignment, supports contained views, and reuses outer
  storage in nested scopes. Stack allocations made inside a stack-backed scope,
  including generated return structs, expire at scope exit.
- Keeps Wasm-backed lists and explicit allocations caller-owned. Public
  `malloc` results are tracked so `Pointer.free()` releases them.
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
