#!/usr/bin/env bash
set -e
echo "Running VoiceGenderNames tests…"
swiftc -o /tmp/voice-gender-tests \
  Mac/Sources/App/Voice/VoiceGenderNames.swift \
  Mac/Tests/coucou/VoiceGenderTests.swift
/tmp/voice-gender-tests
