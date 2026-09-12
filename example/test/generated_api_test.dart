@TestOn('vm')
library;

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart' as allocation;
import 'package:test/test.dart';

import '../../example/lib/generated_bindings_ffi.g.dart';
import '../../test/support/generated_api_contract.dart';
import '../../test/support/typed_data_address_contract.dart';

// Compiles the shared contracts against the ffigen dart:ffi bindings built
// through native assets, mirroring the Wasm runs of the same contracts.
void main() {
  for (final entry in generatedApiContract().entries) {
    test(entry.key, entry.value);
  }
  for (final entry in typedDataAddressContract().entries) {
    test('typed data: ${entry.key}', entry.value);
  }
  test('structs return by value with the expected fields', () {
    // dart:ffi only allows `TypedData.address` on leaf calls, and leaf calls
    // cannot return structs by value, so this non-leaf call uses an
    // explicitly allocated pointer, as ordinary dart:ffi code would.
    final input = allocation.malloc<ffi.Uint8>(1)..[0] = 9;
    try {
      final result = return_struct_for_address_test(input);
      expect(result.a, 9.0);
      expect(result.c, 42);
    } finally {
      allocation.malloc.free(input);
    }
  });
}
