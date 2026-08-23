# Scoping/design: per-module isolation in ffigen_js (multiple Emscripten modules on one page)

Date: 2026-08-23
Branch: `asb/multi-module-plan` (ffigen_js @ `06d47ad`, `0.0.14-pre`)
Status: **research and design only — no code changed.**

Companion document: `thermion` `docs/research/web-physics-scope.md` (branch
`asb/dart-physics-sample-clean`), which scoped the overall web-physics problem,
recommended a single combined WASM (its Option C), and estimated "Option B — two
separate WASM modules" at 1.5–3 weeks / high risk without detailing the ffigen_js
work. The owner has since decided on **completely separate physics**: thermion's
build must stay free of physics, and physics ships as a standalone Emscripten
module that an app loads separately. This document is the detailed ffigen_js
design that Option B needs.

Everything below was verified against the actual sources unless explicitly
marked *verify*. Reference checkouts:

- `ffigen_js` @ `06d47ad` (this repo, master, `0.0.14-pre`)
- `thermion` @ master (`thermion_dart`, `examples/dart/web_gallery`)
- `reactphysics3d_dart` @ master (`0adbbef` — the ffigen_js pin is already
  relaxed to `^0.0.14-pre` and the web bindings are regenerated; the prior
  doc's Option A prerequisite is done, and `native/web/module_init.cpp` now
  exists)

---

## 1. Problem statement

ffigen_js assumes **one Emscripten module per Dart isolate**. The runtime keeps
a single package-level `NativeLibrary _lib` and every helper — allocation,
`getValue`/`setValue`, string conversion, typed-list views, callback
registration — dispatches through it. Generated bindings files from *different
packages* (thermion_dart, reactphysics3d_dart) all read and write that one
global. The second `initBindings` call re-points it, and the losing module's
subsequent calls execute against the **winner's heap**. Addresses are plain
Dart ints, so this is silent memory corruption, not an error.

Goal: make `NativeLibrary.instance` (and all generated-binding runtime helpers)
**per-module**, so two or more Emscripten modules coexist on one page, while
existing single-module users keep working unchanged.

---

## 2. Current architecture (verified)

### 2.1 Runtime: the `_lib` global (`lib/src/types.dart`)

- `types.dart:319` — `late NativeLibrary _lib;` — one package-level global,
  shared by every package that transitively exports
  `package:ffigen_js/ffigen_js.dart` (the generated files re-export it, see
  §2.2, so thermion_dart and reactphysics3d_dart share the *same* `_lib`).
- `types.dart:455-522` — `extension type NativeLibrary(JSObject _)`: wraps one
  Emscripten `Module` instance. Instance members are the per-module Emscripten
  exports: `_stackAlloc` (`@JS('stackAlloc')`), `_malloc`, `_free`,
  `stackSave`/`stackRestore`, `getValue`/`getValueBigInt`/`setValue`,
  `_lengthBytesUTF8`, `_UTF8ToString`, `_stringToUTF8`,
  `writeArrayToMemory`, `addFunction`/`removeFunction`,
  `HEAPU8`/`HEAPU32`/`HEAPF32` getters.
- `types.dart:456-460` — `static NativeLibrary get instance => _lib;` and
  `static set instance`.
- `types.dart:462-468` — `static void initBindings(String moduleName)`:
  `globalContext.getProperty(moduleName.toJS)` (a lookup of a JS global by
  name) then `_lib = lib as NativeLibrary`.
- `types.dart:542` — `final _heapAllocations = <Pointer>{};` — a second piece
  of global state: the set of malloc-tracked pointers consulted by
  `Pointer.free()`.

### 2.2 Generator: what is written into every bindings file

`lib/src/jsgen/code_generator/writer.dart:205-224` emits into every generated
file (class name is hardcoded `GeneratedBindings` regardless of the config
`name:` — the config name only feeds name-conflict resolution,
`writer.dart:110-114`):

```dart
import 'package:ffigen_js/ffigen_js.dart';
export 'package:ffigen_js/ffigen_js.dart';

extension type GeneratedBindings(NativeLibrary _) implements JSObject {
  static GeneratedBindings get instance => NativeLibrary.instance as GeneratedBindings;
  static void initBindings(String moduleName) {
    var lib = globalContext.getProperty(moduleName.toJS);
    if (lib == null) { throw Exception("Failed to find JS module ${moduleName}"); }
    NativeLibrary.instance = lib as NativeLibrary;   // <-- the clobber
  }
  // ... `external` declarations for every bound C function ...
}
```

Two consequences:

1. `GeneratedBindings.instance` is **not** per file — it forwards to the shared
   global. Verified in the wild: `reactphysics3d_dart`'s regenerated
   `lib/src/bindings/src/rp3d_js_interop.g.dart:10-20` carries exactly this
   block, as does thermion's `thermion_dart_js_interop.g.dart:11-20`.
