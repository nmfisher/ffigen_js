import { readFile } from 'fs/promises';
import { compile } from './example.mjs';
import example from './example_lib.js';

async function runDartWasm() {
    
    const memory = new WebAssembly.Memory({
    initial: 256,
    maximum: 256,
    shared:true
    });

    globalThis['module'] = await example({"env":{"wasmMemory":memory}});

    const wasmBytes = await readFile('example.wasm');
    const compiledApp = await compile(wasmBytes);
    
    const instantiatedApp = await compiledApp.instantiate({
        ffi: {
            memory: "memory"
        },
    });
    instantiatedApp.invokeMain();
}

runDartWasm().catch(console.error);

