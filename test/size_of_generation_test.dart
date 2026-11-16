import 'dart:io';

import 'package:ffigen_js/src/jsgen/code_generator.dart';
import 'package:ffigen_js/src/jsgen/config_provider/config.dart';
import 'package:ffigen_js/src/jsgen/header_parser.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('ffigen-js-sizeof-');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> compileAndRun(String header, String checks,
      {bool recordsOnly = false}) async {
    final fixture = File('${directory.path}/layout.h')
      ..writeAsStringSync(header);
    final parsed = parse(Config(
      output: Uri.file('${directory.path}/bindings.dart'),
      entryPoints: [fixture.uri],
      compilerOpts: ['-x', 'c', '-std=c11', '-ffreestanding'],
      functionDecl: DeclarationFilters.includeAll,
      structDecl: DeclarationFilters.includeAll,
      unionDecl: DeclarationFilters.includeAll,
      typedefs: DeclarationFilters.includeAll,
    ));
    // The parser discovers records through signatures. Exercise generation of
    // a library containing only those type bindings as well.
    final library = recordsOnly
        ? Library(
            name: 'SizeOfBindings',
            bindings: parsed.bindings.where((b) => b is! Func).toList(),
          )
        : parsed;
    library.generateFile(File('${directory.path}/bindings.dart'));
    final main = File('${directory.path}/main.dart')..writeAsStringSync('''
import 'bindings.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
int genericSize<T extends NativeType>() => sizeOf<T>();
void check(bool condition) {
  if (!condition) throw StateError('Unexpected ABI size');
}
void main() {
  $checks
}
''');
    final output = '${directory.path}/main.js';
    final compilation = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'js',
      '--packages=${Directory.current.path}/.dart_tool/package_config.json',
      main.path,
      '-o',
      output,
    ]);
    expect(compilation.exitCode, 0,
        reason: '${compilation.stdout}\n${compilation.stderr}');
    final execution = await Process.run('node', [output]);
    expect(execution.exitCode, 0,
        reason: '${execution.stdout}\n${execution.stderr}');
  }

  test('record-only libraries expose sizes without module initialization',
      () async {
    await compileAndRun('''
typedef struct Padded { char tag; int value; char tail; } Padded;
typedef struct __attribute__((packed)) Packed { char tag; int value; } Packed;
typedef union Choice { char tag; double value; } Choice;
typedef Padded Alias;
typedef struct Opaque Opaque;
typedef struct _ffigenJs { int value; } _ffigenJs;
void use(Padded*, Packed*, Choice*, Alias*, Opaque*, _ffigenJs*);
''', '''
check(sizeOf<Padded>() == 12);
check(sizeOf<Packed>() == 5);
check(genericSize<Choice>() == 8);
check(genericSize<Alias>() == 12);
check(sizeOf<Char>() == 1 && sizeOf<Bool>() == 1);
check(sizeOf<Int32>() == 4 && sizeOf<Float64>() == 8);
var unsupported = false;
try { sizeOf<Opaque>(); } on UnsupportedError { unsupported = true; }
check(unsupported);
''', recordsOnly: true);
  });

  test('a conflicting C function retains a callable renamed binding', () async {
    await compileAndRun('int sizeOf(void);', '''
check(sizeOf<Int32>() == 4);
final module = JSObject();
module.setProperty('_sizeOf'.toJS, (() => 37).toJS);
NativeLibrary.instance = module as NativeLibrary;
check(sizeOf1() == 37);
''');
  });

  test('a conflicting C record is renamed before generating its size lookup',
      () async {
    await compileAndRun('''
typedef struct sizeOf { int value; } sizeOf;
void use(sizeOf*);
''', '''
check(genericSize<sizeOf1>() == 4);
''');
  });
}
