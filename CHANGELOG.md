## 0.0.16-pre

- Keeps `Pointer<T>` as an integer-backed extension type and generated bindings
  as direct calls, with no deferred descriptors or automatic call scopes.
- Adds `withNativeBuffers` for explicit synchronous TypedData copy-in,
  write-back, and cleanup. Use `scope.addressOf<T>(data)` inside the scope;
  ordinary Dart lists' `.address` now throws instead of allocating implicitly.
- Uses one temporary allocation per scope: the Emscripten stack for scopes up to
  32 KiB (including alignment), otherwise the heap. TypedData views sharing a
  backing buffer preserve their aliases, alignment, and overlapping writes.
- Supports input-only and unmodifiable buffers with `copyBack: false`. Scopes
  preserve aliases and clean up on exceptions; callbacks can open nested scopes.
- Removes the JavaScript-side `functions.leaf` restriction. Stack allocations
  made inside an explicit stack-backed scope expire when that scope closes.
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
