#!/usr/bin/env bash
# Online installer for RantAI-Copilot. Downloads the latest release bundle (prebuilt static
# rantaiclaw + the hypervisor skill), verifies its checksum, installs the binary, and deploys
# the skills. Non-interactive — safe to pipe:
#
#   curl -fsSL https://raw.githubusercontent.com/RantAI-dev/RantAI-Copilot/main/get.sh | bash
#
# It does NOT configure your LLM (that needs a terminal) — it prints the one command to run next.
# Env: COPILOT_AGENT_VERSION (default: latest) · BINDIR (default ~/.local/bin) · RANTAICLAW_PROFILE
#
# POSIX-sh safe: works whether piped to `sh` (dash on Debian/Ubuntu) or `bash`.
set -eu
# pipefail is a bash/zsh feature — enable it only where supported (no-op on dash).
(set -o pipefail) 2>/dev/null && set -o pipefail || true
# Quiet mode (COPILOT_QUIET=1) silences the ✓ progress lines — used by `copilot-update`.
QUIET="${COPILOT_QUIET:-0}"
say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

REPO="RantAI-dev/RantAI-Copilot"
VER="${COPILOT_AGENT_VERSION:-latest}"
PROFILE="${RANTAICLAW_PROFILE:-default}"
DEST="${BINDIR:-$HOME/.local/bin}"

OS="$(uname -s)"; ARCH="$(uname -m)"
[ "$OS" = "Linux" ]    || die "this bundle is Linux x86_64 only (got $OS). Build from source: https://github.com/$REPO"
[ "$ARCH" = "x86_64" ] || die "this bundle is x86_64 only (got $ARCH). Build from source: https://github.com/$REPO"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v tar  >/dev/null 2>&1 || die "tar is required"

# resolve the release tag (asset filename embeds the version)
if [ "$VER" = "latest" ]; then
  TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" | sed 's#.*/tag/##')"
  [ -n "$TAG" ] || die "could not resolve the latest release tag"
else
  TAG="$VER"
fi
ASSET="rantai-copilot-${TAG}-x86_64-linux.tar.gz"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
say "→ downloading $ASSET …"
if [ "$QUIET" = 1 ]; then
  curl -fsSL -o "$TMP/b.tar.gz" "$URL" || die "download failed: $URL"
else
  curl -fSL --progress-bar -o "$TMP/b.tar.gz" "$URL" || die "download failed: $URL"
fi

# verify the checksum if the sidecar is published
if curl -fsSL -o "$TMP/b.sha256" "$URL.sha256" 2>/dev/null; then
  WANT="$(awk '{print $1}' "$TMP/b.sha256")"
  GOT="$(sha256sum "$TMP/b.tar.gz" | awk '{print $1}')"
  [ "$WANT" = "$GOT" ] || die "checksum mismatch (want $WANT, got $GOT) — aborting"
  say "✓ checksum verified"
fi

tar xzf "$TMP/b.tar.gz" -C "$TMP"
BDIR="$TMP/rantai-copilot-${TAG}-x86_64-linux"
RC="$BDIR/bin/rantaiclaw"
[ -x "$RC" ] || die "bundle is missing the rantaiclaw binary"
"$RC" --version >/dev/null 2>&1 || die "the bundled rantaiclaw won't run on this host (arch/libc mismatch)"

# install the binary — but never silently downgrade a newer rantaiclaw already on PATH.
# Set COPILOT_FORCE=1 to install the bundled binary regardless.
NEW_VER="$("$RC" --version 2>/dev/null | awk '{print $2}')"
CUR_BIN="$(command -v rantaiclaw 2>/dev/null || true)"
CUR_VER=""; [ -n "$CUR_BIN" ] && CUR_VER="$("$CUR_BIN" --version 2>/dev/null | awk '{print $2}')"
mkdir -p "$DEST"
if [ "${COPILOT_FORCE:-0}" != "1" ] && [ -n "$CUR_VER" ] && [ "$CUR_VER" != "$NEW_VER" ] && \
   [ "$(printf '%s\n%s\n' "$CUR_VER" "$NEW_VER" | sort -V | tail -1)" = "$CUR_VER" ]; then
  say "✓ keeping existing rantaiclaw $CUR_VER ($CUR_BIN) — newer than bundled $NEW_VER"
  say "  (force the bundled build with: COPILOT_FORCE=1)"