2. Because each generated file re-exports `package:ffigen_js/ffigen_js.dart`,
   all helper extensions resolve to one runtime library → one `_lib`.

### 2.3 Full inventory of `_lib` / `NativeLibrary.instance` references

**Runtime — `lib/src/types.dart` (64 references: 50 `_lib.`, 11 `NativeLibrary.instance`, 3 declaration/assignment):**

| Group | Lines | Members |
|---|---|---|
| Global + init | 319, 456, 458, 462-468, 542 | `_lib`, `instance` get/set, `initBindings`, `_heapAllocations` |
| `Pointer.free` | 44 | `_lib._free` |
| `PointerClass` statics | 63, 73 | `stackAlloc`, `allocArray` |
| top-level `addFunction` | 81 | `_lib.addFunction` |
| primitive `stackAlloc` statics | 86, 92, 98, 104, 110, 116, 122, 128, 134, 140, 146 | `Char`…`Float64` |
| pointer element access | 159, 164, 182, 186, 196, 200, 210, 218, 222, 226, 236, 240 | `getValue`/`setValue` on `Pointer<Int32/Int64/Float32/Float64>`, `PointerPointerClass` |
| strings | 248, 250, 257, 258, 262 | `String.toNativeUtf8()`, `CharPtr.setValue/toDartString` |
| callbacks | 270 | `DisposePointerClass.dispose` → `removeFunction` |
| `Array` | 281, 285, 291, 295, 301, 305, 311, 315 | `HEAPU8`, `writeArrayToMemory`, element get/set |
| allocators | 322, 326, 330-332 | top-level `malloc`/`stackAlloc`/`free` |
| `make*List` | 360, 367, 374, 385, 392, 399 (via `asTypedList`), 405, 412 | stack-alloc + `HEAPU8.buffer` views |
| typed-data `.address` + `asTypedList` | 607, 659, 672, 689, 706, 723, 740, 757 (via cast), 773, 787, 796, 805 | `Uint8ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, …)` etc. |

**Generator — templates that emit `NativeLibrary.instance` / `GeneratedBindings.instance` into generated code:**

| File:line | Emitted call | Used by |
|---|---|---|
| `writer.dart:214` | `static GeneratedBindings get instance => NativeLibrary.instance as GeneratedBindings;` | everything below |
| `writer.dart:221` | `NativeLibrary.instance = lib as NativeLibrary;` (in `initBindings`) | app init |
| `func.dart:303` | `GeneratedBindings.instance._fn(args)` | **every** generated user-facing wrapper |
| `compound.dart:209` | `NativeLibrary.instance.getValue(addr, llvmType)` | every generated struct getter |
| `compound.dart:213` | `NativeLibrary.instance.setValue(addr, val, llvmType)` | every generated struct setter |
| `compound.dart:233` | `NativeLibrary.instance.stackAlloc<T>(size)` | generated `Struct.stackAlloc()` |
| `func_type.dart:99` | `NativeLibrary.instance.addFunction<T>(fn, sig)` | generated `.addFunction()` on Dart closures |
| `global.dart:63` | `NativeLibrary.instance.getValue(GeneratedBindings.instance._name, …)` | generated global-variable getters |

(`compound.dart:133-137`'s `Pointer<T>.toDart()` and the `StructAllocator`
switch at `writer.dart:240-256` are pure Dart object construction — no `_lib`.)

**Consumer hand-written code that reads the singleton:**

- `thermion_dart/lib/src/bindings/src/js_interop.dart:17-19` —
  `extension type _NativeLibrary(NativeLibrary _)` with
  `static _NativeLibrary get instance => NativeLibrary.instance as _NativeLibrary;`
  plus `stackSave`/`stackRestore` wrappers at `:197-199`.
- `reactphysics3d_dart/lib/src/bindings/src/js_interop.dart` — a larger
  hand-written adapter: `_heapBuffer` (`NativeLibrary.instance.HEAPU8.buffer`),
  `makeUint8List`…`makeFloat32List` built on `malloc` + local views, a
  `Pointer<Uint32>[]` element extension via `NativeLibrary.instance.getValue`.

### 2.4 Consumer packages today

Both packages use the same conditional-export pattern
(`bindings.dart` → `ffi.dart` on native, `js_interop.dart` on web), so
implementation files are shared across platforms and call a platform-neutral
helper surface:

- **thermion_dart**: ~120 direct ambient-helper call sites across 21 shared
  implementation/interface files (`.address`, `.free()`, `toNativeUtf8()`,
  `asTypedList(`, `stackAlloc(`, `addFunction()`), heaviest in
  `ffi_filament_app.dart` (19), `ffi_material.dart` (14),
  `ffi_animation_manager.dart` (14), `ffi_renderable_manager.dart` (12).
