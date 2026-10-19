#!/usr/bin/env node
// Minimal swiftc replacement for this sandbox: runs the Swift 6.3.3 compiler that
// was cross-compiled to WebAssembly (npm @live-codes/swift-wasm, Apache-2.0 toolchain)
// under Node's WASI, then links with wasm-ld.wasm and optionally runs the program.
//
// Usage: node swiftc-wasm.mjs [-D FLAG]... [--run] [--out file.wasm] [--wmo] file1.swift file2.swift ...
//
// Notes:
// - Toolchain: stdlib + Concurrency + StringProcessing only (NO Foundation, no macros).
// - This is a development/test aid only. The shipped app is compiled by Xcode on macOS.
import { WASI } from 'node:wasi';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { WASI as ShimWASI, File, Directory, PreopenDirectory, OpenFile, ConsoleStdout, WASIProcExit } from '@bjorn3/browser_wasi_shim';

import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';

const here = path.dirname(fileURLToPath(import.meta.url));
const TC = process.env.SWIFTWASM_TC || path.join(here, '.cache', 'tc');
const SYSROOT = path.join(TC, 'sysroot');

// First run: inflate the npm-vendored toolchain into .cache/tc (ignored by git).
function ensureToolchain() {
  const marker = path.join(TC, '.ready');
  if (fs.existsSync(marker)) return;
  const pkg = path.join(here, 'node_modules', '@live-codes', 'swift-wasm', 'toolchain');
  if (!fs.existsSync(pkg)) {
    console.error('swift-wasm toolchain missing: run `npm ci` in tools/swiftwasm first');
    process.exit(2);
  }
  fs.mkdirSync(path.join(TC, 'sysroot'), { recursive: true });
  for (const n of ['swift-frontend.wasm', 'wasm-ld.wasm']) {
    fs.writeFileSync(path.join(TC, n), zlib.gunzipSync(fs.readFileSync(path.join(pkg, n + '.gz'))));
  }
  execFileSync('tar', ['-xzf', path.join(pkg, 'swift-sysroot-core.tar.gz'), '-C', path.join(TC, 'sysroot')]);
  fs.writeFileSync(marker, new Date().toISOString());
}
ensureToolchain();

const argv = process.argv.slice(2);
const defines = [];
const files = [];
let run = false;
let out = null;
let wmo = true;
let runArgs = [];
let typecheckOnly = false;
let parseOnly = false;
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '-D') { defines.push(argv[++i]); continue; }
  if (a === '--run') { run = true; continue; }
  if (a === '--out') { out = argv[++i]; continue; }
  if (a === '--per-file') { wmo = false; continue; }
  if (a === '--typecheck') { typecheckOnly = true; continue; }
  if (a === '--parse') { parseOnly = true; continue; }
  if (a.startsWith('--mode=')) { process.env.SWIFTWASM_MODE = a.slice(7); continue; }
  if (a === '--') { runArgs = argv.slice(i + 1); break; }
  files.push(path.resolve(a));
}
if (files.length === 0) { console.error('no input files'); process.exit(2); }

const build = fs.mkdtempSync(path.join(os.tmpdir(), 'swiftwasm-build-'));
fs.mkdirSync(path.join(build, 'objects'));
fs.mkdirSync(path.join(build, 'module-cache'));
fs.mkdirSync(path.join(build, 'src'));
fs.mkdirSync(path.join(build, 'tmp'));
// Copy sources into the build dir, keeping a mapping for diagnostics.
const mapping = new Map();
const vfiles = files.map((f, idx) => {
  const v = `/build/src/${idx}/${path.basename(f)}`;
  fs.mkdirSync(path.join(build, 'src', String(idx)), { recursive: true });
  fs.copyFileSync(f, path.join(build, 'src', String(idx), path.basename(f)));
  mapping.set(v, path.relative(process.cwd(), f));
  return v;
});

const RES = '/sysroot/swift/lib/swift_static';
const SDK = '/sysroot/wasi-sysroot';
const LIBDIR = `${SDK}/lib/wasm32-wasip1`;

const moduleCache = new Map();
async function loadModule(name) {
  if (!moduleCache.has(name)) {
    const bytes = fs.readFileSync(path.join(TC, name));
    moduleCache.set(name, await WebAssembly.compile(bytes));
  }
  return moduleCache.get(name);
}

