#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-notetaker.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Mac/Sources/App/NoteModels.swift Mac/Tests/coucou/NoteModelsTests.swift -o "$TEST_DIR/notetaker-tests"
"$TEST_DIR/notetaker-tests"
