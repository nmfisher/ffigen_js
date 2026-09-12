## 0.0.16-pre

- Preserves the portable `nativeFunction(data.address, length)` calling convention.
  Native targets directly export `dart:ffi`: leaf calls receive the original
  TypedData storage with no helper, allocation, or copy.
- Generated JS wrappers materialize ordinary Dart TypedData in one temporary
  block, copy writes back, and clean up in `finally`. Blocks up to 32 KiB use
  the Emscripten stack; larger blocks use the heap. Aliases retain their offsets
  and alignment.
- Uses Dart-side integer-or-descriptor pointers on web and integer-only JS
  interop signatures, avoiding JS object boxing. Raw Wasm pointers bypass
  temporary scopes.
- Keeps generated return structs outside temporary argument scopes.
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