async function runTool(wasmName, args, { captureStdout = false } = {}) {
  if (process.env.SWIFTWASM_DEBUG) console.error('[run]', wasmName, args.slice(0, 6).join(' '));
  const mod = await loadModule(wasmName);
  const outFile = path.join(build, `tmp/stdout-${Date.now()}-${Math.random()}`);
  const errFile = outFile + '.err';
  const outFd = fs.openSync(outFile, 'w');
  const errFd = fs.openSync(errFile, 'w');
  const wasi = new WASI({
    version: 'preview1',
    args,
    env: { PWD: '/', HOME: '/', TMPDIR: '/tmp' },
    preopens: { '/sysroot': SYSROOT, '/build': build, '/tmp': path.join(build, 'tmp') },
    stdout: outFd,
    stderr: errFd,
    returnOnExit: true,
  });
  const instance = await WebAssembly.instantiate(mod, wasi.getImportObject());
  let code;
  try { code = wasi.start(instance); } catch (e) { code = 99; fs.writeSync(errFd, String(e && e.stack || e)); }
  fs.closeSync(outFd); fs.closeSync(errFd);
  let stdout = fs.readFileSync(outFile, 'utf8');
  let stderr = fs.readFileSync(errFile, 'utf8');
  for (const [v, real] of mapping) { stderr = stderr.split(v).join(real); stdout = stdout.split(v).join(real); }
  return { code, stdout, stderr };
}



// browser_wasi_shim grows a file by exactly the bytes written on every fd_write, which is
// quadratic for multi-megabyte compiler outputs (objects, IR). Use amortized doubling instead.
function makeGrowable(f) {
  if (f._growable) return;
  const initial = f.data;
  f._growable = true;
  f._buf = initial;
  f._len = initial.byteLength;
  Object.defineProperty(f, 'data', {
    get() { return this._buf.subarray(0, this._len); },
    set(v) { this._buf = v; this._len = v.byteLength; },
    configurable: true,
  });
}
function growableWrite(f, data, pos) {
  makeGrowable(f);
  const end = pos + data.byteLength;
  if (end > f._buf.byteLength) {
    const cap = Math.max(end, f._buf.byteLength * 2, 1 << 16);
    const nb = new Uint8Array(cap);
    nb.set(f._buf.subarray(0, f._len));
    f._buf = nb;
  }
  f._buf.set(data, pos);
  if (end > f._len) f._len = end;
}
OpenFile.prototype.fd_write = function (data) {
  if (this.file.readonly) return { ret: 8, nwritten: 0 };
  growableWrite(this.file, data, Number(this.file_pos));
  this.file_pos += BigInt(data.byteLength);
  return { ret: 0, nwritten: data.byteLength };
};
OpenFile.prototype.fd_pwrite = function (data, offset) {
  if (this.file.readonly) return { ret: 8, nwritten: 0 };
  growableWrite(this.file, data, Number(offset));
  return { ret: 0, nwritten: data.byteLength };
};