- **reactphysics3d_dart**: ~40 sites across 6 files
  (`ffi_physics_common.dart` 20, `ffi_collision_shape.dart` 11,
  `ffi_debug_renderer.dart` 7, `sendport_event_listener.dart` 1,
  plus the two bindings adapters).

These counts matter: they are the migration surface for any design that keeps
a shared runtime (see §4A/§5).

---

## 3. The JS side (verified)

### 3.1 How a module loads today

thermion gallery, `examples/dart/web_gallery/web/index.html:136-147`:

```html
<script src="thermion_dart.js"></script>          <!-- Emscripten glue: -sMODULARIZE -sEXPORT_NAME=thermion_dart -->
<script type="module">
  window.thermion_dart = await thermion_dart();   <!-- call factory → Promise<Module>; stash instance under a global name -->
  // ...then boot dart2wasm main.wasm via main.mjs
</script>
```

and Dart side: `NativeLibrary.initBindings("thermion_dart")` (gallery
`main.dart:56`) resolves that stashed global by name.

### 3.2 Two modules CAN coexist — confirmed

- With `-sMODULARIZE`, Emscripten "emit[s] the code wrapped in an async
  function" and the factory "allows you to create multiple instances of the
  module" (verbatim from `emscripten/src/settings.js`, the MODULARIZE entry).
  Each instance closes over its own heap (linear memory), stack, malloc arena,
  wasm table, and runtime methods. There is no shared module-level state
  between two `-sMODULARIZE` builds.
- The only page-level collision is the **factory global name**: each build must
  use a distinct `-sEXPORT_NAME` (a second `<script>` with the same EXPORT_NAME
  overwrites the first factory — that is the JS-level "clobber", separate from
  the Dart-level `_lib` clobber).
- Both consumer builds already produce factory output with distinct names:
  `thermion_dart/native/web/CMakeLists.txt:15,18` (`EXPORT_NAME=${MODULE_NAME}`
  = `thermion_dart`) and
  `reactphysics3d_dart/native/web/CMakeLists.txt:20,22` (`reactphysics3d_dart`).
- Pattern for two modules (what §5.6 sketches):

```html
<script src="thermion_dart.js"></script>
<script src="reactphysics3d_dart.js"></script>
<script type="module">
  const [thermion, rp3d] = await Promise.all([thermion_dart(), reactphysics3d_dart()]);
  window.thermion_dart = thermion;
  window.reactphysics3d = rp3d;   // any name; initBindings resolves by name
  // boot dart2wasm as today
</script>
```

### 3.3 Each module exports everything ffigen_js needs — confirmed

ffigen_js's `NativeLibrary` instance members (§2.1) require, per module:

| Need | thermion (CMakeLists:20-21) | rp3d (CMakeLists:24-25) |
|---|---|---|
| `getValue,setValue,UTF8ToString,stringToUTF8,writeArrayToMemory,lengthBytesUTF8` | ✅ | ✅ |
| `HEAPU8,HEAPU32,HEAPF32` | ✅ | ✅ `HEAPU8,HEAPF32` — **`HEAPU32` not exported** (harmless unless used; `types.dart:513` merely declares it) |
| `addFunction,removeFunction` + `-sALLOW_TABLE_GROWTH=1` | ✅ | ✅ |
| `_malloc,stackAlloc,_free,stackSave,stackRestore` | ✅ | ✅ |

Callbacks are safe per module: each module grows its **own** wasm table, and
the returned `Pointer<NativeFunction>` is a table index in that module only.

### 3.4 Caveats

1. **The ffigen_js example's shared-memory mode does not scale to two
   modules.** `example/build.sh:3,11` compiles the Dart side with
   `--shared-memory` and the native side with `-sIMPORTED_MEMORY`, sharing one
   `WebAssembly.Memory` between dart2wasm and Emscripten (`main.js:7-13`). Two
   `-sIMPORTED_MEMORY` modules cannot share one memory (both initialize static
   data at offset 0). Thermion's real web build does **not** use this mode
   (`-sINITIAL_MEMORY=512mb`, no `IMPORTED_MEMORY`), so it is not a blocker —
   but the multi-module example must use the thermion pattern, not the current
   example pattern.
2. **Cost of a second module:** `512mb` initial linear memory each (rp3d's
   could be cut to ~64mb — physics needs far less than Filament) plus a second
   pthread pool (`PTHREAD_POOL_SIZE=8` vs `1`). Both builds are `-pthread`, so
   the page must remain cross-origin isolated — already required by thermion.
3. `initBindings` resolves the **resolved instance**, not the factory: the app
   must stash `await factory()` under a global name first (thermion does).
   A `fromModule(JSObject)` overload accepting the instance directly would
   remove that JS-global bookkeeping (see §5.1).

