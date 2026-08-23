import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

///
/// Sub-classes of [NativeType] represent a "native" type, meaning a
/// type that can be passed to a WASM-compiled native function), and its
/// equivalent Dart representation.
///
/// Most sub-classes are non-constructible; they are only intended to preserve
/// compile-time type information and to translate between native types and
/// their Dart equivalent.
///
/// The exceptions are [Pointer], [Array] and sub-classes of [Struct]; these can be
/// instantiated and returned to the user.
///
/// Sub-classes doesn't necessarily represent a singular WASM type; for example,
/// WASM does not have a char type but we implement a [Char] type to help
/// preserve "native" type information. Without this, [const char*] would only be
/// represented as Pointer<Int64>, and we would have no way of knowing that
/// it can safely be interpreted/converted to a Dart String.
///
///
abstract class NativeType {}

int sizeOf<T extends NativeType>() {
  if (T == Float32 || T == Int32 || T == Uint32 || T == Char || T == Bool) {
    return 4;
  }
  if (T == Float64 || T == Int64) return 8;
  if (T == Int16 || T == Uint16) return 2;
  if (T == Int8 || T == Uint8) return 1;
  if (T == PointerClass) return 4;
  throw UnsupportedError('sizeOf not supported for $T');
}

extension type const Pointer<T extends NativeType>(int addr) implements int {
  const Pointer.fromAddress(int address) : addr = address;
  Pointer<T> operator +(int numElements) => Pointer<T>(this.addr + (numElements * sizeOf<T>()));
  Pointer<U> cast<U extends NativeType>() => this as Pointer<U>;
  void free() => _lib.free(this);

  int get address => addr;
}

// We can't construct Pointer<Pointer> since the generic type <T> must extend
// [NativeType] and Pointer does not itself extend NativeType.
// [PointerClass] represents the same thing as [Pointer] (i.e. an address in
// memory) but implemented as a subclass of [NativeType].
base class PointerClass<T extends NativeType> extends NativeType {
  final Pointer<T> _addr;

  PointerClass._(this._addr);

  String get llvmType => '*';

  static PointerClass<T> stackAlloc<T extends NativeType>(int count) {
    final ptr = _lib._stackAlloc<T>(sizeOf<T>() * count);
    return PointerClass._(ptr);
  }

  PointerClass<T> operator +(int numElements) =>
      PointerClass<T>._(Pointer<T>(this._addr.addr + (numElements * 4)));
  PointerClass<U> cast<U extends NativeType>() => this as PointerClass<U>;

  static Pointer<PointerClass<T>> allocArray<T extends NativeType>(int count) {
    return Pointer<PointerClass<T>>(
      _lib._stackAlloc<PointerClass<T>>(4 * count).addr,
    );
  }
}

abstract class Null extends NativeType {}

Pointer<NativeFunction<T>> addFunction<T>(JSFunction fn, String signature) {
  return _lib.addFunction(fn, signature);
}

abstract class Char extends NativeType {
  static Pointer<Char> stackAlloc(int count) {
    return Pointer<Char>(_lib._stackAlloc<Char>(4 * count));
  }
}

abstract class Bool extends NativeType {
  static Pointer<Bool> stackAlloc(int count) {
    return Pointer<Bool>(_lib._stackAlloc<Char>(4 * count));
  }
}

abstract class Uint32 extends NativeType {
  static Pointer<Uint32> stackAlloc(int count) {
    return _lib._stackAlloc<Uint32>(4 * count);
  }
}

abstract class Uint8 extends NativeType {
  static Pointer<Uint8> stackAlloc(int count) {
    return _lib._stackAlloc<Uint8>(count);
  }
}

abstract class Int8 extends NativeType {
  static Pointer<Int8> stackAlloc(int count) {
    return _lib._stackAlloc<Int8>(count);
  }
}

abstract class Uint16 extends NativeType {
  static Pointer<Uint16> stackAlloc(int count) {
    return _lib._stackAlloc<Uint16>(2 * count);
  }
}

abstract class Int16 extends NativeType {
  static Pointer<Int16> stackAlloc(int count) {
    return _lib._stackAlloc<Int16>(2 * count);
  }
}

abstract class Int32 extends NativeType {
  static Pointer<Int32> stackAlloc(int count) {
    return _lib._stackAlloc<Int32>(4 * count);
  }
}

abstract class Int64 extends NativeType {
  static Pointer<Int64> stackAlloc(int count) {
    return _lib._stackAlloc<Int64>(8 * count);
  }
}

