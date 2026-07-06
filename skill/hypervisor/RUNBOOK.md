# Hypervisor — Operator Runbook

Step-by-step procedures for the most common Hypervisor (Harvester HCI / KubeVirt /
Longhorn) tasks, driven by `kubectl`. SKILL.md holds the rules and the canonical
manifest; this runbook is the "how-to" sequence. Every procedure assumes the
KUBECONFIG is resolved (see `scripts/env.sh`) and follows the golden rules in
SKILL.md (discover live facts, confirm before mutating, VERIFY after every change,
never fabricate). For the full catalog of failure modes see `reference/pitfalls.md`.

## 0. Preflight (always first)

```bash
. scripts/env.sh && hv_preflight        # READY=yes, or a reason + non-zero exit
scripts/discover.sh                     # nodes, ready images (+ SC), NADs (+ ipam), inventory
```
If `discover.sh` says NOT READY, fix the kubeconfig/connectivity before anything
else (see SKILL.md "Connection" / "Installing a kubeconfig"). Never proceed on a
guess.

## 1. Create an SSH-able Ubuntu VM (the default ask)

This is the proven happy path. The three things that MUST be right together, from
the first boot: a **cloud image** (not an ISO), the **per-image storageClass**,
and **cloud-init userData + networkData**.

0. **Pre-flight network check (FIRST).** Confirm a VM Network exists before promising
   SSH:
   ```bash
   kubectl get clusternetworks.network.harvesterhci.io
   kubectl get network-attachment-definitions -A
   ```
   If none exists, you can't make an SSH-able VM yet — ask the user whether to create
   a cluster network / VM Network and WHAT NAME to give it (admin action: confirm
   name + node uplink NIC + VLAN; never invent). Pod-only (no LAN SSH) is the
   fallback if they don't want one.
1. **Discover inputs & ASK image type.** From `scripts/discover.sh`:
   - ASK the user: cloudimg or live-server? RECOMMEND cloudimg (instant, cloud-init
     works, no manual install). Pick a VM image with `PROGRESS=100` whose name looks
     like `*-cloudimg-*` (a `.img`/qcow2). If none exists, offer to import one and
     wait for PROGRESS=100. Note its `STORAGECLASS` (an `lh-*` id) — clone with THAT,
     not `harvester-longhorn`.
   - pick the **NAD** for LAN/SSH (from step 0) and confirm its DHCP can hand out an
     IP (a DHCP server on that bridge/VLAN, or a sibling VM already holding a
     `192.168.x.x` lease, proves DHCP works).
2. **Gather requirements** (SKILL.md "Gather requirements"): name, ns, vCPU, RAM,
   disk ≥ image virtual size, login user + password (ASK — never invent), SSH
   wanted? which NAD?
3. **Author the manifest** from the canonical template in SKILL.md. Keep BOTH:
   - `userData`: the user, `chpasswd`, `ssh_pwauth: true` (or `ssh_authorized_keys`).
   - `networkData`: `enp1s0: {dhcp4: true}` AND `enp2s0: {dhcp4: true}`.
   Set the volumeClaimTemplate `storageClassName` to the per-image SC and the
   `harvesterhci.io/imageId` annotation to `<ns>/<image-name>`.
4. **Show the manifest, confirm, apply:** `kubectl apply -f -`.
5. **VERIFY (mandatory):**
   ```bash
   scripts/verify-vm.sh <vm-name> <ns>      # VERDICT=RUNNING, PVC Bound, LAN_IP set
   ```
   Wait until VMI `Running` AND the `nic-lan` interface shows a `192.168.x.x` IP
   (DHCP can take 30–60s after Running).
6. **Prove SSH (don't just claim it):**
   ```bash
   scripts/ssh-check.sh <lan-ip> <user> '<password>'   # VERDICT: SSH LOGIN OK
   ```
   Report the real `whoami`/`hostname`/`enp2s0` output. Only now say "SSH works".

## 2. Change a VM's login or network (recreate — patch+restart does NOT work)

Cloud-init (user, password, ssh_pwauth, networkData) is processed only on the
FIRST boot of an instance. Patching a running VM's cloud-init and restarting it
leaves the guest unchanged (symptom: console `Login incorrect`, or bridge NIC
still DOWN). The reliable procedure is delete + recreate:

1. Confirm with the user — this destroys the current disk.
2. ```bash
   kubectl delete vm <name> -n <ns>
   kubectl delete pvc <name>-disk-0 -n <ns> --ignore-not-found
   kubectl get pvc -n <ns> | grep <name> || echo "pvc gone"
   ```
3. Recreate fresh with the corrected userData + networkData (procedure 1).
4. VERIFY (`verify-vm.sh`) and prove SSH (`ssh-check.sh`).

## 3. Bridge NIC is DOWN / VM has no LAN IP

`scripts/verify-vm.sh` shows `nic-lan -> ` empty, or in-guest `ip a` shows
`enp2s0 ... state DOWN` with no `inet`.

1. **Check the cause is the VM, not the network:** does any sibling VM on the same
   NAD have a `192.168.x.x` lease (`scripts/discover.sh` inventory)? If yes, DHCP
   works → the VM is missing `networkData`. If no, suspect the NAD/cluster network
   (see `reference/pitfalls.md` → multus / no-DHCP).
2. **Reliable fix:** recreate with `networkData` enabling DHCP on both NICs
   (procedure 2), OR a full guest `reboot` if cloud-init on disk is already
   correct (reboot re-runs netplan natively).
3. **In-guest manual recovery is a LAST RESORT** and is fragile on Ubuntu 24.04
   cloudimg (`dhclient` absent; `networkctl renew` fails on an unmanaged NIC).
   If you must: write `/etc/netplan/99-lan.yaml` (`renderer: networkd`,
   `enp2s0: {dhcp4: true}`), `sudo systemctl enable --now systemd-networkd`,
   `sudo netplan apply`. Prefer recreate/reboot.

## 4. Start / stop / restart / delete

```bash
kubectl virt start  <name> -n <ns>      # or patch spec.runStrategy
kubectl virt stop   <name> -n <ns>
kubectl virt restart <name> -n <ns>
kubectl delete vm   <name> -n <ns>      # also delete the -disk-0 PVC for a clean rebuild
```
If the `virt` plugin is absent, toggle `spec.runStrategy` (`Halted` ↔
`RerunOnFailure`) with `kubectl patch`. Confirm before any of these, then
`scripts/verify-vm.sh` to confirm the new state.

## 5. Install / rotate a kubeconfig

See SKILL.md "Installing / rotating a kubeconfig". In short: write it to the
workspace path, `chmod 600`, validate the CA decodes (`base64 -d`), smoke-test
with `kubectl get nodes -o wide` (no `--insecure-skip-tls-verify`). Never print
the token/CA; never commit it.
