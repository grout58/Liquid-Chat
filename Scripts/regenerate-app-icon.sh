#!/bin/bash
#
# Regenerates every AppIcon PNG from Scripts/make-app-icon.swift.
#
# Usage: Scripts/regenerate-app-icon.sh [azure|ocean|aurora]
#
# The icon is drawn in code (Core Graphics) rather than stored only as
# flattened PNGs, so the palette or artwork can be changed and re-rendered
# at every size without a design tool.

set -euo pipefail

PALETTE="${1:-azure}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SET="${ROOT}/Liquid Chat/Assets.xcassets/AppIcon.appiconset"
BIN="$(mktemp -d)/makeicon"

xcrun swiftc -O "${ROOT}/Scripts/make-app-icon.swift" -o "${BIN}"

"${BIN}" "${PALETTE}" "${SET}" \
    "16:Liquid Chat-macOS-Default-16x16@1x.png" \
    "32:Liquid Chat-macOS-Default-16x16@2x.png" \
    "32:Liquid Chat-macOS-Default-32x32@1x.png" \
    "64:Liquid Chat-macOS-Default-32x32@2x.png" \
    "128:Liquid Chat-macOS-Default-128x128@1x.png" \
    "256:Liquid Chat-macOS-Default-128x128@2x.png" \
    "256:Liquid Chat-macOS-Default-256x256@1x.png" \
    "512:Liquid Chat-macOS-Default-512x512@1x 1.png" \
    "512:Liquid Chat-macOS-Default-512x512@1x.png" \
    "1024:Liquid Chat-macOS-Default-1024x1024@1x.png"

echo "Regenerated AppIcon (${PALETTE})"