abstract class Float32 extends NativeType {
  static Pointer<Float32> stackAlloc(int count) {
    return _lib._stackAlloc<Float32>(4 * count);
  }
}

abstract class Float64 extends NativeType {
  static Pointer<Float64> stackAlloc(int count) {
    return _lib._stackAlloc<Float64>(8 * count);
  }
}

abstract class NativeFunction<T> extends NativeType {}

abstract class Void extends NativeType {}

Pointer<Never> nullptr = Pointer<Never>(0);

extension PointerPointerClass<T extends NativeType> on Pointer<PointerClass<T>> {
  Pointer<T> operator [](int i) {
    return Pointer<T>(
      _lib.getValue(Pointer<PointerClass<T>>(this.addr + (i * 4)), 'i32').toDartInt,
    );
  }

  void operator []=(int i, Pointer<T> value) {
    _lib.setValue(
      Pointer<PointerClass<T>>(this.addr + (i * 4)),
      value.addr.toJS,
      'i32',
    );
  }
}

extension VoidPointerClass on Pointer<Void> {
  String get llvmType => 'v';

  static Pointer<Void> fromAddress(int addr) => Pointer<Void>(addr);
}

extension Int32PointerClass on Pointer<Int32> {
  String get llvmType => 'i32';

  void setValue(int value) {
    _lib.setValue(this, value.toJS, llvmType);
  }

  int getValue() {
    return _lib.getValue(this, llvmType).toDartInt;
  }

  static Pointer<Int32> fromAddress(int addr) => Pointer<Int32>(addr);
}

extension Int64Pointer on Pointer<Int64> {
  String get llvmType => 'i64';

  void setValue(int value) {
    _lib.setValue(this, value.toJS, llvmType);
  }

  int getValue() {
    return _lib.getValue(this, llvmType).toDartInt;
  }

  static Pointer<Int64> fromAddress(int addr) => Pointer<Int64>(addr);
}

extension Float32Pointer on Pointer<Float32> {
  String get llvmType => 'float';

  void setValue(double value) {
    _lib.setValue(this, value.toJS, llvmType);
  }

  double get value {
    return getValue();
  }

  double getValue() {
    return _lib.getValue(this, llvmType).toDartDouble;
  }

  double operator [](int i) {
    return _lib.getValue(this + i, 'f').toDartDouble;
  }

  operator []=(int i, double val) {
    _lib.setValue(this + i, val.toJS, 'f');
  }

  static Pointer<Float32> fromAddress(int addr) => Pointer<Float32>(addr);
}

extension Float64Pointer on Pointer<Float64> {
  String get llvmType => 'double';

  void setValue(double value) {
    _lib.setValue(this, value.toJS, llvmType);
  }

  double getValue() {
    return _lib.getValue(this, llvmType).toDartDouble;
  }

  static Pointer<Float64> fromAddress(int addr) => Pointer<Float64>(addr);
}

extension StringUtils on String {
  Pointer<Char> toNativeUtf8() => NativeLibrary.instance.toNativeUtf8(this);
}

extension CharPtr on Pointer<Char> {
  void setValue(String value) =>
      NativeLibrary.instance.setNativeUtf8(this, value);

  String toDartString() => NativeLibrary.instance.utf8ToString(this);

  static Pointer<Char> fromAddress(int addr) => Pointer<Char>(addr);
}

extension DisposePointerClass<T extends NativeType> on Pointer<NativeFunction> {
  void dispose() {
    _lib.removeFunction(this);
  }
}

extension type const Array<T extends NativeType>(({int numElements, Pointer<T> addr}) internal) {
  Array<U> cast<U extends NativeType>() => this as Array<U>;

  Uint8List asUint8List() {
    final start = internal.addr;
    final end = internal.addr.addr + internal.numElements;

    return Uint8List.sublistView(_lib.HEAPU8.toDart, start.addr, end);
  }

  void setValue(Uint8List data) {
    _lib.writeArrayToMemory(data.toJS, internal.addr);
  }
}

extension ArrayInt32Ext on Array<Int32> {
  int operator [](int i) {
    return _lib.getValue(internal.addr + i, 'i32').toDartInt;
  }

  void operator []=(int i, int v) {
    _lib.setValue(internal.addr + i, v.toJS, 'i32');
  }
}

extension ArrayFloat32Ext on Array<Float32> {
  double operator [](int i) {
    return _lib.getValue(internal.addr + i, 'double').toDartDouble;
  }

  void operator []=(int i, double v) {
    _lib.setValue(internal.addr + i, v.toJS, 'double');
  }
}

extension ArrayFloat64Ext on Array<Float64> {
  double operator [](int i) {
    return _lib.getValue(internal.addr + i, 'double').toDartDouble;
  }

