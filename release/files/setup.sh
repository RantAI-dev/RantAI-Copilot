#!/usr/bin/env bash
# One-command setup for the pre-set-up RantAI-Copilot bundle.
# Installs the bundled rantaiclaw, deploys the skills, and onboards your LLM key.
# Usage: ./setup.sh            (override install dir with BINDIR=, profile with RANTAICLAW_PROFILE=)
set -euo pipefail
say() { printf '%s\n' "$*"; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. does the bundled binary run on this host?
if ! "$HERE/bin/rantaiclaw" --version >/dev/null 2>&1; then
  say "✗ The bundled rantaiclaw won't run here (architecture/libc mismatch)."
  say "  This bundle is $(cat "$HERE/VERSION" 2>/dev/null | grep ^arch= | cut -d= -f2). Build from source for other platforms."
  exit 1
fi
say "✓ rantaiclaw $("$HERE/bin/rantaiclaw" --version | awk '{print $2}') runs on this host"

# 2. install onto PATH
DEST="${BINDIR:-$HOME/.local/bin}"
mkdir -p "$DEST"
install -m755 "$HERE/bin/rantaiclaw" "$DEST/rantaiclaw"
say "✓ installed → $DEST/rantaiclaw"
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) say "  ⚠ $DEST is not on your PATH — add it:  export PATH=\"$DEST:\$PATH\"" ;;
esac

# 3. LLM provider + key (reuse rantaiclaw's own onboarding if nothing is configured yet)
PROFILE="${RANTAICLAW_PROFILE:-default}"
CFG="$HOME/.rantaiclaw/profiles/$PROFILE/config.toml"
if [ ! -f "$CFG" ]; then
  if [ -n "${NONINTERACTIVE:-}" ]; then
    say "→ No LLM provider configured yet. When ready, run:  rantaiclaw onboard"
  else
    say ""
    say "→ No config yet. Launching 'rantaiclaw onboard' to set your LLM provider + API key…"
    say "  (or Ctrl-C and set api_key/default_provider in $CFG yourself)"
    "$DEST/rantaiclaw" onboard </dev/tty || say "! onboard skipped — configure a provider/key before running"
  fi
else
  say "✓ existing config: $CFG (leaving it as-is)"
fi

# 4. deploy the skills AFTER onboarding (onboard --force can wipe the workspace)
SK="$HOME/.rantaiclaw/profiles/$PROFILE/workspace/skills"
N=0
for d in "$HERE"/skill/*/; do
  s="$(basename "$d")"; N=$((N+1))
  rm -rf "$SK/$s"; mkdir -p "$SK/$s"   # clean replace: drop files removed upstream
  cp -r "$HERE/skill/$s/." "$SK/$s/"
  chmod +x "$SK/$s"/scripts/*.sh 2>/dev/null || true
done
say "✓ $N skills deployed → $SK"

# 5. kubectl reminder for the hypervisor skill (drives a cluster locally)
command -v kubectl >/dev/null 2>&1 \
  && say "✓ kubectl present — the hypervisor skill can drive a cluster" \
  || say "! kubectl not found — install it, then drop a kubeconfig at the workspace as 'kubeconfig-hypervisor'"

# 6. stage the web console (launcher) so `copilot-web` works without a git clone
if [ -f "$HERE/web-ui.sh" ]; then
  command -v git >/dev/null 2>&1 || say "! git not found — needed by the web console (copilot-web). Install git."
  CPDIR="$HOME/.copilot"
  mkdir -p "$CPDIR"
  cp "$HERE/web-ui.sh" "$CPDIR/web-ui.sh"
  [ -f "$HERE/VERSION" ] && cp "$HERE/VERSION" "$CPDIR/VERSION"
  chmod +x "$CPDIR/web-ui.sh"
  ln -sf "$CPDIR/web-ui.sh" "$DEST/copilot-web"
  if [ -f "$HERE/copilot-uninstall" ]; then
    install -m755 "$HERE/copilot-uninstall" "$CPDIR/copilot-uninstall"
    ln -sf "$CPDIR/copilot-uninstall" "$DEST/copilot-uninstall"
  fi
  say "✓ web console staged → run: copilot-web"
fi

cat <<EOF

Done. Next:
  rantaiclaw onboard   # set your LLM provider + key (if you haven't)
  copilot-web          # web console → http://localhost:3939

Operate a Hypervisor cluster (after a kubeconfig is in the workspace):
  cp your-kubeconfig.yaml ~/.rantaiclaw/profiles/$PROFILE/workspace/kubeconfig-hypervisor
  rantaiclaw agent -m "list all VMs on the Hypervisor cluster"
See QUICKSTART.md for details.
EOF
