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

extension type const Pointer<T extends NativeType>(int addr) implements int {
  Pointer<T> operator +(int byteOffset) => Pointer<T>(this.addr + byteOffset);
  Pointer<U> cast<U extends NativeType>() => this as Pointer<U>;
  void free() {
    _lib._free(this);
  }

  int get address => addr;
}

base class PointerClass<T extends NativeType> extends NativeType {
  final Pointer<T> addr;

  PointerClass(this.addr);

  String get llvmType => '*';
  int size() => 4;

  static PointerClass<PointerClass<T>> stackAlloc<T extends NativeType>(
    int count,
  ) {
    return _lib._stackAlloc<T>(4 * count) as PointerClass<PointerClass<T>>;
  }

  PointerClass<T> operator +(int numElements) =>
      PointerClass<T>(this.addr.addr + (numElements * size()) as Pointer<T>);
  PointerClass<U> cast<U extends NativeType>() => this as PointerClass<U>;
}

extension type Null._(NativeType value) implements NativeType {}

Pointer<NativeFunction<T>> addFunction<T>(JSFunction fn, String signature) {
  return _lib.addFunction(fn, signature);
}

extension type Char._(NativeType value) implements NativeType {
  static Pointer<Char> stackAlloc(int count) {
    return Pointer<Char>(_lib._stackAlloc<Char>(4 * count));
  }
}

extension type Bool._(NativeType value) implements NativeType {
  static Pointer<Bool> stackAlloc(int count) {
    return Pointer<Bool>(_lib._stackAlloc<Char>(4 * count));
  }
}

extension type const Uint32._(NativeType nt) implements NativeType {
  static Pointer<Uint32> stackAlloc(int count) {
    return _lib._stackAlloc<Uint32>(4 * count);
  }
}

extension type const Uint8._(NativeType nt) implements NativeType {
  static Pointer<Uint8> stackAlloc(int count) {
    return _lib._stackAlloc<Uint8>(count);
  }
}

extension type const Int8._(NativeType nt) implements NativeType {
  static Pointer<Int8> stackAlloc(int count) {
    return _lib._stackAlloc<Int8>(count);
  }
}

extension type const Uint16._(NativeType nt) implements NativeType {
  static Pointer<Uint16> stackAlloc(int count) {
    return _lib._stackAlloc<Uint16>(2 * count);
  }
}

extension type const Int16._(NativeType nt) implements NativeType {
  static Pointer<Int16> stackAlloc(int count) {
    return _lib._stackAlloc<Int16>(2 * count);
  }
}

extension type const Int32._(NativeType nt) implements NativeType {
  static Pointer<Int32> stackAlloc(int count) {
    return _lib._stackAlloc<Int32>(4 * count);
  }
}

extension type Int64(NativeType nt) implements NativeType {
  static Pointer<Int64> stackAlloc(int count) {
    return _lib._stackAlloc<Int64>(8 * count);
  }
}
extension type Float32._(NativeType nt) implements NativeType {
  static Pointer<Float32> stackAlloc(int count) {
    return _lib._stackAlloc<Float32>(4 * count);
  }
}
extension type Float64._(NativeType nt) implements NativeType {
  static Pointer<Float64> stackAlloc(int count) {
    return _lib._stackAlloc<Float64>(8 * count);
  }
}
extension type NativeFunction<T>._(NativeType nt) implements NativeType {}
extension type Void._(NativeType nt) implements NativeType {}

Pointer<Never> nullptr = Pointer<Never>(0);

extension PointerPointerClass<T extends NativeType>
    on Pointer<PointerClass<T>> {
  operator [](int i) => this + i;
  void operator []=(int i, Pointer<T> value) {
    _lib.setValue(this + (i * 4), value.addr.toJS, 'i64');
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
    return _lib.getValue(this + (i * 4), 'f').toDartDouble;
  }

  operator []=(int i, double val) {
    _lib.setValue(this + (i * 4), val.toJS, 'f');
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
  ({int numElements, Pointer<T> addr}) internal
) {
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
    return _lib.getValue(internal.addr + (i * 4), 'i32').toDartInt;
  }

  void operator []=(int i, int v) {
    _lib.setValue(internal.addr + (i * 4), v.toJS, 'i32');
  }
}

extension ArrayFloat32Ext on Array<Float32> {
  double operator [](int i) {
    return _lib.getValue(internal.addr + (i * 4), 'double').toDartDouble;
  }

  void operator []=(int i, double v) {
    _lib.setValue(internal.addr + (i * 4), v.toJS, 'double');
  }
}

extension ArrayFloat64Ext on Array<Float64> {
  double operator [](int i) {
    return _lib.getValue(internal.addr + (i * 8), 'double').toDartDouble;
  }

  void operator []=(int i, double v) {
    _lib.setValue(internal.addr + (i * 8), v.toJS, 'double');
  }
}

late NativeLibrary _lib;

Pointer<T> malloc<T extends NativeType>(int numBytes) {
  return _lib._malloc<T>(numBytes);
}

Pointer<T> stackAlloc<T extends NativeType>(int numBytes) {
  final ptr = _lib._stackAlloc<T>(numBytes);
  return ptr;
}

