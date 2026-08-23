import 'api.dart';

/// Result of [runDualTargetChecks], so callers (the native `dart test` and
/// the wasm/node smoke) can assert on the same values.
class DualTargetReport {
  final int addResult;
  final (double, double) scaledPoint;
  final String greeting;

  DualTargetReport(this.addResult, this.scaledPoint, this.greeting);
}

/// The ONE consumer, run verbatim on both targets. It only touches the
/// target-agnostic surface from api.dart (which itself routes through the
/// conditional export in bindings.dart).
DualTargetReport runDualTargetChecks() {
  ensureDualReady();

  final addResult = dualAdd(20, 22);
  assert(addResult == 42, 'dualAdd(20, 22) -> $addResult');

  // 1.5 and 3.25 are exactly representable as float32, so the scaled
  // results compare exactly on both targets.
  final scaledPoint = dualScaledPoint(1.5, 3.25, 2);
  assert(scaledPoint.$1 == 3.0, 'scaled x -> ${scaledPoint.$1}');
  assert(scaledPoint.$2 == 6.5, 'scaled y -> ${scaledPoint.$2}');

  final greeting = dualGreet('dual-target');
  assert(greeting == 'hello, dual-target!', 'dualGreet -> "$greeting"');

  return DualTargetReport(addResult, scaledPoint, greeting);
}
