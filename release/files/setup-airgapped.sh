#!/usr/bin/env bash
# Airgapped installer — installs EVERYTHING from this bundle, no network:
# rantaiclaw binary + skills + the web console (claw-ui prebuilt with node_modules)
# + a bundled bun runtime. Use on a restricted host that can't reach GitHub/npm/bun.sh.
#
# Usage: ./setup-airgapped.sh            (BINDIR= to change install dir; RANTAICLAW_PROFILE=)
set -euo pipefail
say() { printf '%s\n' "$*"; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${BINDIR:-$HOME/.local/bin}"
PROFILE="${RANTAICLAW_PROFILE:-default}"
CPDIR="$HOME/.copilot"

say "RantAI-Copilot · airgapped installer"
say ""

# 1. bundled binary runs here?
"$HERE/bin/rantaiclaw" --version >/dev/null 2>&1 || {
  say "✗ bundled rantaiclaw won't run here — this bundle is $(grep -m1 ^arch= "$HERE/VERSION" 2>/dev/null | cut -d= -f2)"; exit 1; }
mkdir -p "$DEST"
install -m755 "$HERE/bin/rantaiclaw" "$DEST/rantaiclaw"
say "✓ rantaiclaw $("$HERE/bin/rantaiclaw" --version | awk '{print $2}') → $DEST/rantaiclaw"
case ":$PATH:" in *":$DEST:"*) ;; *) say "  ⚠ $DEST not on PATH — add: export PATH=\"$DEST:\$PATH\"" ;; esac

# 2. bundled bun runtime (the web console needs a JS runtime; airgapped can't fetch one)
if [ -x "$HERE/bun/bun" ] && ! command -v bun >/dev/null 2>&1 && ! command -v npm >/dev/null 2>&1; then
  install -m755 "$HERE/bun/bun" "$DEST/bun"
  say "✓ bun → $DEST/bun"
fi

# 3. LLM provider + key — configure it yourself after install (kept separate from install).
#    'setup provider' sets just the LLM and needs no network — safe on an airgapped host.
CFG="$HOME/.rantaiclaw/profiles/$PROFILE/config.toml"
if [ -f "$CFG" ]; then
  say "✓ existing config: $CFG (left as-is)"
else
  say "→ set your LLM provider + key after install:  rantaiclaw setup provider   (offline)"
fi

# 4. skills
SK="$HOME/.rantaiclaw/profiles/$PROFILE/workspace/skills"
N=0
for d in "$HERE"/skill/*/; do
  s="$(basename "$d")"; N=$((N+1))
  rm -rf "$SK/$s"; mkdir -p "$SK/$s"; cp -r "$HERE/skill/$s/." "$SK/$s/"   # clean replace
  chmod +x "$SK/$s"/scripts/*.sh 2>/dev/null || true
done
say "✓ $N skills deployed → $SK"

# 5. web console: launcher + PREBUILT claw-ui (with node_modules) → offline copilot-web
mkdir -p "$CPDIR"
install -m755 "$HERE/web-ui.sh" "$CPDIR/.web-ui.sh.$$" && mv -f "$CPDIR/.web-ui.sh.$$" "$CPDIR/web-ui.sh"
[ -f "$HERE/VERSION" ] && cp "$HERE/VERSION" "$CPDIR/VERSION"
chmod +x "$CPDIR/web-ui.sh"
ln -sf "$CPDIR/web-ui.sh" "$DEST/copilot-web"
if [ -f "$HERE/copilot-uninstall" ]; then
  install -m755 "$HERE/copilot-uninstall" "$CPDIR/copilot-uninstall"
  ln -sf "$CPDIR/copilot-uninstall" "$DEST/copilot-uninstall"
fi
if [ -f "$HERE/web-ui/server.js" ] && [ -d "$HERE/web-ui/node_modules" ]; then
  rm -rf "$CPDIR/web-ui"; cp -r "$HERE/web-ui" "$CPDIR/web-ui"
  : > "$CPDIR/offline"                      # marker → copilot-web runs offline (skips fetch)
  say "✓ web console (prebuilt, offline) → run: copilot-web"
else
  say "! web console prebuilt files missing — copilot-web will need network to fetch claw-ui"
fi

# 6. an airgapped `copilot-update` that explains the offline update flow (no network fetch)
cat > "$DEST/.copilot-update.$$" <<'UPD'
#!/usr/bin/env sh
cat >&2 <<'MSG'
✗ Airgapped install — there is no online update here.
  To update, re-install from a newer bundle:
    1. On a machine with internet, download a newer rantai-copilot-airgapped-<version> bundle:
       https://github.com/RantAI-dev/RantAI-Copilot/releases
    2. Transfer it to this host and extract it.
    3. Run ./setup-airgapped.sh from the extracted folder.
MSG
exit 1
UPD
chmod +x "$DEST/.copilot-update.$$"; mv -f "$DEST/.copilot-update.$$" "$DEST/copilot-update"
say "✓ copilot-update → prints the offline update steps"

say ""
say "Done (airgapped). Next:"
say "  rantaiclaw setup provider   # set your LLM provider + key (offline, LLM only)"
say "  rantaiclaw chat             # CLI agent"
say "  copilot-web                 # web console → http://localhost:3939  (offline)"
say "  # updates: bring a newer rantai-copilot-airgapped bundle, re-run ./setup-airgapped.sh"
