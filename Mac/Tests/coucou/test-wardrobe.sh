#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-wardrobe.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/CoucouKit/MochiWardrobe.swift \
    Mac/Tests/coucou/MochiWardrobeTests.swift -o "$TEST_DIR/wardrobe-tests"
"$TEST_DIR/wardrobe-tests"
