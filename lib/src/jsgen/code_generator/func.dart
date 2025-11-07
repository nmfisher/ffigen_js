// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';

import '../code_generator.dart';

import 'binding_string.dart';
import 'utils.dart';
import 'writer.dart';

/// A binding for C function.
///
/// For example, take the following C function.
///
/// ```c
/// int sum(int a, int b);
/// ```
///
/// The generated Dart code for this function is as
/// follows.
///
/// ```dart
/// extension type NativeLibrary(JSObject _) implements JSObject {
///  external int _sum(int a, int b);
/// }
/// late NativeLibrary _lib;
/// int sum(int a, int b) {
///   return _lib._sum(a, b);
/// }
///
/// ```
class Func extends Binding {
  final FunctionType functionType;
  final bool exposeFunctionTypedefs;

  /// Contains typealias for function type if [exposeFunctionTypedefs] is true.
  Typealias? _exposedFunctionTypealias;

  /// [originalName] is looked up in dynamic library, if not
  /// provided, takes the value of [name].
  Func(
      {required String name,
      super.dartDoc,
      required Type returnType,
      List<Parameter>? parameters,
      List<Parameter>? varArgParameters,
      this.exposeFunctionTypedefs = false,
      super.isInternal,
      required super.usr,
      required super.originalName})
      : functionType = FunctionType(
          returnType: returnType,
          parameters: parameters ?? const [],
          varArgParameters: varArgParameters ?? const [],
        ),
        super(
          name: name,
        ) {
    for (var i = 0; i < functionType.parameters.length; i++) {
      if (functionType.parameters[i].name.trim() == '') {
        functionType.parameters[i].name = 'arg$i';
      }
    }

    // Get function name with first letter in upper case.
    final upperCaseName = name[0].toUpperCase() + name.substring(1);
    if (exposeFunctionTypedefs) {
      _exposedFunctionTypealias = Typealias(
        name: upperCaseName,
        type: functionType,
        genFfiDartType: true,
        isInternal: true,
      );
    }
  }