else
  install -m755 "$RC" "$DEST/rantaiclaw"
  say "✓ installed rantaiclaw $NEW_VER → $DEST/rantaiclaw"
fi
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) say "  ⚠ $DEST is not on your PATH — add it:  export PATH=\"$DEST:\$PATH\"" ;;
esac

# deploy all bundled skills
SK="$HOME/.rantaiclaw/profiles/$PROFILE/workspace/skills"
for d in "$BDIR"/skill/*/; do
  s="$(basename "$d")"
  rm -rf "$SK/$s"; mkdir -p "$SK/$s"   # clean replace: don't leave files removed upstream
  cp -r "$d." "$SK/$s/"
  chmod +x "$SK/$s"/scripts/*.sh 2>/dev/null || true
done
say "✓ skills deployed → $SK"

# stage the web console launcher so the browser UI works WITHOUT a git clone.
# This is lazy: no heavy fetch here — the first `copilot-web` run clones claw-ui + installs deps.
if [ -f "$BDIR/web-ui.sh" ]; then
  command -v git >/dev/null 2>&1 || say "! git not found — needed by the web console (copilot-web). Install git."
  CPDIR="$HOME/.copilot"
  mkdir -p "$CPDIR"
  # Atomic install (temp + mv): never truncate-in-place a script that may be executing
  # right now — e.g. copilot-update runs get.sh which rewrites copilot-update itself.
  install -m755 "$BDIR/web-ui.sh" "$CPDIR/.web-ui.sh.$$" && mv -f "$CPDIR/.web-ui.sh.$$" "$CPDIR/web-ui.sh"
  [ -f "$BDIR/VERSION" ] && cp "$BDIR/VERSION" "$CPDIR/VERSION"
  ln -sf "$CPDIR/web-ui.sh" "$DEST/copilot-web"
  cat > "$DEST/.copilot-update.$$" <<'UPD'
#!/usr/bin/env sh
# Update RantAI-Copilot to the latest: bundle (skills + web console + bundled binary) AND the
# rantaiclaw binary (latest upstream release you publish).
set -e
printf '→ updating RantAI-Copilot bundle…\n'
curl -fsSL https://raw.githubusercontent.com/RantAI-dev/RantAI-Copilot/main/get.sh | COPILOT_QUIET=1 sh
if command -v rantaiclaw >/dev/null 2>&1; then
  printf '→ rantaiclaw binary…\n'
  # Show the real result (don't hide it) so a failed update isn't mistaken for "latest".
  rantaiclaw update --yes || printf '! binary update skipped/failed (current: %s)\n' \
    "$(rantaiclaw --version 2>/dev/null | awk '{print $2}')"
fi
printf '✓ done\n'
UPD
  chmod +x "$DEST/.copilot-update.$$"; mv -f "$DEST/.copilot-update.$$" "$DEST/copilot-update"
  if [ -f "$BDIR/copilot-uninstall" ]; then
    install -m755 "$BDIR/copilot-uninstall" "$CPDIR/copilot-uninstall"
    ln -sf "$CPDIR/copilot-uninstall" "$DEST/copilot-uninstall"
  fi
  say "✓ web console ready → run: copilot-web"
fi

PATHHINT=""; case ":$PATH:" in *":$DEST:"*) ;; *) PATHHINT="export PATH=\"$DEST:\$PATH\";  ";; esac
say ""
say "Ready:"
say "  ${PATHHINT}rantaiclaw setup        # set LLM provider/key (once)"
say "  rantaiclaw chat                    # CLI agent"
say "  copilot-web                        # web console → http://localhost:3939"
say "  copilot-update                     # update everything later"
