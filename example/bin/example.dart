import 'dart:typed_data';

import 'package:ffigen_js/ffigen_js.dart';

import '../lib/generated_bindings.dart';

void main(List<String> args) async {
  print("Running WASM example");
  NativeLibrary.initBindings("module");

  assert(returns_bool() == false);

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

  structWithArray = StructAllocator.create<StructWithArray>();
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

  final structWithStruct = StructAllocator.create<StructWithStruct>();
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
  // Set primitive type via int value (TRIANGLES = 4)
  meshData.primitiveTypeAsInt = 4;
  // Can read as enum or int
  assert(meshData.primitiveType == TPrimitiveType.PRIMITIVETYPE_TRIANGLES);
  assert(meshData.primitiveTypeAsInt == 4);

  // Test setting primitive type via int (TRIANGLE_STRIP = 5)
  meshData.primitiveTypeAsInt = 5;
  assert(meshData.primitiveType == TPrimitiveType.PRIMITIVETYPE_TRIANGLE_STRIP);

  foo(meshData);
  print("TGltfMeshData enum test passed");

  // --- TypedData accessor tests ---
  // These test the asUint8List() and .address extensions in types.dart
  // to verify correct behavior for both WASM-heap and Dart-heap TypedData.

  // Float32List (WASM-heap-backed via makeFloat32List)
  final wasmF32 = makeFloat32List(3);
  wasmF32[0] = 1.0;
  wasmF32[1] = 2.0;
  wasmF32[2] = 3.0;
  final wasmF32Bytes = wasmF32.asUint8List();
  assert(wasmF32Bytes.length == 12,
      "wasmF32.asUint8List().length=${wasmF32Bytes.length}, expected 12");
  final wasmF32Addr = wasmF32.address;
  assert(wasmF32Addr != 0, "wasmF32.address should be non-zero");

  // Float32List (Dart-heap — this is what GeometryHelper.cube() produces)
  final dartF32 = Float32List.fromList([1.0, 2.0, 3.0]);
  final dartF32Bytes = dartF32.asUint8List();
  assert(dartF32Bytes.length == 12,
      "dartF32.asUint8List().length=${dartF32Bytes.length}, expected 12");
  // Verify data integrity: float 1.0 = 0x3F800000 (little-endian: 00 00 80 3F)
  assert(
      dartF32Bytes[0] == 0x00 &&
          dartF32Bytes[1] == 0x00 &&
          dartF32Bytes[2] == 0x80 &&
          dartF32Bytes[3] == 0x3F,
      "dartF32.asUint8List() data mismatch: [${dartF32Bytes[0]}, ${dartF32Bytes[1]}, ${dartF32Bytes[2]}, ${dartF32Bytes[3]}]");
  final dartF32Addr = dartF32.address;
  assert(dartF32Addr != 0, "dartF32.address should be non-zero");
  print("Float32List tests passed");

  // Uint16List (WASM-heap)
  final wasmU16 = makeUint16List(6);
  for (int i = 0; i < 6; i++) {
    wasmU16[i] = i;
  }
  final wasmU16Bytes = wasmU16.asUint8List();
  assert(wasmU16Bytes.length == 12,
      "wasmU16.asUint8List().length=${wasmU16Bytes.length}, expected 12 (6*2)");

  // Uint16List (Dart-heap)
  final dartU16 = Uint16List.fromList([0, 1, 2, 3, 4, 5]);
  final dartU16Bytes = dartU16.asUint8List();
  assert(dartU16Bytes.length == 12,
      "dartU16.asUint8List().length=${dartU16Bytes.length}, expected 12 (6*2)");
  print("Uint16List tests passed");

  // Uint32List (WASM-heap)
  final wasmU32 = makeUint32List(3);
  wasmU32[0] = 100;
  wasmU32[1] = 200;
  wasmU32[2] = 300;
  final wasmU32Bytes = wasmU32.asUint8List();
  assert(wasmU32Bytes.length == 12,
      "wasmU32.asUint8List().length=${wasmU32Bytes.length}, expected 12 (3*4)");
  print("Uint32List tests passed");

  // Int32List (WASM-heap)
  final wasmI32 = makeInt32List(3);
  wasmI32[0] = -1;
  wasmI32[1] = 0;
  wasmI32[2] = 1;
  final wasmI32Bytes = wasmI32.asUint8List();
  assert(wasmI32Bytes.length == 12,
      "wasmI32.asUint8List().length=${wasmI32Bytes.length}, expected 12 (3*4)");
  print("Int32List tests passed");

  // Round-trip test: mimics the setBufferAt flow
  //   data.asUint8List() → byteData.address.cast() → pass to native
  final srcF32 = makeFloat32List(3);
  srcF32[0] = 42.0;
  srcF32[1] = -1.5;
  srcF32[2] = 0.0;
  final srcBytes = srcF32.asUint8List();
  final srcAddr = srcBytes.address;
  assert(srcAddr != 0, "round-trip address should be non-zero");
  print("Round-trip test passed");

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
  assert(ptrArray[0].getValue() == 100, "ptrArray[0]=${ptrArray[0].getValue()}");
  assert(ptrArray[1].getValue() == 200, "ptrArray[1]=${ptrArray[1].getValue()}");
  assert(ptrArray[2].getValue() == 300, "ptrArray[2]=${ptrArray[2].getValue()}");
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
