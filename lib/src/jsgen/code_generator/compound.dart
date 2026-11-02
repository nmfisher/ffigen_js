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

  /// Canonical layout from Clang for the configured compilation target.
  int? nativeSize;
  int? nativeAlignment;

  @override
  int get sizeInBytes => isOpaque
      ? 0
      : nativeSize ?? (throw StateError('Missing native layout for $name'));

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

    // Packing is already represented by the explicit field offsets.
    if (isStruct && pack != null) {
      s.write('// Native packing: $pack byte(s).\n');
    }
    final dartClassName = isStruct ? 'Struct' : 'Union';
    // Write class declaration.
    s.write('''

extension ${name}Ext on Pointer<$name> {
  $enclosingClassName toDart() {
    return $enclosingClassName(this);
  }
}''');

    s.write('''
final class $enclosingClassName extends  ${isOpaque ? 'Struct' : dartClassName} {

    Pointer<$enclosingClassName> get address => super.address.cast();
''');
    const depth = '  ';
    for (final m in members) {
      final offset = m.offsetInBytes ??
          (throw StateError('Missing native offset for $name.${m.name}'));
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
        _ => m.type is EnumClass ? '.toDartInt' : ''
      };

      final resolvedType = m.type.typealiasType;
      final memberAddress = 'this.address.addr + $offset';
      if (resolvedType is ConstantArray || resolvedType is Compound) {
        final String value;
        final String sourceAddress;
        if (resolvedType is ConstantArray) {
          value = '$dartType((numElements: ${resolvedType.length}, '
              'addr: ${resolvedType.getInteropDartType(w)}($memberAddress)))';
          sourceAddress = 'val.internal.addr.addr';
        } else {
          value = '$dartType(Pointer<$dartType>($memberAddress))';
          sourceAddress = 'val.address.addr';
        }
        // Inline aggregates are views, not pointer-valued slots. Assignment
        // copies all bytes (including padding) and permits overlapping views.
        s.write("""
$dartType get $memberName => $value;
set $memberName($dartType val) {
  final heap = NativeLibrary.instance.HEAPU8.toDart;
  final source = $sourceAddress;
  final bytes = heap.sublist(source, source + ${resolvedType.sizeInBytes});
  heap.setRange($memberAddress, $memberAddress + ${resolvedType.sizeInBytes}, bytes);
}
""");
        continue;
      }

      String box(String inner, String addr) {
        if (resolvedType is PointerType) {
          return '$dartType($inner.toDartInt)';
        } else if (resolvedType is BooleanType) {
          return '$inner.toDartInt == 1';
        }
        return inner;
      }

      String boxJS(String inner) {
        if (resolvedType is BooleanType) {
          return '($inner ? 1 : 0).toJS';
        }
        return '$inner.toJS';
      }

      // Determine the property name to use for the int getter/setter.
      // For enum types, use 'AsInt' suffix so the enum getter can reference it.
      final isEnumClass = m.type is EnumClass;
      final generateAsInt =
          isEnumClass ? (m.type as EnumClass).generateAsInt : true;
      final propertyName =
          (isEnumClass && !generateAsInt) ? '${memberName}AsInt' : memberName;

      final nativeName = resolvedType.getNativeType();
      final dataMethod = switch (resolvedType.llvmType) {
        'float' => 'Float32',
        'double' => 'Float64',
        'i16' => nativeName.startsWith('u') ? 'Uint16' : 'Int16',
        'i32' => nativeName.startsWith('u') ? 'Uint32' : 'Int32',
        '*' => 'Uint32',
        _ => null,
      };
      final String unalignedGetter;
      final String unalignedSetter;
      if (dataMethod != null) {
        final read = 'data.get$dataMethod(addr.addr, Endian.little)';
        final value = resolvedType is PointerType ? '$dartType($read)' : read;
        final input = resolvedType is PointerType ? 'val.addr' : 'val';
        unalignedGetter = """
  if (addr.addr % ${resolvedType.sizeInBytes} != 0) {
    final data = ByteData.sublistView(NativeLibrary.instance.HEAPU8.toDart);
    return $value;
  }
""";
        unalignedSetter = """
  if (addr.addr % ${resolvedType.sizeInBytes} != 0) {
    final data = ByteData.sublistView(NativeLibrary.instance.HEAPU8.toDart);
    data.set$dataMethod(addr.addr, $input, Endian.little);
    return;
  }
""";
      } else {
        unalignedGetter = '';
        unalignedSetter = '';
      }

      s.write('''
$dartType get $propertyName {
  final addr = Pointer<$enclosingClassName>(this.address.addr + $offset);
$unalignedGetter  final value = NativeLibrary.instance.getValue(addr, '${m.type.llvmType}')$toDart;
  return ${box('value', 'addr')};
}
set $propertyName($dartType val) {
  final addr = Pointer<$enclosingClassName>(this.address.addr + $offset);
$unalignedSetter  NativeLibrary.instance.setValue(addr, ${boxJS('val')}, '${m.type.llvmType}');
}
''');

      if (isEnumClass && !generateAsInt) {
        final enumName = m.type.getDartType(w);
        s.write(
          '$depth$enumName get $memberName => '
          '$enumName.fromValue($propertyName);\n\n',
        );
      }
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
  String getWasmInteropType(Writer w) => name;

  @override
  String getNativeType({String varName = ''}) => '$nativeType $varName';
}

class Member {
  final String? dartDoc;
  final String originalName;
  String name;
  final Type type;

  /// Byte offset reported by Clang, including internal padding.
  final int? offsetInBytes;

  Member({
    String? originalName,
    required this.name,
    required this.type,
    this.offsetInBytes,
    this.dartDoc,
  }) : originalName = originalName ?? name;
}