---

## 4. Design options

### Option A — per-binding-instance library

Each generated `GeneratedBindings` holds its **own** static instance instead of
forwarding to the shared global; generated wrappers and generated
struct/global/callback code resolve the module through *their file's* static.
The hard part is the shared helper surface in `types.dart` (§2.3): helpers
called by hand-written code (`toNativeUtf8`, `makeFloat32List`, `.address`,
`asTypedList`, `getValue`/`setValue` extensions, `stackAlloc` statics,
`.free()`, `.addFunction()`, `.dispose()`) have no receiver that can identify
the caller's module. Sub-options for that dispatch:

- **A1 — pass the library through every generated call.** Full explicitness,
  but it is the "signature churn" nightmare: struct getters would need a
  `lib` argument (structs are dumb `Pointer` wrappers with no library field),
  and every hand-written call site in both packages changes. Rejected as the
  primary mechanism.
- **A2 — zone-based "current library".** Helpers resolve
  `Zone.current[#ffigenModule] ?? _lib`. *Analysis:* `Zone` is pure Dart
  (`dart:async`) and is expected to work under dart2wasm — **verify**, see
  §8. The fatal problem is semantic, not platform support: correctness would
  depend on every helper call executing inside the right zone, i.e. each
  package would have to wrap its entire public API (or the app every call).
  One missed scope = the same silent corruption we are eliminating. Also
  `getValue`/`setValue` are the hottest paths in generated code (every struct
  field access) and would pay a zone-chain lookup each time (*verify* cost).
  Rejected as core mechanism; acceptable as opt-in sugar
  (`NativeLibrary.runWith(lib, body)`) for batch operations.
- **A3 — instance-scoped helpers + legacy ambient fallback (recommended).**
  Keep the ambient API exactly as-is for single-module apps, and add
  *instance-level* equivalents of every helper on `NativeLibrary`. Generated
  code stops using ambient entirely (per-file static). Hand-written adapters
  migrate at their own pace; one package may keep ambient (see §5.7 phase 1).
  Details in §5.

  Feasibility note (verified): extension types can hold mutable static state —
  `static GeneratedBindings? _instance` inside an `extension type` compiles
  and runs on Dart 3.13.

**ffigen_js changes:** runtime (instance helpers, default-lib policy) +
generator (writer/func/compound/func_type/global templates). **Consumer
changes:** regenerate; migrate hand-written ambient call sites (or defer for
the ambient-owning package). **Backward-compat:** excellent (§5.3).
**Effort:** ~1.5–2 weeks total across repos. **Risk:** medium — the silent
cross-module-pointer hazard remains for app code that mixes modules through
the shared `Pointer` type (an `int`); mitigations are debug guards + docs.

### Option B — renamed/namespaced runtime per module

Two (or N) copies of the ffigen_js runtime under different package names, so
each package's `_lib` is a *different* library-level global.

- **B as previously described (fork/rename):** no upstream change, but a fork
  to maintain per module.
- **B' — config-driven runtime import (the sensible version):** ffigen_js adds
  a config option (e.g. `runtime-package:`) so the generated file imports
  `package:<name>/ffigen_js.dart` instead of hardcoding
  `package:ffigen_js/ffigen_js.dart` (`writer.dart:209`). A downstream creates
  a trivial renamed runtime package (same sources, own pubspec) per module.
  ffigen_js change: ~0.5 day. No migration of hand-written call sites at all —
  each package's ambient helpers automatically hit its own copy.
- **B'' — embed a namespaced runtime into each generated file:** the generator
  emits the helper extensions inside each `.g.dart`. No second packages, but
  ~800 lines duplicated per file and per-file type forks.

**The deciding property:** with B, each runtime copy defines its **own**
`Pointer`/`NativeLibrary` types, so a thermion `Pointer<T>` and an rp3d
`Pointer<T>` are different types. That is a *feature* (the compiler stops you
from passing a pointer into the wrong module — the silent hazard of A becomes
a compile error) and a *cost* (any cross-package pointer exchange needs int-level
shims; two Dart packages can never share a bindings-level type). In the
separate-physics architecture the packages exchange only plain Dart data
(`Float32List`, doubles), so the friction is small today — but it is permanent
and grows with every new module (one runtime copy each). Also every runtime
bugfix must be replicated N times.

**Effort:** lowest (~1 week). **Risk:** medium (fork drift, type friction).

### Option C — factory/registry of libraries keyed by module name

A global registry (`Map<String, NativeLibrary>`) filled by `initBindings`;
generated bindings hold their own reference; helpers resolve via a passed-in
library. On its own this does not solve the helper-dispatch problem (the
registry only helps *find* modules, not route ambient calls). It is a good
**component** of A3 — a registry makes hand-written code and adapters able to
grab "their" module deterministically
(`NativeLibrary.byName('reactphysics3d_dart')`) without re-reading JS globals.
Folded into the recommendation rather than standing alone.

