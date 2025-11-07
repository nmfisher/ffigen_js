// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../code_generator.dart';

import 'writer.dart';

enum SupportedNativeType {
  voidType,
  char,
  int8,
  int16,
  int32,
  int64,
  uint8,
  uint16,
  uint32,
  uint64,
  float,
  double,
  intPtr,
  uintPtr,
}

/// Represents a WASM type
class NativeType extends Type {
  static const _primitives = <SupportedNativeType, NativeType>{
    SupportedNativeType.voidType: NativeType._('void', 'void', 0, 'null', 'v'),
    SupportedNativeType.char: NativeType._('int', 'char', 1, 'u8', 'i'),
    SupportedNativeType.int8: NativeType._('int', 'int8_t', 1, 'i8', 'i'),
    SupportedNativeType.int16: NativeType._('int', 'int16_t', 2, 'i16', 'i'),
    SupportedNativeType.int32: NativeType._('int', 'int32_t', 4, 'i32', 'i'),
    SupportedNativeType.int64: NativeType._('BigInt', 'int64_t', 8, 'i64', 'j'),
    SupportedNativeType.uint8: NativeType._('int', 'uint8_t', 1, 'i8', 'i'),
    SupportedNativeType.uint16: NativeType._('int', 'uint16_t', 2, 'i16', 'i'),
    SupportedNativeType.uint32: NativeType._('int', 'uint32_t', 4, 'i32', 'i'),
    SupportedNativeType.uint64: NativeType._('BigInt', 'uint64_t', 8, 'i64', 'j'),
    SupportedNativeType.float: NativeType._('double', 'float', 4, 'float', 'f'),
    SupportedNativeType.double:
        NativeType._('double', 'double', 8, 'double', 'd'),
    SupportedNativeType.intPtr: NativeType._('int', 'intptr_t', 8, '*', 'p'),
    SupportedNativeType.uintPtr: NativeType._('int', 'uintptr_t', 8, '*', 'p'),
  };

  final String _dartType;
  final String _nativeType;

  @override
  final int sizeInBytes;

  @override
  final String llvmType;

  final String wasmType;

  const NativeType._(this._dartType, this._nativeType, this.sizeInBytes,
      this.llvmType, this.wasmType);

  factory NativeType(SupportedNativeType type) => _primitives[type]!;

  String getDartType(Writer w) => _dartType;

  @override
  String getInteropDartType(Writer w) {
    if(llvmType == 'i64') {
      return "JSBigInt";
    }
    return _dartType;
  }

  @override
  String getWasmInteropType(Writer w) {

    switch(_nativeType) {
        case 'char':
          return 'Char';
        case 'BOOL':
          return 'Bool';
        case 'uint8_t':
          return 'Uint8';
        case 'int8_t':
          return 'Int8';
        case 'unsigned short':
        case 'uint16_t':
          return 'Uint16';
        case 'uint32_t':
          return 'Uint32';
        case 'short':
        case 'i16':
          return 'Int16';
        case 'int':
        case 'int32_t':
        case 'long':
          return 'Int32';
        case 'int64_t':
          return 'Int64';
        case 'float':
          return 'Float32';
        case 'double':
          return 'Float64';
        case 'intptr_t':
        case 'uintptr_t':
          return 'Pointer';
        case 'void':
        case 'null':
          return 'Void';
        default:
          throw UnimplementedError(_nativeType);
      }
  }

  @override
  String getNativeType({String varName = ''}) => _nativeType;

  @override
  String cacheKey() => _dartType;
}

class BooleanType extends NativeType {
  const BooleanType._() : super._('bool', 'BOOL', 1, 'i8', 'i');
  static const _boolean = BooleanType._();
  factory BooleanType() => _boolean;

  @override
  String toString() => 'bool';

  @override
  String cacheKey() => 'bool';
}