  void operator []=(int i, double v) {
    _lib.setValue(internal.addr + i, v.toJS, 'double');
  }
}

late NativeLibrary _lib;

/// Allocates [numBytes] from the ambient module's malloc heap.
///
/// The returned pointer is tracked so [free] (and `Pointer.free`) can
/// release it. For explicit per-module allocation use the library handle
/// returned by [NativeLibrary.init].
Pointer<T> malloc<T extends NativeType>(int numBytes) =>
    NativeLibrary.instance.malloc<T>(numBytes);

/// Allocates [numBytes] on the ambient module's Emscripten stack.
Pointer<T> stackAlloc<T extends NativeType>(int numBytes) =>
    NativeLibrary.instance.stackAlloc<T>(numBytes);

void free(Pointer ptr) {
  ptr.free();
}

@JS('BigInt')
external JSBigInt bigInt(String s);

@JS('BigInt.asUintN')
external JSBigInt bigIntasUintN(int numBits, JSBigInt bi);

extension JSBigIntExtension on JSBigInt {
  BigInt get toDart {
    return BigInt.parse(this.toString());
  }
}

extension BigIntExtension on int {
  JSBigInt get toJSBigInt {
    return bigInt(this.toString());
  }
}

extension DartBigIntExtension on BigInt {
  JSBigInt get toJSBigInt {
    return bigInt(this.toString());
  }
}

Uint8List makeUint8List(int length) =>
    NativeLibrary.instance.makeUint8List(length);

Int16List makeInt16List(int length) =>
    NativeLibrary.instance.makeInt16List(length);

Uint16List makeUint16List(int length) =>
    NativeLibrary.instance.makeUint16List(length);

IntPtrList makeIntPtrList(int length) => makeInt32List(length);

Uint32List makeUint32List(int length) =>
    NativeLibrary.instance.makeUint32List(length);

Int32List makeInt32List(int length) =>
    NativeLibrary.instance.makeInt32List(length);

Int64List makeInt64List(int length) =>
    NativeLibrary.instance.makeInt64List(length);

Float32List makeFloat32List(int length) =>
    NativeLibrary.instance.makeFloat32List(length);

Float64List makeFloat64List(int length) =>
    NativeLibrary.instance.makeFloat64List(length);

extension TypedDataExtension<T> on TypedData {
  /// Releases the backing allocation only when this view was created from a
  /// tracked `malloc` pointer. This does not reclaim the stack allocation used
  /// by `make*List`; restore the corresponding Emscripten stack marker instead.
  void free() {
    Pointer<Void>(this.offsetInBytes).free();
  }

  Uint8List asUint8List() {
    if (this is Int32List) {
      return (this as Int32List).asUint8List();
    }

    if (this is Uint32List) {
      return (this as Uint32List).asUint8List();
    }

    if (this is Int16List) {
      return (this as Int16List).asUint8List();
    }

    if (this is Uint16List) {
      return (this as Uint16List).asUint8List();
    }

    if (this is Float32List) {
      return (this as Float32List).asUint8List();
    }
    if (this is Int64List) {
      return (this as Int64List).asUint8List();
    }
    if (this is Float64List) {
      return (this as Float64List).asUint8List();
    }
    throw UnimplementedError();
  }
}

extension type NativeLibrary(JSObject _) implements JSObject {
  /// The ambient/default library, shared by the extension-based helpers
  /// below (`String.toNativeUtf8`, `.address`, `makeFloat32List`, ...).
  ///
  /// Kept for backward compatibility with single-module apps and with
  /// bindings files generated before per-module support. Multi-module pages
  /// should prefer [init] plus the instance-scoped helpers.
  static NativeLibrary get instance => _lib;

  /// Re-points the ambient library ([instance]) at [lib].
  ///
  /// Last-write wins, exactly as in previous versions; nothing is
  /// registered. For the first-wins default-slot policy used by [init] see
  /// [setDefault].
  static set instance(NativeLibrary lib) {
    _lib = lib;
  }

  /// Initializes the ambient library from the JS global [moduleName].
  ///
  /// Legacy single-module entry point; unchanged from previous versions.
  /// New code (and regenerated bindings) should use [init] instead.
  static void initBindings(String moduleName) {
    _lib = _resolveModule(moduleName);
  }

