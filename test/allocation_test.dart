@TestOn('js')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:ffigen_js/ffigen_js.dart';
import 'package:test/test.dart';

void main() {
  final allocations = <int, int>{};
  final freed = <int>[];
  late Uint8List heap;
  var nextAddress = 16;
  var failAllocation = false;

  setUp(() {
    allocations.clear();
    freed.clear();
    heap = Uint8List(128 * 1024);
    nextAddress = 16;
    failAllocation = false;
    final module = JSObject();
    module.setProperty('HEAPU8'.toJS, heap.toJS);
    module.setProperty(
        '_malloc'.toJS,
        ((int size) {
          if (failAllocation) return 0;
          final address = nextAddress;
          nextAddress += size;
          allocations[address] = size;
          return address;
        }).toJS);
    module.setProperty(
        '_free'.toJS,
        ((int address) {
          final size = allocations.remove(address)!;
          freed.add(address);
          heap.fillRange(address, address + size, 0xcc);
        }).toJS);
    module.setProperty('stackAlloc'.toJS, ((int _) => 96 * 1024).toJS);
    NativeLibrary.instance = module as NativeLibrary;
  });

  test('free releases a direct malloc allocation', () {
    final pointer = malloc<Char>(256);
    expect(allocations, {pointer.address: 256});
    free(pointer);
    expect(freed, [pointer.address]);
    expect(allocations, isEmpty);
  });

  test('cast aliases and repeated free release an allocation once', () {
    final pointer = malloc<Char>(32);
    pointer.cast<Uint8>().free();
    free(pointer);
    pointer.free();
    expect(freed, [pointer.address]);
    expect(allocations, isEmpty);
  });

  test('a heap-backed typed-data view can release its malloc allocation', () {
    final pointer = malloc<Uint8>(32);
    final view = pointer.asTypedList(32);
    view.free();
    expect(freed, [pointer.address]);
    expect(allocations, isEmpty);
  });

  test('stack pointers are not passed to the heap allocator', () {
    free(stackAlloc<Char>(16));
    expect(freed, isEmpty);
  });

  test('borrowed pointers are not passed to the heap allocator', () {
    free(const Pointer<Char>.fromAddress(4096));
    expect(freed, isEmpty);
  });

  test('a failed allocation does not register the null pointer', () {
    failAllocation = true;
    final pointer = malloc<Char>(32);
    expect(pointer, nullptr);
    free(pointer);
    free(nullptr);
    expect(freed, isEmpty);
    expect(allocations, isEmpty);
  });

  test('a reused address is registered for its new allocation', () {
    final first = malloc<Char>(32);
    free(first);
    nextAddress = first.address;
    final second = malloc<Uint8>(64);
    free(second);
    expect(freed, [first.address, second.address]);
    expect(allocations, isEmpty);
  });

  test('large typed-data copies still release their heap allocation', () {
    final data = Uint8List(32 * 1024);
    data[0] = 0xa5;
    data[data.length - 1] = 0x5a;
    final pointer = data.address;
    expect(heap[pointer.address], 0xa5);
    expect(heap[pointer.address + data.length - 1], 0x5a);
    free(pointer);
    expect(freed, [pointer.address]);
    expect(allocations, isEmpty);
  });
}
