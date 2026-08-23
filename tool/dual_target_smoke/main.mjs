import { readFile } from 'fs/promises';
import { existsSync } from 'fs';
import { compile } from './main_dual.mjs';

// ---------------------------------------------------------------------------
// Publishes the Emscripten Module under the JS global the bindings expect:
// globalThis['dual'] (the `ffi-native: asset-id: dual` in js_config.yaml).
//
// Two implementations of the SAME C functions (native/src/dual.c):
//
//  1. REAL (preferred): build/dual.js, produced by build.sh with emcc from
//     dual.c. Used whenever it exists - this is what CI should exercise.
//
//  2. STAND-IN (fallback for environments without emcc): a hand-written JS
//     implementation over a fake Emscripten runtime. It exists only so the
//     conditional-import routing and the consumer can still be run under
//     dart2wasm + node without the Emscripten toolchain. It is NOT a test
//     of the compiled C code - CI must run build.sh (emcc) for that.
// ---------------------------------------------------------------------------

function makeFakeRuntime() {
  const size = 1 << 20;
  const buffer = new ArrayBuffer(size);
  const HEAPU8 = new Uint8Array(buffer);
  const HEAPU32 = new Uint32Array(buffer);
  const HEAPF32 = new Float32Array(buffer);
  const enc = new TextEncoder();
  const dec = new TextDecoder();

  let sp = size; // stack grows down from the top
  let heapPtr = 8; // malloc grows up from the bottom

  const runtime = {
    HEAPU8,
    HEAPU32,
    HEAPF32,
    stackSave: () => sp,
    stackRestore: (p) => {
      sp = p;
    },
    stackAlloc: (n) => {
      sp -= (n + 15) & ~15;
      return sp;
    },
    _malloc: (n) => {
      const p = heapPtr;
      heapPtr += (n + 15) & ~15;
      return p;
    },
    _free: () => {},
    getValue(ptr, type) {
      switch (type) {
        case 'i8':
          return HEAPU8[ptr];
        case 'i16':
          return new Int16Array(buffer, ptr, 1)[0];
        case 'i32':
        case '*':
          return HEAPU32[ptr >> 2];
        case 'float':
          return HEAPF32[ptr >> 2];
        case 'double':
          return new Float64Array(buffer, ptr, 1)[0];
        default:
          return HEAPU32[ptr >> 2];
      }
    },
    setValue(ptr, value, type) {
      switch (type) {
        case 'i8':
          HEAPU8[ptr] = value;
          break;
        case 'i16':
          new Int16Array(buffer, ptr, 1)[0] = value;
          break;
        case 'float':
          HEAPF32[ptr >> 2] = value;
          break;
        case 'double':
          new Float64Array(buffer, ptr, 1)[0] = value;
          break;
        default:
          HEAPU32[ptr >> 2] = value;
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
    writeArrayToMemory(arr, ptr) {
      HEAPU8.set(arr, ptr);
    },
    addFunction: () => 0x1000,
    removeFunction: () => {},
  };

  const f32 = (addr) => HEAPF32[addr >> 2];

  // Mirrors native/src/dual.c exactly (snprintf semantics included).
  return {
    ...runtime,
    _dualAdd: (a, b) => a + b,
    _dualPointScale(p, k) {
      const kf = Math.fround(k);
      HEAPF32[p >> 2] = Math.fround(f32(p) * kf);
      HEAPF32[(p + 4) >> 2] = Math.fround(f32(p + 4) * kf);
    },
    _dualGreet(name, out, outLen) {
      const formatted = `hello, ${runtime.UTF8ToString(name)}!`;
      runtime.stringToUTF8(formatted, out, outLen);
      return runtime.lengthBytesUTF8(formatted);
    },
  };
}

async function loadModule() {
  if (existsSync('./dual.js')) {
    const factory = (await import('./dual.js')).default;
    console.log('main.mjs: using REAL Emscripten module (build/dual.js)');
    return factory();
  }
  console.log(
      'main.mjs: dual.js not found (no emcc build) - using the JS STAND-IN.' +
      ' CI must run build.sh with emcc to test the compiled C.');
  return makeFakeRuntime();
}

globalThis['dual'] = await loadModule();

const memory = new WebAssembly.Memory({ initial: 64 });
const wasmBytes = await readFile('main_dual.wasm');
const compiled = await compile(wasmBytes);
const instantiated = await compiled.instantiate({ ffi: { memory } });
instantiated.invokeMain();
