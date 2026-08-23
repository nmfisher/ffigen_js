import 'package:ffigen_js/src/jsgen/code_generator.dart';
import 'package:ffigen_js/src/jsgen/code_generator/writer.dart';
import 'package:ffigen_js/src/jsgen/config_provider/config_types.dart';
import 'package:test/test.dart';

void main() {
  Func addOneFunc() => Func(
        name: 'addOne',
        returnType: NativeType(SupportedNativeType.int32),
        parameters: [
          Parameter(name: 'value', type: NativeType(SupportedNativeType.int32))
        ],
        usr: 'c:@F@addOne',
        originalName: 'addOne',
      );

  Writer writerFor({
    List<Binding> bindings = const [],
    List<Binding> typeBindings = const [],
    FfiNativeConfig ffiNativeConfig =
        const FfiNativeConfig(enabled: false),
  }) =>
      Writer(
        bindings: bindings,
        typeBindings: typeBindings,
        className: 'NativeLibrary',
        silenceEnumWarning: true,
        nativeEntryPoints: [],
        ffiNativeConfig: ffiNativeConfig,
      );

  test('user-facing function wrappers remain top-level', () {
    final writer = writerFor(bindings: [addOneFunc()]);
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

  test('generated wrapper keeps its own per-file instance', () {
    final output = writerFor(bindings: [addOneFunc()]).generate();

    // The wrapper caches its own instance instead of reading the ambient
    // library directly, so two bindings files on one page dispatch to
    // different modules.
    expect(output, contains('static GeneratedBindings? _instance;'));
    expect(
      output,
      contains(
        '_instance ?? (NativeLibrary.instance as GeneratedBindings)',
      ),
    );
    // Legacy escape hatch: assigning the static re-points just this file.
    expect(
      output,
      contains('static set instance(GeneratedBindings lib)'),
    );
  });

  test('initBindings registers through NativeLibrary.init', () {
    final output = writerFor(bindings: [addOneFunc()]).generate();

    // Optional-positional keeps the legacy `initBindings("name")` call
    // shape working; makeDefault lets secondary modules skip the ambient
    // (default) slot.
    expect(
      output,
      contains(
        'static void initBindings([String? moduleName, bool makeDefault = true])',
      ),
    );
    expect(
      output,
      contains('NativeLibrary.init(moduleName, makeDefault: makeDefault)'),
    );
    // The old template resolved the module inline; the new one delegates to
    // the runtime registry.
    expect(output, isNot(contains('globalContext.getProperty')));
  });

  test('without an asset-id, initBindings requires a module name', () {
    final output = writerFor(bindings: [addOneFunc()]).generate();

    expect(output, contains('if (moduleName == null)'));
    expect(output, contains("ffi-native: asset-id:"));
    expect(output, isNot(contains('moduleName ??=')));
  });

  test('ffi-native asset-id is baked in as the default module name', () {
    final output = writerFor(
      bindings: [addOneFunc()],
      ffiNativeConfig: const FfiNativeConfig(enabled: true, assetId: 'thermion'),
    ).generate();

    expect(output, contains("moduleName ??= 'thermion';"));
    // With a baked default, initBindings() takes no argument.
    expect(output, isNot(contains('if (moduleName == null)')));
  });

  test('struct member access goes through the per-file instance', () {
    final struct = Struct(
      usr: 'c:@S@Vec3',
      originalName: 'Vec3',
      name: 'Vec3',
      members: [
        Member(
          name: 'x',
          type: NativeType(SupportedNativeType.float),
          originalName: 'x',
        ),
      ],
    );
    final output = writerFor(typeBindings: [struct]).generate();

    expect(
      output,
      contains("GeneratedBindings.instance.getValue(addr, 'float')"),
    );
    expect(
      output,
      contains('GeneratedBindings.instance.setValue('),
    );
    expect(
      output,
      contains('GeneratedBindings.instance.stackAlloc'),
    );
    // Ambient calls must not appear in newly generated struct code.
    expect(output, isNot(contains('NativeLibrary.instance.getValue')));
    expect(output, isNot(contains('NativeLibrary.instance.setValue')));
    expect(output, isNot(contains('NativeLibrary.instance.stackAlloc')));
  });
}
