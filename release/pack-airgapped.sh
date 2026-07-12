#!/usr/bin/env bash
# Build an AIRGAPPED all-in-one bundle: the normal bundle + a prebuilt web console
# (claw-ui prebuilt release: .next + node_modules) + a bun runtime + the offline installer.
# Run this on a CONNECTED machine of the SAME arch/OS (Linux x86_64) as the airgapped target —
# `rantaiclaw ui install` fetches the signed claw-ui release here so the target needs no network.
#
# Usage: release/pack-airgapped.sh <path-to-rantaiclaw-binary> [tag]
set -euo pipefail
say() { printf '%s\n' "$*"; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

RC_BIN="${1:?usage: pack-airgapped.sh <rantaiclaw-binary> [tag]}"
TAG="${2:-v0.0.0}"
ARCH="$(uname -m)"
NAME="rantai-copilot-airgapped-${TAG}-${ARCH}-linux"
OUT="$REPO/dist"; STAGE="$OUT/$NAME"

command -v bun >/dev/null 2>&1 || { say "✗ bun not found here — install bun first (this machine builds the web deps)"; exit 1; }

# 1. base bundle (binary + skills + web-ui.sh + setup.sh + docs)
say "→ building base bundle…"
bash "$HERE/build-bundle.sh" "$RC_BIN" "$TAG" >/dev/null
rm -rf "$STAGE"; mkdir -p "$OUT"
tar xzf "$OUT/rantai-copilot-${TAG}-${ARCH}-linux.tar.gz" -C "$OUT"
mv "$OUT/rantai-copilot-${TAG}-${ARCH}-linux" "$STAGE"

# 2. prebuild the web console: fetch the signed prebuilt claw-ui release (.next + node_modules).
#    Use a throwaway HOME so `ui install` gets a fresh config (avoids a schema mismatch
#    if this machine's rantaiclaw config was written by a newer binary than $RC_BIN).
say "→ fetching claw-ui prebuilt release (needs network — done HERE, not on the target)…"
_rc_home="$(mktemp -d)"
if _ui_out="$(HOME="$_rc_home" "$STAGE/bin/rantaiclaw" ui install --dir "$STAGE/web-ui" 2>&1)"; then
  say "$_ui_out"
else
  say "$_ui_out"; rm -rf "$_rc_home"; say "✗ claw-ui install failed"; exit 1
fi
rm -rf "$_rc_home"
# record the claw-ui release tag in VERSION for traceability (prebuilt release, not a git checkout)
_claw_ui="$(printf '%s\n' "$_ui_out" | grep -oE 'claw-ui-v[0-9][^ ]*\.tar\.gz' | head -1 | sed -E 's/^claw-ui-//; s/\.tar\.gz$//')"
printf 'claw_ui=%s\n' "${_claw_ui:-unknown}" >> "$STAGE/VERSION"

# 3. bundle the bun runtime
mkdir -p "$STAGE/bun"; install -m755 "$(command -v bun)" "$STAGE/bun/bun"
say "✓ bundled bun $("$STAGE/bun/bun" --version 2>/dev/null)"

# 4. offline installer (replaces the online setup.sh path)
install -m755 "$HERE/files/setup-airgapped.sh" "$STAGE/setup-airgapped.sh"

# 5. tarball + checksum
say "→ packing airgapped tarball…"
( cd "$OUT" && tar czf "$NAME.tar.gz" "$NAME" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256" )
rm -rf "$STAGE"
say "✓ $OUT/$NAME.tar.gz"
say "  $(cat "$OUT/$NAME.tar.gz.sha256")"
say "  size: $(du -h "$OUT/$NAME.tar.gz" | cut -f1)"
