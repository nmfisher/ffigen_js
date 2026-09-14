import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final builder = CBuilder.library(
      name: 'ffigen_js_example',
      assetName: 'ffigen_js_example.dart',
      sources: ['native/src/example.cpp'],
      includes: ['native/include'],
      language: Language.cpp,
      std: 'c++17',
      cppLinkStdLib: 'c++',
    );
    await builder.run(input: input, output: output);
  });
}
