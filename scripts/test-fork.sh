#!/bin/bash
# Compile production services against minimal domain doubles. No audio, keys,
# model downloads, persistent preferences, or SwiftData macro plugin required.
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/parrot-tests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
python3 - "$TEST_DIR" <<'PY'
from pathlib import Path
import sys
text=Path('Parrot/Services/AnalysisProvider.swift').read_text()
Path(sys.argv[1], 'AnalysisTypes.swift').write_text(text.split('/// Backend that turns')[0])
PY
CACHE_DIR="${SWIFT_MODULECACHE_PATH:-$PWD/.build/fork-module-cache}"
swiftc -module-cache-path "$CACHE_DIR" -parse-as-library \
  Parrot/Services/CallAnalysisEngine.swift "$TEST_DIR/AnalysisTypes.swift" \
  scripts/tests/SchedulerProbe.swift -o "$TEST_DIR/scheduler"
"$TEST_DIR/scheduler"
swiftc -module-cache-path "$CACHE_DIR" -parse-as-library \
  Parrot/Services/KnowledgeBaseService.swift Parrot/Models/KnowledgeBase.swift \
  scripts/tests/KnowledgeProbe.swift -o "$TEST_DIR/knowledge"
"$TEST_DIR/knowledge" "$TEST_DIR/account.txt"
