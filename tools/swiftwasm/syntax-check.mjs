// Syntax check for Swift files that cannot be compiled in the sandbox (the macOS app shell).
// Uses swift-format (SwiftSyntax) compiled to WebAssembly. Catches parse errors only — not type errors.
import { format, init } from '@scalar/swift-fmt';
import fs from 'node:fs';
await init();
let bad = 0;
for (const f of process.argv.slice(2)) {
  const src = fs.readFileSync(f, 'utf8');
  try {
    await format(src, { lineLength: 200 });
    console.log(`ok    ${f}`);
  } catch (e) {
    bad++;
    console.log(`ERROR ${f}: ${String(e && e.message || e).slice(0, 2000)}`);
  }
}
process.exit(bad ? 1 : 0);
