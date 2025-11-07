// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../code_generator.dart';

import '../strings.dart' as strings;
import 'binding_string.dart';
import 'utils.dart';
import 'writer.dart';

/// A simple Typealias, Expands to -
///
/// ```dart
/// typedef $name = $type;
/// );
/// ```
class Typealias extends BindingType {
  final Type type;
  String? _ffiDartAliasName;
  String? _dartAliasName;

  /// Creates a Typealias.
  ///
  /// If [genFfiDartType] is true, a binding is generated for the Ffi Dart type
  /// in addition to the C type. See [Type.getInteropDartType].
  factory Typealias({
    String? usr,
    String? originalName,
    String? dartDoc,
    required String name,
    required Type type,
    bool genFfiDartType = false,
    bool isInternal = false,
  }) {
    final funcType = _getFunctionTypeFromPointer(type);
    if (funcType != null) {
      type = PointerType(NativeFunc(Typealias._(
        name: '${name}Function',
        type: funcType,
        genFfiDartType: genFfiDartType,
        isInternal: isInternal,
      )));
    }

    return Typealias._(
      usr: usr,
      originalName: originalName,
      dartDoc: dartDoc,
      name: name,
      type: type,
      genFfiDartType: genFfiDartType,
      isInternal: isInternal,
    );
  }

  Typealias._({
    super.usr,
    super.originalName,
    super.dartDoc,
    required String name,
    required this.type,
    bool genFfiDartType = false,
    super.isInternal,
  })  : _ffiDartAliasName = genFfiDartType ? 'Dart$name' : null,
        _dartAliasName =
            (!genFfiDartType && type is! Typealias) ? 'Dart$name' : null,
        super(
          name: genFfiDartType ? 'Native$name' : name,
        );

  @override
  String get wasmType { 
    return type.wasmType;
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
    type.addDependencies(dependencies);
  }

  static FunctionType? _getFunctionTypeFromPointer(Type type) {
    if (type is! PointerType) return null;
    final pointee = type.child;
    if (pointee is! NativeFunc) return null;
    return pointee.type;
  }

  @override
  BindingString toBindingString(Writer w, {bool writeModuleBinding = false}) {
    if (_ffiDartAliasName != null) {
      _ffiDartAliasName = w.topLevelUniqueNamer.makeUnique(_ffiDartAliasName!);
    }
    if (_dartAliasName != null) {
      _dartAliasName = w.topLevelUniqueNamer.makeUnique(_dartAliasName!);
    }

    final sb = StringBuffer();
    if (dartDoc != null) {
      sb.write(makeDartDoc(dartDoc!));
    }
    sb.write('typedef $name = ${type.getInteropDartType(w)};\n');
    if (_ffiDartAliasName != null) {
      sb.write('typedef $_ffiDartAliasName = ${type.getInteropDartType(w)};\n');
    }
    if (_dartAliasName != null) {
      sb.write('typedef $_dartAliasName = ${type.getDartType(w)};\n');
    }
    return BindingString(
        type: BindingStringType.typeDef, string: sb.toString());
  }

  @override
  Type get typealiasType => type.typealiasType;

  @override
  bool get isIncompleteCompound => type.isIncompleteCompound;

  @override
  String getInteropDartType(Writer w) => name;

  @override
  String getNativeType({String varName = ''}) =>
      type.getNativeType(varName: varName);

  @override
  String getWasmInteropType(Writer w) => type.getWasmInteropType(w);

  @override
  String getDartType(Writer w) {
    if (_dartAliasName != null) {
      return _dartAliasName!;
    } else {
      return type.getDartType(w);
    }
  }

  @override
  String cacheKey() => type.cacheKey();

  // Used to compare whether two Typealias are same symbols and ensure that they
  // are unique when adding to a [Set].
  @override
  bool operator ==(Object other) {
    if (other is! Typealias) return false;
    if (identical(this, other)) return true;
    return other.usr == usr;
  }

  // [usr] is unique for specific symbols.
  @override
  int get hashCode => usr.hashCode;

  @override
  String get llvmType => typealiasType.llvmType;

  @override
  int get sizeInBytes => typealiasType.sizeInBytes;
}
