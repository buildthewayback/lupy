#!/usr/bin/env bash
set -e
echo "Running EntityResolver tests…"
swiftc -o /tmp/voice-entity-tests \
  Mac/Tests/coucou/VoiceTestStubs.swift \
  Mac/Tests/coucou/PillFixture.swift \
  Mac/Sources/App/Voice/VoiceIntent.swift \
  Mac/Sources/App/Voice/IntentParser.swift \
  Mac/Sources/App/Voice/VoiceQuery.swift \
  Mac/Sources/App/Voice/EntityResolver.swift \
  Mac/Tests/coucou/EntityResolverTests.swift
/tmp/voice-entity-tests
