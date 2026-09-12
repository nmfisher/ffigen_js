@TestOn('vm')
library;

import 'dart:ffi' as ffi;
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
      final ffi.Pointer<ffi.Uint8> destination =
          fill_bytes(view.address, 42, 4);
      expect(destination.address, original.address);
      expect(view, everyElement(42));
    } finally {
      allocation.malloc.free(original);
    }
  });
}
