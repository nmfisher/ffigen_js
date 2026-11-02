import 'dart:io';

import 'package:ffigen_js/src/jsgen/code_generator.dart';
import 'package:ffigen_js/src/jsgen/config_provider/config.dart';
import 'package:ffigen_js/src/jsgen/header_parser.dart';
import 'package:test/test.dart';

void main() {
  late Map<String, Compound> compounds;
  setUpAll(() {
    final library = parse(Config(
      output: Uri.file('${Directory.systemTemp.path}/unused-layout.dart'),
      entryPoints: [File('example/native/include/abi_layout.h').absolute.uri],
      compilerOpts: ['-x', 'c', '-std=c11', '-ffreestanding'],
      functionDecl: DeclarationFilters.includeAll,
    ));
    compounds = {
      for (final b in library.bindings.whereType<Compound>()) b.originalName: b,
    };
  });

  void layout(String name, int size, int alignment, Map<String, int> offsets) {
    final record = compounds[name]!;
    expect(record.sizeInBytes, size, reason: 'sizeof($name)');
    expect(record.nativeAlignment, alignment, reason: 'alignof($name)');
    for (final member in record.members) {
      if (offsets.containsKey(member.originalName)) {
        expect(member.offsetInBytes, offsets[member.originalName],
            reason: '$name.${member.originalName}');
      }
    }
    for (final field in offsets.keys) {
      expect(record.members.any((m) => m.originalName == field), isTrue);
    }
  }

  test('uses target padding for fields and record allocation', () {
    layout('Padded', 20, 4, {'enabled': 0, 'values': 4, 'tail': 16});
    layout('Nested', 28, 4, {'tag': 0, 'entry': 4, 'end': 24});
    layout('OverAligned', 16, 16, {'tail': 0});
  });

  test('preserves packed offsets and nested tail padding', () {
    layout('Packed', 35, 1,
        {'tag': 0, 'amount': 1, 'count': 5, 'entry': 7, 'samples': 27});
  });

  test('union members overlap and allocation includes alignment padding', () {
    layout('Choice', 24, 8, {'byte': 0, 'number': 0, 'record': 0});
  });

  test('finds anonymous records through promoted field offsets', () {
    layout('Anonymous', 16, 4, {'tag': 0, '': 4, 'tail': 12});
    final nestedUnion = compounds['Anonymous']!.members[1].type as Compound;
    expect(nestedUnion.members.map((m) => m.offsetInBytes), everyElement(0));
  });

  test('array sizes use padded record stride and every dimension', () {
    layout('Arrays', 72, 4, {'tag': 0, 'entries': 4, 'matrix': 44, 'tail': 68});
    final fields = compounds['Arrays']!.members;
    expect(fields[1].type.sizeInBytes, 40);
    expect(fields[2].type.sizeInBytes, 24);
  });

  test('unsupported bitfields remain opaque', () {
    expect(compounds['Bitfield']!.isOpaque, isTrue);
    expect(compounds['Bitfield']!.isIncomplete, isTrue);
  });
}
