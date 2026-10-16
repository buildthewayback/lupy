#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-claude-host.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/ClaudeHost.swift \
    Mac/Tests/coucou/ClaudeHostTests.swift -o "$TEST_DIR/claude-host-tests"
"$TEST_DIR/claude-host-tests"