// Build an in-memory Directory from a host directory (optionally filtered).
function hostDir(p, filter = () => true) {
  const m = new Map();
  for (const ent of fs.readdirSync(p, { withFileTypes: true })) {
    const full = path.join(p, ent.name);
    if (ent.isDirectory()) m.set(ent.name, hostDir(full, filter));
    else if (ent.isFile() && filter(full)) m.set(ent.name, new File(fs.readFileSync(full), { readonly: true }));
  }
  return new Directory(m);
}
// Lazily-loaded host file: bytes are read on first access (the sysroot has ~30k files).
class LazyFile extends File {
  constructor(hostPath) {
    super(new Uint8Array(0), { readonly: true });
    this._host = hostPath;
    this._bytes = null;
  }
  get data() {
    if (this._bytes === null && this._host !== undefined) this._bytes = new Uint8Array(fs.readFileSync(this._host));
    return this._bytes ?? new Uint8Array(0);
  }
  set data(v) { if (this._host === undefined) return; this._bytes = v; }
}
function lazyHostDir(p) {
  const m = new Map();
  for (const ent of fs.readdirSync(p, { withFileTypes: true })) {
    const full = path.join(p, ent.name);
    if (ent.isDirectory()) m.set(ent.name, lazyHostDir(full));
    else if (ent.isFile()) m.set(ent.name, new LazyFile(full));
    else if (ent.isSymbolicLink()) {
      const st = fs.statSync(full);
      if (st.isDirectory()) m.set(ent.name, lazyHostDir(full)); else m.set(ent.name, new LazyFile(full));
    }
  }
  return new Directory(m);
}
let fullSysroot = null;
function sysrootTree() { if (!fullSysroot) fullSysroot = lazyHostDir(SYSROOT).contents; return fullSysroot; }
let sysrootLinkTree = null;
function linkSysroot() {
  if (!sysrootLinkTree) {
    const want = (f) => /\.(a|o)$/.test(f);
    sysrootLinkTree = new Map([
      ['swift', new Directory(new Map([['lib', new Directory(new Map([['swift_static', hostDir(path.join(SYSROOT, 'swift/lib/swift_static'), want)]]))]]))],
      ['wasi-sysroot', new Directory(new Map([['lib', hostDir(path.join(SYSROOT, 'wasi-sysroot/lib'), want)]]))],
    ]);
  }
  return sysrootLinkTree;
}
async function runShimCompile(args, objectOut) {
  if (process.env.SWIFTWASM_DEBUG) console.error('[shim-compile]', args.slice(0, 6).join(' '));
  const mod = await loadModule('swift-frontend.wasm');
  const srcTree = lazyHostDir(path.join(build, 'src')).contents;
  const objects = new Map();
  const buildDir = new Map([['src', new Directory(srcTree)], ['objects', new Directory(objects)], ['module-cache', new Directory(new Map())]]);
  let stdout = '', stderr = '';
  const fds = [
    new OpenFile(new File([])),
    ConsoleStdout.lineBuffered((l) => { stdout += l + '\n'; }),
    ConsoleStdout.lineBuffered((l) => { stderr += l + '\n'; }),
    new PreopenDirectory('/sysroot', sysrootTree()),
    new PreopenDirectory('/build', buildDir),
    new PreopenDirectory('/tmp', new Map()),
  ];
  const wasi = new ShimWASI(args, ['PWD=/', 'HOME=/', 'TMPDIR=/tmp'], fds, { debug: false });
  const inst = await WebAssembly.instantiate(mod, { wasi_snapshot_preview1: wasi.wasiImport });
  let code = 0;
  try { code = wasi.start(inst); } catch (e) { if (e instanceof WASIProcExit) code = e.code; else { code = 98; stderr += String(e && e.stack || e); } }
  const name = path.basename(objectOut);
  const o = objects.get(name);
  if (o) fs.writeFileSync(path.join(build, 'objects', name), o.data);
  for (const [v, real] of mapping) { stderr = stderr.split(v).join(real); }
  return { code, stdout, stderr };
}

async function runShim(wasmName, args, objectFiles, outName) {
  if (process.env.SWIFTWASM_DEBUG) console.error('[shim]', wasmName, args.slice(0, 4).join(' '));
  const mod = await loadModule(wasmName);
  const objs = new Map(objectFiles.map(o => [path.basename(o), new File(fs.readFileSync(path.join(build, 'objects', path.basename(o))))]));
  const buildDir = new Map([['objects', new Directory(objs)]]);
  let stdout = '', stderr = '';
  const fds = [
    new OpenFile(new File([])),
    ConsoleStdout.lineBuffered((l) => { stdout += l + '\n'; }),
    ConsoleStdout.lineBuffered((l) => { stderr += l + '\n'; }),
    new PreopenDirectory('/sysroot', linkSysroot()),
    new PreopenDirectory('/build', buildDir),
    new PreopenDirectory('/tmp', new Map()),
  ];
  const wasi = new ShimWASI(args, ['PWD=/', 'HOME=/', 'TMPDIR=/tmp'], fds, { debug: false });
  const inst = await WebAssembly.instantiate(mod, { wasi_snapshot_preview1: wasi.wasiImport });
  let code = 0;
  try { code = wasi.start(inst); } catch (e) { if (e instanceof WASIProcExit) code = e.code; else { code = 98; stderr += String(e && e.stack || e); } }
  const outEntry = buildDir.get(outName);
  if (outEntry) fs.writeFileSync(path.join(build, outName), outEntry.data);
  return { code, stdout, stderr };
}

const common = [
  '-target', 'wasm32-unknown-wasip1', '-disable-objc-interop',
  '-sdk', SDK, '-resource-dir', RES, '-use-static-resource-dir',
  '-module-cache-path', '/build/module-cache', '-no-color-diagnostics',
  '-empty-abi-descriptor', '-module-name', 'main', '-swift-version', '6',
  ...defines.flatMap(d => ['-D', d]),
  ...(process.env.SWIFTWASM_EXTRA ? process.env.SWIFTWASM_EXTRA.split(' ').filter(Boolean) : []),
];

