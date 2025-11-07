// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../config_provider/config_types.dart';
import 'binding.dart';
import 'binding_string.dart';
import 'compound.dart';
import 'pointer.dart';
import 'type.dart';
import 'utils.dart';
import 'writer.dart';

/// A binding to a global variable
///
/// For a C global variable -
/// ```c
/// int a;
/// ```
/// The generated dart code is -
/// ```dart
/// final int a = _dylib.lookup<ffi.Int32>('a').value;
/// ```
class Global extends Binding {
  final Type type;
  final bool constant;

  Global({
    required super.usr,
    required super.originalName,
    required super.name,
    required this.type,
    super.dartDoc,
    this.constant = false,
  });

  @override
  BindingString toBindingString(Writer w, { bool writeModuleBinding = false}) {
    
    final s = StringBuffer();
    final globalVarName = name;
    if (dartDoc != null) {
      s.write(makeDartDoc(dartDoc!));
    }
    final dartType = type.getDartType(w);
    final ffiDartType = type.getInteropDartType(w);
    final cType = type.getInteropDartType(w);

      if (type case final ConstantArray arr) {
        throw UnimplementedError();
      }

      final pointerName = '_$globalVarName';

      if(writeModuleBinding) {
        s.writeln('external Pointer<Int32> $pointerName;');
      } else {
        final isIntType = type.getDartType(w) == "int";
        final isDoubleType = type.getDartType(w) == "double";
        final isBigInt = type.llvmType == "i64";
        
        s.write('''$dartType get ${pointerName.replaceFirst('_', "")} {
            final value = NativeLibrary.instance.getValue${isBigInt ? "BigInt" : ""}(GeneratedBindings.instance.$pointerName, "${type.llvmType}");''');
        if(isBigInt) {
          if(type.getNativeType() == "uint64_t") {
            s.write('return bigIntasUintN(64, value).toDart;');
          } else {
            s.write('return value.toDart;');
          }
        } else if(isIntType) {
          s.write('return value.toDartInt;');
        } else if(isDoubleType) {
          s.write('return value.toDartDouble;');
        } else {
          throw Exception();
        }
        s.write('}');
      }    

    return BindingString(type: BindingStringType.global, string: s.toString());
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
    type.addDependencies(dependencies);
  }
}
