// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'type.dart';
import 'writer.dart';

/// A library import which will be written as an import in the generated file.
class LibraryImport {
  final String name;
  final String _importPath;

  String prefix;

  LibraryImport(this.name, this._importPath)
      : 
        prefix = name;

  @override
  bool operator ==(Object other) {
    return other is LibraryImport && name == other.name;
  }

  @override
  int get hashCode => name.hashCode;

  // The import path, which may be different if this library is being imported
  // into package:objective_c's generated code.
  String importPath() {
    return _importPath;
  }
}

/// An imported type which will be used in the generated code.
class ImportedType extends Type {
  final LibraryImport libraryImport;
  final String cType;
  final String dartType;
  final String nativeType;
  final String? defaultValue;

  ImportedType(this.libraryImport, this.cType, this.dartType, this.nativeType,
      [this.defaultValue]);

  @override
  String getInteropDartType(Writer w) {
    w.markImportUsed(libraryImport);
    return '${libraryImport.prefix}.$cType';
  }

  @override
  String getNativeType({String varName = ''}) => '$nativeType $varName';

  @override
  String toString() => '${libraryImport.name}.$cType';


  @override
  String get llvmType => throw UnimplementedError();

  @override
  int get sizeInBytes => throw UnimplementedError();
}

/// An unchecked type similar to [ImportedType] which exists in the generated
/// binding itself.
class SelfImportedType extends Type {
  final String interopDartType;
  final String dartType;
  final String llvmType;
  final int sizeInBytes;

  SelfImportedType(this.interopDartType, this.dartType, this.llvmType, this.sizeInBytes);

  @override
  String getInteropDartType(Writer w) => interopDartType;

  @override
  String toString() => interopDartType;

}

final pkgWebImport = LibraryImport('pkg_web', 'package:web/web.dart');
final jsInteropImport = LibraryImport('js_interop', 'dart:js_interop');
final jsInteropUnsafeImport = LibraryImport('js_interop', 'dart:js_interop');

final self = LibraryImport('self', '');

final voidType = ImportedType(jsInteropUnsafeImport, 'Void', 'void', 'void');