const t0 = Date.now();
const objects = [];
if (parseOnly) {
  const cargs = ['swift-frontend', '-frontend', '-parse', ...vfiles, ...common];
  const r = await runShimCompile(cargs, '/build/objects/none.o');
  if (r.stderr.trim()) process.stderr.write(r.stderr);
  console.error(`[swiftc-wasm] parse ${Date.now() - t0} ms -> ${r.code === 0 ? 'OK' : 'FAILED'}`);
  process.exit(r.code);
}
if (typecheckOnly) {
  const cargs = ['swift-frontend', '-frontend', '-typecheck', ...vfiles, ...common];
  const r = await runShimCompile(cargs, '/build/objects/none.o');
  if (r.stderr.trim()) process.stderr.write(r.stderr);
  console.error(`[swiftc-wasm] typecheck ${Date.now() - t0} ms -> ${r.code === 0 ? 'OK' : 'FAILED'}`);
  fs.rmSync(build, { recursive: true, force: true });
  process.exit(r.code === 0 ? 0 : 1);
}
if (wmo) {
  const o = '/build/objects/all.o';
  const mode = process.env.SWIFTWASM_MODE || '-c';
  const cargs = ['swift-frontend', '-frontend', mode, ...vfiles, ...common, '-o', o];
  if (mode !== '-c') {
    const r0 = await runShimCompile(cargs, o);
    if (r0.stderr.trim()) process.stderr.write(r0.stderr.slice(0, 2000));
    console.error(`[swiftc-wasm] ${mode} ${Date.now() - t0} ms exit=${r0.code}`);
    process.exit(r0.code);
  }
  const r = process.env.SWIFTWASM_NODE_WASI ? await runTool('swift-frontend.wasm', cargs) : await runShimCompile(cargs, o);
  if (r.stderr.trim()) process.stderr.write(r.stderr);
  if (r.code !== 0) { console.error(`compile failed (exit ${r.code})`); process.exit(1); }
  objects.push(o);
} else {
  for (let i = 0; i < vfiles.length; i++) {
    const o = `/build/objects/${i}.o`;
    const others = vfiles.filter((_, j) => j !== i);
    const cargs = ['swift-frontend', '-frontend', '-c', '-primary-file', vfiles[i], ...others, ...common, '-o', o];
    const r = process.env.SWIFTWASM_NODE_WASI ? await runTool('swift-frontend.wasm', cargs) : await runShimCompile(cargs, o);
    if (r.stderr.trim()) process.stderr.write(r.stderr);
    if (r.code !== 0) { console.error(`compile failed (exit ${r.code})`); process.exit(1); }
    objects.push(o);
  }
}
const t1 = Date.now();
const linkArgs = [
  'wasm-ld', '-m', 'wasm32', `-L${RES}/wasi`, `-L${LIBDIR}`,
  `${LIBDIR}/crt1-command.o`, `${RES}/wasi/wasm32/swiftrt.o`, ...objects,
  '-lswiftSwiftOnoneSupport', '-lswiftCore', '-lswift_Concurrency', '-lswift_StringProcessing',
  '-lswift_RegexParser', '-ldl', '-lc++', '-lc++abi', '-lm', '-lwasi-emulated-mman',
  '-lwasi-emulated-signal', '-lwasi-emulated-process-clocks',
  '--error-limit=0', '--threads=1', '--global-base=4096', '--table-base=4096',
  '-z', 'stack-size=1048576', '-lc', `${RES}/clang/lib/wasip1/libclang_rt.builtins-wasm32.a`,
  '-o', '/build/program.wasm',
];
const l = await runShim('wasm-ld.wasm', linkArgs, objects, 'program.wasm');
if (l.stderr.trim()) process.stderr.write(l.stderr);
if (l.code !== 0) { console.error(`link failed (exit ${l.code})`); process.exit(1); }
const t2 = Date.now();
const programPath = path.join(build, 'program.wasm');
if (out) fs.copyFileSync(programPath, path.resolve(out));
console.error(`[swiftc-wasm] compile ${t1 - t0} ms, link ${t2 - t1} ms`);

if (run) {
  const mod = await WebAssembly.compile(fs.readFileSync(programPath));
  const fds = [
    new OpenFile(new File([])),
    ConsoleStdout.lineBuffered((l) => { process.stdout.write(l + '\n'); }),
    ConsoleStdout.lineBuffered((l) => { process.stderr.write(l + '\n'); }),
    new PreopenDirectory('/tmp', new Map()),
  ];
  const wasi = new ShimWASI(['program', ...runArgs], ['HOME=/'], fds, { debug: false });
  const inst = await WebAssembly.instantiate(mod, { wasi_snapshot_preview1: wasi.wasiImport });
  let code = 0;
  try { code = wasi.start(inst); } catch (e) { if (e instanceof WASIProcExit) code = e.code; else { console.error(String(e && e.stack || e)); code = 97; } }
  fs.rmSync(build, { recursive: true, force: true });
  process.exit(code);
}
fs.rmSync(build, { recursive: true, force: true });
