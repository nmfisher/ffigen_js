import 'package:ffigen_js/ffigen_js.dart';

void main() {
  // --- init: first module claims the ambient/default slot -------------
  final a = NativeLibrary.init('mod_a');
  final b = NativeLibrary.init('mod_b', makeDefault: false);
  final spA = a.stackSave();
  final spB = b.stackSave();

  // --- heap isolation --------------------------------------------------
  // Both stacks are fresh and identical, so these allocations land at the
  // SAME numeric address in their respective heaps. Each library must see
  // its own bytes: same address, different contents.
  final pa = a.toNativeUtf8('sentinel-a');
  final pb = b.toNativeUtf8('sentinel-b');
  assert(pa.addr == pb.addr);
  assert(a.utf8ToString(pa) == 'sentinel-a');
  assert(b.utf8ToString(pb) == 'sentinel-b');
  assert(a.utf8ToString(pb) == 'sentinel-a');
  assert(b.utf8ToString(pa) == 'sentinel-b');

  // --- init is idempotent per name ------------------------------------
  final aAgain = NativeLibrary.init('mod_a');
  final pa2 = aAgain.toNativeUtf8('second');
  assert(a.utf8ToString(pa2) == 'second');

  // --- ambient follows the FIRST module, not the latest ---------------
  final pAmbient = NativeLibrary.instance.toNativeUtf8('ambient');
  assert(a.utf8ToString(pAmbient) == 'ambient');
  // b's stack has only its first allocation; this offset is untouched.
  assert(NativeLibrary.byName('mod_b').utf8ToString(pAmbient) == '');

  // --- byName round-trips to the registered library -------------------
  assert(NativeLibrary.byName('mod_b').utf8ToString(pb) == 'sentinel-b');
  assert(NativeLibrary.byName('mod_a').utf8ToString(pa) == 'sentinel-a');
  var threw = false;
  try {
    NativeLibrary.byName('nope');
  } on StateError {
    threw = true;
  }
  assert(threw);

  // --- setDefault is first-wins: a later claim by b is ignored --------
  NativeLibrary.setDefault(b);
  final pAfter = NativeLibrary.instance.toNativeUtf8('after-setdefault');
  assert(a.utf8ToString(pAfter) == 'after-setdefault');
  assert(NativeLibrary.byName('mod_b').utf8ToString(pAfter) == '');

  // --- legacy escape hatch: assigning instance still switches ---------
  NativeLibrary.instance = b;
  final pLegacy = NativeLibrary.instance.toNativeUtf8('via-legacy');
  assert(b.utf8ToString(pLegacy) == 'via-legacy');
  assert(a.utf8ToString(pLegacy) != 'via-legacy');

  // --- typed lists: same numeric address, separate memory --------------
  a.stackRestore(spA);
  b.stackRestore(spB);
  final f32A = a.makeFloat32List(2);
  final f32B = b.makeFloat32List(2);
  assert(f32A.offsetInBytes == f32B.offsetInBytes);
  f32A[0] = 1.5;
  f32B[0] = 9.5;
  assert(f32A[0] == 1.5);
  assert(f32B[0] == 9.5);

  final listA = a.makeUint8List(4);
  final listB = b.makeUint8List(4);
  listA[0] = 42;
  listB[0] = 7;
  assert(listA[0] == 42 && listB[0] == 7);

  // --- a missing module global raises instead of yielding a broken lib --
  var missingThrew = false;
  try {
    NativeLibrary.init('missing_module');
  } on Exception {
    missingThrew = true;
  }
  assert(missingThrew);

  // --- malloc/free are tracked and safe to double-free ----------------
  final m = a.malloc<Uint8>(16);
  a.free(m);
  a.free(m); // untracked by now: ignored, not passed to the module

  print('SMOKE OK');
}
