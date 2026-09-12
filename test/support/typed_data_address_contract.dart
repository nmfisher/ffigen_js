import 'dart:typed_data';

import 'package:ffigen_js/ffigen_js.dart';

import 'address_bindings_native.dart'
    if (dart.library.js_interop) 'address_bindings_web.dart';

// These call sites compile unchanged for leaf dart:ffi and generated JS calls.
Map<String, void Function()> typedDataAddressContract() => {
      'inline TypedData.address input and output': () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        fill_bytes(data.address, 77, data.length);
        check(
            data.every((value) => value == 77), 'native write was not visible');
        final expected = Uint8List.fromList([77, 77, 77, 77]);
        check(compare_bytes(data.address, expected.address, data.length) == 0,
            'native input did not match');
      },
      'inline subview addresses respect offsets': () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        final view = Uint8List.sublistView(data, 1, 3);
        fill_bytes(view.address, 99, view.length);
        check(data[0] == 1 && data[1] == 99 && data[2] == 99 && data[3] == 4,
            'subview write changed the wrong bytes');
        check(compare_bytes(view.address, view.address, view.length) == 0,
            'aliased inline addresses disagreed');
      },
      'large buffers retain the same call convention': () {
        final data = Uint8List(64 * 1024);
        fill_bytes(data.address, 19, data.length);
        check(data.every((value) => value == 19), 'large-buffer write failed');
      },
    };

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