  /// Registry of libraries initialized via [init], keyed by module name.
  ///
  /// A module name is ffigen_js's analog of ffigen's `ffi-native:
  /// asset-id` config (`package:ffigen`'s `NativeExternalBindings`): the
  /// string identifying which loaded native library a set of bindings
  /// resolves against. Where ffigen resolves an asset id through the native
  /// assets machinery at load time, ffigen_js resolves a module name by
  /// reading a JS global of that name - the resolved Emscripten `Module`
  /// instance stashed there by the page (e.g.
  /// `window.thermion_dart = await thermion_dart()`).
  static final Map<String, NativeLibrary> _modules = {};

  static NativeLibrary? _defaultLib;

  /// Initializes (or returns the already-initialized) library for
  /// [moduleName] and registers it under that name.
  ///
  /// This is the ffigen_js counterpart of constructing ffigen's
  /// `DynamicLibraryBindings` wrapper (`NativeLibrary(DynamicLibrary)`): it
  /// resolves the library and returns a handle whose instance-scoped helpers
  /// ([malloc], [toNativeUtf8], [makeFloat32List], [addressOf], ...) operate
  /// on that module's heap only. Two modules on one page are two [init]
  /// calls with different names.
  ///
  /// If [makeDefault] is true (the default), the module also claims the
  /// ambient/default slot ([instance]) used by the legacy extension-based
  /// helpers. The FIRST module initialized with `makeDefault: true` keeps
  /// that slot; a later `makeDefault: true` for a different module is
  /// ignored with a warning instead of silently re-pointing every ambient
  /// helper at the wrong heap. Initialize secondary modules with
  /// `makeDefault: false`.
  static NativeLibrary init(String moduleName, {bool makeDefault = true}) {
    final lib = _modules[moduleName] ?? _resolveModule(moduleName);
    _modules[moduleName] = lib;
    if (makeDefault) setDefault(lib);
    return lib;
  }

  /// Returns the library registered under [moduleName] by [init].
  static NativeLibrary byName(String moduleName) {
    final lib = _modules[moduleName];
    if (lib == null) {
      throw StateError(
          "No JS module registered under the name '$moduleName'. "
          'Call NativeLibrary.init(...) first.');
    }
    return lib;
  }

  /// Makes [lib] the ambient/default module for the legacy helpers.
  ///
  /// First module wins: if a different module already holds the default
  /// slot, this call is ignored with a warning rather than re-pointing the
  /// ambient helpers at another heap. To deliberately change the default at
  /// runtime, assign [instance] instead.
  static void setDefault(NativeLibrary lib) {
    final incumbent = _defaultLib;
    if (incumbent != null && !_objectIs(incumbent, lib)) {
      developer.log(
        "NativeLibrary.setDefault ignored: the ambient/default module is "
        'already claimed by a different module. Initialize secondary modules '
        "with 'makeDefault: false' (or assign NativeLibrary.instance to "
        'switch deliberately).',
        name: 'ffigen_js',
        level: 900, // WARNING
      );
      return;
    }
    _defaultLib = lib;
    _lib = lib;
  }

  static NativeLibrary _resolveModule(String moduleName) {
    final lib = globalContext.getProperty(moduleName.toJS);
    if (lib == null) {
      throw Exception("Failed to find JS module '$moduleName'");
    }
    return lib as NativeLibrary;
  }

  @JS('stackAlloc')
  external Pointer<T> _stackAlloc<T extends NativeType>(int numBytes);

  Pointer<T> stackAlloc<T extends NativeType>(int numBytes) {
    return _stackAlloc<T>(numBytes);
  }

  external Pointer<T> _malloc<T extends NativeType>(int numBytes);

  external void _free(Pointer ptr);

  @JS('stackSave')
  external Pointer<Void> stackSave();

  @JS('stackRestore')
  external void stackRestore(Pointer<Void> ptr);

  @JS('getValue')
  external JSBigInt getValueBigInt(Pointer addr, String llvmType);
  external JSNumber getValue(Pointer addr, String llvmType);
  external void setValue(Pointer addr, JSNumber value, String llvmType);

  @JS("lengthBytesUTF8")
  external int _lengthBytesUTF8(String str);

  @JS("UTF8ToString")
  external String _UTF8ToString(Pointer<Char> ptr);

  @JS("stringToUTF8")
  external void _stringToUTF8(
    String str,
    Pointer<Char> ptr,
    int maxBytesToWrite,
  );

  external void writeArrayToMemory(JSUint8Array data, Pointer ptr);

  external Pointer<NativeFunction<T>> addFunction<T>(
    JSFunction f,
    String signature,
  );
  external void removeFunction<T>(Pointer<NativeFunction<T>> f);
  external JSUint8Array get HEAPU8;
  external JSUint32Array get HEAPU32;
  external JSFloat32Array get HEAPF32;

