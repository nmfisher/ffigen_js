// Copyright (c) 2021, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import '../code_generator.dart';

import 'binding_string.dart';
import 'utils.dart';
import 'writer.dart';

enum CompoundType { struct, union }

/// A binding for Compound type - Struct/Union.
abstract class Compound extends BindingType {
  /// Marker for if a struct definition is complete.
  ///
  /// A function can be safely pass this struct by value if it's complete.
  bool isIncomplete;

  List<Member> members;

  bool get isOpaque => members.isEmpty;

  /// Value for `@Packed(X)` annotation. Can be null (no packing), 1, 2, 4, 8,
  /// or 16.
  ///
  /// Only supported for [CompoundType.struct].
  int? pack;

  /// Marker for checking if the dependencies are parsed.
  bool parsedDependencies = false;

  CompoundType compoundType;
  bool get isStruct => compoundType == CompoundType.struct;
  bool get isUnion => compoundType == CompoundType.union;

  /// The way the native type is written in C source code. This isn't always the
  /// same as the originalName, because the type may need to be prefixed with
  /// `struct` or `union`, depending on whether the declaration is a typedef.
  final String nativeType;

  ///
  ///
  String get wasmType => '*';

  Compound({
    super.usr,
    super.originalName,
    required super.name,
    required this.compoundType,
    this.isIncomplete = false,
    this.pack,
    super.dartDoc,
    List<Member>? members,
    super.isInternal,
    String? nativeType,
  })  : members = members ?? [],
        nativeType = nativeType ?? originalName ?? name;

  factory Compound.fromType({
    required CompoundType type,
    String? usr,
    String? originalName,
    required String name,
    bool isIncomplete = false,
    int? pack,
    String? dartDoc,
    List<Member>? members,
    String? nativeType,
  }) {
    switch (type) {
      case CompoundType.struct:
        return Struct(
          usr: usr,
          originalName: originalName,
          name: name,
          isIncomplete: isIncomplete,
          pack: pack,
          dartDoc: dartDoc,
          members: members,
          nativeType: nativeType,
        );
      case CompoundType.union:
        return Union(
          usr: usr,
          originalName: originalName,
          name: name,
          isIncomplete: isIncomplete,
          pack: pack,
          dartDoc: dartDoc,
          members: members,
          nativeType: nativeType,
        );
    }
  }

  String _getInlineArrayTypeString(Type type, Writer w) {
    if (type is ConstantArray) {
      return 'Array<'
          '${_getInlineArrayTypeString(type.child, w)}>';
    }
    return type.getWasmInteropType(w);
  }

  @override
  BindingString toBindingString(Writer w, {bool writeModuleBinding = false}) {
    final bindingType =
        isStruct ? BindingStringType.struct : BindingStringType.union;

    final s = StringBuffer();
    final enclosingClassName = name;
    if (dartDoc != null) {
      s.write(makeDartDoc(dartDoc!));
    }

    /// Adding [enclosingClassName] because dart doesn't allow class member
    /// to have the same name as the class.
    final localUniqueNamer = UniqueNamer({enclosingClassName});

    /// Marking type names because dart doesn't allow class member to have the
    /// same name as a type name used internally.
    for (final m in members) {
      localUniqueNamer.markUsed(m.type.getInteropDartType(w));
    }

    /// Write @Packed(X) annotation if struct is packed.
    if (isStruct && pack != null) {
      s.write('@Packed($pack)\n');
    }
    final dartClassName = isStruct ? 'Struct' : 'Union';
    // Write class declaration.
    s.write('''

extension ${name}Ext on Pointer<$name> {
  $enclosingClassName toDart() {
    return $enclosingClassName(this);
  }
}''');

    s.write('final class $enclosingClassName extends ');
    s.write('${isOpaque ? 'Struct' : dartClassName}{\n');
    const depth = '  ';
    int offset = 0;
    for (final m in members) {
      m.name = localUniqueNamer.makeUnique(m.name);
      if (m.dartDoc != null) {
        s.write('$depth/// ');
        s.writeAll(m.dartDoc!.split('\n'), '\n$depth/// ');
        s.write('\n');
      }
      final memberName = m.name;

      final dartType = m.type is PointerType
          ? m.type.getDartType(w)
          : m.type.getInteropDartType(w);

      final toDart = switch (m.type.getDartType(w)) {
        'double' => '.toDartDouble',
        'int' => '.toDartInt',
        _ => ''
      };

      String box(String inner, String addr) {
        if (m.type is ConstantArray) {
          var arrType = m.type as ConstantArray;
          return '$dartType((numElements: ${arrType.length}, addr: ${m.type.getInteropDartType(w)}(this.address + $offset)))';
        } else if (m.type is PointerType) {
          return '$dartType($inner.toDartInt)';
        } else if (m.type is BooleanType) {
          return '$inner.toDartInt == 1';
        } else if (m.type is BindingType) {
          return '${m.type.getInteropDartType(w)}(Pointer<${m.type.getInteropDartType(w)}>(addr))';
        }
        return inner;
      }

      String boxJS(String inner) {
        if (m.type is BooleanType) {
          return '($inner ? 1 : 0).toJS';
        } else if (m.type is ConstantArray) {
          return '${inner}.internal.addr.addr.toJS';
        } else if (m.type is BindingType) {
          return '${inner}.address.toJS';
        }
        return '$inner.toJS';
      }

      s.write('''
$dartType get $memberName {
  final addr = this.address + $offset;
  final value = NativeLibrary.instance.getValue(addr, '${m.type.llvmType}')$toDart;
  return ${box('value', 'addr')};
}
set $memberName($dartType val) {
  NativeLibrary.instance.setValue(this.address + $offset, ${boxJS('val')}, '${m.type.llvmType}');
}
''');

      if (m.type case EnumClass(:final generateAsInt) when !generateAsInt) {
        final enumName = m.type.getDartType(w);
        final memberName = m.name;
        s.write(
          '${depth}$enumName get $memberName => '
          '$enumName.fromValue(${memberName}AsInt);\n\n',
        );
      }

      offset += m.type.sizeInBytes;
    }

    // Add constructor with required named parameters
    s.write('$enclosingClassName(super.address);\n\n');

    s.write('''
static Pointer<$name> stackAlloc() {
    return Pointer<$name>(NativeLibrary.instance.stackAlloc<$name>($sizeInBytes));
  }
  ''');

    s.write('}\n\n');

    return BindingString(type: bindingType, string: s.toString());
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
    for (final m in members) {
      m.type.addDependencies(dependencies);
    }
  }

  @override
  bool get isIncompleteCompound => isIncomplete;

  @override
  String getInteropDartType(Writer w) {
    return name;
  }

  @override
  String getNativeType({String varName = ''}) => '$nativeType $varName';
}

class Member {
  final String? dartDoc;
  final String originalName;
  String name;
  final Type type;

  Member({
    String? originalName,
    required this.name,
    required this.type,
    this.dartDoc,
  }) : originalName = originalName ?? name;
}
