import 'dart:js_interop';
import 'generated_bindings_js.g.dart';

@JS('module.allocations')
external JSArray<JSNumber> get allocations;

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

int lastAllocation() => allocations.toDart.last.toDartInt;

void runAbiLayoutChecks() {
  final p = Padded.stackAlloc();
  final paddedSize = lastAllocation();
  final v = p.toDart();
  v.enabled = 7;
  v.tail = 9;
  v.values[0] = 0.125;
  v.values[1] = 0.5;
  v.values[2] = 0.875;
  check(checkPadded(p) == 1, 'Dart writes padded float array into native C');
  check(v.tail == 9, 'float writes preserve the adjacent byte');

  final nested = Nested.stackAlloc();
  final nestedSize = lastAllocation();
  fillNested(nested);
  check(nested.toDart().tag == 3 && nested.toDart().end == 11,
      'native writes retain surrounding fields');
  check(checkPadded(nested.toDart().entry.address) == 1, 'nested inline view');
  nested.toDart().entry = v;
  check(nested.toDart().end == 11, 'aggregate copy preserves the next member');

  final packed = Packed.stackAlloc();
  final packedSize = lastAllocation();
  final pv = packed.toDart();
  pv.tag = 5;
  pv.amount = 1.25;
  pv.count = -1234;
  pv.entry = v;
  pv.samples[0] = 2.0;
  pv.samples[1] = 4.0;
  check(
      checkPacked(packed) == 1, 'unaligned fields, nested records and arrays');
  fillPacked(packed);
  check(
      pv.amount == 1.25 &&
          pv.count == -1234 &&
          pv.entry.values[2] == 0.875 &&
          pv.samples[1] == 4.0,
      'native-to-Dart packed readback');

  final choice = Choice.stackAlloc();
  final choiceSize = lastAllocation();
  fillChoice(choice);
  check(choice.toDart().number == 8.5, 'native union member readback');
  choice.toDart().record = v;
  check(
      checkPadded(choice.toDart().record.address) == 1, 'union aggregate copy');

  final other = Padded.stackAlloc().toDart();
  other.enabled = 7;
  other.tail = 9;
  other.values = v.values;
  other.values = other.values;
  check(
      checkPadded(other.address) == 1, 'inline array assignment copies bytes');
  check(checkSizes(paddedSize, nestedSize, packedSize, choiceSize) == 1,
      'generated allocation sizes match sizeof compiled for Wasm');
  print('All ABI layout tests passed');
}