  // ignore: unused_element, non_constant_identifier_names
  external int _emscripten_stack_get_base();
  // ignore: non_constant_identifier_names, unused_element
  external Pointer _emscripten_stack_get_current();
  // ignore: non_constant_identifier_names, unused_element
  external int _emscripten_stack_get_free();

  // -------------------------------------------------------------------------
  // Instance-scoped (per-module) helpers.
  //
  // These mirror the ambient library-wide helpers exported by this file
  // (`String.toNativeUtf8`, `makeFloat32List`, `TypedData.address`,
  // `Pointer.asTypedList`, ...) but always operate on THIS module's heap.
  // The ambient helpers are one-line delegations to these, so there is a
  // single source of truth. Hand-written code that runs while more than one
  // module is loaded should call these through the library handle obtained
  // from [init] (e.g. `NativeLibrary.byName('my_module').makeFloat32List(n)`)
  // instead of the ambient extensions.
  // -------------------------------------------------------------------------

  /// Allocates [numBytes] from this module's malloc heap.
  ///
  /// The returned pointer is tracked so that [free] (and the ambient
  /// `Pointer.free`) can release it.
  Pointer<T> malloc<T extends NativeType>(int numBytes) {
    final ptr = _malloc<T>(numBytes);
    _heapAllocations.add(ptr);
    return ptr;
  }

  /// Releases a pointer allocated by [malloc] (or the heap copy created by
  /// [addressOf] for large values).
  ///
  /// Untracked pointers - e.g. Emscripten stack allocations returned by
  /// [stackAlloc] and the `make*List` helpers - are ignored rather than
  /// passed to the module's free, mirroring `Pointer.free`. Restore the
  /// stack with [stackRestore] to reclaim those.
  void free(Pointer ptr) {
    if (_heapAllocations.contains(ptr)) {
      _heapAllocations.remove(ptr);
      _free(ptr);
    }
  }

  /// Copies [str] into this module's heap as a NUL-terminated UTF-8 string.
  Pointer<Char> toNativeUtf8(String str) {
    var len = _lengthBytesUTF8(str) + 1;
    var ptr = _stackAlloc<Char>(4 * len);
    _stringToUTF8(str, ptr, len);
    return ptr;
  }

  /// Reads a NUL-terminated UTF-8 string from this module's heap.
  String utf8ToString(Pointer<Char> ptr) => _UTF8ToString(ptr);

  /// Writes [value] to the UTF-8 string buffer [ptr] in this module's heap.
  void setNativeUtf8(Pointer<Char> ptr, String value) {
    var len = _lengthBytesUTF8(value);
    _stringToUTF8(value, ptr, len);
  }

  /// Allocates a [Uint8List] view over this module's Emscripten stack.
  Uint8List makeUint8List(int length) {
    var ptr = _stackAlloc<Uint8>(length);
    var wrapper = Uint8ArrayWrapper(HEAPU8.buffer, ptr, length) as JSUint8Array;
    return wrapper.toDart;
  }

  /// Allocates an [Int16List] view over this module's Emscripten stack.
  Int16List makeInt16List(int length) {
    var ptr = _stackAlloc<Int16>(length * 2);
    var wrapper = Int16ArrayWrapper(HEAPU8.buffer, ptr, length) as JSInt16Array;
    return wrapper.toDart;
  }

  /// Allocates a [Uint16List] view over this module's Emscripten stack.
  Uint16List makeUint16List(int length) {
    var ptr = _stackAlloc<Uint16>(length * 2);
    var wrapper =
        Uint16ArrayWrapper(HEAPU8.buffer, ptr, length) as JSUint16Array;
    return wrapper.toDart;
  }

  /// Allocates a [Uint32List] view over this module's Emscripten stack.
  Uint32List makeUint32List(int length) {
    var ptr = _stackAlloc<Uint32>(length * 4);
    var wrapper =
        Uint32ArrayWrapper(HEAPU8.buffer, ptr, length) as JSUint32Array;
    return wrapper.toDart;
  }

  /// Allocates an [Int32List] view over this module's Emscripten stack.
  Int32List makeInt32List(int length) {
    var ptr = _stackAlloc<Int32>(length * 4);
    var wrapper = Int32ArrayWrapper(HEAPU8.buffer, ptr, length) as JSInt32Array;
    return wrapper.toDart;
  }

  /// Allocates an [IntPtrList] view over this module's Emscripten stack.
  IntPtrList makeIntPtrList(int length) => makeInt32List(length);

