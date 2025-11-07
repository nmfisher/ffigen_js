// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../code_generator.dart';

import 'writer.dart';

/// Type class for return types, variable types, etc.
///
/// Implementers should extend either Type, or BindingType if the type is also a
/// binding, and override at least getInteropDartType and toString.
abstract class Type {
  const Type();

  String get llvmType;
  int get sizeInBytes;

  /// Get all dependencies of this type and save them in [dependencies].
  void addDependencies(Set<Binding> dependencies) {}

  /// Get base type for any type.
  ///
  /// E.g int** has base [Type] of int.
  /// double[2][3] has base [Type] of double.
  Type get baseType => this;

  /// Get base Array type.
  ///
  /// Returns itself if it's not an Array Type.
  Type get baseArrayType => this;

  /// Get base typealias type.
  ///
  /// Returns itself if it's not a Typealias.
  Type get typealiasType => this;

  /// Returns true if the type is a [Compound] and is incomplete.
  bool get isIncompleteCompound => false;

  String get wasmType => throw UnimplementedError();

  /// Returns the Dart type of the Type. This is only used for pointers.
  String getWasmInteropType(Writer w) =>
      throw UnsupportedError('No mapping for type: $this');

  /// Returns the Dart type of the Type. This is the type that is passed from
  /// Dart to the interop code.
  String getInteropDartType(Writer w) =>
      throw UnsupportedError('No mapping for type: $this');

  /// Returns the user type of the Type. This is the type that is presented to
  /// users by the ffigened API to users. For C bindings this is always the same
  /// as getInteropDartType. For ObjC bindings this refers to the wrapper object.
  String getDartType(Writer w) => getInteropDartType(w);

  /// Returns the C/ObjC type of the Type. This is the type as it appears in
  /// C/ObjC source code. It should not be used in Dart source code.
  ///
  /// This method takes a [varName] arg because some C/ObjC types embed the
  /// variable name inside the type. Eg, to pass an ObjC block as a function
  /// argument, the syntax is `int (^arg)(int)`, where arg is the [varName].
  String getNativeType({String varName = ''}) =>
      throw UnsupportedError('No native mapping for type: $this');

  /// Cache key used in various places to dedupe Types. By default this is just
  /// the hash of the Type, but in many cases this does not dedupe sufficiently.
  /// So Types that may be duplicated should override this to return a more
  /// specific key. Types that are already deduped don't need to override this.
  /// toString() is not a valid cache key as there may be name collisions.
  String cacheKey() => hashCode.toRadixString(36);
}

/// Base class for all Type bindings.
///
/// Since Dart doesn't have multiple inheritance, this type exists so that we
/// don't have to reimplement the default methods in all the classes that want
/// to extend both NoLookUpBinding and Type.
abstract class BindingType extends Binding implements Type {
  BindingType({
    String? usr,
    String? originalName,
    required super.name,
    super.dartDoc,
    super.isInternal,
  }) : super(
          usr: usr ?? name,
          originalName: originalName ?? name,
        );

  @override
  Type get baseType => this;

  @override
  Type get baseArrayType => this;

  @override
  Type get typealiasType => this;

  @override
  bool get isIncompleteCompound => false;

  @override
  String getWasmInteropType(Writer w) =>
      throw UnsupportedError('No WASM type for $this');

  @override
  String getInteropDartType(Writer w) =>
      throw UnsupportedError('No mapping for type: $this');

  @override
  String getDartType(Writer w) => getInteropDartType(w);

  @override
  String getNativeType({String varName = ''}) =>
      throw UnsupportedError('No native mapping for type: $this');

  @override
  String cacheKey() => hashCode.toRadixString(36);
}

/// Represents an unimplemented type. Used as a marker, so that declarations
/// having these can exclude them.
class UnimplementedType extends Type {
  String reason;
  UnimplementedType(this.reason);

  @override
  String toString() => '(Unimplemented: $reason)';

  @override
  String get llvmType => throw UnimplementedError(reason);

  @override
  int get sizeInBytes => throw UnimplementedError(reason);
}