### Option D — zone-local / thread-local "current module"

See A2. Zones: expected to work under dart2wasm (pure Dart) but semantically
fragile and hottest-path-costly; rejected as the core, kept as optional sugar.
"Thread-local": there is no Dart-level thread-local mechanism, and ffigen_js
targets dart2wasm (single-threaded per isolate; thermion's pthreads live
inside the Emscripten modules, invisible to Dart). Not applicable.

### Option E — other approaches considered

- **Pack a module id into the `Pointer` int's upper bits** (wasm32 addresses
  stay < 4GB, Dart ints are 64-bit): helpers mask to find the module. Rejected:
  `Pointer implements int` and generated code does raw arithmetic on it
  (`this.address.addr + offset`); every boundary would need masking, and any
  leak of an unmasked/masked int breaks silently. High blast radius for a
  debug-grade guarantee.
- **One combined WASM (`EXTERNAL_PROJECTS`)** — dissolves the problem by
  construction (one module, one `_lib`), and is the prior doc's recommendation,
  but it is **rejected by the owner's decision**: thermion's build must stay
  free of physics; physics must ship standalone.
- **JS-side dispatch (a JS global holding "current module" flipped per
  call):** strictly worse than the Dart-side `_lib` (same ambiguity, plus an
  extra interop hop). Rejected.

### Comparison

| | A3 (per-file instance + instance helpers) | B' (renamed runtime copies) | A2/D (zones) | E (packed bits) |
|---|---|---|---|---|
| ffigen_js change | medium | tiny | medium | large |
| Consumer migration | regenerate + adapter (+ optional full) | regenerate only | wrap everything | everything |
| Shared `Pointer` type across packages | yes | **no** (per-copy types) | yes | yes |
| Cross-module misuse detection | runtime-only (debug guards) | **compile time** | none | partial |
| Nth module cost | none | +1 runtime package | none | none |
| Backward compat | full | full | full | poor |
| Silent-corruption risk after migration | low (app-level mixing remains possible) | very low | **high** (missed zone) | medium |

---

## 5. Recommendation: A3 + registry ("per-file instance, instance-scoped helpers, legacy ambient")

One runtime, shared types, per-module dispatch where it is statically known
(generated code), explicit dispatch where it is not (hand-written code), and a
preserved ambient path for single-module backward compatibility.

### 5.1 Runtime changes (`lib/src/types.dart`)

1. **Keep** `NativeLibrary.instance` get/set and the static
   `initBindings(String)` exactly as they are (legacy apps depend on them,
   including old generated files still calling `NativeLibrary.instance =`).
2. **Add a default-module policy:**

```dart
static NativeLibrary? _defaultLib;

/// The ambient module used by the extension-based helpers below.
/// Set explicitly or by the first initBindings; changing it later logs a
/// warning in debug builds (it usually means two modules are fighting).
static void setDefault(NativeLibrary lib, {bool ifUnset = false}) { ... }

static final Map<String, NativeLibrary> _registry = {};
static NativeLibrary byName(String moduleName) => ...;  // filled by init
```

3. **Add instance-scoped equivalents of every ambient helper** (names
   indicative):

```dart
extension type NativeLibrary(JSObject _) implements JSObject {
  // existing instance members unchanged (getValue/setValue/stackAlloc/
  // _malloc/_free/addFunction/removeFunction/HEAPU8/HEAPF32/...)

  Pointer<Char> toNativeUtf8(String s);            // was String.toNativeUtf8()
  String utf8ToString(Pointer<Char> p);             // was p.toDartString()
  Pointer<T> alloc<T extends NativeType>(int bytes);        // was malloc/stackAlloc
  void freePointer(Pointer p);                      // per-module tracked set
  Uint8List makeUint8List(int n);  Int32List makeInt32List(int n);
  Float32List makeFloat32List(int n);  /* ... */
  Pointer<T> addressOf<T extends NativeType>(TypedData d);  // was d.address
  Uint8List viewUint8(Pointer<Uint8> p, int n);  Float32List viewFloat32(...);
  Pointer<NativeFunction<T>> addFunctionOf<T>(Function f, String sig);
  // optional debug guard, used by all of the above in assert builds:
  //   0 <= addr < HEAPU8.buffer.byteLength (see §7 R1 for limits)
}
```

   Implementation is mechanical: each is the body of the existing ambient
   extension (§2.3 lines) with `_lib` replaced by `this`. The ambient
   extensions are re-implemented as one-line delegations to
   `NativeLibrary.instance`, so there is a single source of truth.
