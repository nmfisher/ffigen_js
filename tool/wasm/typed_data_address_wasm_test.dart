import 'dart:typed_data';

import 'package:ffigen_js/ffigen_js.dart';

import '../../example/lib/generated_bindings_js.g.dart';
import '../../test/support/generated_api_contract.dart';
import '../../test/support/typed_data_address_contract.dart';

// Runs the shared TypedData.address and generated-API contracts plus
// Wasm-specific offset cases against the Emscripten heap. Compiled with
// `dart compile wasm` and launched by main.js; a failure throws so node exits
// non-zero.
void main() {
  GeneratedBindings.initBindings("module");

  final failures = <String>[];
  void run(String name, void Function() body) {
    try {
      body();
      print('PASS $name');
    } catch (error) {
      print('FAIL $name: $error');
      failures.add(name);
    }
  }

  for (final entry in typedDataAddressContract().entries) {
    run(entry.key, entry.value);
  }
  for (final entry in generatedApiContract().entries) {
    run('generated API: ${entry.key}', entry.value);
  }

  run('empty wasm-backed lists have a null address', () {
    check(makeUint8List(0).address.addr == 0,
        'An empty TypedData value should have a null address');
  });

  run('wasm-backed subviews keep their absolute heap offset', () {
    final float32 = makeFloat32List(3);
    check(float32.address.addr == float32.offsetInBytes,
        'A heap-backed list address did not match its heap byte offset');
    float32[0] = -1.5;
    final subview = Float32List.sublistView(float32, 1, 3);
    check(subview.address.addr == float32.address.addr + 4,
        'A heap-backed subview did not keep its non-zero heap offset');
    write_float32_for_address_test(subview.address);
    check(
        float32[1] == 12.5 && float32[0] == -1.5,
        'A native write through a heap-backed subview did not land at the '
        'absolute heap offset');
    final byteView = float32.asUint8List();
    check(byteView.address.addr == float32.address.addr,
        'A byte view of a heap-backed list did not retain its heap address');
  });

  run('a scope borrows wasm-backed buffers without copying', () {
    final borrowed = makeUint8List(8)
      ..fillRange(0, 8, 0)
      ..[2] = 9;
    final before = NativeLibrary.instance.stackSave();
    withNativeBuffers([borrowed], () {
      check(NativeLibrary.instance.stackSave().addr == before.addr,
          'A wasm-backed buffer triggered a temporary allocation');
      write_uint8_for_address_test(borrowed.address);
      check(borrowed[0] == 201,
          'A native write did not reach an Emscripten-backed list directly');
    });
    check(borrowed[0] == 201, 'A borrowed buffer must not need copy-back');
    NativeLibrary.instance.stackRestore(before);
  });

  if (failures.isNotEmpty) {
    print('${failures.length} wasm TypedData.address test(s) failed');
    throw StateError('Wasm TypedData.address tests failed: $failures');
  }
  print('All wasm TypedData.address tests passed');
}