void free(Pointer ptr) {
  _lib._free(ptr);
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

final _allocations = <TypedData>{};

Uint8List makeUint8List(int length) {
  var ptr = malloc<Uint8>(length);
  var buf = NativeLibrary.instance._emscripten_make_uint8_buffer(ptr, length);
  var uint8List = buf.toDart;
  _allocations.add(uint8List);
  return uint8List;
}

Int32List makeInt32List(int length) {
  var ptr = stackAlloc<Int32>(length * 4);
  var buf = NativeLibrary.instance._emscripten_make_int32_buffer(ptr, length);
  var int32List = buf.toDart;
  _allocations.add(int32List);
  return int32List;
}

Float32List makeFloat32List(int length) {
  var ptr = stackAlloc<Float32>(length * 4);
  var buf = NativeLibrary.instance._emscripten_make_f32_buffer(ptr, length);
  var f32List = buf.toDart;
  _allocations.add(f32List);
  return f32List;
}

extension FreeTypedData<T> on TypedData {
  void free() {
    Pointer<Void>(this.offsetInBytes).free();
    _allocations.remove(this);
  }
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
  external JSFloat32Array get HEAPF32;

  external JSUint8Array _emscripten_make_uint8_buffer(
    Pointer<Uint8> ptr,
    int length,
  );
  external JSUint16Array _emscripten_make_uint16_buffer(
    Pointer<Uint16> ptr,
    int length,
  );
  external JSInt16Array _emscripten_make_int16_buffer(
    Pointer<Int16> ptr,
    int length,
  );
  external JSInt32Array _emscripten_make_int32_buffer(
    Pointer<Int32> ptr,
    int length,
  );
  external JSFloat32Array _emscripten_make_f32_buffer(
    Pointer<Float32> ptr,
    int length,
  );
  external JSFloat64Array _emscripten_make_f64_buffer(
    Pointer<Float64> ptr,
    int length,
  );
  external Pointer _emscripten_get_byte_offset(JSObject obj);

  external int _emscripten_stack_get_base();
  external Pointer _emscripten_stack_get_current();
  external int _emscripten_stack_get_free();
}

abstract base class Struct extends NativeType {
  
  final Pointer _address;
  Pointer get address => address;

  Struct(this._address);

  static T create<T extends Struct>() {
    throw UnimplementedError();
  }
}

Pointer<T> getPointer<T extends NativeType>(TypedData data, JSObject obj) {
  late Pointer<T> ptr;

  if (data.lengthInBytes < 32 * 1024) {
    ptr = stackAlloc(data.lengthInBytes).cast<T>();
  } else {
    ptr = malloc<T>(data.lengthInBytes);
  }

  return ptr;
}

extension JSUint8BackingBuffer on JSUint8Array {
  @JS('buffer')
  external JSObject buffer;
}

extension JSFloat32BackingBuffer on JSFloat32Array {
  @JS('buffer')
  external JSObject buffer;
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
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    if (_allocations.contains(this)) {
      return Pointer<Uint8>(
        NativeLibrary.instance._emscripten_get_byte_offset(this.toJS),
      );
    }
    final ptr = getPointer<Uint8>(this, this.toJS);
    final wrapper =
        Uint8ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSUint8Array;
    wrapper.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension Float32ListExtension on Float32List {
  Pointer<Float32> get address {
    final ptr = getPointer<Float32>(this, this.toJS);
    final wrapper =
        Float32ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSFloat32Array;
    wrapper.toDart.setRange(0, length, this);
    return ptr;
  }

  Uint8List asUint8List() {
    var ptr = Pointer<Uint8>(
      NativeLibrary.instance._emscripten_get_byte_offset(this.toJS),
    );
    return ptr.asTypedList(length * 4);
  }
}

extension Int16ListExtension on Int16List {
  Pointer<Int16> get address {
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    final ptr = getPointer<Int16>(this, this.toJS);
    final wrapper =
        Int16ArrayWrapper(NativeLibrary.instance.HEAPU8, ptr, length)
            as JSInt16Array;
    wrapper.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension Uint16ListExtension on Uint16List {
  Pointer<Uint16> get address {
    final ptr = getPointer<Uint16>(this, this.toJS);
    final wrapper =
        Uint16ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSUint16Array;
    wrapper.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension UInt32ListExtension on Uint32List {
  Pointer<Uint32> get address {
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    final ptr = getPointer<Uint32>(this, this.toJS);
    final wrapper =
        Uint32ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSUint32Array;
    wrapper.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension Int32ListExtension on Int32List {
  Pointer<Int32> get address {
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    if (_allocations.contains(this)) {
      return Pointer<Int32>(
        NativeLibrary.instance._emscripten_get_byte_offset(this.toJS),
      );
    }
    try {
      this.buffer.asUint8List(this.offsetInBytes);
      final ptr = getPointer<Int32>(this, this.toJS);
      final wrapper =
          Int32ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
              as JSInt32Array;
      wrapper.toDart.setRange(0, length, this);
      return ptr;
    } catch (_) {
      return Pointer<Int32>(this.offsetInBytes);
    }
  }
}

extension Int64ListExtension on Int64List {
  Pointer<Float32> get address {
    throw Exception();
  }

  static Int64List create(int length) {
    throw Exception();
  }
}

extension Float64ListExtension on Float64List {
  Pointer<Float64> get address {
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    final ptr = getPointer<Float64>(this, this.toJS);
    final wrapper =
        Float64ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSFloat64Array;
    wrapper.toDart.setRange(0, length, this);
    return ptr;
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

extension AsFloat32List on Pointer<Float> {
  Float32List asTypedList(int length) {
    final start = addr;
    final wrapper =
        Float32ArrayWrapper(
              NativeLibrary.instance.HEAPF32.buffer,
              start,
              length,
            )
            as JSFloat32Array;
    return wrapper.toDart;
  }
}

int sizeOf<T extends NativeType>() {
  switch (T) {
    case Float:
      return 4;
    default:
      throw Exception();
  }
}

typedef IntPtrList = Int32List;
typedef Utf8 = Char;
typedef Float = Float32;
typedef Double = Float64;
