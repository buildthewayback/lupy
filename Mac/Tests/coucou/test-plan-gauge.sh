#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-plan-gauge.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/ClaudePlanGauge.swift \
    Mac/Tests/coucou/ClaudePlanGaugeTests.swift -o "$TEST_DIR/plan-gauge-tests"
"$TEST_DIR/plan-gauge-tests"
