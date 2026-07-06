#!/usr/bin/env bash
# hypervisor · cluster discovery — emits a KEY=VALUE / block report of the
# live cluster facts the skill needs before creating or diagnosing anything:
# API server, nodes, ready VM images (+ per-image storageClass), VM networks
# (NADs + ipam), and current VM/VMI inventory. READ-ONLY. Never prints secrets
# (no token/CA). Safe to re-run. Base every answer on THIS output, not memory.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
. "${DIR}/env.sh"

if ! hv_preflight; then
  echo "=== NOT READY — cannot discover; fix the above and re-run ==="
  exit 1
fi

echo "=== CLUSTER ==="
emit API_SERVER "$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)"
emit K8S_VERSION "$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null)"
emit NODE_OS "$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.osImage}' 2>/dev/null)"

echo
echo "=== NODES ==="
kubectl get nodes -o wide 2>&1

echo
echo "=== VM IMAGES (use one with PROGRESS=100; prefer *-cloudimg-* for SSH/cloud-init) ==="
# NAME, displayName, progress, and the PER-IMAGE storageClass to clone from.
kubectl get virtualmachineimages.harvesterhci.io -A \
  -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,DISPLAY:.spec.displayName,PROGRESS:.status.progress,STORAGECLASS:.status.storageClassName' 2>&1

echo
echo "=== VM NETWORKS (NADs) — check ipam: a bridge NIC needs DHCP or a static IP ==="
kubectl get network-attachment-definitions -A \
  -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' 2>&1
# Inspect each NAD's config (type/vlan/ipam) so the caller knows if it hands out IPs.
for row in $(kubectl get network-attachment-definitions -A \
               -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null); do
  ns="${row%%/*}"; name="${row##*/}"
  cfg="$(kubectl get net-attach-def "${name}" -n "${ns}" -o jsonpath='{.spec.config}' 2>/dev/null)"
  printf '  %s/%s :: %s\n' "${ns}" "${name}" "${cfg}"
done

echo
echo "=== STORAGE CLASSES (default + per-image lh-*) ==="
kubectl get sc 2>&1

echo
echo "=== VM / VMI INVENTORY ==="
kubectl get virtualmachines.kubevirt.io -A 2>&1
echo
kubectl get virtualmachineinstances.kubevirt.io -A -o wide 2>&1

echo
echo "=== DISCOVERY DONE ==="
