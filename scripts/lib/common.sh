#!/usr/bin/env bash
# Common helpers shared by all libghostty-android build scripts.
#
# Sourced by: build.sh, smoke_test.sh, package.sh
# Not executable on its own.

# Run safely under set -euo pipefail (callers set this).

# --- Configuration -----------------------------------------------------------

# Android API level for every build (min supported by NDK r30 is 21; we use 24
# as requested).
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-24}"

# Android NDK version pin.
ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-r30}"

# Zig version pin (must match Ghostty's build.zig.zon minimum_zig_version).
ZIG_VERSION="${ZIG_VERSION:-0.16.0}"

# Directory layout (relative to the repo root).
GHOSTTY_SRC_DIR="${GHOSTTY_SRC_DIR:-ghostty-src}"
OUT_DIR="${OUT_DIR:-out}"
STAGING_DIR="${STAGING_DIR:-staging}"

# Resolve the repo root: prefer an externally-supplied REPO_ROOT, otherwise
# derive it from this script's location (scripts/lib/common.sh -> repo root is
# two levels up).
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# --- Arch mapping ------------------------------------------------------------

# Map an Android ABI name to the Zig target triple (without the API-level
# suffix; callers append ".${ANDROID_API_LEVEL}").
arch_to_zig_target() {
  local arch="$1"
  case "$arch" in
    arm64-v8a)    echo "aarch64-linux-android" ;;
    armeabi-v7a)  echo "arm-linux-androideabi" ;;
    x86_64)       echo "x86_64-linux-android" ;;
    *) echo "ERROR: Unknown Android ABI: $arch" >&2; exit 1 ;;
  esac
}

# Map an Android ABI name to the ELF machine string that readelf reports.
arch_to_elf_machine() {
  local arch="$1"
  case "$arch" in
    arm64-v8a)    echo "AArch64" ;;
    armeabi-v7a)  echo "ARM" ;;
    x86_64)       echo "Advanced Micro Devices X86-64" ;;
    *) echo "ERROR: Unknown Android ABI: $arch" >&2; exit 1 ;;
  esac
}

# Map an Android ABI name to the NDK LLVM triple (used for llvm-strip etc.).
arch_to_ndk_triple() {
  local arch="$1"
  case "$arch" in
    arm64-v8a)    echo "aarch64-linux-android" ;;
    armeabi-v7a)  echo "arm-linux-androideabi" ;;
    x86_64)       echo "x86_64-linux-android" ;;
    *) echo "ERROR: Unknown Android ABI: $arch" >&2; exit 1 ;;
  esac
}

# Validate an Android ABI name.
validate_arch() {
  local arch="$1"
  case "$arch" in
    arm64-v8a|armeabi-v7a|x86_64) return 0 ;;
    *) echo "ERROR: Unknown Android ABI: $arch (expected arm64-v8a, armeabi-v7a, or x86_64)" >&2; exit 1 ;;
  esac
}

# --- Logging helpers ---------------------------------------------------------

info()  { printf ':: \033[1;34mINFO\033[0m  %s\n' "$*" >&2; }
ok()    { printf ':: \033[1;32mOK\033[0m    %s\n' "$*" >&2; }
warn()  { printf ':: \033[1;33mWARN\033[0m  %s\n' "$*" >&2; }
die()   { printf ':: \033[1;31mERROR\033[0m %s\n' "$*" >&2; exit 1; }
