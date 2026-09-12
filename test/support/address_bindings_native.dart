import 'dart:ffi' as ffi;

// Direct leaf declarations, equivalent to native ffigen output. libc provides
// these symbols so this test needs no native allocator or wrapper library.
@ffi.Native<
    ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Uint8>, ffi.Int, ffi.Size)>(
  symbol: 'memset',
  isLeaf: true,
)
external ffi.Pointer<ffi.Uint8> fill_bytes(
    ffi.Pointer<ffi.Uint8> data, int value, int length);

@ffi.Native<
    ffi.Int Function(ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Uint8>, ffi.Size)>(
  symbol: 'memcmp',
  isLeaf: true,
)
external int compare_bytes(
    ffi.Pointer<ffi.Uint8> a, ffi.Pointer<ffi.Uint8> b, int length);
