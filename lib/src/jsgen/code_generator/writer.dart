// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../code_generator.dart';
import '../strings.dart' as strings;
import 'utils.dart';

final _logger = Logger('jsgen.code_generator.writer');

/// To store generated String bindings.
class Writer {
  final String? header;

  final List<Binding> bindings;
  final List<Binding> typeBindings;

  late String _className;
  String get className => _className;

  final String? classDocComment;

  final List<String> nativeEntryPoints;

  /// Tracks where enumType.getInteropDartType is called. Reset everytime [generate] is
  /// called.
  bool usedEnumCType = false;

  String? _pkgWebLibraryPrefix;
  String get pkgWebLibraryPrefix {
    if (_pkgWebLibraryPrefix != null) {
      return _pkgWebLibraryPrefix!;
    }

    final import = _usedImports.firstWhere(
      (element) => element.name == pkgWebImport.name,
      orElse: () => pkgWebImport,
    );
    _usedImports.add(import);
    return _pkgWebLibraryPrefix = import.prefix;
  }

  String? _jsInteropLibraryPrefix;
  String get jsInteropLibraryPrefix {
    if (_jsInteropLibraryPrefix != null) {
      return _jsInteropLibraryPrefix!;
    }

    final import = _usedImports.firstWhere(
      (element) => element.name == jsInteropImport.name,
      orElse: () => jsInteropImport,
    );
    _usedImports.add(import);
    return _jsInteropLibraryPrefix = import.prefix;
  }

  late String selfImportPrefix = () {
    final import = _usedImports.firstWhere(
      (element) => element.name == self.name,
      orElse: () => self,
    );
    _usedImports.add(import);
    return import.prefix;
  }();

  final Set<LibraryImport> _usedImports = {};

  /// Initial namers set after running constructor. Namers are reset to this
  /// initial state everytime [generate] is called.
  late UniqueNamer _initialTopLevelUniqueNamer, _initialWrapperLevelUniqueNamer;

  /// Used by [Binding]s for generating required code.
  late UniqueNamer _topLevelUniqueNamer;
  UniqueNamer get topLevelUniqueNamer => _topLevelUniqueNamer;
  late UniqueNamer _wrapperLevelUniqueNamer;
  UniqueNamer get wrapperLevelUniqueNamer => _wrapperLevelUniqueNamer;

  /// Set true after calling [generate]. Indicates if
  /// [generateSymbolOutputYamlMap] can be called.
  bool get canGenerateSymbolOutput => _canGenerateSymbolOutput;
  bool _canGenerateSymbolOutput = false;

  final bool silenceEnumWarning;

  Writer({
    required this.bindings,
    required this.typeBindings,
    required String className,
    List<LibraryImport>? additionalImports,
    this.classDocComment,
    this.header,
    required this.silenceEnumWarning,
    required this.nativeEntryPoints,
  }) {
    final globalLevelNameSet = bindings.map((e) => e.name).toSet();
    final wrapperLevelNameSet = bindings.map((e) => e.name).toSet();
    final allNameSet = <String>{}
      ..addAll(globalLevelNameSet)
      ..addAll(wrapperLevelNameSet);

    _initialTopLevelUniqueNamer = UniqueNamer(globalLevelNameSet);
    _initialWrapperLevelUniqueNamer = UniqueNamer(wrapperLevelNameSet);
    final allLevelsUniqueNamer = UniqueNamer(allNameSet);

    /// Wrapper class name must be unique among all names.
    _className = _resolveNameConflict(
      name: className,
      makeUnique: allLevelsUniqueNamer,
      markUsed: [_initialWrapperLevelUniqueNamer, _initialTopLevelUniqueNamer],
    );

    /// Library imports prefix should be unique unique among all names.
    if (additionalImports != null) {
      for (final lib in additionalImports) {
        lib.prefix = _resolveNameConflict(
          name: lib.prefix,
          makeUnique: allLevelsUniqueNamer,
          markUsed: [
            _initialWrapperLevelUniqueNamer,
            _initialTopLevelUniqueNamer,
          ],
        );
      }
    }
    _resetUniqueNamersNamers();
  }

  /// Resolved name conflict using [makeUnique] and marks the result as used in
  /// all [markUsed].
  String _resolveNameConflict({
    required String name,
    required UniqueNamer makeUnique,
    List<UniqueNamer> markUsed = const [],
  }) {
    final s = makeUnique.makeUnique(name);
    for (final un in markUsed) {
      un.markUsed(s);
    }
    return s;
  }

  final _arrays = <ConstantArray>{};
  void markArray(ConstantArray arr) {
    _arrays.add(arr);
  }

  final _nativeFunctions = <FunctionType>{};
  void markNativeFunction(FunctionType func) {
    _nativeFunctions.add(func);
  }

  /// Resets the namers to initial state. Namers are reset before generating.
  void _resetUniqueNamersNamers() {
    _topLevelUniqueNamer = _initialTopLevelUniqueNamer.clone();
    _wrapperLevelUniqueNamer = _initialWrapperLevelUniqueNamer.clone();
  }

  void markImportUsed(LibraryImport import) {
    _usedImports.add(import);
  }

