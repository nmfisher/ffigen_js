@TestOn('vm')
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/dual_target_smoke/lib/consumer.dart';

// Dual-target integration test, native half. The SAME native/src/dual.c is
// compiled to build/libdual.so (here or by build.sh) and to an Emscripten
// module (build.sh); the web half runs the SAME consumer.dart under
// dart-compiled wasm + node via run_web.sh. consumer.dart imports only
// conditional exports (bindings.dart / api.dart), so this test exercises
// the dart.library.ffi branch and the web smoke the dart.library.js_interop
// branch of the exact same source.
void main() {
  final fixture = p.join('tool', 'dual_target_smoke');
  final lib = p.join(fixture, 'build', 'libdual.so');

  setUpAll(() {
    if (File(lib).existsSync()) return;
    final cc = Platform.environment['CC'] ?? 'cc';
    final which = Process.runSync('sh', ['-c', 'command -v $cc']);
    if (which.exitCode != 0) {
      throw StateError('no C compiler ($cc) on PATH; cannot build $lib');
    }
    final result = Process.runSync(cc, [
      '-shared',
      '-fPIC',
      '-o',
      lib,
      p.join(fixture, 'native', 'src', 'dual.c'),
      '-I${p.join(fixture, 'native', 'include')}',
    ]);
    expect(result.exitCode, 0,
        reason: 'compiling ${p.join(fixture, 'native', 'src', 'dual.c')} '
            'failed:\n${result.stderr}');
  });

  test('same .c + conditional import runs through native dart:ffi bindings',
      () {
    final report = runDualTargetChecks();

    // Records compare structurally, so the expected values are literal.
    expect(report.addResult, 42);
    expect(report.scaledPoint.$1, 3.0);
    expect(report.scaledPoint.$2, 6.5);
    expect(report.greeting, 'hello, dual-target!');
  });
}
