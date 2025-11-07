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
    var ft = this is Typealias
        ? typealiasType as FunctionType
        : this as FunctionType;
    var signature = '${ft.returnType.wasmType}';
    
    for (final param in ft.parameters) {
      signature += param.type.wasmType;
    }
    return signature;
  }

  static final _written = <String>{};
  
  String getExtensionMethod(Writer w, int index) {
    final s = StringBuffer();
    final originalType = getDartType(w); //getInteropDartType(w);
    final targetType = originalType.replaceAll(RegExp(r"Function\(Pointer<.*"), "Function(Pointer<T>)");
    if(_written.contains(targetType)) {
      return "";
    }
    _written.add(targetType);
    
    s.write('''extension NativeFunctionPointer$index<T extends NativeType> on $targetType { 

    Pointer<NativeFunction<$originalType>> addFunction() {
      return Pointer<NativeFunction<$originalType>>(NativeLibrary.instance.addFunction<$originalType>(this.toJS, '${wasmSignature}')).cast();
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