4. **Per-module allocation tracking:** key `_heapAllocations` by the
   underlying `JSObject` (e.g. `Map<JSObject, Set<int>>`) so `freePointer`
   consults the right module's set. The ambient `Pointer.free()` keeps its
   membership check, so a cross-module `.free()` becomes a silent no-op
   (leak) rather than a wrong-heap free — strictly safer than today.
5. **Optional:** `static void fromModule(JSObject module)` so callers can pass
   the resolved Emscripten instance directly instead of stashing it on a JS
   global first (§3.4.3).

### 5.2 Generator changes

`writer.dart` template (per-file static + policy-aware init):

```dart
extension type GeneratedBindings(NativeLibrary _) implements JSObject {
  static GeneratedBindings? _instance;
  static GeneratedBindings get instance =>
      _instance ??= NativeLibrary.instance as GeneratedBindings;  // legacy bridge
  static set instance(GeneratedBindings lib) => _instance = lib;

  static void initBindings(String moduleName, {bool makeDefault = true}) {
    final lib = globalContext.getProperty(moduleName.toJS);
    if (lib == null) { throw Exception("Failed to find JS module ${moduleName}"); }
    _instance = lib as GeneratedBindings;
    if (makeDefault) NativeLibrary.setDefault(this.instance);  // first-wins + warn
  }
  ...
}
```

and switch the ambient lookups in emitted code to the file's own instance:

| Template | From | To |
|---|---|---|
| `func.dart:303` | `GeneratedBindings.instance._fn(...)` | unchanged (now per-file) |
| `compound.dart:209,213` | `NativeLibrary.instance.getValue/setValue` | `GeneratedBindings.instance.getValue/setValue` |
| `compound.dart:233` | `NativeLibrary.instance.stackAlloc<T>(n)` | `GeneratedBindings.instance.stackAlloc<T>(n)` |
| `func_type.dart:99` | `NativeLibrary.instance.addFunction<T>(...)` | `GeneratedBindings.instance.addFunction<T>(...)` |
| `global.dart:63` | `NativeLibrary.instance.getValue(GeneratedBindings.instance._x, ...)` | `GeneratedBindings.instance.getValue(GeneratedBindings.instance._x, ...)` |

All target members already exist as instance members on `NativeLibrary`
(§2.1), so this is a pure name change in four templates plus the writer block.
`test/generator_compatibility_test.dart` asserts the current strings and needs
matching updates; add a test that two generated files in one test isolate keep
separate instances.

Recommended follow-up (small, breaking only in the "new name" sense): stop
hardcoding the class name `GeneratedBindings` and use the config `name:` (two
packages both exporting a class literally named `GeneratedBindings` can only
be referenced with import prefixes today).

### 5.3 Backward-compat contract

- **Old generated files + new runtime:** work unchanged — they only touch
  `NativeLibrary.instance`/ambient helpers, which keep their exact semantics.
- **New generated files + old-style init** (`NativeLibrary.initBindings("x")`
  from app code, no generated `initBindings` call): work via the
  `??= NativeLibrary.instance` fallback in `GeneratedBindings.instance`.
- **`NativeLibrary.instance` setter:** semantics unchanged (last-write-wins).
  Only the *generated* `initBindings` gains first-wins-with-warning via
  `makeDefault`, because a second module blindly repointing the ambient
  library is precisely today's corruption bug. Apps that today intentionally
  re-call generated `initBindings` to *swap* modules should instead assign
  `GeneratedBindings.instance = ...` / call `NativeLibrary.setDefault`.
- **Versioning:** ship as `0.0.15-pre`; changelog states that regeneration is
  recommended for multi-module use but not required for single-module use.

### 5.4 Changes in thermion_dart

1. Regenerate `thermion_dart_js_interop.g.dart` with the new generator; pin
   `ffigen_js: ^0.0.15-pre`.
2. `lib/src/bindings/src/js_interop.dart`: replace the
   `_NativeLibrary.instance` singleton reads (`:17-19`, `:197-199` and the
   `NativeLibrary.instance` uses behind helpers) with a package-owned handle,
   e.g. a `ThermionWeb.module` static set by a new public init API. ~0.5 day.
3. Phase 1 shortcut (see §5.7): thermion remains the **ambient/default**
   module, so its ~120 shared-impl call sites (§2.4) need **zero** changes —
   they resolve to thermion's module by policy, as long as thermion inits
   first and rp3d inits with `makeDefault: false`.

### 5.5 Changes in reactphysics3d_dart

