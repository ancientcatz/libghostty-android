#!/usr/bin/env bash
# Build libghostty-vt.so for one Android ABI.
#
# Usage:
#   ./scripts/build.sh <arch>
#
# Arguments:
#   arch   Android ABI: arm64-v8a | armeabi-v7a | x86_64
#
# Prerequisites (set up by the GitHub Actions workflow):
#   - Zig on PATH (version must satisfy Ghostty's build.zig.zon)
#   - ANDROID_NDK_HOME pointing at an extracted NDK r30
#   - Ghostty source checked out at $GHOSTTY_SRC_DIR (default: ghostty-src)
#
# Output:
#   $OUT_DIR/<arch>/lib/libghostty-vt.so
#
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ARCH="${1:-}"
validate_arch "$ARCH" || die "Usage: build.sh <arch>"

ZIG_TARGET="$(arch_to_zig_target "$ARCH")"
NDK_TRIPLE="$(arch_to_ndk_triple "$ARCH")"
PREFIX="$REPO_ROOT/$OUT_DIR/$ARCH"

# Verify prerequisites.
command -v zig >/dev/null 2>&1 || die "zig not found on PATH"
[ -n "${ANDROID_NDK_HOME:-}" ] || die "ANDROID_NDK_HOME is not set"
[ -d "${ANDROID_NDK_HOME}" ] || die "ANDROID_NDK_HOME does not exist: $ANDROID_NDK_HOME"
[ -d "$REPO_ROOT/$GHOSTTY_SRC_DIR" ] || die "Ghostty source not found at $REPO_ROOT/$GHOSTTY_SRC_DIR"

SO_PATH="$PREFIX/lib/libghostty-vt.so"

info "Building libghostty-vt for $ARCH"
info "  Zig target : $ZIG_TARGET.$ANDROID_API_LEVEL"
info "  NDK        : $ANDROID_NDK_HOME ($ANDROID_NDK_VERSION)"
info "  Ghostty src: $REPO_ROOT/$GHOSTTY_SRC_DIR"
info "  Output     : $SO_PATH"

cd "$REPO_ROOT/$GHOSTTY_SRC_DIR"

# Detect whether this Ghostty version uses the new -Demit-lib-vt flag (main
# branch) or the older "lib-vt" build step (all stable releases up to and
# including v1.3.1). We probe Config.zig for the option declaration.
if grep -q '"emit-lib-vt"' src/build/Config.zig 2>/dev/null; then
  BUILD_TARGET=(-Demit-lib-vt)
else
  BUILD_TARGET=(lib-vt)
fi

# Run the Zig build. Ghostty's pkg/android-ndk auto-discovers the NDK via
# ANDROID_NDK_HOME and generates the libc.txt, so no --libc flag is needed.
zig build \
  "${BUILD_TARGET[@]}" \
  -Dtarget="${ZIG_TARGET}.${ANDROID_API_LEVEL}" \
  -Doptimize=ReleaseFast \
  -Dcpu=baseline \
  -Dstrip=true \
  --prefix "$PREFIX"

cd "$REPO_ROOT"

# Verify the shared library was produced.
[ -f "$SO_PATH" ] || die "Build completed but $SO_PATH was not produced"

# Extra strip pass with the NDK's llvm-strip to guarantee no debug sections
# remain (Zig's -Dstrip=true should already handle this, but this is a cheap
# safety net and keeps the .so size consistent with other platforms).
NDK_HOST_TAG="linux-x86_64"
LLVM_STRIP="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_TAG/bin/llvm-strip"
if [ -x "$LLVM_STRIP" ]; then
  info "Stripping $SO_PATH with NDK llvm-strip"
  "$LLVM_STRIP" --strip-all "$SO_PATH" || warn "llvm-strip returned non-zero (continuing)"
fi

SO_SIZE=$(stat -c%s "$SO_PATH" 2>/dev/null || stat -f%z "$SO_PATH")
ok "Built $SO_PATH (${SO_SIZE} bytes)"
