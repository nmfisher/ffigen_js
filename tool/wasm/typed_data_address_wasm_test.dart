import 'dart:typed_data';

import 'package:ffigen_js/ffigen_js.dart';

import '../../example/lib/generated_bindings_js.g.dart';
import '../../test/support/typed_data_address_contract.dart';

// Runs the shared TypedData.address contract plus web-specific offset cases
// against the Emscripten heap. Compiled with `dart compile wasm` and launched
// by main.js; a failure throws so node exits non-zero.
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

  run('all typed list widths copy in and out through one scope', () {
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
      check(
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
          'Ordinary Dart typed lists were not copied into Wasm memory '
          'correctly');
      write_uint8_for_address_test(dartUint8.address);
      write_int16_for_address_test(dartInt16.address);
      write_uint16_for_address_test(dartUint16.address);
      write_int32_for_address_test(dartInt32.address);
      write_int64_for_address_test(dartInt64.address);
      write_uint32_for_address_test(dartUint32.address);
      write_float32_for_address_test(dartFloat32.address);
      write_float64_for_address_test(dartFloat64.address);
    });
    check(
        dartUint8[0] == 201 &&
            dartInt16[0] == -1234 &&
            dartUint16[0] == 54321 &&
            dartInt32[0] == -123456789 &&
            dartInt64[0] == -9007199254740995 &&
            dartUint32[0] == 3456789012 &&
            dartFloat32[0] == 12.5 &&
            dartFloat64[0] == 9876.5,
        'Native writes were not copied back to ordinary Dart typed lists');
  });

  run('aliased views share one allocation and copy back to the exact offset',
      () {
    final aliasedData = Uint8List.fromList([1, 2, 3, 4]);
    final aliasedView = Uint8List.sublistView(aliasedData, 1);
    withNativeBuffers([aliasedData, aliasedView], () {
      check(verify_typed_data_alias(aliasedData.address, aliasedView.address),
          'Overlapping TypedData views did not preserve pointer aliasing');
    });
    check(aliasedData[1] == 77 && aliasedView[0] == 77,
        'An aliased native write was not copied back to the Dart buffer');
  });

  run('mixed-type views keep alignment across differing element sizes', () {
    final mixedBuffer = Uint8List(16);
    final mixedBytes = Uint8List.view(mixedBuffer.buffer, 1, 7);
    final mixedWords = Uint32List.view(mixedBuffer.buffer, 4, 1);
    withNativeBuffers([mixedBytes, mixedWords], () {
      check(verify_typed_data_alignment(mixedBytes.address, mixedWords.address),
          'Mixed-type aliases lost their alignment or relative offsets');
    });
    check(
        mixedWords[0] == 123456, 'An aligned native write was not copied back');
  });

  run(
      'a subview at an odd offset of a large buffer copies back only its own '
      'bytes', () {
    final large = Uint8List(64 * 1024 + 8);
    final view = Uint8List.sublistView(large, 3, 7);
    withNativeBuffers([view], () {
      fill_bytes(view.address, 7, view.length);
      check(compare_bytes(view.address, view.address, view.length) == 0,
          'A large odd-offset view disagreed with itself in Wasm memory');
    });
    for (var i = 0; i < large.length; i++) {
      final expected = i >= 3 && i < 7 ? 7 : 0;
      check(
          large[i] == expected,
          'Byte $i was ${large[i]} instead of $expected: copy-back shifted '
          'bytes around the view offset');
    }
  });

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
