import 'dart:typed_data';

import 'package:ffigen_js/ffigen_js.dart';

import 'generated_api_bindings_native.dart'
    if (dart.library.js_interop) 'generated_api_bindings_web.dart';
import 'typed_data_address_contract.dart' show check;

// Every entry compiles unchanged against the ffigen dart:ffi bindings (Dart
// VM) and the jsgen JS bindings (web/Wasm), so identical call-site code is
// executed and its outputs checked on both platforms. Only leaf functions can
// accept `TypedData.address` on the VM, so pointer arguments are covered
// through the leaf subset.
Map<String, void Function()> generatedApiContract() => {
      'plain integer calls agree on both platforms': () {
        check(sum(1, 2) == 3, 'sum was not marshalled');
        check(sum_with_typedef(1, 2) == 3, 'a typedef call was not marshalled');
      },
      'typed lists of every width marshal with correct values': () {
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
              'Ordinary Dart typed lists were not readable by native code');
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
            'Native writes did not reach the Dart typed lists');
      },
      'overlapping views share one allocation and copy back to the exact '
          'offset': () {
        final aliasedData = Uint8List.fromList([1, 2, 3, 4]);
        final aliasedView = Uint8List.sublistView(aliasedData, 1);
        withNativeBuffers([aliasedData, aliasedView], () {
          check(
              verify_typed_data_alias(aliasedData.address, aliasedView.address),
              'Overlapping views did not preserve pointer aliasing');
        });
        check(aliasedData[1] == 77 && aliasedView[0] == 77,
            'An aliased native write did not reach the Dart buffer');
      },
      'mixed-type views keep alignment across differing element sizes': () {
        final mixedBuffer = Uint8List(16);
        final mixedBytes = Uint8List.view(mixedBuffer.buffer, 1, 7);
        final mixedWords = Uint32List.view(mixedBuffer.buffer, 4, 1);
        withNativeBuffers([mixedBytes, mixedWords], () {
          check(
              verify_typed_data_alignment(
                  mixedBytes.address, mixedWords.address),
              'Mixed-type views lost their alignment or relative offsets');
        });
        check(mixedWords[0] == 123456,
            'An aligned native write did not reach the Dart buffer');
      },
      'a subview at an odd offset of a large buffer copies back only its own '
          'bytes': () {
        final large = Uint8List(64 * 1024 + 8);
        final view = Uint8List.sublistView(large, 3, 7);
        withNativeBuffers([view], () {
          fill_bytes(view.address, 7, view.length);
          check(compare_bytes(view.address, view.address, view.length) == 0,
              'A large odd-offset view disagreed with itself');
        });
        for (var i = 0; i < large.length; i++) {
          final expected = i >= 3 && i < 7 ? 7 : 0;
          check(large[i] == expected,
              'Byte $i was ${large[i]} instead of $expected');
        }
      },
      'floating-point results read back through pointers': () {
        final quotient = divide(10, 2);
        check(quotient.asTypedList(1)[0] == 5.0,
            'A pointer return value was not readable');
      },
      'unreferenced enums are still emitted': () {
        check(UnreferencedEnum.UNREFERENCED_ENUM_B.value == 2,
            'UnreferencedEnum lost UNREFERENCED_ENUM_B');
        check(UnreferencedEnum.UNREFERENCED_ENUM_C.value == 4,
            'UnreferencedEnum lost UNREFERENCED_ENUM_C');
      },
    };
