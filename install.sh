#!/usr/bin/env bash
# Install RantAI-Copilot into your local RantaiClaw — deploy the skills.
# Usage: ./install.sh [profile]   (default: "default")
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '%s\n' "$*"; }

say "RantAI-Copilot · installer"
say ""

# 1. RantaiClaw present?
if ! command -v rantaiclaw >/dev/null 2>&1; then
  say "✗ rantaiclaw not found on PATH"
  say "    install a RantaiClaw build first — see README.md"
  exit 1
fi
say "✓ rantaiclaw $(rantaiclaw --version | awk '{print $2}')"

# 2. kubectl for the hypervisor skill — it drives a Hypervisor cluster locally over kubectl
#    (not over SSH). Soft check: only matters once you have a cluster, so warn, don't fail.
if command -v kubectl >/dev/null 2>&1; then
  say "✓ kubectl present — the hypervisor skill can drive a cluster"
else
  say "! kubectl not found — needed by the hypervisor skill (drives a cluster via kubeconfig)"
  say "    install kubectl, then drop a kubeconfig at the workspace as 'kubeconfig-hypervisor'"
fi

# 3. Deploy the skills into the active profile's workspace
ROOT="${RANTAICLAW_HOME:-$HOME/.rantaiclaw}"
PROFILE="${1:-${RANTAICLAW_PROFILE:-default}}"
SKILLS_DIR="$ROOT/profiles/$PROFILE/workspace/skills"
say "→ deploying skills (profile: $PROFILE)…"
N=0
for d in "$HERE"/skill/*/; do
  s="$(basename "$d")"; N=$((N+1))
  DEST="$SKILLS_DIR/$s"
  rm -rf "$DEST"; mkdir -p "$DEST"   # clean replace: don't leave files removed upstream
  cp -r "$HERE/skill/$s/." "$DEST/"
  chmod +x "$DEST"/scripts/*.sh 2>/dev/null || true
  say "  ✓ $s"
done

# 4. Confirm they load
LOADED="$(rantaiclaw skills list 2>/dev/null | grep -ci hypervisor || true)"
if [ "${LOADED:-0}" -ge "$N" ]; then
  say "✓ all $N skills loaded"
elif [ "${LOADED:-0}" -gt 0 ]; then
  say "! $LOADED of $N skills loaded — re-check 'rantaiclaw skills list'"
else
  say "! skills copied but not listed — is profile '$PROFILE' the active one?"
fi

say ""
say "Done. Next:"
say "  rantaiclaw setup     # set your LLM provider + key (if you haven't)"
say "  ./web-ui.sh          # launch the web console → http://localhost:3939"
say ""
say "  # operate a Hypervisor cluster (after a kubeconfig is in the workspace):"
say "  rantaiclaw agent -m \"list all VMs on the Hypervisor cluster\""
