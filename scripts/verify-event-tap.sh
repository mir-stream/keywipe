#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p .build
swiftc Sources/KeyWipeCore/*.swift scripts/EventTapProbe.swift -o .build/EventTapProbe
.build/EventTapProbe