  /// Allocates an [Int64List] view over this module's Emscripten stack.
  Int64List makeInt64List(int length) {
    var ptr = _stackAlloc<Int64>(length * 8);
    final bytes = viewUint8(ptr.cast<Uint8>(), length * 8);
    return bytes.buffer.asInt64List(bytes.offsetInBytes, length);
  }

  /// Allocates a [Float32List] view over this module's Emscripten stack.
  Float32List makeFloat32List(int length) {
    var ptr = _stackAlloc<Float32>(length * 4);
    var wrapper =
        Float32ArrayWrapper(HEAPU8.buffer, ptr, length) as JSFloat32Array;
    return wrapper.toDart;
  }

  /// Allocates a [Float64List] view over this module's Emscripten stack.
  Float64List makeFloat64List(int length) {
    var ptr = _stackAlloc<Float64>(length * 8);
    var wrapper =
        Float64ArrayWrapper(HEAPU8.buffer, ptr, length) as JSFloat64Array;
    return wrapper.toDart;
  }

  /// Views [length] bytes of this module's heap at [ptr] as a [Uint8List].
  Uint8List viewUint8(Pointer<Uint8> ptr, int length) {
    final wrapper =
        Uint8ArrayWrapper(HEAPU8.buffer, ptr.addr, length) as JSUint8Array;
    return wrapper.toDart;
  }

  /// Views [length] elements of this module's heap at [ptr] as a
  /// [Uint32List].
  Uint32List viewUint32(Pointer<Uint32> ptr, int length) {
    final wrapper =
        Uint32ArrayWrapper(HEAPU8.buffer, ptr.addr, length) as JSUint32Array;
    return wrapper.toDart;
  }

  /// Views [length] elements of this module's heap at [ptr] as a
  /// [Float32List].
  Float32List viewFloat32(Pointer<Float32> ptr, int length) {
    final wrapper =
        Float32ArrayWrapper(HEAPF32.buffer, ptr.addr, length) as JSFloat32Array;
    return wrapper.toDart;
  }

  /// Returns [data]'s address in this module's heap, allocating (and, when
  /// needed, copying) if [data] is not already backed by this heap.
  ///
  /// Mirrors the ambient `TypedData.address` extensions. Values already
  /// backed by THIS module's heap keep their existing address; values backed
  /// by plain Dart memory or by ANOTHER module's heap are copied into this
  /// heap, so it is safe to call across modules. Values of at least 32 KiB
  /// are malloc-backed (released with [free]) and smaller ones are
  /// stack-backed, matching the ambient behavior.
  Pointer<T> addressOf<T extends NativeType>(TypedData data) {
    switch (data) {
      case final Uint8List list:
        final heapAddress = _wasmHeapAddress<T>(this, data, list.toJS);
        if (heapAddress != null) return heapAddress;
        final ptr = _allocFor<T>(data);
        (Uint8ArrayWrapper(HEAPU8.buffer, ptr, list.length) as JSUint8Array)
            .toDart
            .setRange(0, list.length, list);
        return ptr;
      case final Int16List list:
        final heapAddress = _wasmHeapAddress<T>(this, data, list.toJS);
        if (heapAddress != null) return heapAddress;
        final ptr = _allocFor<T>(data);
        (Int16ArrayWrapper(HEAPU8.buffer, ptr, list.length) as JSInt16Array)
            .toDart
            .setRange(0, list.length, list);
        return ptr;
      case final Uint16List list:
        final heapAddress = _wasmHeapAddress<T>(this, data, list.toJS);
        if (heapAddress != null) return heapAddress;
        final ptr = _allocFor<T>(data);
        (Uint16ArrayWrapper(HEAPU8.buffer, ptr, list.length) as JSUint16Array)
            .toDart
            .setRange(0, list.length, list);
        return ptr;
      case final Uint32List list:
        final heapAddress = _wasmHeapAddress<T>(this, data, list.toJS);
        if (heapAddress != null) return heapAddress;
        final ptr = _allocFor<T>(data);
        (Uint32ArrayWrapper(HEAPU8.buffer, ptr, list.length) as JSUint32Array)
            .toDart
            .setRange(0, list.length, list);
        return ptr;
      case final Int32List list:
        final heapAddress = _wasmHeapAddress<T>(this, data, list.toJS);
        if (heapAddress != null) return heapAddress;
        final ptr = _allocFor<T>(data);
        (Int32ArrayWrapper(HEAPU8.buffer, ptr, list.length) as JSInt32Array)
            .toDart
            .setRange(0, list.length, list);
        return ptr;
      case final Int64List list:
        final bytes =
            list.buffer.asUint8List(list.offsetInBytes, list.lengthInBytes);
        final heapAddress = _wasmHeapAddress<T>(this, data, bytes.toJS);
        if (heapAddress != null) return heapAddress;
        final ptr = _allocFor<T>(data);
        viewUint8(ptr.cast<Uint8>(), list.lengthInBytes).setAll(0, bytes);
        return ptr;
      case final Float32List list:
        final heapAddress = _wasmHeapAddress<T>(this, data, list.toJS);
        if (heapAddress != null) return heapAddress;
        final ptr = _allocFor<T>(data);
        (Float32ArrayWrapper(HEAPU8.buffer, ptr, list.length)
                as JSFloat32Array)
            .toDart
            .setRange(0, list.length, list);
        return ptr;
      case final Float64List list:
        final heapAddress = _wasmHeapAddress<T>(this, data, list.toJS);
        if (heapAddress != null) return heapAddress;
        final ptr = _allocFor<T>(data);
        (Float64ArrayWrapper(HEAPU8.buffer, ptr, list.length)
                as JSFloat64Array)
            .toDart
            .setRange(0, list.length, list);
        return ptr;
      default:
        throw UnimplementedError(
            'addressOf is not supported for ${data.runtimeType}');
    }
  }

