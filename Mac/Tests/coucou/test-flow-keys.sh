#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-flow-keys.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/FlowKeyLogic.swift Mac/Sources/App/DictationTranscript.swift \
    Mac/Tests/coucou/FlowKeyLogicTests.swift -o "$TEST_DIR/flow-keys-tests"
"$TEST_DIR/flow-keys-tests"
