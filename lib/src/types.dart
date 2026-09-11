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

final class _DeferredTypedDataPointer {
  final TypedData data;
  final int additionalByteOffset;

  const _DeferredTypedDataPointer(this.data, this.additionalByteOffset);
}

/// A pointer passed to or returned from Wasm.
///
/// Raw pointers are represented by a JavaScript number. A TypedData `address`
/// is represented by a boxed Dart descriptor until a generated function
/// wrapper materializes it for the duration of the native call.
extension type Pointer<T extends NativeType>._(JSAny _value) implements JSAny {
  Pointer(int address) : this._(address.toJS);
  Pointer.fromAddress(int address) : this(address);

  Pointer._fromTypedData(TypedData data)
      : this._(_DeferredTypedDataPointer(data, 0).toJSBox);

  Pointer._fromDeferred(_DeferredTypedDataPointer pointer)
      : this._(pointer.toJSBox);

  bool get _isDeferred => !_value.typeofEquals('number');

  _DeferredTypedDataPointer get _deferred =>
      (_value as JSBoxedDartObject).toDart as _DeferredTypedDataPointer;

  int get addr {
    if (_isDeferred) {
      throw StateError(
        'A TypedData address is only available during a generated native call.',
      );
    }
    return (_value as JSNumber).toDartInt;
  }

  Pointer<T> operator +(int numElements) {
    final byteOffset = numElements * sizeOf<T>();
    if (!_isDeferred) return Pointer<T>(addr + byteOffset);
    final deferred = _deferred;
    return Pointer<T>._fromDeferred(
      _DeferredTypedDataPointer(
        deferred.data,
        deferred.additionalByteOffset + byteOffset,
      ),
    );
  }

  Pointer<U> cast<U extends NativeType>() => Pointer<U>._(_value);

  void free() {
    final address = addr;
    if (_heapAllocations.remove(address)) {
      _lib._free(this);
    }
  }

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
    return _lib._stackAlloc<Char>(4 * count);
  }
}

