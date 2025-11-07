# **_package:ffigen_js**: 

`ffigen_js` is an adaptation of the `ffigen` package to support generating Javascript-interop bindings from C header files. 

Internally, this uses dart:js_interop to make calls to a WASM library, but externally it exposes the same dart:ffi types. 

See https://hydroxide.dev/articles/dart-javascript-interop-web-assembly/ for an overview

This allows Dart packages to easily integrate invoke WASM libraries (via JS interop) with (mostly) the same FFI

This package is intended as a (mostly) drop-in replacement for `ffigen`. This means that:
- the `config.yaml` format is the same as `ffigen` (though not all options are currently supported) 
- 

It's pretty hack-ish but it works - I'm using it as a temporary workaround on web until proper support for WASM linking and/or FFI is supported.

This means you can use ffigen to generate bindings for native, jsgen to generate for wasm, then use a single library fiile with a conditional import to switch between the two at compile time. The idea is that only minimal changes to your code should be require (mostly around allocating memory).


configuration format Not all `ffigen` configuration  