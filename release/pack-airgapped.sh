#!/usr/bin/env bash
# Build an AIRGAPPED all-in-one bundle: the normal bundle + a prebuilt web console
# (claw-ui cloned, deps installed) + a bun runtime + the offline installer. Run this on a
# CONNECTED machine of the SAME arch/OS (Linux x86_64) as the airgapped target — it fetches
# claw-ui + node_modules here so the target needs no network.
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

# 2. prebuild the web console: fetch claw-ui + deps.
#    Use a throwaway HOME so `ui install` gets a fresh config (avoids a schema mismatch
#    if this machine's rantaiclaw config was written by a newer binary than $RC_BIN).
say "→ fetching + building claw-ui (this needs network, done HERE not on the target)…"
_rc_home="$(mktemp -d)"
HOME="$_rc_home" "$STAGE/bin/rantaiclaw" ui install --dir "$STAGE/web-ui"
rm -rf "$_rc_home"
# record the exact claw-ui commit in VERSION so the snapshot is reproducible/traceable
printf 'claw_ui=%s\n' "$(git -C "$STAGE/web-ui" rev-parse --short HEAD 2>/dev/null || echo unknown)" >> "$STAGE/VERSION"
rm -rf "$STAGE/web-ui/.git"   # not needed offline; saves space

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
