# Third-party notices

## Coucou (source code only)

Parts of Lupy's macOS shell are adapted from **Coucou** (https://github.com/Louis-CFM/coucou),
inspected at commit `f09ac0b451128781b88b0f8a77f69bab622b9f24` (2026-10-15). Adapted code is
marked in file headers with `Adapted from Coucou (MIT)`. Coucou's source code is licensed under
the MIT License, reproduced here as its terms require:

```
MIT License

Copyright (c) 2026 Louis Raillé

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Not used:** Coucou's `LICENSE-ASSETS.md` reserves the names "Coucou" and "Mochi", the Mochi
character (design, look, expressions and animations as a character), the app and menu-bar icons,
the sounds, and the media in `docs/media/` and `design/`. Lupy ships **none** of these. Lupy's
character, name, icon are original; Lupy ships no sound files (it may play built-in macOS system
sounds by name, which are not redistributed).

## Development-only tools (not shipped in the app)

- `@live-codes/swift-wasm` 0.1.0 (MIT, © 2026 Hatem Hosny) — vendors the Swift 6.3.3 compiler
  cross-compiled to WebAssembly (Swift: Apache-2.0 with Runtime Library Exception; LLVM: Apache-2.0
  with LLVM Exceptions; wasi-libc: Apache-2.0/MIT). Used only to compile and test LupyCore inside
  Linux sandboxes. Installed via npm into `tools/swiftwasm/node_modules`, never committed.
- `@bjorn3/browser_wasi_shim` 0.4.2 (MIT OR Apache-2.0) — WASI implementation used by the dev tool.
- XcodeGen (MIT) — used on the macOS build machine to generate the Xcode project. Not shipped.

The shipped app has **no third-party runtime dependencies**: it uses only Apple system frameworks.
