#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Build test bundles outside synced folders, which may inject Finder metadata
# after compilation and invalidate Xcode's test-bundle signing step.
TEST_BUILD="$(mktemp -d "${TMPDIR:-/tmp}/decrypt-store-tests.XXXXXX")"
python3 -m unittest discover -s "$ROOT_DIR/tests" -v
swift test --package-path "$ROOT_DIR/macos" --scratch-path "$TEST_BUILD"
