import 'lib/consumer.dart';

void main() {
  final report = runDualTargetChecks();
  print(
      'DUAL TARGET SMOKE OK (web): add=${report.addResult} '
      'point=${report.scaledPoint} greet="${report.greeting}"');
}
