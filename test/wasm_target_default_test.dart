import 'package:ffigen_js/src/jsgen/config_provider/config_types.dart';
import 'package:test/test.dart';

void main() {
  test('prepends default wasm32 target when none is specified', () {
    final opts = withDefaultWasmTarget(['-I/headers']);

    expect(opts, equals(['-target', 'wasm32-unknown-emscripten', '-I/headers']));
  });

  test('does not duplicate default when user specifies -target', () {
    final opts = withDefaultWasmTarget(
        ['-target', 'wasm32-unknown-wasip1', '-I/headers']);

    expect(opts, equals(['-target', 'wasm32-unknown-wasip1', '-I/headers']));
  });

  test('does not duplicate default when user specifies --target=', () {
    final opts = withDefaultWasmTarget(['--target=wasm32-unknown-emscripten']);

    expect(opts, equals(['--target=wasm32-unknown-emscripten']));
  });
}