  @override
  BindingString toBindingString(Writer w, {bool writeModuleBinding = false}) {
    final s = StringBuffer();

    if (dartDoc != null) {
      s.write(makeDartDoc(dartDoc!));
    }
    // Resolve name conflicts in function parameter names.
    final paramNamer = UniqueNamer({});
    for (final p in functionType.dartTypeParameters) {
      p.name = paramNamer.makeUnique(p.name);
    }

    //
    // we will generate two methods for each native function definition:
    // 1) an internal interop method that accepts/returns interop argument types
    // 2) a user-facing method that accepts/returns only Dart types, converting
    //    to interop types as needed and forwarding to (1)
    // The methods share the same name, but the interop method is prefixed with
    // an underscore.
    //
    // For arguments and return values that are primitive numeric types
    // (int/float/double), there is no difference between the interop and the
    // user-facing method. The signature will be exactly the same (except the
    // interop method will be marked as [external])
    //
    // If the interop method returns a struct by value:
    // - the first argument to the interop method will be a pointer to
    //   the struct
    // - the user-facing method will stack-allocate sufficient memory to
    //   represent the struct, and pass the pointer to the interop method
    // - after the interop method has returned, the user-facing method will
    //   instantiate the generated Dart class that corresponds to the struct,
    //   using getValue() to retrieve the correct vales.
    //
    // If the interop method takes a struct by value as an argument:
    // - the user-facing method will take, as an argument, the generated Dart
    //   class corresponding to the struct
    // - internally, the user-facing method will stack-allocate sufficient
    //   memory to represent the struct and call setValue to set its member
    //   values
    //
    // If the interop method takes a function pointer as an argument:
    // - the user-facing method will take, as an argument, a Dart
    //   function with the matching signature
    // - internally, the user-facing method will call addFunction to convert the
    //   Dart function to the correct interop type
    // - a Finalizer will be used to call removeFunction when the Dart Function
    //   is garbage-collected. (?)
    //
    final interopFunctionName = '_$name';
    final userFunctionName = name;

    var userReturnType = functionType.returnType.getDartType(w);
    var interopReturnType = functionType.returnType.getInteropDartType(w);

    final interopArguments = <Parameter>[];
    final userArguments = <Parameter>[];
    final interopArgumentConstructors = <String>[];
    final interopReturnTypeConstructors = <String>[];

    // iterate over the arguments for the native function
    for (final param in functionType.parameters) {
      final paramType = param.type;

      // if the argument is a struct:
      // 1) inside the user-facing function, stack-allocate memory for the
      //    struct
      // 2) populate the memory with the values from the Dart class
      // 3) adjust the interop argument to accept a pointer

      if (paramType is Struct) {
        interopArgumentConstructors
            .add('final ${param.name}Ptr = ${param.name}.address;');
        interopArguments.add(
            Parameter(name: '${param.name}Ptr', type: PointerType(paramType)));
        userArguments.add(
            Parameter(type: Struct(name: paramType.name), name: param.name));
      } else if (paramType is PointerType) {
        final child = paramType.child;

        // if the argument is a function pointer, the user-facing method takes
        // the same Pointer type as an argument
        // this means we need to give the user some way of converting Dart functions
        // to Pointer types.
        // we do this with an extension method, e.g.
        // ```
        // final callback = (int val) {
        //   ...
        // }
        // final fnPtr = callback.addFunction()
        // native_method_with_fn_ptr(fnPtr);
        // fnPtr.dispose()
        // ```
        if (child is NativeFunc) {
          w.markNativeFunction(child.type);
        }

        if (child is Struct) {
          interopArguments.add(Parameter(
              name: param.name,
              originalName: param.originalName,
              type: PointerType(child)));
        } else {
          interopArguments.add(param);
        }

        userArguments.add(param);
      } else {
        interopArguments.add(param);
        userArguments.add(param);
      }
    }

    // if the function returns a struct by value:
    // 1) inside the user-facing function, stack-allocate memory for the struct
    // 2) adjust the parameters for the interop function to accept a pointer to
    //    this struct as the first parameter
    // 3) adjust the return type for the interop function to return void
    if (functionType.returnType is Struct) {
      final originalReturnType = functionType.returnType;

      interopReturnType =
          NativeType(SupportedNativeType.voidType).getDartType(w);
      userReturnType = originalReturnType.getInteropDartType(w);
      final structType = functionType.returnType as Struct;
      final structName = structType.name;

      final outParam = Parameter(
          name: '${structName}_out', type: PointerType(originalReturnType));
      interopArgumentConstructors
          .add('final ${outParam.name} = ${structType.name}.stackAlloc();');

      interopArguments.insert(0, outParam);

      interopReturnTypeConstructors.add('return ${outParam.name}.toDart();');
      // if the return type is a PointerPointer, we need to wrap inside a Pointer
    } else if (functionType.returnType is PointerType ||
        functionType.returnType.typealiasType is PointerType) {
      var ptrType = functionType.returnType.typealiasType is PointerType
          ? functionType.returnType.typealiasType as PointerType
          : functionType.returnType as PointerType;
      var wrappedType = ptrType.baseType;

      if (wrappedType is! NativeType &&
          wrappedType is! Struct &&
          wrappedType is! Typealias &&
          wrappedType is! NativeFunc) {
        throw UnimplementedError(wrappedType.runtimeType.toString());
      }

      if (functionType.returnType is Typealias) {
        userReturnType = functionType.returnType.getDartType(w);
      } else {
        userReturnType = ptrType.getDartType(w);
      }

      interopReturnTypeConstructors
          .add('return ${functionType.returnType.getDartType(w)}(result);');
    } else if (functionType.returnType is EnumClass &&
        !(functionType.returnType as EnumClass).generateAsInt) {
      interopReturnTypeConstructors.add(
          'return ${functionType.returnType.getDartType(w)}.fromValue(result);');
    } else if (functionType.returnType is NativeType &&
        functionType.returnType.llvmType == 'i64') {
      if (functionType.returnType.getNativeType() == "uint64_t") {
        interopReturnTypeConstructors
            .add('return bigIntasUintN(64,result).toDart;');
      } else {
        interopReturnTypeConstructors.add('return result.toDart;');
      }
    } else if (functionType.returnType is NativeType &&
        functionType.returnType.getDartType(w) == 'bool') {
      interopReturnType = 'int';
      interopReturnTypeConstructors.add('return result == 1;');
    } else {
      interopReturnTypeConstructors.add('return result;');
    }

    final userArgsString = userArguments
        .map((p) => '${p.type.getDartType(w)} ${p.name},\n')
        .join('');
    final interopArgsString = interopArguments
        .map((p) => '${p.type.getInteropDartType(w)} ${p.name},\n')
        .join('');
    final invokeInteropArgsString = interopArguments.map((p) {
      if (p.type.baseType is NativeFunc) {
        return '${p.name}.cast()';
      }

      if (p.type is PointerType) {
        if ((p.type.baseType is Struct)) {
          return '${p.name}.cast()';
        }

        return '${p.name}'; // as ${p.type.getWasmInteropType(w)}';
      }

      if (p.type is EnumClass) {
        if ((p.type as EnumClass).generateAsInt) {
          return '${p.name}';
        } else {
          return '${p.name}.value';
        }
      }

      if (p.type.llvmType == "i64") {
        return '${p.name}.toJSBigInt';
      }

      if (p.type is Typealias && p.type.typealiasType is PointerType) {
        var pointerType = p.type.typealiasType as PointerType;
        return '${p.name} as ${pointerType.getWasmInteropType(w)}';
      }

      return '${p.name}';
    }).join(',');

    if (writeModuleBinding) {
      s.write(
          '''external $interopReturnType $interopFunctionName($interopArgsString);\n''');
    } else {
      s.write('''$userReturnType $userFunctionName($userArgsString) {
              ${interopArgumentConstructors.join("\n")}
              final result = GeneratedBindings.instance.$interopFunctionName($invokeInteropArgsString);
              ${interopReturnTypeConstructors.join("\n")}
  }''');
    }

    return BindingString(type: BindingStringType.func, string: s.toString());
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
    functionType.addDependencies(dependencies);
    if (exposeFunctionTypedefs) {
      _exposedFunctionTypealias!.addDependencies(dependencies);
    }
  }
}

/// Represents a Parameter, used in [Func] or [Typealias]
class Parameter {
  final String? originalName;
  String name;
  Type type;

  Parameter({
    String? originalName,
    this.name = '',
    required Type type,
  })  : originalName = originalName ?? name,
        // A [NativeFunc] is wrapped with a pointer because this is a shorthand
        // used in C for Pointer to function.
        type = type.typealiasType is NativeFunc ? PointerType(type) : type;

  String getNativeType({String varName = ''}) =>
      '${type.getNativeType(varName: varName)}';
}
