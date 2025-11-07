// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'compound.dart';
import 'writer.dart';

/// A binding for C Struct.
///
/// For a C structure -
/// ```c
/// struct C {
///   int a;
///   double b;
///   int c;
/// };
/// ```
/// The generated dart code is -
/// ```dart
/// final class Struct extends Struct {
///  int a;
///
///  double b;
///
///  int c;
///
/// }
/// ```
class Struct extends Compound {
  Struct({
    super.usr,
    super.originalName,
    required super.name,
    super.isIncomplete,
    super.pack,
    super.dartDoc,
    super.members,
    super.isInternal,
    super.nativeType,
  }) : super(compoundType: CompoundType.struct);

  @override
  String get llvmType => '*';

  @override
  int get sizeInBytes {
    int size = 0;
    for (final member in members) {
      size += member.type.sizeInBytes;
    }
    return size;
  }

}
