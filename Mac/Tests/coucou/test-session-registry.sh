#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-session-registry.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/PillSessionRegistry.swift \
    Mac/Tests/coucou/PillSessionRegistryTests.swift -o "$TEST_DIR/session-registry-tests"
"$TEST_DIR/session-registry-tests"
