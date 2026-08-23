import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// Imported directly rather than through bindings.dart so that the sibling
// web adapter (which needs the non-default branch) analyzes cleanly; see
// the comment in api_web.dart.
import '../generated/dual_bindings_ffi.g.dart' as bindings;

late final bindings.DualNativeLibrary _lib = bindings.DualNativeLibrary(
    DynamicLibrary.open(Platform.environment['DUAL_NATIVE_LIB'] ??
        'tool/dual_target_smoke/build/libdual.so'));

void ensureDualReady() {
  // Touch the lazy field so a missing library fails fast with a clear error.
  _lib.dualAdd(0, 0);
}

int dualAdd(int a, int b) => _lib.dualAdd(a, b);

(double, double) dualScaledPoint(double x, double y, double k) {
  final p = calloc<bindings.DualPoint>();
  try {
    p.ref.x = x; // struct field write, via generated binding
    p.ref.y = y;
    _lib.dualPointScale(p, k); // C mutates the point through the pointer
    return (p.ref.x, p.ref.y); // struct field read, via generated binding
  } finally {
    calloc.free(p);
  }
}

String dualGreet(String name) {
  final namePtr = name.toNativeUtf8();
  final out = calloc<Char>(64);
  try {
    _lib.dualGreet(namePtr.cast(), out, 64);
    return out.cast<Utf8>().toDartString();
  } finally {
    calloc.free(namePtr);
    calloc.free(out);
  }
}
