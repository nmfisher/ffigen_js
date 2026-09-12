@TestOn('vm')
library;

import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as allocation;
import 'package:ffigen_js/ffigen_js.dart';
import 'package:test/test.dart';

import 'support/address_bindings_native.dart';
import 'support/typed_data_address_contract.dart';

void main() {
  for (final entry in typedDataAddressContract().entries) {
    test(entry.key, entry.value);
  }
  test('native leaf call receives the original backing address', () {
    final original = allocation.malloc<ffi.Uint8>(4);
    try {
      final view = original.asTypedList(4);
      // memset returns its destination. A temporary copy would differ here.
      withNativeBuffers([view], () {
        final ffi.Pointer<ffi.Uint8> destination =
            fill_bytes(view.address, 42, 4);
        expect(destination.address, original.address);
        expect(view, everyElement(42));
      });
      expect(view, everyElement(42));
    } finally {
      allocation.malloc.free(original);
    }
  });
  test('native scope does not enumerate or materialize buffers', () {
    Iterable<TypedData> unusedBuffers() sync* {
      throw StateError('native must not inspect buffers');
    }

    final data = Uint8List(4);
    final result = withNativeBuffers(unusedBuffers(), () {
      fill_bytes(data.address, 63, data.length);
      // Native writes are visible before the callback returns, not copied back.
      expect(data, everyElement(63));
      return 123;
    });
    expect(result, 123);
  });
}
