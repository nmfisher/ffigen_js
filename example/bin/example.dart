import 'dart:typed_data';

import 'package:ffigen_js_example/generated_bindings_js.g.dart';

import '../../test/support/generated_api_contract.dart';
import '../../test/support/typed_data_address_contract.dart';

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

  for (final entry in typedDataAddressContract().entries) {
    entry.value();
  }
  print('Shared TypedData.address call sites passed on Wasm');

  for (final entry in generatedApiContract().entries) {
    entry.value();
  }
  print('Shared generated-API call sites passed on Wasm');

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

  // Ordinary Dart TypedData is registered up front. The explicit scope owns
  // copying and cleanup; generated calls still take integer-backed Pointers.
  // On native the same scope simply runs its callback without copying.
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
  ], () {
    assert(
        verify_typed_data_inputs_for_address_test(
          dartUint8.address,
          dartInt16.address,
          dartUint16.address,
          dartInt32.address,
          dartInt64.address,
          dartUint32.address,
          dartFloat32.address,
          dartFloat64.address,
        ),
        'Ordinary Dart typed lists were not copied into Wasm memory correctly');
    assert(pointer_is_on_stack(dartUint8.address),
        'A small buffer scope was not allocated on the stack');
    write_uint8_for_address_test(dartUint8.address);
    write_int16_for_address_test(dartInt16.address);
    write_uint16_for_address_test(dartUint16.address);
    write_int32_for_address_test(dartInt32.address);
    write_int64_for_address_test(dartInt64.address);
    write_uint32_for_address_test(dartUint32.address);
    write_float32_for_address_test(dartFloat32.address);
    write_float64_for_address_test(dartFloat64.address);
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
  final largeInput = Uint8List(64 * 1024)..[0] = 5;
  withNativeBuffers([largeInput], () {
    assert(!pointer_is_on_stack(largeInput.address),
        'A large buffer scope was not allocated on the heap');
    assert(sum_bytes(largeInput.address, largeInput.length) == 5,
        'A large temporary input was not readable by native code');
    write_uint8_for_address_test(largeInput.address);
  });
  assert(largeInput[0] == 201,
      'A native write was not copied back to a large Dart list');

  // Separate address expressions over the same backing buffer must resolve to
  // one allocation so native pointer identity and overlapping writes agree.
  final aliasedData = Uint8List.fromList([1, 2, 3, 4]);
  final aliasedView = Uint8List.sublistView(aliasedData, 1);
  withNativeBuffers([aliasedData, aliasedView], () {
    assert(verify_typed_data_alias(aliasedData.address, aliasedView.address),
        'Overlapping TypedData views did not preserve pointer aliasing');
  });
  assert(aliasedData[1] == 77 && aliasedView[0] == 77,
      'An aliased native write was not copied back to the Dart buffer');

  final mixedBuffer = Uint8List(16);
  final mixedBytes = Uint8List.view(mixedBuffer.buffer, 1, 7);
  final mixedWords = Uint32List.view(mixedBuffer.buffer, 4, 1);
  withNativeBuffers([mixedBytes, mixedWords], () {
    assert(verify_typed_data_alignment(mixedBytes.address, mixedWords.address),
        'Mixed-type aliases lost their alignment or relative offsets');
  });
  assert(
      mixedWords[0] == 123456, 'An aligned native write was not copied back');

  // The combined aligned size determines where the entire scope is allocated.
  // Both paths must copy back and release memory even when the body throws.
  for (final length in [16 * 1024, 16 * 1024 + 1]) {
    final first = Uint8List(length);
    final second = Uint8List(length);
    final marker = NativeLibrary.instance.stackSave();
    final failure = StateError('native call failed');
    try {
      withNativeBuffers([first, second], () {
        final firstRaw = first.address;
        final secondRaw = second.address;
        final onStack = length == 16 * 1024;
        assert(pointer_is_on_stack(firstRaw) == onStack);
        assert(pointer_is_on_stack(secondRaw) == onStack);
        assert(secondRaw.addr - firstRaw.addr == ((length + 15) & ~15),
            'Independent ranges were not placed in one aligned block');
        firstRaw.asTypedList(1)[0] = 21;
        secondRaw.asTypedList(1)[0] = 22;
        throw failure;
      });
    } on StateError catch (error) {
      assert(identical(error, failure));
    }
    assert(first[0] == 21 && second[0] == 22,
        'A throwing call did not copy back both ranges');
    assert(NativeLibrary.instance.stackSave().addr == marker.addr,
        'A throwing call did not restore the stack');
  }

  final resultMarker = NativeLibrary.instance.stackSave();
  final resultInput = Uint8List.fromList([9]);
  final resultValues = withNativeBuffers([resultInput], () {
    final result = return_struct_for_address_test(resultInput.address);
    // Stack-backed return storage also expires at scope exit. Read it here.
    return (result.a, result.c);
  });
  makeUint8List(128).fillRange(0, 128, 0);
  assert(resultValues.$1 == 9 && resultValues.$2 == 42);
  NativeLibrary.instance.stackRestore(resultMarker);

  // A scoped address is a real integer and can be reused until scope exit.
  final reusableData = Uint8List.fromList([6, 7]);
  withNativeBuffers([reusableData], () {
    final reusableAddress = reusableData.address;
    final int rawAddress = reusableAddress;
    assert(rawAddress == reusableAddress.addr);
    assert((reusableAddress + 1).addr == rawAddress + 1);
    assert(reusableAddress.cast<Int8>().addr == rawAddress);
    assert(sum_bytes(reusableAddress, reusableData.length) == 13,
        'A scoped address was not readable');
    write_uint8_for_address_test(reusableAddress);
    assert(sum_bytes(reusableAddress, reusableData.length) == 208);
    assert(reusableData[0] == 6, 'Copy-back should happen at scope exit');
  });
  assert(reusableData[0] == 201, 'A scoped write was not copied back');

  var rejected = false;
  try {
    reusableData.address;
  } on StateError {
    rejected = true;
  }
  assert(rejected, 'Ordinary .address must require an active registration');
  withNativeBuffers([reusableData], () {
    var unregisteredRejected = false;
    try {
      Uint8List(1).address;
    } on StateError {
      unregisteredRejected = true;
    }
    assert(unregisteredRejected,
        'Unregistered buffers must not allocate silently');
    final view = Uint8List.sublistView(reusableData, 1);
    assert(view.address.addr == reusableData.address.addr + 1);
    final before = NativeLibrary.instance.stackSave();
    withNativeBuffers([view], () {
      assert(view.address.addr == reusableData.address.addr + 1);
      assert(NativeLibrary.instance.stackSave().addr == before.addr,
          'Nested aliases must reuse existing storage');
    });
  });

  // JS callbacks can reenter while the outer copy remains live. Native leaf
  // TypedData.address calls cannot invoke Dart callbacks.
  for (final length in [1, 64 * 1024]) {
    final data = Uint8List(length)..[0] = 5;
    final marker = NativeLibrary.instance.stackSave();
    var called = false;
    final callback = (() {
      called = true;
      assert(data[0] == 5);
      final nested = Uint8List.fromList([3, 4]);
      withNativeBuffers([nested], () {
        write_uint8_for_address_test(nested.address);
      });
      assert(nested[0] == 201);
    }).addFunction();
    try {
      withNativeBuffers([data], () {
        update_bytes_with_callback(data.address, callback);
      });
    } finally {
      callback.dispose();
    }
    assert(called && data[0] == 22);
    assert(NativeLibrary.instance.stackSave().addr == marker.addr);
  }

  // Repeated inputs exceed the fixed Wasm heap if buffer scopes retain
  // every temporary allocation.
  for (var i = 0; i < 256; i++) {
    final batchInput = Uint8List(64 * 1024)..[i % (64 * 1024)] = i % 256;
    withNativeBuffers([batchInput], () {
      sum_bytes(batchInput.address, batchInput.length);
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
  final beforeBorrow = NativeLibrary.instance.stackSave();
  withNativeBuffers([borrowed], () {
    assert(NativeLibrary.instance.stackSave().addr == beforeBorrow.addr);
    write_uint8_for_address_test(borrowed.address);
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

  print("Explicit TypedData.address buffer scopes passed");

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
