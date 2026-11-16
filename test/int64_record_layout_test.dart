import 'dart:io';

import 'package:ffigen_js/src/jsgen/code_generator.dart';
import 'package:ffigen_js/src/jsgen/config_provider/config.dart';
import 'package:ffigen_js/src/jsgen/config_provider/config_types.dart';
import 'package:ffigen_js/src/jsgen/header_parser.dart';
import 'package:test/test.dart';

void main() {
  test('explicitly included pointer dependencies retain their layout', () {
    final library = parse(Config(
      output: Uri.file('${Directory.systemTemp.path}/unused-int64-record.dart'),
      entryPoints: [File('test/fixtures/int64_record.h').absolute.uri],
      compilerOpts: ['-x', 'c', '-std=c11', '-ffreestanding'],
      functionDecl: DeclarationFilters.includeAll,
      structDecl: DeclarationFilters.includeAll,
      structDependencies: CompoundDependencies.opaque,
    ));
    final record = library.bindings.whereType<Compound>().single;
    expect(record.sizeInBytes, 16);
    expect(record.nativeAlignment, 8);
    expect(record.members.map((field) => field.originalName),
        ['frameId', 'value']);
    expect(record.members.map((field) => field.offsetInBytes), [0, 8]);
    expect(record.members.last.type.typealiasType.sizeInBytes, 8);
  });

  test('excluded pointer dependencies remain opaque', () {
    final library = parse(Config(
      output:
          Uri.file('${Directory.systemTemp.path}/unused-opaque-record.dart'),
      entryPoints: [File('test/fixtures/int64_record.h').absolute.uri],
      compilerOpts: ['-x', 'c', '-std=c11', '-ffreestanding'],
      functionDecl: DeclarationFilters.includeAll,
      structDecl: YamlDeclarationFilters(excludeAllByDefault: true),
      structDependencies: CompoundDependencies.opaque,
    ));
    final record = library.bindings.whereType<Compound>().single;
    expect(record.isOpaque, isTrue);
    expect(record.members, isEmpty);
  });
}
