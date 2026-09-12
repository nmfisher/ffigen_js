import 'dart:typed_data';

import 'package:ffigen_js_example/generated_bindings_js.g.dart';

import '../../test/support/native_buffer_contract.dart';

void _expectHeapAddress(TypedData data, int address, String label) {
  assert(
    address == data.offsetInBytes,
    '$label address $address did not match its Emscripten heap byte offset '
    '${data.offsetInBytes}',
  );
}

void main(List<String> args) async {
  print("Running WASM example");
  GeneratedBindings.initBindings("module");

  for (final entry in nativeBufferContract().entries) {
    entry.value();
  }
  print('Shared native buffer contract passed on Wasm');

  assert(returns_bool() == false);

  // UnreferencedEnum appears in no function signature; the generator must
  // still emit it and evaluate its enumerators.
  assert(UnreferencedEnum.UNREFERENCED_ENUM_B.value == 2);
  assert(UnreferencedEnum.UNREFERENCED_ENUM_C.value == 4);

  var structWithArray = return_struct_with_array_by_value();

  assert(structWithArray.array1[0] == 10.0, structWithArray.array1[0]);
  assert(structWithArray.array1[1] == 20.0, structWithArray.array1[1]);
  assert(structWithArray.array2[0] == 30.0, structWithArray.array2[0]);
  assert(structWithArray.array2[1] == 40.0, structWithArray.array2[1]);
  assert(structWithArray.array2[2] == 50.0, structWithArray.array2[2]);

  final intPointer = Int32.stackAlloc(1);
  intPointer.setValue(11);
  assert(intPointer.getValue() == 11);

  final floatPointer = Float32.stackAlloc(1);
  floatPointer.setValue(5.0);
  assert(floatPointer.getValue() == 5.0, floatPointer.getValue());
  assert(sum(1, 2) == 3);
  assert(sum_with_typedef(1, 2) == 3);
  assert(subtract(intPointer, 2) == 9);
  assert((divide(10, 2).getValue() - 5.0).abs() < 0.0001);
  assert(divide_precision(floatPointer, floatPointer).getValue() == 1.0);
  var copy = copy_string('MY STRING'.toNativeUtf8());
  assert(copy.toDartString() == 'MY STRING', copy.toDartString());

  var myStruct = return_struct_by_value(10.0, copy);

  assert(myStruct.a == 10.0, myStruct.a);
  assert(myStruct.c == 2, myStruct.c);
  assert(myStruct.b.toDartString() == 'MY STRING', myStruct.b.toDartString());

  var ptr = MyStruct.stackAlloc();
  var struct = ptr.toDart();
  struct.a = 20.0;
  struct.b = Pointer<Char>(0);
  struct.c = 8;

  assert(ptr.toDart().a == 20.0, ptr.toDart().a);

  var structArg = double3(ptr)
    ..x = 1.0
    ..y = 2.0
    ..z = 3.0;
  assert(struct_as_argument(structArg) == 6, struct_as_argument(structArg));

  accept_struct_ptr(Pointer<Never>(0));

  print("structArgument done");
  assert(GLOBALINT.toString() == "9223372036854775808", GLOBALINT.toString());

  final bigIntFnResult = bigint_method(BigInt.parse("9223372036854775808"));
  assert(bigIntFnResult == BigInt.parse("9223372036854775809"),
      bigIntFnResult.toString());

  final sizeTresult = size_tmethod(12345);
  assert(sizeTresult == 12346, sizeTresult);

  var done = false;
  void Function() callback = () {
    done = true;
  };

  final fnPtr = callback.addFunction();
  accept_fn_pointer_with_no_args(fnPtr);
  assert(done);

  done = false;
  print("voidFunctionArgument done");

  fnPtr.dispose();

  final fnPtr2 = (int intVal) {
    print(intVal + 10);
    done = true;
  }.addFunction();

  accept_fn_pointer_with_primitive_args(fnPtr2);

  fnPtr.dispose();

  assert(done);

  done = false;

  final fnPtr3 = (Pointer<MyStruct> ptr) {
    done = true;
  }.addFunction();

  accept_fn_pointer_with_ptr_args(fnPtr3);
  done = false;
  accept_fn_typedef_arg(fnPtr3.cast());
  fnPtr3.dispose();

  assert(done);

  print("Function argument completed");

  structWithArray = StructWithArray.stackAlloc().toDart();
  structWithArray.array1[0] = 1.0;
  structWithArray.array1[1] = 2.0;
  structWithArray.array2[0] = 4.0;
  structWithArray.array2[1] = 5.0;
  structWithArray.array2[2] = 6.0;
  assert(structWithArray.array1[0] == 1, structWithArray.array1[0]);
  assert(structWithArray.array1[1] == 2, structWithArray.array1[1]);
  assert(structWithArray.array2[0] == 4);
  assert(structWithArray.array2[1] == 5);
  assert(structWithArray.array2[2] == 6);

  final structWithStruct = StructWithStruct.stackAlloc().toDart();
  // final arr1 = structWithStruct.arr1;
  structWithStruct.struct1.array1[0] = 1.0;
  structWithStruct.struct1.array1[1] = 2.0;
  structWithStruct.struct1.array2[0] = 3.0;
  structWithStruct.struct1.array2[1] = 4.0;
  structWithStruct.struct1.array2[2] = 5.0;
  structWithStruct.struct2.array1[0] = 6.0;
  structWithStruct.struct2.array1[1] = 7.0;
  structWithStruct.struct2.array2[0] = 8.0;
  structWithStruct.struct2.array2[1] = 9.0;
  structWithStruct.struct2.array2[2] = 10.0;

  assert(structWithStruct.struct1.array1[0] == 1.0,
      structWithStruct.struct1.array1[0]);
  assert(structWithStruct.struct1.array1[1] == 2.0,
      structWithStruct.struct1.array1[1]);
  assert(structWithStruct.struct1.array2[0] == 3.0,
      structWithStruct.struct1.array2[0]);
  assert(structWithStruct.struct1.array2[1] == 4.0,
      structWithStruct.struct1.array2[1]);
  assert(structWithStruct.struct1.array2[2] == 5.0,
      structWithStruct.struct1.array2[2]);
  assert(structWithStruct.struct2.array1[0] == 6.0,
      structWithStruct.struct2.array1[0]);
  assert(structWithStruct.struct2.array1[1] == 7.0,
      structWithStruct.struct2.array1[1]);
  assert(structWithStruct.struct2.array2[0] == 8.0,
      structWithStruct.struct2.array2[0]);
  assert(structWithStruct.struct2.array2[1] == 9.0,
      structWithStruct.struct2.array2[1]);
  assert(structWithStruct.struct2.array2[2] == 10.0,
      structWithStruct.struct2.array2[2]);

  // Test TGltfMeshData with enum member
  final meshData = TGltfMeshData.stackAlloc().toDart();
  meshData.vertexCount = 3;
  meshData.indexCount = 3;
  meshData.primitiveTypeAsInt = 4;
  assert(meshData.primitiveType == TPrimitiveType.PRIMITIVETYPE_TRIANGLES);
  assert(meshData.primitiveTypeAsInt == 4);

  meshData.primitiveTypeAsInt = 5;
  assert(meshData.primitiveType == TPrimitiveType.PRIMITIVETYPE_TRIANGLE_STRIP);

  foo(meshData);
  print("TGltfMeshData enum test passed");

  // TypedData address tests use native writers so failures detect writes that
  // were accidentally redirected into temporary allocations.
  final typedDataStack = NativeLibrary.instance.stackSave();

  final float32 = makeFloat32List(3);
  final float32Address = float32.address;
  _expectHeapAddress(float32, float32Address.addr, 'Float32List');
  write_float32_for_address_test(float32Address);
  assert(float32[0] == 12.5, 'Float32List did not observe a native write');
  final float32Bytes = float32.asUint8List();
  assert(float32Bytes.address.addr == float32Address.addr,
      'Float32List byte view did not retain its heap address');
  write_float32_for_address_test(float32Bytes.address.cast<Float32>());
  assert(float32[0] == 12.5,
      'Float32List did not observe a native write through its byte view');
  final float32Subview = Float32List.sublistView(float32, 1, 3);
  final float32SubviewAddress = float32Subview.address;
  assert(float32SubviewAddress.addr == float32Address.addr + 4,
      'Float32List subview did not retain its non-zero heap offset');
  write_float32_for_address_test(float32SubviewAddress);
  assert(float32[1] == 12.5,
      'Float32List did not observe a native write through its subview');

  final int16 = makeInt16List(3);
  final int16Address = int16.address;
  _expectHeapAddress(int16, int16Address.addr, 'Int16List');
  write_int16_for_address_test(int16Address);
  assert(int16[0] == -1234, 'Int16List did not observe a native write');
  assert(int16.asUint8List().address.addr == int16Address.addr,
      'Int16List byte view did not retain its heap address');

  final uint16 = makeUint16List(3);
  final uint16Address = uint16.address;
  _expectHeapAddress(uint16, uint16Address.addr, 'Uint16List');
  write_uint16_for_address_test(uint16Address);
  assert(uint16[0] == 54321, 'Uint16List did not observe a native write');
  assert(uint16.asUint8List().address.addr == uint16Address.addr,
      'Uint16List byte view did not retain its heap address');

  final int32 = makeInt32List(3);
  final int32Address = int32.address;
  _expectHeapAddress(int32, int32Address.addr, 'Int32List');
  write_int32_for_address_test(int32Address);
  assert(int32[0] == -123456789, 'Int32List did not observe a native write');
  assert(int32.asUint8List().address.addr == int32Address.addr,
      'Int32List byte view did not retain its heap address');

  final int64 = makeInt64List(3);
  final int64Address = int64.address;
  _expectHeapAddress(int64, int64Address.addr, 'Int64List');
  write_int64_for_address_test(int64Address);
  assert(int64[0] == -9007199254740995,
      'Int64List did not observe a native write');
  assert(int64.asUint8List().address.addr == int64Address.addr,
      'Int64List byte view did not retain its heap address');

  final uint32 = makeUint32List(3);
  final uint32Address = uint32.address;
  _expectHeapAddress(uint32, uint32Address.addr, 'Uint32List');
  write_uint32_for_address_test(uint32Address);
  assert(uint32[0] == 3456789012, 'Uint32List did not observe a native write');
  assert(uint32.asUint8List().address.addr == uint32Address.addr,
      'Uint32List byte view did not retain its heap address');

  final uint8 = makeUint8List(3);
  final uint8Address = uint8.address;
  _expectHeapAddress(uint8, uint8Address.addr, 'Uint8List');
  write_uint8_for_address_test(uint8Address);
  assert(uint8[0] == 201, 'Uint8List did not observe a native write');

  final float64 = makeFloat64List(3);
  final float64Address = float64.address;
  _expectHeapAddress(float64, float64Address.addr, 'Float64List');
  write_float64_for_address_test(float64Address);
  assert(float64[0] == 9876.5, 'Float64List did not observe a native write');
  assert(float64.asUint8List().address.addr == float64Address.addr,
      'Float64List byte view did not retain its heap address');

  assert(makeUint8List(0).address.addr == 0,
      'An empty TypedData value should have a null address');

  NativeLibrary.instance.stackRestore(typedDataStack);

  // Pointers are integer values; only an explicit scope copies Dart buffers.
  const integerPointer = Pointer<Uint8>(1024);
  final int integerAddress = integerPointer;
  assert(integerAddress == 1024 && (integerPointer + 3).addr == 1027);
  assert(integerPointer.cast<Int32>() == const Pointer<Int32>(1024));
  assert({integerPointer: 7}[const Pointer<Uint8>(1024)] == 7);

  var ordinaryAddressRejected = false;
  try {
    Uint8List(1).address;
  } on StateError {
    ordinaryAddressRejected = true;
  }
  assert(ordinaryAddressRejected, 'Ordinary Dart data needs an explicit scope');

  final dartUint8 = Uint8List.fromList([17]);
  final dartInt16 = Int16List.fromList([-18]);
  final dartUint16 = Uint16List.fromList([60000]);
  final dartInt32 = Int32List.fromList([-1234567]);
  final dartInt64 = Int64List.fromList([-9007199254740993]);
  final dartUint32 = Uint32List.fromList([4000000000]);
  final dartFloat32 = Float32List.fromList([1.25]);
  final dartFloat64 = Float64List.fromList([-2.5]);
  withNativeBuffers([
    dartUint8,
    dartInt16,
    dartUint16,
    dartInt32,
    dartInt64,
    dartUint32,
    dartFloat32,
    dartFloat64,
  ], (scope) {
    assert(
        verify_typed_data_inputs_for_address_test(
          scope.addressOf(dartUint8),
          scope.addressOf(dartInt16),
          scope.addressOf(dartUint16),
          scope.addressOf(dartInt32),
          scope.addressOf(dartInt64),
          scope.addressOf(dartUint32),
          scope.addressOf(dartFloat32),
          scope.addressOf(dartFloat64),
        ),
        'Typed-list inputs were not copied correctly');
    final pointer = scope.addressOf<Uint8>(dartUint8);
    assert(pointer_is_on_stack(pointer));
    write_uint8_for_address_test(pointer);
    assert(sum_bytes(pointer, 1) == 201,
        'A pointer could not be reused in its scope');
    assert(dartUint8[0] == 17, 'Copy-back happened before scope exit');
    write_int16_for_address_test(scope.addressOf(dartInt16));
    write_uint16_for_address_test(scope.addressOf(dartUint16));
    write_int32_for_address_test(scope.addressOf(dartInt32));
    write_int64_for_address_test(scope.addressOf(dartInt64));
    write_uint32_for_address_test(scope.addressOf(dartUint32));
    write_float32_for_address_test(scope.addressOf(dartFloat32));
    write_float64_for_address_test(scope.addressOf(dartFloat64));
  });
  assert(
      dartUint8[0] == 201 &&
          dartInt16[0] == -1234 &&
          dartUint16[0] == 54321 &&
          dartInt32[0] == -123456789 &&
          dartInt64[0] == -9007199254740995 &&
          dartUint32[0] == 3456789012 &&
          dartFloat32[0] == 12.5 &&
          dartFloat64[0] == 9876.5,
      'Native writes were not copied back to ordinary Dart typed lists');

  final signedBytes = Int8List.fromList([-7]);
  final empty = Uint8List(0);
  late NativeBufferScope closedScope;
  withNativeBuffers([signedBytes, empty], (scope) {
    closedScope = scope;
    final pointer = scope.addressOf<Int8>(signedBytes);
    assert(pointer.asTypedList(1)[0] == -7);
    pointer.asTypedList(1)[0] = -8;
    assert(scope.addressOf<Uint8>(empty).addr == 0);
    var unregisteredRejected = false;
    try {
      scope.addressOf<Uint8>(Uint8List(1));
    } on ArgumentError {
      unregisteredRejected = true;
    }
    assert(unregisteredRejected);
  });
  assert(signedBytes[0] == -8);
  var closedRejected = false;
  try {
    closedScope.addressOf<Int8>(signedBytes);
  } on StateError {
    closedRejected = true;
  }
  assert(closedRejected);

  final readonly = Uint8List.fromList([2, 3]).asUnmodifiableView();
  final total = withNativeBuffers([readonly], (scope) {
    final pointer = scope.addressOf<Uint8>(readonly);
    final sum = sum_bytes(pointer, readonly.length);
    write_uint8_for_address_test(pointer);
    return sum;
  }, copyBack: false);
  assert(total == 5 && readonly[0] == 2, 'Input-only scope wrote back');

  final aliasedData = Uint8List.fromList([1, 2, 3, 4]);
  final aliasedView = Uint8List.sublistView(aliasedData, 1);
  withNativeBuffers([aliasedData, aliasedView], (scope) {
    assert(verify_typed_data_alias(
        scope.addressOf(aliasedData), scope.addressOf(aliasedView)));
  });
  assert(aliasedData[1] == 77 && aliasedView[0] == 77);

  final mixedBuffer = Uint8List(16);
  final mixedBytes = Uint8List.view(mixedBuffer.buffer, 1, 7);
  final mixedWords = Uint32List.view(mixedBuffer.buffer, 4, 1);
  withNativeBuffers([mixedBytes, mixedWords], (scope) {
    assert(verify_typed_data_alignment(
        scope.addressOf(mixedBytes), scope.addressOf(mixedWords)));
  });
  assert(mixedWords[0] == 123456, 'Aligned native write was not copied back');

  // The combined aligned size determines the allocation for the whole scope.
  // Cleanup and copy-back run even if the body throws.
  for (final length in [16 * 1024, 16 * 1024 + 1]) {
    final first = Uint8List(length);
    final second = Uint8List(length);
    final marker = NativeLibrary.instance.stackSave();
    final failure = StateError('native call failed');
    try {
      withNativeBuffers([first, second], (scope) {
        final firstRaw = scope.addressOf<Uint8>(first);
        final secondRaw = scope.addressOf<Uint8>(second);
        final onStack = length == 16 * 1024;
        assert(pointer_is_on_stack(firstRaw) == onStack);
        assert(pointer_is_on_stack(secondRaw) == onStack);
        assert(secondRaw.addr - firstRaw.addr == ((length + 15) & ~15));
        firstRaw.asTypedList(1)[0] = 21;
        secondRaw.asTypedList(1)[0] = 22;
        throw failure;
      });
    } on StateError catch (error) {
      assert(identical(error, failure));
    }
    assert(first[0] == 21 && second[0] == 22);
    assert(NativeLibrary.instance.stackSave().addr == marker.addr);
  }

  // Copy values out of a returned struct before the explicit stack scope ends.
  final resultInput = Uint8List.fromList([9]);
  final scopedResult = withNativeBuffers([resultInput], (scope) {
    final result = return_struct_for_address_test(scope.addressOf(resultInput));
    return (a: result.a, c: result.c);
  });
  final resultMarker = NativeLibrary.instance.stackSave();
  makeUint8List(128).fillRange(0, 128, 0);
  assert(scopedResult.a == 9 && scopedResult.c == 42);
  NativeLibrary.instance.stackRestore(resultMarker);

  // Callbacks can open nested scopes while the outer buffers remain live.
  for (final length in [1, 64 * 1024]) {
    final callbackData = Uint8List(length)..[0] = 5;
    final callbackMarker = NativeLibrary.instance.stackSave();
    var callbackRan = false;
    final callbackPointer = (() {
      callbackRan = true;
      assert(callbackData[0] == 5, 'Copy-back happened during a callback');
      final nestedData = Uint8List.fromList([3, 4]);
      withNativeBuffers([nestedData], (scope) {
        final pointer = scope.addressOf<Uint8>(nestedData);
        write_uint8_for_address_test(pointer);
        assert(sum_bytes(pointer, nestedData.length) == 205);
      });
      assert(nestedData[0] == 201);
    }).addFunction();
    try {
      withNativeBuffers([callbackData], (scope) {
        final pointer = scope.addressOf<Uint8>(callbackData);
        assert(pointer_is_on_stack(pointer) == (length == 1));
        update_bytes_with_callback(pointer, callbackPointer);
      });
    } finally {
      callbackPointer.dispose();
    }
    assert(callbackRan && callbackData[0] == 22);
    assert(NativeLibrary.instance.stackSave().addr == callbackMarker.addr);
  }

  // Repeated inputs exceed the fixed Wasm heap if scopes retain allocations.
  for (var i = 0; i < 256; i++) {
    final batchInput = Uint8List(64 * 1024)..[0] = i % 256;
    withNativeBuffers([batchInput], (scope) {
      assert(
          sum_bytes(scope.addressOf(batchInput), batchInput.length) == i % 256);
    });
  }
  // Views already backed by Emscripten memory remain caller-owned.
  final borrowedMarker = NativeLibrary.instance.stackSave();
  final borrowed = makeUint8List(8)
    ..fillRange(0, 8, 0)
    ..[2] = 9;
  write_uint8_for_address_test(borrowed.address);
  assert(borrowed[0] == 201,
      'A native write did not reach an Emscripten-backed list');
  assert(sum_bytes(borrowed.address, borrowed.length) == 210,
      'An Emscripten-backed list was not readable after a native call');
  final borrowedScopeMarker = NativeLibrary.instance.stackSave();
  withNativeBuffers([borrowed], (scope) {
    assert(scope.addressOf<Uint8>(borrowed).addr == borrowed.address.addr);
    assert(NativeLibrary.instance.stackSave().addr == borrowedScopeMarker.addr,
        'Borrowing a Wasm view allocated temporary stack memory');
    write_uint8_for_address_test(scope.addressOf(borrowed));
    assert(borrowed[0] == 201);
  });
  NativeLibrary.instance.stackRestore(borrowedMarker);

  // Data retained beyond one call uses explicit native allocation, as it does
  // with dart:ffi, and remains valid until its pointer is freed.
  final retainedPointer = malloc<Uint8>(3);
  final retained = retainedPointer.asTypedList(3)..setAll(0, [9, 8, 7]);
  assert(sum_bytes(retainedPointer, retained.length) == 24,
      'Explicitly allocated data was not readable by native code');
  write_uint8_for_address_test(retainedPointer);
  assert(retained[0] == 201,
      'Explicitly allocated data did not remain backed by Wasm memory');
  retainedPointer.free();

  print("explicit native buffer scope tests passed");

  print("All TypedData accessor tests passed");

  // --- Pointer<PointerClass<T>> (double-pointer) tests ---

  // Test allocArray + operator[] + operator[]=
  final ptrArray = PointerClass.allocArray<Int32>(3);
  final p0 = Int32.stackAlloc(1)..setValue(100);
  final p1 = Int32.stackAlloc(1)..setValue(200);
  final p2 = Int32.stackAlloc(1)..setValue(300);
  ptrArray[0] = p0;
  ptrArray[1] = p1;
  ptrArray[2] = p2;
  // Read back stored pointers and verify values
  assert(
      ptrArray[0].getValue() == 100, "ptrArray[0]=${ptrArray[0].getValue()}");
  assert(
      ptrArray[1].getValue() == 200, "ptrArray[1]=${ptrArray[1].getValue()}");
  assert(
      ptrArray[2].getValue() == 300, "ptrArray[2]=${ptrArray[2].getValue()}");
  print("PointerClass.allocArray + operator[] test passed");

  // Test ptr_ptr native function (swaps two int**)
  final a = PointerClass.allocArray<Int32>(1);
  final b = PointerClass.allocArray<Int32>(1);
  final valA = Int32.stackAlloc(1)..setValue(10);
  final valB = Int32.stackAlloc(1)..setValue(20);
  a[0] = valA;
  b[0] = valB;
  final swapped = ptr_ptr(a, b);
  // ptr_ptr swaps: out[0] = *b, out[1] = *a
  assert(swapped[0].getValue() == 20, "swapped[0]=${swapped[0].getValue()}");
  assert(swapped[1].getValue() == 10, "swapped[1]=${swapped[1].getValue()}");
  print("ptr_ptr native call test passed");

  print("All Pointer<PointerClass<T>> tests passed");
}
