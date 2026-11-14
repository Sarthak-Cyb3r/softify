#!/usr/bin/env bash
# tools/build_android_libs.sh - builds Android native libraries for Softify
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NDK_VERSION="27.2.12479018"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/$NDK_VERSION}"

if [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo "Error: Android NDK not found at $ANDROID_NDK_HOME" >&2
    exit 1
fi

export PATH="$HOME/.cargo/bin:$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

TARGET_DIR="$ROOT_DIR/composeApp/src/androidMain/jniLibs"
mkdir -p "$TARGET_DIR/arm64-v8a"
mkdir -p "$TARGET_DIR/x86_64"

echo "=== Building softify_core release cdylib for arm64-v8a & x86_64 ==="
cd "$ROOT_DIR/rust/softify_core"

if which cargo-ndk >/dev/null 2>&1; then
    cargo ndk -t arm64-v8a -t x86_64 -o "$TARGET_DIR" build --release
else
    echo "cargo-ndk not found in PATH, using clang toolchain wrappers directly"
    CC_aarch64="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang"
    AR_aarch64="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
    CC_x86_64="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android24-clang"
    AR_x86_64="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"

    CC_aarch64_linux_android="$CC_aarch64" AR_aarch64_linux_android="$AR_aarch64" \
    cargo build --target aarch64-linux-android --release

    CC_x86_64_linux_android="$CC_x86_64" AR_x86_64_linux_android="$AR_x86_64" \
    cargo build --target x86_64-linux-android --release

    cp target/aarch64-linux-android/release/libsoftify_core.so "$TARGET_DIR/arm64-v8a/libsoftify_core.so"
    cp target/x86_64-linux-android/release/libsoftify_core.so "$TARGET_DIR/x86_64/libsoftify_core.so"
fi

echo "=== Strip verification ==="
file "$TARGET_DIR/arm64-v8a/libsoftify_core.so"
file "$TARGET_DIR/x86_64/libsoftify_core.so"
ls -lh "$TARGET_DIR/arm64-v8a/libsoftify_core.so" "$TARGET_DIR/x86_64/libsoftify_core.so"
echo "Build complete."
