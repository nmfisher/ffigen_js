// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../code_generator.dart';

import 'writer.dart';

/// Represents a pointer.
class PointerType extends Type {
  final Type child;

  @override
  final int sizeInBytes = 4;

  @override
  final String llvmType = '*';

  final String wasmType = 'p';

  PointerType._(this.child);

  factory PointerType(Type child) {
    return PointerType._(child);
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    child.addDependencies(dependencies);
  }

  @override
  Type get baseType => child.baseType;

  @override
  String getInteropDartType(Writer w) {
    if (child is PointerType || child is Struct) {
      return 'Pointer<${child.getDartType(w).replaceAll("Pointer<", "PointerClass<")}>';
    }
    return 'Pointer<${child.getWasmInteropType(w).replaceAll("Pointer<", "PointerClass<")}>';
  }

  @override
  String getDartType(Writer w) {
    if (child == NativeType(SupportedNativeType.char)) {
      return 'Pointer<Char>';
    } else if (child is PointerType || child is Struct) {
      return 'Pointer<${child.getDartType(w).replaceAll("Pointer<", "PointerClass<")}>';
    } else {
      return 'Pointer<${child.getWasmInteropType(w)}>';
    }
  }

  @override
  String getWasmInteropType(Writer w) => getInteropDartType(w);

  @override
  String getNativeType({String varName = ''}) =>
      '${child.getNativeType()}* $varName';

  @override
  String toString() => '$child*';

  @override
  String cacheKey() => '${child.cacheKey()}*';
}

/// Represents a constant array, which has a fixed size.
class ConstantArray extends PointerType {
  final int length;
  final bool useArrayType;

  ConstantArray(this.length, Type child, {required this.useArrayType})
      : super._(child);

  @override
  Type get baseArrayType => child.baseArrayType;

  @override
  bool get isIncompleteCompound => baseArrayType.isIncompleteCompound;

  @override
  String getInteropDartType(Writer w) {
    w.markArray(this);
    return super.getInteropDartType(w);
  }

  @override
  String getNativeType({String varName = ''}) =>
      '${child.getNativeType()} $varName[$length]';

  @override
  String toString() => '$child[$length]';

  @override
  String cacheKey() => '${child.cacheKey()}[$length]';

  @override
  String getDartType(Writer w) {
    return 'Array<${child.getWasmInteropType(w)}>';
  }

  @override
  int get sizeInBytes => length * baseArrayType.sizeInBytes;
}

/// Represents an incomplete array, which has an unknown size.
class IncompleteArray extends PointerType {
  IncompleteArray(super.child) : super._();

  @override
  Type get baseArrayType => child.baseArrayType;

  @override
  String getNativeType({String varName = ''}) =>
      '${child.getNativeType()} $varName[]';

  @override
  String toString() => '$child[]';

  @override
  String cacheKey() => '${child.cacheKey()}[]';
}