abstract class Bool extends NativeType {
  static Pointer<Bool> stackAlloc(int count) {
    return _lib._stackAlloc<Char>(4 * count).cast();
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

extension PointerPointerClass<T extends NativeType>
    on Pointer<PointerClass<T>> {
  Pointer<T> operator [](int i) {
    return Pointer<T>(
      _lib
          .getValue(Pointer<PointerClass<T>>(this.addr + (i * 4)), 'i32')
          .toDartInt,
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
  Pointer<Char> toNativeUtf8() {
    var len = _lib._lengthBytesUTF8(this) + 1;
    var ptr = Char.stackAlloc(len);
    _lib._stringToUTF8(this, ptr, len);
    return ptr;
  }
}

extension CharPtr on Pointer<Char> {
  void setValue(String value) {
    var len = _lib._lengthBytesUTF8(value);
    _lib._stringToUTF8(value, this, len);
  }

  String toDartString() {
    return _lib._UTF8ToString(this);
  }

  static Pointer<Char> fromAddress(int addr) => Pointer<Char>(addr);
}

extension DisposePointerClass<T extends NativeType> on Pointer<NativeFunction> {
  void dispose() {
    _lib.removeFunction(this);
  }
}

extension type const Array<T extends NativeType>(
    ({int numElements, Pointer<T> addr}) internal) {
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

Pointer<T> malloc<T extends NativeType>(int numBytes) {
  final pointer = _lib._malloc<T>(numBytes);
  _heapAllocations.add(pointer.addr);
  return pointer;
}

Pointer<T> stackAlloc<T extends NativeType>(int numBytes) {
  final ptr = _lib._stackAlloc<T>(numBytes);
  return ptr;
}

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

Uint8List makeUint8List(int length) {
  var ptr = stackAlloc<Uint8>(length);
  var wrapper =
      Uint8ArrayWrapper(_lib.HEAPU8.buffer, ptr.addr, length) as JSUint8Array;
  var uint8List = wrapper.toDart;
  return uint8List;
}

Int16List makeInt16List(int length) {
  var ptr = stackAlloc<Int16>(length * 2);
  var wrapper =
      Int16ArrayWrapper(_lib.HEAPU8.buffer, ptr.addr, length) as JSInt16Array;
  var int16List = wrapper.toDart;
  return int16List;
}

Uint16List makeUint16List(int length) {
  var ptr = stackAlloc<Uint16>(length * 2);
  var wrapper =
      Uint16ArrayWrapper(_lib.HEAPU8.buffer, ptr.addr, length) as JSUint16Array;
  var uint16List = wrapper.toDart;
  return uint16List;
}

IntPtrList makeIntPtrList(int length) {
  return makeInt32List(length);
}

Uint32List makeUint32List(int length) {
  var ptr = stackAlloc<Uint32>(length * 4);
  var wrapper =
      Uint32ArrayWrapper(_lib.HEAPU8.buffer, ptr.addr, length) as JSUint32Array;
  var uint32List = wrapper.toDart;
  return uint32List;
}

Int32List makeInt32List(int length) {
  var ptr = stackAlloc<Int32>(length * 4);
  var wrapper =
      Int32ArrayWrapper(_lib.HEAPU8.buffer, ptr.addr, length) as JSInt32Array;
  var int32List = wrapper.toDart;
  return int32List;
}

Int64List makeInt64List(int length) {
  var ptr = stackAlloc<Int64>(length * 8);
  var bytes = ptr.cast<Uint8>().asTypedList(length * 8);
  return bytes.buffer.asInt64List(bytes.offsetInBytes, length);
}

Float32List makeFloat32List(int length) {
  var ptr = stackAlloc<Float32>(length * 4);
  var wrapper = Float32ArrayWrapper(_lib.HEAPU8.buffer, ptr.addr, length)
      as JSFloat32Array;
  var f32List = wrapper.toDart;
  return f32List;
}

Float64List makeFloat64List(int length) {
  var ptr = stackAlloc<Float64>(length * 8);
  var wrapper = Float64ArrayWrapper(_lib.HEAPU8.buffer, ptr.addr, length)
      as JSFloat64Array;
  var f64List = wrapper.toDart;
  return f64List;
}

extension TypedDataExtension<T> on TypedData {
  Uint8List asUint8List() => Uint8List.sublistView(this);
}

extension type NativeLibrary(JSObject _) implements JSObject {
  static NativeLibrary get instance => _lib;

  static set instance(NativeLibrary lib) {
    _lib = lib;
  }

  static void initBindings(String moduleName) {
    var lib = globalContext.getProperty(moduleName.toJS);
    if (lib == null) {
      throw Exception("Failed to find JS module \${moduleName}");
    }
    _lib = lib as NativeLibrary;
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

final _heapAllocations = <int>{};

/// Returns [pointer] when it is already a raw Wasm address.
///
/// Generated non-leaf functions use this to reject TypedData addresses, which
/// have the same leaf-call restriction as `dart:ffi`.
Pointer<T> rawPointer<T extends NativeType>(Pointer<T> pointer) {
  if (pointer._isDeferred) {
    throw StateError(
      'TypedData.address can only be passed to a generated function configured '
      'as leaf.',
    );
  }
  return pointer;
}

final class _TypedDataRange {
  final ByteBuffer buffer;
  int start;
  int end;
  Pointer<Uint8>? pointer;
  bool heapAllocated = false;

  _TypedDataRange(this.buffer, this.start, this.end);

  int get length => end - start;

  Uint8List get source => buffer.asUint8List(start, length);
}

/// Materializes deferred TypedData pointers for one generated native call.
///
/// Generated wrappers create a scope only when a function has pointer
/// arguments. Raw Wasm pointers pass through unchanged. TypedData pointers
/// sharing a backing buffer share one Wasm allocation, preserving pointer
/// aliasing and overlapping views.
final class NativeCallScope {
  static const _maximumStackBytes = 32 * 1024;

  final _ranges = <_TypedDataRange>[];
  final _pointerRanges = <_DeferredTypedDataPointer, _TypedDataRange>{};
  Pointer<Void>? _stackMarker;
  bool _closed = false;

  NativeCallScope(Iterable<Pointer> pointers) {
    try {
      _prepare(pointers);
    } catch (_) {
      _close(copyBack: false);
      rethrow;
    }
  }

  void _prepare(Iterable<Pointer> pointers) {
    for (final pointer in pointers) {
      if (!pointer._isDeferred) continue;
      final deferred = pointer._deferred;
      final data = deferred.data;
      final start = data.offsetInBytes;
      final end = start + data.lengthInBytes;
      _TypedDataRange? range;
      for (final candidate in _ranges) {
        if (candidate.buffer == data.buffer) {
          range = candidate;
          break;
        }
      }
      if (range == null) {
        range = _TypedDataRange(data.buffer, start, end);
        _ranges.add(range);
      } else {
        if (start < range.start) range.start = start;
        if (end > range.end) range.end = end;
      }
      _pointerRanges[deferred] = range;
    }

    if (_ranges.isEmpty) return;

    _stackMarker = _lib.stackSave();
    var stackBytes = 0;
    for (final range in _ranges) {
      // Emscripten aligns stack allocations to 16 bytes. Account for the
      // aligned size so a collection of small views cannot exceed the limit.
      final alignedLength = (range.length + 15) & ~15;
      final useStack =
          stackBytes + alignedLength <= NativeCallScope._maximumStackBytes;
      final pointer = useStack
          ? stackAlloc<Uint8>(range.length)
          : malloc<Uint8>(range.length);
      range.pointer = pointer;
      range.heapAllocated = !useStack;
      if (useStack) stackBytes += alignedLength;
      pointer.asTypedList(range.length).setAll(0, range.source);
    }
  }

  /// Returns the raw Wasm pointer used for this call.
  Pointer<T> addressOf<T extends NativeType>(Pointer<T> pointer) {
    if (!pointer._isDeferred) return pointer;
    final deferred = pointer._deferred;
    final range = _pointerRanges[deferred]!;
    final address = range.pointer!.addr +
        deferred.data.offsetInBytes -
        range.start +
        deferred.additionalByteOffset;
    return Pointer<T>(address);
  }

  void close() => _close(copyBack: true);

  void _close({required bool copyBack}) {
    if (_closed) return;
    _closed = true;
    try {
      if (copyBack) {
        for (final range in _ranges) {
          final pointer = range.pointer;
          if (pointer != null) {
            range.source.setAll(0, pointer.asTypedList(range.length));
          }
        }
      }
    } finally {
      try {
        for (final range in _ranges) {
          if (range.heapAllocated) range.pointer?.free();
        }
      } finally {
        final stackMarker = _stackMarker;
        if (stackMarker != null) _lib.stackRestore(stackMarker);
      }
    }
  }
}

/// Runs a generated native call with all deferred pointers materialized.
R withNativeCall<R>(
  Iterable<Pointer> pointers,
  R Function(NativeCallScope scope) body,
) {
  final scope = NativeCallScope(pointers);
  try {
    return body(scope);
  } finally {
    scope.close();
  }
}

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

/// Returns [data]'s existing Emscripten heap address, if it is already backed
/// by that heap.
///
/// Checking the backing buffer also recognizes views derived from an allocated
/// list, such as `floatList.asUint8List()`.
Pointer<T>? _wasmHeapAddress<T extends NativeType>(
    TypedData data, JSObject jsArray) {
  if (data.lengthInBytes == 0) {
    return Pointer<T>(0);
  }
  final view = _JSTypedArrayView._(jsArray);
  if (_objectIs(view.buffer, NativeLibrary.instance.HEAPU8.buffer)) {
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
  Pointer<Uint8> get address {
    final jsArray = toJS;
    final heapAddress = _wasmHeapAddress<Uint8>(this, jsArray);
    if (heapAddress != null) return heapAddress;
    return Pointer<Uint8>._fromTypedData(this);
  }
}

extension Int8ListExtension on Int8List {
  Pointer<Int8> get address {
    final jsArray = toJS;
    final heapAddress = _wasmHeapAddress<Int8>(this, jsArray);
    if (heapAddress != null) return heapAddress;
    return Pointer<Int8>._fromTypedData(this);
  }
}

extension Float32ListExtension on Float32List {
  Pointer<Float32> get address {
    final jsArray = toJS;
    final heapAddress = _wasmHeapAddress<Float32>(this, jsArray);
    if (heapAddress != null) return heapAddress;
    return Pointer<Float32>._fromTypedData(this);
  }
}

extension Int16ListExtension on Int16List {
  Pointer<Int16> get address {
    final jsArray = toJS;
    final heapAddress = _wasmHeapAddress<Int16>(this, jsArray);
    if (heapAddress != null) return heapAddress;
    return Pointer<Int16>._fromTypedData(this);
  }
}

extension Uint16ListExtension on Uint16List {
  Pointer<Uint16> get address {
    final jsArray = toJS;
    final heapAddress = _wasmHeapAddress<Uint16>(this, jsArray);
    if (heapAddress != null) return heapAddress;
    return Pointer<Uint16>._fromTypedData(this);
  }
}

extension UInt32ListExtension on Uint32List {
  Pointer<Uint32> get address {
    final jsArray = toJS;
    final heapAddress = _wasmHeapAddress<Uint32>(this, jsArray);
    if (heapAddress != null) return heapAddress;
    return Pointer<Uint32>._fromTypedData(this);
  }
}

extension Int32ListExtension on Int32List {
  Pointer<Int32> get address {
    final jsArray = toJS;
    final heapAddress = _wasmHeapAddress<Int32>(this, jsArray);
    if (heapAddress != null) return heapAddress;
    return Pointer<Int32>._fromTypedData(this);
  }
}

extension Int64ListExtension on Int64List {
  Pointer<Int64> get address {
    final bytes = buffer.asUint8List(offsetInBytes, lengthInBytes);
    final jsArray = bytes.toJS;
    final heapAddress = _wasmHeapAddress<Int64>(this, jsArray);
    if (heapAddress != null) return heapAddress;
    return Pointer<Int64>._fromTypedData(this);
  }
}

extension Float64ListExtension on Float64List {
  Pointer<Float64> get address {
    final jsArray = toJS;
    final heapAddress = _wasmHeapAddress<Float64>(this, jsArray);
    if (heapAddress != null) return heapAddress;
    return Pointer<Float64>._fromTypedData(this);
  }
}

extension AsUint8List on Pointer<Uint8> {
  Uint8List asTypedList(int length) {
    final start = addr;
    final wrapper =
        Uint8ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, start, length)
            as JSUint8Array;
    return wrapper.toDart;
  }
}

extension AsInt8List on Pointer<Int8> {
  Int8List asTypedList(int length) {
    final wrapper = Int8ArrayWrapper(
      NativeLibrary.instance.HEAPU8.buffer,
      addr,
      length,
    ) as JSInt8Array;
    return wrapper.toDart;
  }
}

extension AsInt16List on Pointer<Int16> {
  Int16List asTypedList(int length) {
    final wrapper = Int16ArrayWrapper(
      NativeLibrary.instance.HEAPU8.buffer,
      addr,
      length,
    ) as JSInt16Array;
    return wrapper.toDart;
  }
}

extension AsUint16List on Pointer<Uint16> {
  Uint16List asTypedList(int length) {
    final wrapper = Uint16ArrayWrapper(
      NativeLibrary.instance.HEAPU8.buffer,
      addr,
      length,
    ) as JSUint16Array;
    return wrapper.toDart;
  }
}

extension AsInt32List on Pointer<Int32> {
  Int32List asTypedList(int length) {
    final wrapper = Int32ArrayWrapper(
      NativeLibrary.instance.HEAPU8.buffer,
      addr,
      length,
    ) as JSInt32Array;
    return wrapper.toDart;
  }
}

extension AsUint32List on Pointer<Uint32> {
  Uint32List asTypedList(int length) {
    final start = addr;
    final wrapper =
        Uint32ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, start, length)
            as JSUint32Array;
    return wrapper.toDart;
  }
}

extension AsInt64List on Pointer<Int64> {
  Int64List asTypedList(int length) {
    final bytes = cast<Uint8>().asTypedList(length * 8);
    return bytes.buffer.asInt64List(bytes.offsetInBytes, length);
  }
}

extension AsFloat32List on Pointer<Float> {
  Float32List asTypedList(int length) {
    final start = addr;
    final wrapper = Float32ArrayWrapper(
      NativeLibrary.instance.HEAPF32.buffer,
      start,
      length,
    ) as JSFloat32Array;
    return wrapper.toDart;
  }
}

extension AsFloat64List on Pointer<Double> {
  Float64List asTypedList(int length) {
    final wrapper = Float64ArrayWrapper(
      NativeLibrary.instance.HEAPU8.buffer,
      addr,
      length,
    ) as JSFloat64Array;
    return wrapper.toDart;
  }
}

typedef IntPtrList = Int32List;
typedef Utf8 = Char;
typedef Float = Float32;
typedef Double = Float64;

/// Registry of struct sizes (in bytes).
/// Populated by the generated bindings class during initialization.
/// Used by calloc-like allocators that need to know struct sizes at runtime.
final Map<Type, int> structSizeRegistry = {};
