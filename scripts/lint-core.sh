#!/usr/bin/env bash
# Static checks for LupyCore that the WebAssembly toolchain cannot catch.
#  1. Availability: the WASM stdlib has no OS availability, but the Mac app targets macOS 14.
#     Reject stdlib APIs that need macOS 15+ (Swift 6.0 runtime additions) or newer.
#  2. Purity: LupyCore must not import Foundation/AppKit/SwiftUI (functional core, D-003).
#  3. Secrets: no credential-looking literals in source or tests.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
core_files=$(find LupyCore/Sources LupyCore/Tests -name '*.swift')

banned_api='String\(validating|\bMutex\b|Atomic<|\bUInt128\b|\bInt128\b|\bRangeSet\b|count\(where:|InlineArray|\bSpan<|Task\.immediate|@concurrent|isTriviallyIdentical|import Synchronization'
if grep -nE "$banned_api" $core_files; then
  echo "lint: macOS-15+/newer stdlib API used in LupyCore (target is macOS 14)"; fail=1
fi

source_files=$(find LupyCore/Sources -name '*.swift')
if grep -nE '^\s*(@testable\s+)?import\s+(Foundation|AppKit|SwiftUI|Combine|Security|Darwin|Glibc|WASILibc|Dispatch)\b' $source_files; then
  echo "lint: LupyCore must stay stdlib-only"; fail=1
fi

# Credential-looking literals (test fixtures must use obviously fake values like sk-test-FAKE...).
secret_re='(sk-(proj-)?[A-Za-z0-9]{32,}|sk-ant-[A-Za-z0-9_-]{32,}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[bp]-[0-9A-Za-z-]{20,})'
if grep -rnE "$secret_re" --include='*.swift' --include='*.md' --include='*.yml' --include='*.json' --include='*.sh' . \
     --exclude-dir=node_modules --exclude-dir=.cache --exclude-dir=.git | grep -v 'FAKE'; then
  echo "lint: possible real credential committed"; fail=1
fi

if [ $fail -ne 0 ]; then exit 1; fi
echo "lint-core: OK ($(echo "$core_files" | wc -l | tr -d ' ') files)"