  /// Allocates memory for [data]: on this module's stack when small, from
  /// this module's malloc heap (tracked, see [free]) when large.
  Pointer<T> _allocFor<T extends NativeType>(TypedData data) {
    if (data.lengthInBytes < 32 * 1024) {
      return _stackAlloc<T>(data.lengthInBytes);
    }
    return malloc<T>(data.lengthInBytes);
  }
}

abstract base class Struct extends NativeType {
  final Pointer _address;
  Pointer get address => _address;

  Struct(this._address);

  static T create<T extends Struct>() {
    throw UnimplementedError();
  }
}

abstract base class Union extends NativeType {
  final Pointer _address;
  Pointer get address => _address;

  Union(this._address);
}

final _heapAllocations = <Pointer>{};

extension JSUint8BackingBuffer on JSUint8Array {
  @JS('buffer')
  external JSObject buffer;
  @JS('byteOffset')
  external int byteOffset;
}

extension JSFloat32BackingBuffer on JSFloat32Array {
  @JS('buffer')
  external JSObject buffer;
  @JS('byteOffset')
  external int byteOffset;
}

extension JSUint16BackingBuffer on JSUint16Array {
  @JS('byteOffset')
  external int byteOffset;
}

extension JSInt32BackingBuffer on JSInt32Array {
  @JS('byteOffset')
  external int byteOffset;
}

extension JSUint32BackingBuffer on JSUint32Array {
  @JS('byteOffset')
  external int byteOffset;
}

extension type _JSTypedArrayView._(JSObject _) implements JSObject {
  @JS('buffer')
  external JSObject get buffer;
  @JS('byteOffset')
  external int get byteOffset;
}

@JS('Object.is')
external bool _objectIs(JSObject a, JSObject b);

/// Returns [data]'s existing address in [lib]'s heap, if it is already
/// backed by that heap.
///
/// Checking the backing buffer also recognizes views derived from an
/// allocated list, such as `floatList.asUint8List()`.
Pointer<T>? _wasmHeapAddress<T extends NativeType>(
    NativeLibrary lib, TypedData data, JSObject jsArray) {
  if (data.lengthInBytes == 0) {
    return Pointer<T>(0);
  }
  final view = _JSTypedArrayView._(jsArray);
  if (_objectIs(view.buffer, lib.HEAPU8.buffer)) {
    return Pointer<T>(view.byteOffset);
  }
  return null;
}

@JS('Uint8Array')
extension type Uint8ArrayWrapper._(JSObject _) implements JSObject {
  external Uint8ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Int8Array')
extension type Int8ArrayWrapper._(JSObject _) implements JSObject {
  external Int8ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Uint16Array')
extension type Uint16ArrayWrapper._(JSObject _) implements JSObject {
  external Uint16ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Int16Array')
extension type Int16ArrayWrapper._(JSObject _) implements JSObject {
  external Int16ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Uint32Array')
extension type Uint32ArrayWrapper._(JSObject _) implements JSObject {
  external Uint32ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Int32Array')
extension type Int32ArrayWrapper._(JSObject _) implements JSObject {
  external Int32ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Float32Array')
extension type Float32ArrayWrapper._(JSObject _) implements JSObject {
  external Float32ArrayWrapper(JSObject buffer, int offset, int length);
}
@JS('Float64Array')
extension type Float64ArrayWrapper._(JSObject _) implements JSObject {
  external Float64ArrayWrapper(JSObject buffer, int offset, int length);
}

extension Uint8ListExtension on Uint8List {
  /// Address of this view in the *ambient* module's heap. When several
  /// modules are loaded, call the instance-scoped `addressOf` on the
  /// right [NativeLibrary] (from [NativeLibrary.init]) instead.
  Pointer<Uint8> get address =>
      NativeLibrary.instance.addressOf<Uint8>(this);
}

extension Float32ListExtension on Float32List {
  /// Address of this view in the *ambient* module's heap. When several
  /// modules are loaded, call the instance-scoped `addressOf` on the
  /// right [NativeLibrary] (from [NativeLibrary.init]) instead.
  Pointer<Float32> get address =>
      NativeLibrary.instance.addressOf<Float32>(this);