  /// Writes all bindings to a String.
  String generate() {
    final s = StringBuffer();

    // We write the source first to determine which imports are actually
    // referenced. Headers and [s] are then combined into the final result.
    final result = StringBuffer();

    // Reset unique namers to initial state.
    _resetUniqueNamersNamers();

    // Reset [usedEnumCType].
    usedEnumCType = false;

    // Write file header (if any).
    if (header != null) {
      result.writeln(header);
    }

    // Write auto generated declaration.
    result.write(
      makeDoc(
        'AUTO GENERATED FILE, DO NOT EDIT.\n\nGenerated by `package:jsgen`.',
      ),
    );

    // Write lint ignore if not specified by user already.
    if (!RegExp(r'ignore_for_file:\s*type\s*=\s*lint').hasMatch(header ?? '')) {
      result.write(makeDoc('ignore_for_file: type=lint'));
    }

    /// Write [bindings].
    if (bindings.isNotEmpty) {
      // Write doc comment for wrapper class.
      if (classDocComment != null) {
        s.write(makeDartDoc(classDocComment!));
      }
      // Write wrapper classs.

      s.write('''
import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:ffigen_js/ffigen_js.dart';
export 'package:ffigen_js/ffigen_js.dart';

extension type GeneratedBindings(NativeLibrary _) implements JSObject {

  static GeneratedBindings get instance => NativeLibrary.instance as GeneratedBindings;
  
  static void initBindings(String moduleName) {
    var lib = globalContext.getProperty(moduleName.toJS);
    if (lib == null) {
      throw Exception("Failed to find JS module \${moduleName}");
    }
    NativeLibrary.instance = lib as NativeLibrary;
  }

''');
      s.write('\n');
      for (final b in bindings) {
        s.write(b.toBindingString(this, writeModuleBinding: true).string);
      }
      s.write('}\n\n');
    }

    for (final b in bindings) {
      s.write(b.toBindingString(this, writeModuleBinding: false).string);
    }

    for (final b in typeBindings) {
      s.write(b.toBindingString(this, writeModuleBinding: false).string);
    }

    s.write('''extension StructAllocator on Struct {
  static T create<T>() {
    switch (T) {''');
    for (final b in typeBindings) {
      if (b is Compound) {
        s.write('''
      case ${b.name}:
        final ptr = ${b.name}.stackAlloc();
        return ptr.toDart() as T;
''');
      }
    }
    s.write('''
    }
    throw Exception("Unsupported type \$T");
  }
}''');

    var written = <String>{};
    _nativeFunctions.forEachIndexed((i, fn) {
      if (written.contains(fn.cacheKey())) {
        return;
      }
      s.write(fn.getExtensionMethod(this, i));
      written.add(fn.cacheKey());
    });

    // Write neccesary imports.
    for (final lib in _usedImports) {
      final path = lib.importPath();
      result.write("import '$path' as ${lib.prefix};\n");
    }
    result.write(s);

    // Warn about Enum usage in API surface.
    if (!silenceEnumWarning && usedEnumCType) {
      _logger.severe(
        'The integer type used for enums is '
        'implementation-defined. FFIgen tries to mimic the integer sizes '
        'chosen by the most common compilers for the various OS and '
        'architecture combinations. To prevent any crashes, remove the '
        'enums from your API surface. To rely on the (unsafe!) mimicking, '
        'you can silence this warning by adding silence-enum-warning: true '
        'to the FFIgen config.',
      );
    }

    _canGenerateSymbolOutput = true;
    return result.toString();
  }

  Map<String, dynamic> generateSymbolOutputYamlMap(String importFilePath) {
    if (!canGenerateSymbolOutput) {
      throw Exception(
        'Invalid state: generateSymbolOutputYamlMap() '
        'called before generate()',
      );
    }

    // Warn for macros.
    final hasMacroBindings = bindings.any(
      (element) => element is Constant && element.usr!.contains('@macro@'),
    );
    if (hasMacroBindings) {
      _logger.info(
        'Removing all Macros from symbol file since they cannot '
        'be cross referenced reliably.',
      );
    }

    // Remove internal bindings and macros.
    bindings.removeWhere((element) {
      return element.isInternal ||
          (element is Constant && element.usr!.contains('@macro@'));
    });

    // Sort bindings alphabetically by USR.
    bindings.sort((a, b) => a.usr!.compareTo(b.usr!));

    final usesFfiNative = true;

    return {
      strings.formatVersion: strings.symbolFileFormatVersion,
      strings.files: {
        importFilePath: {
          strings.usedConfig: {strings.ffiNative: usesFfiNative},
          strings.symbols: {
            for (final b in bindings) b.usr: {strings.name: b.name},
          },
        },
      },
    };
  }

  static String _objcImport(String entryPoint, String outDir) {
    final frameworkHeader = parseObjCFrameworkHeader(entryPoint);

    if (frameworkHeader == null) {
      // If it's not a framework header, use a relative import.
      return '#import "${p.relative(entryPoint, from: outDir)}"\n';
    }

    // If it's a framework header, use a <> style import.
    return '#import <$frameworkHeader>\n';
  }
}
