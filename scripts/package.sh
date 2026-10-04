#!/usr/bin/env bash
# Package a built libghostty-vt.so into release assets.
#
# Usage:
#   ./scripts/package.sh <arch> <ghostty_commit>
#
# Produces (in $STAGING_DIR/<arch>/):
#   libghostty-vt-<arch>.so         renamed copy of the built .so
#   libghostty-vt-<arch>.tar.gz     reproducible archive containing
#                                   a single file named `libghostty-vt.so`
#   libghostty-vt-<arch>.sha256     SHA-256 checksums for the two files above
#   ghostty-commit-<arch>.txt       exact Ghostty commit SHA used for this build
#   include-ghostty-<arch>.tar.gz   reproducible archive of the C headers
#                                   under include/ghostty/ (arch-independent;
#                                   the release job picks one copy and
#                                   publishes it as libghostty-vt-headers.tar.gz)
#
# Reproducibility:
#   The tar archive uses SOURCE_DATE_EPOCH (the Ghostty commit's committer
#   timestamp, in seconds since the epoch) for deterministic mtimes, and
#   normalised owner/group/numeric ownership so two builds from the same
#   Ghostty commit produce byte-identical archives.
#
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ARCH="${1:-}"
GHOSTTY_COMMIT="${2:-}"
validate_arch "$ARCH" || die "Usage: package.sh <arch> <ghostty_commit>"
[ -n "$GHOSTTY_COMMIT" ] || die "Usage: package.sh <arch> <ghostty_commit>"

SO_PATH="$REPO_ROOT/$OUT_DIR/$ARCH/lib/libghostty-vt.so"
STAGING="$REPO_ROOT/$STAGING_DIR/$ARCH"

[ -f "$SO_PATH" ] || die "Shared library not found: $SO_PATH (did build.sh run?)"

mkdir -p "$STAGING"

# --- Resolve SOURCE_DATE_EPOCH ------------------------------------------------
# Prefer an externally-supplied value; otherwise read it from the Ghostty
# checkout's HEAD commit timestamp.
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
  if [ -d "$REPO_ROOT/$GHOSTTY_SRC_DIR/.git" ]; then
    SOURCE_DATE_EPOCH="$(git -C "$REPO_ROOT/$GHOSTTY_SRC_DIR" log -1 --format=%ct)"
  else
    warn "Ghostty source is not a git checkout; using epoch 0 for reproducible mtime"
    SOURCE_DATE_EPOCH=0
  fi
fi
export SOURCE_DATE_EPOCH
info "SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH (for reproducible tar)"

# --- 1. Renamed .so ----------------------------------------------------------
ASSET_SO="$STAGING/libghostty-vt-$ARCH.so"
cp "$SO_PATH" "$ASSET_SO"
info "Created $ASSET_SO"

# --- 2. Reproducible tar.gz containing libghostty-vt.so ----------------------
# Stage a clean directory with the generic filename so the archive extracts
# to `libghostty-vt.so` (no subdirectory, no arch suffix).
TAR_STAGE="$(mktemp -d)"
trap 'rm -rf "$TAR_STAGE"' EXIT
cp "$SO_PATH" "$TAR_STAGE/libghostty-vt.so"

ASSET_TAR="$STAGING/libghostty-vt-$ARCH.tar.gz"
(
  cd "$TAR_STAGE"
  tar \
    --sort=name \
    --mtime="@${SOURCE_DATE_EPOCH}" \
    --owner=0 --group=0 --numeric-owner \
    --format=ustar \
    -czf "$ASSET_TAR" \
    libghostty-vt.so
)
info "Created $ASSET_TAR (reproducible)"

# --- 3. SHA-256 checksums -----------------------------------------------------
ASSET_SHA="$STAGING/libghostty-vt-$ARCH.sha256"
(
  cd "$STAGING"
  sha256sum \
    "libghostty-vt-$ARCH.so" \
    "libghostty-vt-$ARCH.tar.gz" \
    > "libghostty-vt-$ARCH.sha256"
)
info "Created $ASSET_SHA"

# --- 4. C headers archive (arch-independent) --------------------------------
# The headers are installed by the Zig build to <out>/<arch>/include/ghostty/.
# They are arch-independent, so every arch job produces the same archive.
# The release job picks one copy and publishes it as
# libghostty-vt-headers.tar.gz.
HEADERS_SRC="$REPO_ROOT/$OUT_DIR/$ARCH/include/ghostty"
ASSET_HEADERS="$STAGING/include-ghostty-$ARCH.tar.gz"
if [ -d "$HEADERS_SRC" ]; then
  TAR_HEADERS_STAGE="$(mktemp -d)"
  mkdir -p "$TAR_HEADERS_STAGE/include/ghostty"
  cp -r "$HEADERS_SRC"/. "$TAR_HEADERS_STAGE/include/ghostty/"
  (
    cd "$TAR_HEADERS_STAGE"
    tar \
      --sort=name \
      --mtime="@${SOURCE_DATE_EPOCH}" \
      --owner=0 --group=0 --numeric-owner \
      --format=ustar \
      -czf "$ASSET_HEADERS" \
      include
  )
  rm -rf "$TAR_HEADERS_STAGE"
  info "Created $ASSET_HEADERS (reproducible)"
else
  warn "Headers directory not found at $HEADERS_SRC; skipping headers archive"
fi

# --- 5. Record the exact Ghostty commit --------------------------------------
COMMIT_FILE="$STAGING/ghostty-commit-$ARCH.txt"
printf '%s\n' "$GHOSTTY_COMMIT" > "$COMMIT_FILE"
info "Created $COMMIT_FILE"

# --- Summary -----------------------------------------------------------------
ok "Packaged $ARCH:"
ls -la "$STAGING" >&2
