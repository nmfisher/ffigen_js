import { readFile } from 'fs/promises';
import { compile } from '../../example/build/typed_data_address_test.mjs';
import example from '../../example/build/example_lib.js';

async function runDartWasmTests() {
  const memory = new WebAssembly.Memory({
    initial: 256,
    maximum: 256,
    shared: true,
  });

  globalThis['module'] = await example({ env: { wasmMemory: memory } });

  const wasmUrl = new URL(
    '../../example/build/typed_data_address_test.wasm',
    import.meta.url,
  );
  const wasmBytes = await readFile(wasmUrl);
  const compiledApp = await compile(wasmBytes);

  const instantiatedApp = await compiledApp.instantiate({
    ffi: {
      memory: 'memory',
    },
  });
  await instantiatedApp.invokeMain();
}

runDartWasmTests().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
