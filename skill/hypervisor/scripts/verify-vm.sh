#!/usr/bin/env bash
# hypervisor · verify ONE VM — the mandatory post-mutation read, packaged.
# Usage: verify-vm.sh <vm-name> [namespace]   (namespace defaults to "default")
# Emits a VERDICT plus the real phase/IP/PVC/events so the caller never has to
# claim success blindly. READ-ONLY. Safe to re-run. Run this AFTER any
# create/apply/start/stop/restart and base the report on its output only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
. "${DIR}/env.sh"

NAME="${1:-}"
NS="${2:-default}"
if [ -z "${NAME}" ]; then
  echo "usage: verify-vm.sh <vm-name> [namespace]" >&2
  exit 2
fi

if ! hv_preflight; then
  echo "=== NOT READY — cannot verify; do NOT report status from memory ==="
  exit 1
fi

echo "=== VM ${NS}/${NAME} ==="
if ! kubectl get vm "${NAME}" -n "${NS}" >/dev/null 2>&1; then
  emit VERDICT NOTFOUND
  emit DETAIL "no VirtualMachine named ${NAME} in ${NS} — it was NOT created (or was deleted)"
  echo "=== VERIFY DONE ==="
  exit 0
fi

VM_STATUS="$(kubectl get vm "${NAME}" -n "${NS}" -o jsonpath='{.status.printableStatus}' 2>/dev/null)"
VMI_PHASE="$(kubectl get vmi "${NAME}" -n "${NS}" -o jsonpath='{.status.phase}' 2>/dev/null)"
PVC_STATUS="$(kubectl get pvc "${NAME}-disk-0" -n "${NS}" -o jsonpath='{.status.phase}' 2>/dev/null)"

emit VM_STATUS "${VM_STATUS:-unknown}"
emit VMI_PHASE "${VMI_PHASE:-none}"
emit PVC_DISK0 "${PVC_STATUS:-none}"

echo
echo "--- interfaces (LAN IP must be non-empty to be SSH-able off-cluster) ---"
kubectl get vmi "${NAME}" -n "${NS}" \
  -o jsonpath='{range .status.interfaces[*]}{.name}{" -> "}{.ipAddress}{"\n"}{end}' 2>/dev/null

# Derive a single honest verdict.
LAN_IP="$(kubectl get vmi "${NAME}" -n "${NS}" \
  -o jsonpath='{range .status.interfaces[*]}{.ipAddress}{"\n"}{end}' 2>/dev/null \
  | grep -vE '^10\.|^$' | head -1)"

echo
if [ "${VMI_PHASE}" = "Running" ] && [ "${PVC_STATUS}" = "Bound" ]; then
  emit VERDICT RUNNING
  [ -n "${LAN_IP}" ] && emit LAN_IP "${LAN_IP}" || emit LAN_IP "(none-yet: pod-only, or bridge NIC has no IP)"
else
  emit VERDICT NOT_READY
  emit DETAIL "vmi=${VMI_PHASE:-none} pvc=${PVC_STATUS:-none} — see events below"
  echo
  echo "--- recent events (why it's not ready) ---"
  kubectl get events -n "${NS}" --sort-by=.lastTimestamp 2>/dev/null | grep -i "${NAME}" | tail -15
  echo
  echo "--- describe tail ---"
  kubectl describe vm "${NAME}" -n "${NS}" 2>/dev/null | sed -n '/Events:/,$p' | tail -20
fi

echo
echo "=== VERIFY DONE ==="
