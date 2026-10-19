#!/usr/bin/env bash
# THE BETA GATE — the founder's pre-beta checklist, executable:
# beta council (29 static checks) + ten-million beta stress (26.7M measurements).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/ui/audit_beta.py | tail -1
node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run tools/ui/stress_beta.swift | tail -2
