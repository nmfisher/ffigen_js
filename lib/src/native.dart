import 'dart:typed_data';

export 'dart:ffi';

/// Executes [body] directly, without allocating or copying native buffers.
///
/// Use TypedData `.address` directly as an argument to a leaf FFI function
/// inside [body]. The buffer list is used only on web. Keep the callback
/// synchronous for portability with web's temporary buffer lifetime.
R withNativeBuffers<R>(Iterable<TypedData> buffers, R Function() body) =>
    body();
