## 0.0.16-pre

- First release published via GitHub Actions OIDC automated publishing.
- No code changes since `0.0.15-pre`.

## 0.0.15-pre

- Parses headers with the `wasm32-unknown-emscripten` target by default, so
  target-dependent C types (`size_t`, `long`, ...) resolve with the Wasm ABI
  instead of the host ABI (e.g. `size_t` was 64-bit and generated mismatched
  `JSBigInt` bindings on 64-bit hosts). Override with `compiler-opts:
  ['-target', '<other-triple>']`.
- Disables the automatic macOS SDK include paths by default
  (`compiler-opts-automatic.macos.include-c-standard-library` now defaults to
  `false`): they use the host ABI and conflict with the wasm32 target. Wasm
  headers get `stddef.h`/`stdint.h`/`stdbool.h` from clang's built-in headers.
  Opt back in with `compiler-opts-automatic.macos.include-c-standard-library:
  true`.
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
