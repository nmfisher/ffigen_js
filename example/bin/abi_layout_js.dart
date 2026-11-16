import 'package:ffigen_js_example/abi_layout_checks.dart';
import 'package:ffigen_js_example/generated_bindings_js.g.dart';

void main() {
  runSizeOfChecks();
  GeneratedBindings.initBindings('module');
  runAbiLayoutChecks();
}
