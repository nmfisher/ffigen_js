import {readFile} from 'node:fs/promises';
import createLayout from '../../build/layout_smoke/layout.cjs';
import {compile} from '../../build/layout_smoke/main.mjs';

globalThis.layout = await createLayout();
layout.allocations = [];
const allocate = layout.stackAlloc;
layout.stackAlloc = bytes => { layout.allocations.push(bytes); return allocate(bytes); };
const compiled = await compile(await readFile(new URL('../../build/layout_smoke/main.wasm', import.meta.url)));
const instance = await compiled.instantiate({});
instance.invokeMain();
