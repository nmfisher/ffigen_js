## 0.0.16-pre

- Adds `usingBytes`: a scoped helper that makes a `TypedData` value readable
  from native code for the duration of a synchronous call. Heap-backed values
  are borrowed directly; ordinary Dart values are copied (stack for inputs
  under 32 KiB, tracked heap allocation otherwise) and the copy is always
  released afterwards, including when the body throws.
- Fixes `TypedData.free` for ordinary Dart lists. It released
  `Pointer<Void>(offsetInBytes)`, which never matched the Wasm-heap copy that
  the `address` getter created, so every input of 32 KiB or more leaked its
  copy. It now releases the copies registered by `address`, and still falls
  back to releasing a view created directly over a tracked allocation.
- Adds `debugTrackedAddressCopies` (test hook): the number of pending
  Wasm-heap copies handed out by `address` getters.

- Adds `debugCopiedInputs` (test hook): the number of TypedData values that
  had to be copied into the Emscripten heap because they were not
  heap-backed - a nonzero value in tests means a pathway received data that
  was not allocated with `make*List`.
- Adds `isWasmBacked(TypedData)`: whether a value is already backed by the
  Emscripten heap, so its `address` borrows instead of copying.
- Adds `heapCopy(TypedData)`: a malloc-backed Emscripten-heap copy (never a
  stack allocation) of the same typed view, for cases where native code
  borrows the data beyond the current call; released with `TypedData.free`
  on the returned view.

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
