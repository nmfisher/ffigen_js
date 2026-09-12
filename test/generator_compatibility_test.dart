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
    expect(output, isNot(contains('withNativeCall')));
    expect(
      output,
      contains('GeneratedBindings.instance._addOne(value)'),
    );
  });

  test('JS wrappers materialize pointers and expose integer interop arguments',
      () {
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
    );
    final writer = Writer(
      bindings: [function],
      typeBindings: [],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    );

    final output = writer.generate();

    expect(output, contains('external int _readBytes(int data,'));
    expect(output, contains('if (!data.isDeferred && !other.isDeferred)'));
    expect(output, contains('_readBytes(data.addr,other.addr,length)'));
    expect(output, contains('withNativeCall(<Pointer>[data,other], (scope)'));
    expect(
      output,
      contains(
        'GeneratedBindings.instance._readBytes('
        'scope.addressOf(data),scope.addressOf(other),length)',
      ),
    );
    expect(output, isNot(contains('releaseTemporaryTypedDataAddress')));
  });

  test('void JS wrappers scope TypedData arguments without leaf configuration',
      () {
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
            'scope.addressOf(data))'));
    expect(output, contains('withNativeCall'));
  });

  test('scope parameter does not shadow the internal call scope', () {
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
    );
    final output = Writer(
      bindings: [function],
      typeBindings: [],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    ).generate();

    expect(output, contains('_readBytes(scope1.addressOf(scope))'));
  });

  test('returned structs retain caller-managed stack ownership', () {
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
    expect(allocation, lessThan(output.indexOf('final result =')));
    expect(allocation, lessThan(output.indexOf('return withNativeCall(')));
    expect(output, contains('return Result_out.toDart()'));
  });

  test('pointer typedefs retain user types but cross JS as integers', () {
    final pointer = Typealias(
        name: 'Bytes',
        type: PointerType(NativeType(SupportedNativeType.uint8)));
    final function = Func(
      name: 'identity',
      returnType: pointer,
      parameters: [Parameter(name: 'data', type: pointer)],
      usr: 'identity',
      originalName: 'identity',
    );
    final output = Writer(
      bindings: [function],
      typeBindings: [pointer],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    ).generate();
    expect(output, contains('external int _identity(int data,'));
    expect(output, contains('scope.addressOf(data)'));
    expect(output, contains('return Pointer(result).cast()'));
  });

  test('pointer callbacks convert integer JS arguments into Dart pointers', () {
    final callback = NativeFunc(FunctionType(
      returnType: NativeType(SupportedNativeType.voidType),
      parameters: [
        Parameter(
            name: 'data',
            type: PointerType(NativeType(SupportedNativeType.uint8)))
      ],
    ));
    final function = Func(
      name: 'invoke',
      returnType: NativeType(SupportedNativeType.voidType),
      parameters: [Parameter(name: 'callback', type: PointerType(callback))],
      usr: 'invoke',
      originalName: 'invoke',
    );
    final output = Writer(
      bindings: [function],
      typeBindings: [],
      className: 'NativeLibrary',
      silenceEnumWarning: true,
      nativeEntryPoints: [],
    ).generate();
    expect(output, contains('final callback = (int arg0)'));
    expect(output, contains('this(Pointer<T>(arg0))'));
    expect(output, contains('callback.toJS'));
    expect(output, isNot(contains('this.toJS')));
  });
}
