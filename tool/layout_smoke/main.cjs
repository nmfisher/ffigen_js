globalThis.self = globalThis;
require('../../build/layout_smoke/layout.cjs')().then(module => {
  globalThis.layout = module;
  module.allocations = [];
  const allocate = module.stackAlloc;
  module.stackAlloc = bytes => {
    module.allocations.push(bytes);
    return allocate(bytes);
  };
  require('../../build/layout_smoke/main.js');
}).catch(error => { console.error(error); process.exitCode = 1; });