  Uint8List asUint8List() {
    return address.cast<Uint8>().asTypedList(lengthInBytes);
  }
}

extension Int16ListExtension on Int16List {
  /// Address of this view in the *ambient* module's heap. When several
  /// modules are loaded, call the instance-scoped `addressOf` on the
  /// right [NativeLibrary] (from [NativeLibrary.init]) instead.
  Pointer<Int16> get address =>
      NativeLibrary.instance.addressOf<Int16>(this);

  Uint8List asUint8List() {
    return address.cast<Uint8>().asTypedList(lengthInBytes);
  }
}

extension Uint16ListExtension on Uint16List {
  /// Address of this view in the *ambient* module's heap. When several
  /// modules are loaded, call the instance-scoped `addressOf` on the
  /// right [NativeLibrary] (from [NativeLibrary.init]) instead.
  Pointer<Uint16> get address =>
      NativeLibrary.instance.addressOf<Uint16>(this);

  Uint8List asUint8List() {
    return address.cast<Uint8>().asTypedList(lengthInBytes);
  }
}

extension UInt32ListExtension on Uint32List {
  /// Address of this view in the *ambient* module's heap. When several
  /// modules are loaded, call the instance-scoped `addressOf` on the
  /// right [NativeLibrary] (from [NativeLibrary.init]) instead.
  Pointer<Uint32> get address =>
      NativeLibrary.instance.addressOf<Uint32>(this);

  Uint8List asUint8List() {
    return address.cast<Uint8>().asTypedList(lengthInBytes);
  }
}

extension Int32ListExtension on Int32List {
  /// Address of this view in the *ambient* module's heap. When several
  /// modules are loaded, call the instance-scoped `addressOf` on the
  /// right [NativeLibrary] (from [NativeLibrary.init]) instead.
  Pointer<Int32> get address =>
      NativeLibrary.instance.addressOf<Int32>(this);

  Uint8List asUint8List() {
    return address.cast<Uint8>().asTypedList(lengthInBytes);
  }
}

extension Int64ListExtension on Int64List {
  /// Address of this view in the *ambient* module's heap. When several
  /// modules are loaded, call the instance-scoped `addressOf` on the
  /// right [NativeLibrary] (from [NativeLibrary.init]) instead.
  Pointer<Int64> get address =>
      NativeLibrary.instance.addressOf<Int64>(this);

  Uint8List asUint8List() {
    return address.cast<Uint8>().asTypedList(lengthInBytes);
  }
}

extension Float64ListExtension on Float64List {
  /// Address of this view in the *ambient* module's heap. When several
  /// modules are loaded, call the instance-scoped `addressOf` on the
  /// right [NativeLibrary] (from [NativeLibrary.init]) instead.
  Pointer<Float64> get address =>
      NativeLibrary.instance.addressOf<Float64>(this);

  Uint8List asUint8List() {
    return address.cast<Uint8>().asTypedList(lengthInBytes);
  }
}

extension AsUint8List on Pointer<Uint8> {
  Uint8List asTypedList(int length) =>
      NativeLibrary.instance.viewUint8(this, length);
}

extension AsUint32List on Pointer<Uint32> {
  Uint32List asTypedList(int length) =>
      NativeLibrary.instance.viewUint32(this, length);
}

extension AsFloat32List on Pointer<Float> {
  Float32List asTypedList(int length) =>
      NativeLibrary.instance.viewFloat32(cast<Float32>(), length);
}

typedef IntPtrList = Int32List;
typedef Utf8 = Char;
typedef Float = Float32;
typedef Double = Float64;

/// Registry of struct sizes (in bytes).
/// Populated by the generated bindings class during initialization.
/// Used by calloc-like allocators that need to know struct sizes at runtime.
final Map<Type, int> structSizeRegistry = {};
