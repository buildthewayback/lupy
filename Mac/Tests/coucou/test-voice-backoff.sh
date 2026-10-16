#!/usr/bin/env bash
set -e
echo "Running WakeWindowBackoff tests…"
swiftc -o /tmp/voice-backoff-tests \
  Mac/Sources/App/Voice/WakeWindowBackoff.swift \
  Mac/Tests/coucou/WakeWindowBackoffTests.swift
/tmp/voice-backoff-tests
