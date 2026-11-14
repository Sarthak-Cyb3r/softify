#!/usr/bin/env bash
# tools/make_report.sh - collects objective facts for REPORT.md
set -u
export JAVA_HOME="${JAVA_HOME:-$HOME/.local/jdk-17}"
export PATH="$JAVA_HOME/bin:$HOME/.cargo/bin:$PATH"
OUT=docs/agent/FACTS.md
mkdir -p docs/agent
{
  echo "# Facts $(date -Iseconds)"
  echo "## Git"
  git log --oneline -n 10
  git status --short

  echo "## Diff stat"
  git diff --stat HEAD~1 2>/dev/null

  echo "## Rust tests list"
  (cd rust/softify_core && cargo test --lib -- --list)

  echo "## Rust tests summary"
  (cd rust/softify_core && cargo test --lib 2>&1 | tail -n 8)

  echo "## Rust clippy"
  (cd rust/softify_core && cargo clippy -- -D warnings 2>&1 | tail -n 6)

  echo "## Desktop tests summary"
  ./gradlew --no-daemon -Dorg.gradle.jvmargs="-Xmx768m" desktopTest 2>&1 | tail -n 10
  if [ -f composeApp/build/test-results/desktopTest/TEST-com.softify.app.UniFfiIntegrationTest.xml ]; then
    grep -E "testsuite|testcase" composeApp/build/test-results/desktopTest/TEST-com.softify.app.UniFfiIntegrationTest.xml
  fi

  echo "## Gradle assembleDebug"
  ./gradlew --no-daemon -Dorg.gradle.jvmargs="-Xmx768m" assembleDebug --rerun-tasks 2>&1 | tail -n 10

  echo "## Native libraries in APK"
  unzip -l composeApp/build/outputs/apk/debug/*.apk 2>/dev/null | grep '\.so' || true

  echo "## Quality verifier 30 tracks reference"
  echo "Full output saved at docs/agent/quality_30.txt"
  if [ -f docs/agent/quality_30.txt ]; then
    tail -n 8 docs/agent/quality_30.txt
  fi
} > "$OUT"
echo "wrote $OUT"
