#!/usr/bin/env bash
# tools/make_report.sh - collects objective facts for REPORT.md
set -u
export JAVA_HOME="${JAVA_HOME:-$HOME/.local/jdk-17}"
export PATH="$JAVA_HOME/bin:$HOME/.cargo/bin:$PATH"
OUT=docs/agent/FACTS.md
mkdir -p docs/agent
{
  echo "# Facts $(date -Iseconds)"
  echo "## Git"; git log --oneline -n 10; git status --short
  echo "## Diff stat"; git diff --stat HEAD~1 2>/dev/null
  echo "## Rust tests"; (cd rust/softify_core && cargo test --lib 2>&1 | tail -n 15)
  echo "## Rust clippy"; (cd rust/softify_core && cargo clippy 2>&1 | tail -n 5)
  echo "## Gradle build"; ./gradlew assembleDebug 2>&1 | tail -n 8
} > "$OUT"
echo "wrote $OUT"
