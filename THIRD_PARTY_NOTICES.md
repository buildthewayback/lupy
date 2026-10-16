# Third-party notices

## Coucou — the app Lupy is built on

Lupy for Mac **is Coucou's macOS app** (https://github.com/Louis-CFM/coucou, commit
`f09ac0b451128781b88b0f8a77f69bab622b9f24`, imported unmodified into `Mac/` and extended; see
`Mac/UPSTREAM.txt` and `docs/COUCOU_REUSE_MAP.md`), by Louis Raillé. Coucou's source code is
licensed under the MIT License, reproduced here as its terms require (also in the app as
`LICENSE-COUCOU-MIT.txt`):

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

## Coucou's name, character and artwork (not MIT)

Coucou's `LICENSE-ASSETS.md` (© 2026 Louis Raillé, all rights reserved except as stated there)
covers the names “Coucou” and “Mochi”, the Mochi character (design, look, expressions and
animations as a character), the app and menu-bar icons and the sounds. At the founder's explicit
decision (2026-10-16), this **private, personal build** for the founder's own Mac includes the
original Mochi character (drawn by Coucou's code), app icon, menu-bar icon and sounds. They are kept
in `Mac/CoucouAssets/` with their licence and notice. This build must not be published, shared,
sold or distributed; to distribute Lupy, replace them or obtain written permission from the author
(raillelouis@gmail.com). The product's own name is Lupy, and it does not claim to be Coucou or to be
endorsed by its author.

## FluidAudio (Apache-2.0)

FluidAudio 0.17.7 (https://github.com/FluidInference/FluidAudio), Apache License 2.0, used by
Coucou Flow's optional on-device Parakeet dictation and the Notetaker's speaker separation. Its
speech models are downloaded only when the user clicks Download; none ship in the app. The Apache
License 2.0 text is at https://www.apache.org/licenses/LICENSE-2.0.

## Development-only tools (not shipped in the app)

- `@live-codes/swift-wasm` 0.1.0 (MIT, © 2026 Hatem Hosny) — vendors the Swift 6.3.3 compiler
  cross-compiled to WebAssembly (Swift: Apache-2.0 with Runtime Library Exception; LLVM: Apache-2.0
  with LLVM Exceptions; wasi-libc: Apache-2.0/MIT). Used only to compile and test LupyCore inside
  Linux sandboxes. Installed via npm into `tools/swiftwasm/node_modules`, never committed.
- `@bjorn3/browser_wasi_shim` 0.4.2 (MIT OR Apache-2.0) — WASI implementation used by the dev tool.
- XcodeGen (MIT) — used on the macOS build machine to generate the Xcode project. Not shipped.

Runtime dependencies shipped in the app: Coucou's code (MIT, above), FluidAudio (Apache-2.0, below) and Apple system frameworks.
