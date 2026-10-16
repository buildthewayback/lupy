#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-display.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/IslandDisplayChoice.swift \
    Mac/Tests/coucou/IslandDisplayChoiceTests.swift -o "$TEST_DIR/display-tests"
"$TEST_DIR/display-tests"
