import 'dart:typed_data';

import 'package:ffigen_js/ffigen_js.dart';

import 'address_bindings_native.dart'
    if (dart.library.js_interop) 'address_bindings_web.dart';

// The scopes and call sites compile unchanged for leaf dart:ffi and JS calls.
Map<String, void Function()> typedDataAddressContract() => {
      'inline TypedData.address input and output': () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        withNativeBuffers([data], () {
          fill_bytes(data.address, 77, data.length);
        });
        check(
            data.every((value) => value == 77), 'native write was not visible');
        final expected = Uint8List.fromList([77, 77, 77, 77]);
        final comparison = withNativeBuffers([data, expected], () {
          return compare_bytes(data.address, expected.address, data.length);
        });
        check(comparison == 0, 'native input did not match');
      },
      'inline subview addresses respect offsets': () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        final view = Uint8List.sublistView(data, 1, 3);
        withNativeBuffers([view], () {
          fill_bytes(view.address, 99, view.length);
          check(compare_bytes(view.address, view.address, view.length) == 0,
              'aliased inline addresses disagreed');
        });
        check(data[0] == 1 && data[1] == 99 && data[2] == 99 && data[3] == 4,
            'subview write changed the wrong bytes');
      },
      'large buffers retain the same call convention': () {
        final data = Uint8List(64 * 1024);
        withNativeBuffers([data], () {
          fill_bytes(data.address, 19, data.length);
        });
        check(data.every((value) => value == 19), 'large-buffer write failed');
      },
      'scope copies writes back after an exception': () {
        final data = Uint8List(4);
        final failure = StateError('body failed');
        try {
          withNativeBuffers([data], () {
            fill_bytes(data.address, 31, data.length);
            throw failure;
          });
        } on StateError catch (error) {
          check(identical(error, failure), 'scope replaced the exception');
        }
        check(data.every((value) => value == 31), 'write-back was lost');
      },
      'nested scopes preserve aliases and restore the outer scope': () {
        final data = Uint8List(4);
        final nested = Uint8List(4);
        withNativeBuffers([data], () {
          fill_bytes(data.address, 41, data.length);
          final view = Uint8List.sublistView(data, 1, 3);
          withNativeBuffers([view, nested], () {
            fill_bytes(view.address, 42, view.length);
            fill_bytes(nested.address, 43, nested.length);
          });
          check(
              nested.every((value) => value == 43), 'inner write-back failed');
          check(compare_bytes(data.address, data.address, data.length) == 0,
              'outer scope was not restored');
        });
        check(data[0] == 41 && data[1] == 42 && data[2] == 42 && data[3] == 41,
            'nested scope lost aliased writes');
      },
    };

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