1. Regenerate `rp3d_js_interop.g.dart`; pin the new ffigen_js.
2. Migrate the ~40 ambient call sites in 6 files (§2.4) to instance-scoped
   helpers (`lib.toNativeUtf8(...)` etc.), with the package exposing an init
   API (`ReactPhysics3D.init(moduleName: 'reactphysics3d', makeDefault: false)`)
   that stores its `NativeLibrary`. The hand-written
   `bindings/src/js_interop.dart` adapter is the natural home for module-aware
   versions of its `make*List`/view/element helpers, so the shared
   `ffi_*.dart` implementation files change as little as possible (most calls
   already route through that adapter). ~1–1.5 days.
3. Web artifact: `native/web/` now has `module_init.cpp`; build and publish a
   `reactphysics3d_dart.js`/`.wasm` with `EXPORT_NAME=reactphysics3d_dart`,
   the §3.3 runtime-method list, and a reduced `INITIAL_MEMORY` (physics does
   not need 512mb). ~1–2 days including CI.

### 5.6 Downstream app API sketch

```html
<!-- index.html -->
<script src="thermion_dart.js"></script>
<script src="reactphysics3d_dart.js"></script>
<script type="module">
  const [thermion, rp3d] = await Promise.all([thermion_dart(), reactphysics3d_dart()]);
  window.thermion_dart = thermion;     // resolved instances under known names
  window.reactphysics3d = rp3d;
  /* boot dart2wasm main.wasm exactly as today */
</script>
```

```dart
// main.dart (dart2wasm)
// thermion owns the ambient/default slot; physics does not.
await ThermionWeb.init('thermion_dart');                       // makeDefault: true (first-wins)
await ReactPhysics3D.init('reactphysics3d', makeDefault: false);

// from here: thermion's API and rp3d's API are used side by side;
// data crosses between modules only as plain Dart values, e.g.:
final transforms = physicsWorld.readInterpolatedTransforms(); // Float32List view of rp3d heap
for (final e in entities) { viewer.setTransform(e, ...); }     // copied into thermion heap
```

(Low-level equivalent, without package wrappers:
`GeneratedBindings.initBindings('thermion_dart')` from thermion's bindings
import and `initBindings('reactphysics3d', makeDefault: false)` from rp3d's —
the two classes share a name today, so the app needs import prefixes or the
§5.2 class-name fix.)

### 5.7 Phasing

- **Phase 1 (pragmatic, ships the feature):** ffigen_js §5.1–5.3; thermion
  §5.4 items 1–2 + ambient policy; rp3d §5.5 full migration. Thermion keeps
  ambient helpers; correctness depends on init order (thermion first), made
  visible by the repoint warning.
- **Phase 2 (clean end state):** migrate thermion's ~120 ambient call sites to
  instance-scoped helpers, after which no package depends on the ambient
  global and init order is irrelevant. Can land incrementally, file by file.

---

## 6. Effort estimate

| # | Task | Repo | Estimate |
|---|---|---|---|
| 1 | Instance-scoped helpers + default-lib policy + registry + per-module alloc tracking in `types.dart`, with unit tests | ffigen_js | 1.5–2 d |
| 2 | Generator: writer/compound/func_type/global templates + `makeDefault`; update `generator_compatibility_test` | ffigen_js | 0.5–1 d |
| 3 | Two-module acceptance example: second tiny emcc target, both loaded, assert isolation (thermion-pattern loading, not the example's current `IMPORTED_MEMORY` mode) | ffigen_js | 1–1.5 d |
| 4 | README + CHANGELOG + `0.0.15-pre` | ffigen_js | 0.5 d |
| 5 | Regenerate + adapter handle + init API (phase 1) | thermion_dart | 0.5–1 d |
| 6 | Regenerate + migrate ~40 sites + init API | reactphysics3d_dart | 1–1.5 d |
| 7 | rp3d standalone web artifact + CI (EXPORT_NAME, runtime methods, smaller memory) | reactphysics3d_dart | 1–2 d |
| 8 | Gallery/example wiring: load both modules, both inits, physics scene enabled | thermion (examples) | 1 d |
| 9 | Browser integration test (two modules, run frames, no corruption) + single-module regression | thermion | 2–3 d |
| 10 | Phase 2: thermion's ~120 ambient call sites | thermion_dart (deferred) | 2–3 d |

**Total phase 1: ~9–13.5 working days (~2–3 weeks elapsed with review).**
Phase 2 adds ~2–3 days and can trail. This turns the prior doc's coarse
"1.5–3 weeks" into concrete tasks; the 1.5-week end is reachable only by
cutting tasks 3 and 9 (the two-module tests), which is where the risk actually
lives — not recommended.

---

## 7. Risks

- **R1 — silent cross-module pointer misuse remains possible.** `Pointer` is a
  shared `int` type; an in-range address from module A applied to module B
  corrupts silently. The debug guard (address < heap length) only catches
  out-of-range. Mitigations: document; keep the repoint warning; optionally
  extend per-module allocation registries to tag known ranges in assert
  builds. Full compile-time safety is only available under Option B' (forked
  types), which is why B' remains the fallback if R1 incidents appear.
