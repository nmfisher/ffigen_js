// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../code_generator.dart';
import 'utils.dart';

import 'writer.dart';

/// Represents a function type.
class FunctionType extends Type {
  final Type returnType;
  final List<Parameter> parameters;
  final List<Parameter> varArgParameters;

  /// Get all the parameters for generating the dart type. This includes both
  /// [parameters] and [varArgParameters].
  List<Parameter> get dartTypeParameters => parameters + varArgParameters;

  FunctionType({
    required this.returnType,
    required this.parameters,
    this.varArgParameters = const [],
  });

  String _getTypeImpl(
      bool writeArgumentNames, String Function(Type) typeToString,
      {String? varArgWrapper}) {
    final params = varArgWrapper != null ? parameters : dartTypeParameters;
    String? varArgPack;
    if (varArgWrapper != null && varArgParameters.isNotEmpty) {
      final varArgPackBuf = StringBuffer();
      varArgPackBuf.write('$varArgWrapper<(');
      varArgPackBuf.write(varArgParameters.map<String>((p) {
        return '${typeToString(p.type)} ${writeArgumentNames ? p.name : ""}';
      }).join(', '));
      varArgPackBuf.write(',)>');
      varArgPack = varArgPackBuf.toString();
    }

    // Write return Type.
    final sb = StringBuffer();
    sb.write(typeToString(returnType));

    // Write Function.
    sb.write(' Function(');
    sb.write([
      ...params.map<String>((p) {
        return '${typeToString(p.type)} ${writeArgumentNames ? p.name : ""}';
      }),
      if (varArgPack != null) varArgPack,
    ].join(', '));
    sb.write(')');

    return sb.toString();
  }

  @override
  String getInteropDartType(Writer w, {bool writeArgumentNames = true}) =>
      _getTypeImpl(writeArgumentNames, (Type t) => t.getInteropDartType(w),
          varArgWrapper: 'VarArgs');

  @override
  String getDartType(Writer w, {bool writeArgumentNames = true}) =>
      _getTypeImpl(writeArgumentNames, (Type t) => t.getDartType(w));

  @override
  String getNativeType({String varName = ''}) {
    final arg = dartTypeParameters.map<String>((p) => p.type.getNativeType());
    return '${returnType.getNativeType()} (*$varName)(${arg.join(', ')})';
  }

  String get wasmSignature {
    var signature = '${returnType.wasmType}';

    for (final param in parameters) {
      signature += param.type.wasmType;
    }
    return signature;
  }

  static final _written = <String>{};

  String getExtensionMethod(Writer w, int index) {
    final s = StringBuffer();
    final originalType = getDartType(w);
    final genericPointer = parameters.length == 1 &&
        parameters.single.type.typealiasType is PointerType;
    final targetType = genericPointer
        ? '${returnType.getDartType(w)} Function(Pointer<T>)'
        : originalType;
    if (_written.contains(targetType)) {
      return "";
    }
    _written.add(targetType);

    final argumentDeclarations = <String>[];
    final arguments = <String>[];
    for (var i = 0; i < parameters.length; i++) {
      final type = parameters[i].type;
      final name = 'arg$i';
      if (type.typealiasType is PointerType) {
        argumentDeclarations.add('int $name');
        arguments.add(genericPointer
            ? 'Pointer<T>($name)'
            : '${type.getDartType(w)}($name)');
      } else {
        argumentDeclarations.add('${type.getInteropDartType(w)} $name');
        arguments.add(type.llvmType == 'i64' ? '$name.toDart' : name);
      }
    }
    final invocation = 'this(${arguments.join(',')})';
    final String body;
    if (returnType.getDartType(w) == 'void') {
      body = '$invocation;';
    } else if (returnType.typealiasType is PointerType) {
      body = 'return $invocation.addr;';
    } else if (returnType.llvmType == 'i64') {
      body = 'return $invocation.toJSBigInt;';
    } else {
      body = 'return $invocation;';
    }

    s.write(
        '''extension NativeFunctionPointer$index<T extends NativeType> on $targetType {

    Pointer<NativeFunction<$originalType>> addFunction() {
      final callback = (${argumentDeclarations.join(',')}) { $body };
      return NativeLibrary.instance.addFunction<$originalType>(callback.toJS, '${wasmSignature}').cast();
  }
    }
  
    ''');
    return s.toString();
  }

  @override
  String cacheKey() {
    final ck = _getTypeImpl(false, (Type t) => t.cacheKey());
    return ck;
  }

  @override
  int get hashCode => cacheKey().hashCode;

  @override
  void addDependencies(Set<Binding> dependencies) {
    returnType.addDependencies(dependencies);
    for (final p in parameters) {
      p.type.addDependencies(dependencies);
    }
  }

  void addParameterNames(List<String> names) {
    if (names.length != parameters.length) {
      return;
    }
    final paramNamer = UniqueNamer({});
    for (var i = 0; i < parameters.length; i++) {
      final finalName = paramNamer.makeUnique(names[i]);
      parameters[i] = Parameter(
        type: parameters[i].type,
        originalName: names[i],
        name: finalName,
      );
    }
  }

  @override
  String get llvmType => throw UnimplementedError();

  @override
  int get sizeInBytes => throw UnimplementedError();
}

/// Represents a NativeFunction<Function>.
class NativeFunc extends Type {
  // Either a FunctionType or a Typealias of a FunctionType.
  final Type _type;

  NativeFunc(this._type) : assert(_type is FunctionType || _type is Typealias);

  FunctionType get type {
    if (_type is Typealias) {
      return _type.typealiasType as FunctionType;
    }
    return _type as FunctionType;
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    _type.addDependencies(dependencies);
  }

  @override
  String getInteropDartType(Writer w, {bool writeArgumentNames = true}) {
    final funcType = _type is FunctionType
        ? _type.getInteropDartType(w, writeArgumentNames: writeArgumentNames)
        : _type.getInteropDartType(w);
    return 'NativeFunction<$funcType>';
  }

  @override
  String getNativeType({String varName = ''}) =>
      _type.getNativeType(varName: varName);

  @override
  String toString() => 'NativeFunction<${_type.toString()}>';

  @override
  String cacheKey() => 'NatFn(${_type.cacheKey()})';

  @override
  String get llvmType => throw Exception();

  @override
  String getWasmInteropType(Writer w) => getInteropDartType(w);

  @override
  int get sizeInBytes => throw UnimplementedError();
}
