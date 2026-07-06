#!/usr/bin/env bash
# hypervisor · shared env — resolve & export the Hypervisor KUBECONFIG and
# provide small helpers used by the other read-only scripts. Source this, do not
# execute it: `. "$(dirname "$0")/env.sh"`. Never prints secrets. Safe to re-run.
set -u

# Resolve the kubeconfig path portably (any user/profile). Precedence:
# existing $KUBECONFIG → RantaiClaw workspace location → fail with guidance.
hv_resolve_kubeconfig() {
  if [ -n "${KUBECONFIG:-}" ] && [ -r "${KUBECONFIG}" ]; then
    printf '%s' "${KUBECONFIG}"
    return 0
  fi
  local home="${RANTAICLAW_HOME:-$HOME/.rantaiclaw}"
  local prof="${RANTAICLAW_PROFILE:-default}"
  printf '%s' "${home}/profiles/${prof}/workspace/kubeconfig-hypervisor"
}

KUBECONFIG="$(hv_resolve_kubeconfig)"
export KUBECONFIG

# kubectl wrapper so callers never forget the config.
kc() { kubectl "$@"; }

# helpers (same idiom as sibling skills)
emit() { printf '%s=%s\n' "$1" "$2"; }
has()  { command -v "$1" >/dev/null 2>&1; }

# Preflight: kubectl present + kubeconfig readable + API reachable. Emits a
# READY=yes/no line and a reason; returns non-zero when not ready so callers can
# stop early instead of producing fake data.
hv_preflight() {
  if ! has kubectl; then emit READY no; emit REASON "kubectl-not-installed"; return 1; fi
  if [ ! -r "${KUBECONFIG}" ]; then
    emit READY no; emit REASON "kubeconfig-missing:${KUBECONFIG}"; return 1
  fi
  if ! kubectl version -o yaml >/dev/null 2>&1 \
     && ! kubectl get --raw='/readyz' >/dev/null 2>&1; then
    emit READY no; emit REASON "api-unreachable"; return 1
  fi
  emit READY yes
  return 0
}