- **R2 — phase-1 init-order dependence** (thermion must be the default
  module). Mitigated by the warning; removed in phase 2.
- **R3 — behavior change for apps that re-call generated `initBindings` to
  swap modules.** They must switch to `GeneratedBindings.instance =` /
  `setDefault` (§5.3). Expected to be rare; called out in the changelog.
- **R4 — memory/thread cost of a second 512mb pthread module.** Mitigate by
  sizing rp3d's `INITIAL_MEMORY` down (its CMake currently copies thermion's
  512mb).
- **R5 — generator output churn** touches every consumer; pinned versions +
  the §5.3 bridge keep old files running, but both packages must regenerate
  in a coordinated release window.

---

## 8. Unknowns to verify (before/at implementation)

1. **dart2wasm + `Zone`**: expected to work (pure Dart) — only relevant if the
   optional `runWith` sugar is built; verify `Zone.current` cost in
   `getValue`/`setValue`-hot paths before relying on it. Not needed for the
   recommended design.
2. **Two `-pthread` Emscripten modules under one COOP/COEP page** across
   target browsers (each spawns its own worker pool; no known shared state —
   but must be tested, task 9).
3. **`Map` keyed by the underlying `JSObject`** for per-module allocation
   tracking (JS reference equality as `==`/hashCode) — expected fine, verify.
4. **rp3d artifact completeness**: `native/web/module_init.cpp` exists on
   master but the artifact build/publish pipeline is new; verify the exported
   symbol list matches §3.3 (and decide whether to add `HEAPU32`).
5. **Exact churn in `func_type.dart`'s generated `addFunction` extensions**
  when two files emit `NativeFunctionPointer$index` extensions that could both
  apply to one closure type at app level (pre-existing quirk, unchanged by
  this design; confirm no new ambiguity after regeneration).
6. **`getProperty` null-check semantics** (`types.dart:464`) for undefined
  globals under dart2wasm — the current `lib == null` check may not fire for
   `undefined`; worth hardening while touching `initBindings` (*verify*).

---

## 9. Implementation status (phase 1, 0.0.15-pre)

Phase 1 (Option A3) is implemented with one deliberate deviation from §5's
config sketch: instead of a new `module: {name: ..., make-default: ...}`
block, the per-module name reuses **ffigen's own `ffi-native: asset-id:`**
config key (same class name `FfiNativeConfig`, same YAML shape as
`package:ffigen`). This keeps ffigen_js config-consistent with ffigen, per
the project constraint; `asset-id` maps to the JS module name (the JS global
holding the resolved Emscripten `Module`), and it is baked into the
generated `initBindings` as its default argument — the analog of ffigen
baking the asset id into `@DefaultAsset`. `makeDefault` stays a runtime
parameter of `init`/`initBindings` rather than a config key, since only the
app knows module load order.

What landed (branch `asb/multi-module-plan`):

- Runtime: `NativeLibrary.init`/`byName`/`setDefault` (first-wins default
  slot), instance-scoped helpers, ambient API unchanged (`types.dart`).
- Generator: per-file `GeneratedBindings.instance` with ambient fallback;
  struct/global/function-pointer emission dispatches through it
  (`writer.dart`, `compound.dart`, `global.dart`, `func_type.dart`).
- Config: `ffi-native: asset-id:` parsed into `FfiNativeConfig` and threaded
  to the writer.
- Verification: `tool/multi_module_smoke` (dart2wasm + node against two fake
  Emscripten modules; same-address/opposite-contents heap isolation),
  legacy-bindings compatibility fixture (`test/fixtures/`), generator
  template tests, regenerated example bindings.

§8.6 is addressed: `_resolveModule` now distinguishes `undefined` from a
module object via `getProperty` null semantics on dart2wasm — validated in
the smoke harness (missing module raises, not silently treated as a library).

Still open for phase 2 (§5.5): rp3d migration (~40 ambient call sites,
`makeDefault: false`), thermion regeneration is optional (existing files
keep working via the ambient fallback).

---

## References

- Prior scoping: thermion `docs/research/web-physics-scope.md`
  (branch `asb/dart-physics-sample-clean`) — established the singleton
  diagnosis, verified two-module JS coexistence, and estimated this work at
  1.5–3 weeks / high risk.
- Emscripten `src/settings.js`, `MODULARIZE`/`EXPORT_NAME` entries — factory
  semantics and explicit multi-instance support (§3.2).
- Consumer builds: `thermion_dart/native/web/CMakeLists.txt:13-29`,
  `reactphysics3d_dart/native/web/CMakeLists.txt:18-34`,
  `ffigen_js/example/build.sh:5-19`.
