import 'package:ffigen_js/ffigen_js.dart';

// Imported directly rather than through bindings.dart: the analyzer
// resolves a conditional export to its default (native) branch, so
// web-only symbols do not resolve through it statically. At compile time
// (dart compile wasm) bindings.dart would select this same file.
import '../generated/dual_bindings_js.g.dart' as bindings;

void ensureDualReady() {
  // Baked-in default from js_config.yaml's `ffi-native: asset-id: dual`:
  // resolves globalThis['dual'] (published by main.mjs) and registers it.
  bindings.GeneratedBindings.initBindings();
}

int dualAdd(int a, int b) => bindings.dualAdd(a, b);

(double, double) dualScaledPoint(double x, double y, double k) {
  final p = bindings.DualPoint.stackAlloc().toDart();
  p.x = x; // struct field write, via generated binding
  p.y = y;
  bindings.dualPointScale(p.address, k); // C mutates through the pointer
  return (p.x, p.y); // struct field read, via generated binding
}

String dualGreet(String name) {
  final lib = bindings.GeneratedBindings.instance;
  final namePtr = lib.toNativeUtf8(name);
  final out = lib.makeUint8List(64); // view over the module's memory
  final outPtr = out.address.cast<Char>();
  bindings.dualGreet(namePtr, outPtr, 64);
  return outPtr.toDartString();
}
