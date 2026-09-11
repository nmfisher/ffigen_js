import 'package:ffigen_js/src/jsgen/code_generator.dart';
import 'package:ffigen_js/src/jsgen/code_generator/writer.dart';
import 'package:test/test.dart';

void main() {
  test('user-facing function wrappers remain top-level', () {
    final int32 = NativeType(SupportedNativeType.int32);
    final function = Func(
      name: 'addOne',
      returnType: int32,
      parameters: [Parameter(name: 'value', type: int32)],
      usr: 'c:@F@addOne',
      originalName: 'addOne',
    );
    final writer = Writer(
      bindings: [function],
      typeBindings: [],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    );

    final output = writer.generate();
    final externalBinding = output.indexOf('external int _addOne(int value,');
    final publicWrapper = output.indexOf('int addOne(int value,');

    expect(externalBinding, greaterThanOrEqualTo(0));
    expect(publicWrapper, greaterThan(externalBinding));
    expect(output, isNot(contains('class NativeLibrary')));
    expect(
      output,
      contains('GeneratedBindings.instance._addOne(value)'),
    );
  });

  test('pointer arguments are materialized in a native call scope', () {
    final uint8 = NativeType(SupportedNativeType.uint8);
    final int32 = NativeType(SupportedNativeType.int32);
    final function = Func(
      name: 'readBytes',
      returnType: int32,
      parameters: [
        Parameter(name: 'data', type: PointerType(uint8)),
        Parameter(name: 'other', type: PointerType(uint8)),
        Parameter(name: 'length', type: int32),
      ],
      usr: 'c:@F@readBytes',
      originalName: 'readBytes',
      isLeaf: true,
    );
    final writer = Writer(
      bindings: [function],
      typeBindings: [],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    );

    final output = writer.generate();

    expect(
      output,
      contains('withNativeCall(<Pointer>[data,other], (scope)'),
    );
    expect(
      output,
      contains(
        'GeneratedBindings.instance._readBytes('
        'scope.addressOf(data),scope.addressOf(other),length)',
      ),
    );
    expect(output, isNot(contains('releaseTemporaryTypedDataAddress')));
  });

  test('non-leaf pointer arguments require an existing Wasm address', () {
    final uint8 = NativeType(SupportedNativeType.uint8);
    final function = Func(
      name: 'readBytes',
      returnType: NativeType(SupportedNativeType.voidType),
      parameters: [Parameter(name: 'data', type: PointerType(uint8))],
      usr: 'c:@F@readBytes',
      originalName: 'readBytes',
    );
    final writer = Writer(
      bindings: [function],
      typeBindings: [],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    );

    final output = writer.generate();

    expect(
        output,
        contains('GeneratedBindings.instance._readBytes('
            'rawPointer(data))'));
    expect(output, isNot(contains('withNativeCall')));
  });

  test('scope parameter does not shadow the generated call scope', () {
    final function = Func(
      name: 'readBytes',
      returnType: NativeType(SupportedNativeType.int32),
      parameters: [
        Parameter(
          name: 'scope',
          type: PointerType(NativeType(SupportedNativeType.uint8)),
        ),
      ],
      usr: 'c:@F@readBytes',
      originalName: 'readBytes',
      isLeaf: true,
    );
    final output = Writer(
      bindings: [function],
      typeBindings: [],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    ).generate();

    expect(output, contains('(scope1)'));
    expect(output, contains('_readBytes(scope1.addressOf(scope))'));
  });

  test('returned structs are allocated before the temporary call scope', () {
    final result = Struct(name: 'Result', members: [
      Member(name: 'value', type: NativeType(SupportedNativeType.int32)),
    ]);
    final function = Func(
      name: 'readResult',
      returnType: result,
      parameters: [
        Parameter(
          name: 'data',
          type: PointerType(NativeType(SupportedNativeType.uint8)),
        ),
      ],
      usr: 'c:@F@readResult',
      originalName: 'readResult',
      isLeaf: true,
    );
    final output = Writer(
      bindings: [function],
      typeBindings: [result],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    ).generate();

    final allocation = output.indexOf('final Result_out = Result.stackAlloc()');
    expect(allocation, greaterThanOrEqualTo(0));
    expect(allocation, lessThan(output.indexOf('return withNativeCall(')));
    expect(output, contains('return Result_out.toDart()'));
  });
}
