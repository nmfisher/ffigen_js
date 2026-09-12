import 'dart:typed_data';

/// Layout and copying rules for explicit temporary Wasm buffer scopes.
/// Internal to the package; addresses are relative to an aligned allocation.
final class NativeBufferLayout {
  static const alignment = 16;

  final _ranges = <_BufferRange>[];
  final _offsets = Map<TypedData, int>.identity();
  int lengthInBytes = 0;

  NativeBufferLayout(Iterable<TypedData> buffers) {
    final inputs = buffers.toList();
    for (final data in inputs) {
      if (data.lengthInBytes == 0) {
        _offsets[data] = 0;
        continue;
      }
      final start = data.offsetInBytes;
      final end = start + data.lengthInBytes;
      _BufferRange? range;
      // ByteBuffer wrappers may compare equal without having equal hashes on
      // Dart Wasm. Compare buffers directly instead of using them as map keys.
      for (final candidate in _ranges) {
        if (candidate.buffer == data.buffer) {
          range = candidate;
          break;
        }
      }
      if (range == null) {
        _ranges.add(_BufferRange(data.buffer, start, end));
      } else {
        if (start < range.start) range.start = start;
        if (end > range.end) range.end = end;
      }
    }
    for (final range in _ranges) {
      // Rounding down the source start preserves mixed-type alias alignment.
      range.start &= ~(alignment - 1);
      range.offset = lengthInBytes;
      lengthInBytes += (range.length + alignment - 1) & ~(alignment - 1);
    }
    for (final data in inputs) {
      if (_offsets.containsKey(data)) continue;
      final range = _ranges.firstWhere((r) => r.buffer == data.buffer);
      _offsets[data] = range.offset + data.offsetInBytes - range.start;
    }
  }

  bool containsBuffer(ByteBuffer buffer) =>
      _ranges.any((range) => range.buffer == buffer);

  int? addressOf(TypedData data, int baseAddress) {
    if (data.lengthInBytes == 0) return 0;
    final offset = _offsets[data];
    if (offset != null) return baseAddress + offset;
    // Views created inside a scope may borrow a registered enclosing range.
    for (final range in _ranges) {
      if (range.buffer == data.buffer &&
          data.offsetInBytes >= range.start &&
          data.offsetInBytes + data.lengthInBytes <= range.end) {
        return baseAddress + range.offset + data.offsetInBytes - range.start;
      }
    }
    return null;
  }

  void copyIn(Uint8List allocation) {
    for (final range in _ranges) {
      allocation.setRange(
          range.offset, range.offset + range.length, range.source);
    }
  }

  void copyBack(Uint8List allocation) {
    for (final range in _ranges) {
      final target = range.source;
      // Use the checked setter first: some VM bulk-copy paths bypass the
      // setter on unmodifiable typed-list views. Every range is nonempty.
      target[0] = allocation[range.offset];
      target.setRange(1, range.length, allocation, range.offset + 1);
    }
  }
}

final class _BufferRange {
  final ByteBuffer buffer;
  int start;
  int end;
  int offset = 0;

  _BufferRange(this.buffer, this.start, this.end);

  int get length => end - start;
  Uint8List get source => buffer.asUint8List(start, length);
}
