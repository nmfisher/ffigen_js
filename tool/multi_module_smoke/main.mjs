import { readFile } from 'fs/promises';
import { compile } from './smoke.mjs';

// Minimal Emscripten-like module: its own buffer, its own stack and heap
// bump allocators, and the runtime methods ffigen_js calls. Nothing is
// shared between instances - that is the point.
function makeFakeModule() {
  const size = 1 << 20;
  const buffer = new ArrayBuffer(size);
  const HEAPU8 = new Uint8Array(buffer);
  const HEAPU32 = new Uint32Array(buffer);
  const HEAPF32 = new Float32Array(buffer);
  const enc = new TextEncoder();
  const dec = new TextDecoder();

  let sp = size; // stack grows down from the top
  let heapPtr = 8; // malloc grows up from the bottom

  return {
    HEAPU8, HEAPU32, HEAPF32,
    stackSave: () => sp,
    stackRestore: (p) => { sp = p; },
    stackAlloc: (n) => { sp -= (n + 15) & ~15; return sp; },
    _malloc: (n) => { const p = heapPtr; heapPtr += (n + 15) & ~15; return p; },
    _free: () => {},
    getValue(ptr, type) {
      switch (type) {
        case 'i8': return HEAPU8[ptr];
        case 'i16': return new Int16Array(buffer, ptr, 1)[0];
        case 'i32': return HEAPU32[ptr >> 2];
        case 'float': return HEAPF32[ptr >> 2];
        case 'double': return new Float64Array(buffer, ptr, 1)[0];
        default: return HEAPU32[ptr >> 2]; // '*'
      }
    },
    setValue(ptr, value, type) {
      switch (type) {
        case 'i8': HEAPU8[ptr] = value; break;
        case 'i16': new Int16Array(buffer, ptr, 1)[0] = value; break;
        case 'i32': HEAPU32[ptr >> 2] = value; break;
        case 'float': HEAPF32[ptr >> 2] = value; break;
        case 'double': new Float64Array(buffer, ptr, 1)[0] = value; break;
        default: HEAPU32[ptr >> 2] = value;
      }
    },
    lengthBytesUTF8: (s) => enc.encode(s).length,
    UTF8ToString(ptr) {
      let end = ptr;
      while (HEAPU8[end] !== 0) end++;
      return dec.decode(HEAPU8.subarray(ptr, end));
    },
    stringToUTF8(str, ptr, maxBytesToWrite) {
      const bytes = enc.encode(str);
      HEAPU8.set(bytes.subarray(0, maxBytesToWrite - 1), ptr);
      HEAPU8[ptr + Math.min(bytes.length, maxBytesToWrite - 1)] = 0;
    },
    writeArrayToMemory(arr, ptr) { HEAPU8.set(arr, ptr); },
    addFunction: () => 0x1000,
    removeFunction: () => {},
  };
}

globalThis['mod_a'] = makeFakeModule();
globalThis['mod_b'] = makeFakeModule();

const memory = new WebAssembly.Memory({ initial: 64 });
const wasmBytes = await readFile('smoke.wasm');
const compiled = await compile(wasmBytes);
const instantiated = await compiled.instantiate({ ffi: { memory } });
instantiated.invokeMain();
