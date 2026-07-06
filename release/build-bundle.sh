#!/usr/bin/env bash
# Assemble a "pre-set-up agent" release bundle: a prebuilt rantaiclaw + the skills + a
# one-command setup. Produces dist/<bundle>.tar.gz.
#
# Usage: release/build-bundle.sh <path-to-rantaiclaw-binary> [tag]
#   e.g. release/build-bundle.sh ~/rc/target/x86_64-unknown-linux-musl/release/rantaiclaw v0.1.0
set -euo pipefail
say() { printf '%s\n' "$*"; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

RC_BIN="${1:?usage: build-bundle.sh <rantaiclaw-binary> [tag]}"
TAG="${2:-v0.1.0}"
ARCH="$(uname -m)"
NAME="rantai-copilot-${TAG}-${ARCH}-linux"
OUT="$REPO/dist"
STAGE="$OUT/$NAME"

[ -x "$RC_BIN" ] || { say "✗ rantaiclaw binary not found/executable: $RC_BIN"; exit 1; }

say "→ staging $NAME"
rm -rf "$STAGE"; mkdir -p "$STAGE/bin"
install -m755 "$RC_BIN" "$STAGE/bin/rantaiclaw"

# skills — all of them
for d in "$REPO"/skill/*/; do
  s="$(basename "$d")"
  mkdir -p "$STAGE/skill/$s"
  cp -r "$REPO/skill/$s/." "$STAGE/skill/$s/"
  chmod +x "$STAGE/skill/$s"/scripts/*.sh 2>/dev/null || true
done

# web console: launcher only (claw-ui itself is fetched on demand by copilot-web)
install -m755 "$REPO/web-ui.sh" "$STAGE/web-ui.sh"
install -m755 "$REPO/copilot-uninstall" "$STAGE/copilot-uninstall"

# setup + docs
install -m755 "$HERE/files/setup.sh" "$STAGE/setup.sh"
cp "$HERE/files/QUICKSTART.md" "$STAGE/QUICKSTART.md"
[ -d "$REPO/tutorials" ] && cp -r "$REPO/tutorials" "$STAGE/tutorials"
[ -f "$REPO/README.md" ]   && cp "$REPO/README.md"   "$STAGE/README.md"
[ -f "$REPO/LICENSE" ] && cp "$REPO/LICENSE" "$STAGE/LICENSE" 2>/dev/null || true
RC_VER="$("$RC_BIN" --version 2>/dev/null | awk '{print $2}')"
cat > "$STAGE/VERSION" <<EOF
bundle=$TAG
rantaiclaw=$RC_VER
skills=$(for d in "$REPO"/skill/*/; do s=$(basename "$d"); v=$(grep -m1 '^version:' "$d/SKILL.md" 2>/dev/null | awk '{print $2}'); printf '%s,%s;' "$s" "$v"; done)
arch=$ARCH-linux
EOF

# tarball + checksum
say "→ packing tarball"
( cd "$OUT" && tar czf "$NAME.tar.gz" "$NAME" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256" )
say "✓ $OUT/$NAME.tar.gz"
say "  $(cat "$OUT/$NAME.tar.gz.sha256")"
say "  size: $(du -h "$OUT/$NAME.tar.gz" | cut -f1)"
