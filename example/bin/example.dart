import 'dart:typed_data';

import 'package:ffigen_js_example/generated_bindings_js.g.dart';

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
  struct.b = Pointer<Char>(0 as Pointer<Char>);
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

  final dartUint8 = Uint8List.fromList([17]);
  final dartInt16 = Int16List.fromList([-18]);
  final dartUint16 = Uint16List.fromList([60000]);
  final dartInt32 = Int32List.fromList([-1234567]);
  final dartInt64 = Int64List.fromList([-9007199254740993]);
  final dartUint32 = Uint32List.fromList([4000000000]);
  final dartFloat32 = Float32List.fromList([1.25]);
  final dartFloat64 = Float64List.fromList([-2.5]);
  final dartUint8Address = dartUint8.address;
  final dartInt16Address = dartInt16.address;
  final dartUint16Address = dartUint16.address;
  final dartInt32Address = dartInt32.address;
  final dartInt64Address = dartInt64.address;
  final dartUint32Address = dartUint32.address;
  final dartFloat32Address = dartFloat32.address;
  final dartFloat64Address = dartFloat64.address;

  assert(
      verify_typed_data_inputs_for_address_test(
        dartUint8Address,
        dartInt16Address,
        dartUint16Address,
        dartInt32Address,
        dartInt64Address,
        dartUint32Address,
        dartFloat32Address,
        dartFloat64Address,
      ),
      'Ordinary Dart typed lists were not copied into Wasm memory correctly');

  write_uint8_for_address_test(dartUint8Address);
  write_int16_for_address_test(dartInt16Address);
  write_uint16_for_address_test(dartUint16Address);
  write_int32_for_address_test(dartInt32Address);
  write_int64_for_address_test(dartInt64Address);
  write_uint32_for_address_test(dartUint32Address);
  write_float32_for_address_test(dartFloat32Address);
  write_float64_for_address_test(dartFloat64Address);
  assert(
      dartUint8[0] == 17 &&
          dartInt16[0] == -18 &&
          dartUint16[0] == 60000 &&
          dartInt32[0] == -1234567 &&
          dartInt64[0] == -9007199254740993 &&
          dartUint32[0] == 4000000000 &&
          dartFloat32[0] == 1.25 &&
          dartFloat64[0] == -2.5,
      'Native writes to copied inputs unexpectedly changed a Dart list');

  NativeLibrary.instance.stackRestore(typedDataStack);

  final largeDartUint8 = Uint8List(32 * 1024)..[0] = 99;
  final largeDartUint8Address = largeDartUint8.address;
  assert(largeDartUint8Address.asTypedList(1)[0] == 99,
      'The malloc-backed input was not copied into Wasm memory');
  write_uint8_for_address_test(largeDartUint8Address);
  assert(largeDartUint8[0] == 99,
      'A native write to a malloc-backed copy changed the Dart list');
  largeDartUint8Address.free();

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
