#!/usr/bin/env bash
# Lightweight ABI/ELF smoke test for a built libghostty-vt.so.
#
# Usage:
#   ./scripts/smoke_test.sh <arch>
#
# This is the FIRST validation pass after building. It runs `file` and
# `readelf` to verify:
#   1. The output is an ELF shared object (Type: DYN)
#   2. The ELF machine matches the requested Android ABI
#   3. The file is not suspiciously small (would indicate a broken build)
#
# It is intentionally fast so obviously incorrect binaries are caught before
# the more expensive packaging step runs.
#
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ARCH="${1:-}"
validate_arch "$ARCH" || die "Usage: smoke_test.sh <arch>"

EXPECTED_MACHINE="$(arch_to_elf_machine "$ARCH")"
SO_PATH="$REPO_ROOT/$OUT_DIR/$ARCH/lib/libghostty-vt.so"

[ -f "$SO_PATH" ] || die "Shared library not found: $SO_PATH (did build.sh run?)"

info "Smoke test: $ARCH"
info "  File: $SO_PATH"

# --- Check 1: `file` output --------------------------------------------------
# Should report "ELF ... LSB shared object" for a valid Android .so.
info "  [1/3] file(1) output:"
FILE_OUT="$(file "$SO_PATH")"
printf '       %s\n' "$FILE_OUT" >&2

case "$FILE_OUT" in
  *ELF*) ;;
  *) die "file(1) did not report ELF: not a valid shared library" ;;
esac
case "$FILE_OUT" in
  *"shared object"*) ;;
  *) die "file(1) did not report 'shared object'" ;;
esac

# --- Check 2: readelf ELF header ---------------------------------------------
info "  [2/3] readelf -h (Type + Machine):"
READELF_OUT="$(readelf -h "$SO_PATH")"
printf '%s\n' "$READELF_OUT" | sed 's/^/       /' >&2

# Type must be DYN (shared object).
TYPE="$(printf '%s\n' "$READELF_OUT" | sed -n 's/^  Type: *\([^ ]*\).*/\1/p' | head -1)"
[ -n "$TYPE" ] || die "Could not parse ELF Type from readelf output"
if [ "$TYPE" != "DYN" ]; then
  die "ELF Type is '$TYPE', expected 'DYN' (shared object)"
fi

# Machine must match the requested Android ABI.
MACHINE="$(printf '%s\n' "$READELF_OUT" | sed -n 's/^  Machine: *\(.*\)$/\1/p' | head -1)"
[ -n "$MACHINE" ] || die "Could not parse ELF Machine from readelf output"
if [ "$MACHINE" != "$EXPECTED_MACHINE" ]; then
  die "ELF Machine is '$MACHINE', expected '$EXPECTED_MACHINE' for $ARCH"
fi

# --- Check 3: minimum size sanity -------------------------------------------
SO_SIZE=$(stat -c%s "$SO_PATH" 2>/dev/null || stat -f%z "$SO_PATH")
MIN_SIZE=100000   # 100 KB; libghostty-vt.so is ~1 MB in ReleaseFast
if [ "$SO_SIZE" -lt "$MIN_SIZE" ]; then
  die "Shared library is only ${SO_SIZE} bytes (< ${MIN_SIZE}); suspiciously small"
fi

ok "Smoke test passed: $ARCH (type=$TYPE, machine=$MACHINE, size=${SO_SIZE}B)"
