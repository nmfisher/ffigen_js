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
}
