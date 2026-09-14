import 'package:ffigen_js/src/jsgen/code_generator.dart';
import 'package:ffigen_js/src/jsgen/code_generator/writer.dart';
import 'package:test/test.dart';

void main() {
  test('generates bindings for uint64_t pointers', () {
    final uint64 = NativeType(SupportedNativeType.uint64);
    final function = Func(
      name: 'readUint64',
      returnType: NativeType(SupportedNativeType.voidType),
      parameters: [
        Parameter(name: 'value', type: PointerType(uint64)),
      ],
      usr: 'c:@F@readUint64',
      originalName: 'readUint64',
    );
    final writer = Writer(
      bindings: [function],
      typeBindings: [],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    );

    final output = writer.generate();

    expect(output, contains('Pointer<Int64> value'));
  });
}
