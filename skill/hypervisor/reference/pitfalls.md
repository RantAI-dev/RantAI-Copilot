# Hypervisor — Pitfalls & Failure Catalog

Real failure modes observed operating a Harvester/KubeVirt/Longhorn cluster, each
with the SYMPTOM, the actual ROOT CAUSE, and the CORRECT fix. SKILL.md summarizes
these; this is the long-form reference. Rule of thumb running through all of them:
**a VM object existing ≠ a VM working**, and **the agent's own status claim ≠ the
cluster's real state** — always re-read with `kubectl` (or `scripts/verify-vm.sh`
/ `scripts/ssh-check.sh`).

## A. Image & disk

### A1. ISO used as the root disk → boots an installer
- Symptom: VM console shows the Ubuntu installer ("select your language"), and the
  user/password you set never exist. cloud-init is ignored.
- Root cause: the image is an installer ISO (`*-live-server-*-amd64.iso`), not a
  cloud image. Cloning an ISO gives a disk that contains the INSTALLER.
- Fix: use a CLOUD image (`*-cloudimg-*`, a `.img`/qcow2). Import one with a
  `VirtualMachineImage` `sourceType: download` from e.g.
  `https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img`.
  (If an ISO is truly required: attach it as a CD-ROM boot device `cdrom: {bus: sata}`
  AND add a separate blank data disk as the install target — then install manually
  or via an autoinstall seed. Default to cloudimg.)

### A2. ISO-clone is the only disk → "Block probing did not discover any disks"
- Symptom: installer aborts: "Block probing did not discover any disks.
  Unfortunately this means that installation will not be possible."
- Root cause: the single disk IS the ISO clone; there is no separate blank target.
- Fix: cloudimg (no install needed), or ISO-as-CDROM + a blank
  `harvester-longhorn` data disk (see A1).

### A3. Wrong storageClass on the root PVC → ErrorPvcNotFound / Unschedulable
- Symptom: VM `STATUS=ErrorPvcNotFound`; VMI conditions:
  `PVC <ns>/<image> does not exist, waiting for it to appear`; stays Unschedulable;
  `virt-launcher` pod is `invalid: spec.containers[1].image: Required value`.
- Root cause: the root disk was created with the default `harvester-longhorn`
  (a BLANK volume, no OS cloned), and/or a volume referenced the IMAGE name as a
  PVC `claimName`. A VirtualMachineImage is NOT a PVC.
- Fix: clone with the image's OWN per-image storageClass
  (`.status.storageClassName`, an `lh-*` id) on the volumeClaimTemplate, plus the
  annotation `harvesterhci.io/imageId: <ns>/<image-name>`. Read the SC live
  (`scripts/discover.sh`); never hardcode it.

### A4. Root disk smaller than the image virtual size → PVC won't provision
- Symptom: `<name>-disk-0` PVC stuck Pending; VM never schedules.
- Fix: request disk ≥ the image's virtualSize. Check the image size first.

### A5. VM "Volumes" tab is EMPTY in the Hypervisor UI (shows only `bootOrder`)
- Symptom: in the UI a VM's Volumes panel has no disk card — just `bootOrder: 1` — so it
  looks like "the volume is gone". The VM is Running and the data is fine; the disk and its
  PVC exist (`kubectl get pvc` shows `<name>-disk-0` Bound). Often seen on ISO-install VMs or
  after editing a VM's disks (e.g. ejecting a CD-ROM).
- Root cause: the disk is declared as a raw KubeVirt **`dataVolume`** (PVC carries
  `cdi.kubevirt.io/createdForDataVolume`) instead of the Harvester-native
  `persistentVolumeClaim` backed by the `harvesterhci.io/volumeClaimTemplates` annotation.
  Harvester's UI only renders volumeClaimTemplates-managed PVCs, so a bare dataVolume disk is
  invisible there (still works at the KubeVirt level). NOT data loss.
- Fix / prevent: always declare VM disks the Harvester-native way (volumeClaimTemplates +
  `persistentVolumeClaim` volume), for BOTH cloudimg root disks and ISO blank target disks —
  never a bare `dataVolume`. To repair an existing VM, recreate the disk reference as a
  persistentVolumeClaim pointing at the same (already-Bound) PVC and add the matching
  volumeClaimTemplates annotation (confirm with the user; it restarts the VM). Verify the
  volume now shows in the UI / that `kubectl … volumes` reports `persistentVolumeClaim`.

## B. cloud-init (the biggest time sink this session)

### B1. cloud-init is FIRST-BOOT only → patch+restart does nothing
- Symptom: you patch a running VM's cloud-init (new user/password/networkData) and
  restart; `spec` read-back looks right, but console login is `Login incorrect`
  and/or the bridge NIC is still DOWN.
- Root cause: cloud-init processes userData AND networkData only on the FIRST boot
  of an instance-id. Later boots skip the user/network modules.
- Fix: DELETE + RECREATE the VM (and its `-disk-0` PVC) so it boots fresh with the
  correct cloud-init from the start. Do not waste turns patching+restarting. (See
  RUNBOOK procedure 2.)

### B2. Missing networkData → second NIC DOWN, no LAN IP
- Symptom: `verify-vm.sh` shows `nic-lan -> ` empty; in-guest `ip a` shows
  `enp2s0 ... state DOWN` and no `inet`.
- Root cause: cloud images auto-configure only the FIRST NIC. Without
  `networkData` enabling DHCP on `enp2s0`, the bridge NIC never comes up.
- Fix: include `networkData` with `enp1s0: {dhcp4: true}` and `enp2s0: {dhcp4: true}`
  on the SAME cloudinit disk as userData, from first boot (recreate if needed).

### B3. Agent silently drops fields / invents credentials
- Symptom: the VM ends up with a different user (e.g. `ubuntu`), a foreign SSH key,
  no password, or no networkData — despite the requested cloud-init.
- Root cause: the model edited the manifest loosely.
- Fix: after authoring/patching, READ BACK the exact field and show it
  (`kubectl get vm <name> -n <ns> -o jsonpath='{...cloudInitNoCloud.networkData}'`)
  before claiming done. Never invent a username/password/SSH key — ASK (golden
  rule 7).

## C. Networking / DHCP

### C1. Bridge NAD with no ipam + no external DHCP → no IP
- Symptom: bridge NIC up but never gets an IPv4.
- Root cause: the NAD has `ipam: {}` (CNI gives no IP); the LAN/VLAN has no DHCP
  server, so nothing leases an address.
- Fix: ensure a DHCP server serves that bridge/VLAN, or assign a static IP via
  cloud-init networkData. Diagnostic: if a sibling VM on the same NAD holds a
  `192.168.x.x` lease, DHCP works and the problem is the VM (usually B1/B2).

### C2. In-guest DHCP recovery fails on Ubuntu 24.04 cloudimg
- Symptom: trying to fix a DOWN NIC from the console:
  - `sudo dhclient enp2s0` → `dhclient: command not found` (24.04 ships
    systemd-networkd, not isc-dhcp-client).
  - `sudo networkctl renew enp2s0` → `Interface enp2s0 is not managed by
    systemd-networkd` (no netplan config for it yet).
  - `sudo ip link set enp2s0 up` brings the link UP but still no IPv4.
- Fix: prefer recreate (B1/B2) or a full `reboot` (re-runs cloud-init→netplan→
  networkd natively). Manual path that CAN work: write
  `/etc/netplan/99-lan.yaml` (`renderer: networkd`, `enp2s0: {dhcp4: true}`),
  `sudo systemctl enable --now systemd-networkd`, `sudo netplan apply` — brittle;
  use only as a last resort.

### C3. multus "no valid IP addresses" → VM stuck Scheduling
- Symptom: VMI stuck `Scheduling`, no IP;
  `describe pod virt-launcher-<name>-*` shows
  `FailedCreatePodSandBox ... plugin type="multus" ... network "<nad>": cannot
  convert: no valid IP addresses`.
- Root cause: CLUSTER network config — the NAD's VM Network / cluster-network
  uplink (VLAN) can't hand out an IP. The VM manifest is fine.
- Fix: this is an admin task (Networks → Cluster/VM Networks). Either fix the VM
  network uplink, or recreate the VM pod-network-only for an internal IP. Stop the
  stuck VM to end the launcher retry loop (disk preserved). Do NOT report it
  "running" / "SSH ready".

## D. SSH access

### D1. Server is publickey-only → password login always rejected
- Symptom: `ssh user@host` → `Permission denied (publickey)`; the auth-method
  probe (`ssh -o PreferredAuthentications=none`) lists only `publickey`.
- Root cause: the VM's sshd has `PasswordAuthentication no` (or cloud-init's
  `ssh_pwauth` didn't apply — see B1), and your key isn't installed.
- Fix: set `ssh_pwauth: true` + a password in cloud-init (first boot), OR install
  the public key via cloud-init `ssh_authorized_keys` / the console
  `~/.ssh/authorized_keys`.

### D2. Claiming "SSH-ready" off a LAN IP alone
- Symptom: agent says SSH works because the VM has an IP — but login fails.
- Fix: PROVE it with `scripts/ssh-check.sh <ip> <user> [password]` (reachability,
  auth-method probe, real login via sshpass or python pexpect). Report the actual
  `whoami`/`hostname`/`enp2s0` output. `sshpass` is often not installed — pexpect
  is the fallback.

## E. Control-plane / platform

### E1. harvester-webhook down → VM create rejected
- Symptom: `kubectl apply` of a VM fails with
  `no endpoints available for service "harvester-webhook"` or
  `failed calling webhook validator.harvesterhci.io`.
- Root cause: the admission webhook Deployment is unhealthy (often an
  `ErrImagePull`/`ImagePullBackOff` on a bad image tag after a Helm/Fleet upgrade).
  NOT a manifest problem; you already have full kubectl access.
- Fix: diagnose
  `kubectl get pods -n harvester-system | grep -E 'harvester-webhook|harvester-[0-9a-f]{6,}'`
  and the Deployment images; report to the admin (Fleet/Helm-managed — don't patch
  system deployments without confirmation). Apply the VM once the webhook is
  `1/1 Running`.

### E2. "Rate limit exceeded: too many actions" from the tool layer
- Symptom: the agent refuses to run kubectl/ssh with
  "Rate limit exceeded: too many actions in the last hour", with nothing in the
  cluster wrong.
- Root cause: the RantaiClaw per-hour action budget
  (`autonomy.max_actions_per_hour`, default low ~20) — a REAL but SILENT cap (not
  logged), not an LLM/API 429 and not a cluster fault. A complex create burns many
  tool calls (`max_tool_iterations`), so a couple of operations exhaust it. The
  in-memory counter resets on daemon restart.
- Fix (operator side, not in-skill): raise `autonomy.max_actions_per_hour` in
  `config.toml` and restart the daemon. In-skill behavior: don't present it as a
  cluster problem, and don't use it as an excuse to skip a verify you CAN still
  run; re-read state when able and report the REAL state, never status from memory.

## F. Power / object hygiene

### F1. Leftover PVC after delete → collides with the new clone
- Symptom: recreating a VM hits a stale `<name>-disk-0` PVC.
- Fix: on delete-for-rebuild, also
  `kubectl delete pvc <name>-disk-0 -n <ns> --ignore-not-found` and confirm it's
  gone before re-applying.

### F2. `spec.running` deprecation warning
- Symptom: `kubectl apply` warns `spec.running is deprecated, please use
  spec.runStrategy instead`.
- Fix: cosmetic — the VM still applies. Use `spec.runStrategy: RerunOnFailure`
  (or `Always`) in new manifests; `Halted` ↔ `RerunOnFailure` to stop/start.

## G. Storage health (Longhorn)

### G1. Longhorn volumes `degraded` + `VolumeResizeFailed` on a single-node cluster
- Symptom: `kubectl get volumes.longhorn.io -n longhorn-system` shows volumes
  `attached degraded` (and some `detached unknown`); PVC resize fails with
  `cannot expand volume before replica scheduling success` (a `VolumeResizeFailed`
  event). VMs still run, but data redundancy is gone and resizes are blocked.
- Root cause: Longhorn `default-replica-count = 3` (the default) but the cluster has
  only ONE schedulable node. 3 replicas can never be placed on 1 node → every volume
  is permanently `degraded`, and resize is blocked until replicas schedule.
  Confirm: `kubectl get settings.longhorn.io default-replica-count -n longhorn-system -o jsonpath='{.value}'`
  (=3), `kubectl get nodes.longhorn.io -n longhorn-system` (1 node), and per-volume
  `kubectl get volumes.longhorn.io <vol> -n longhorn-system -o jsonpath='{.spec.numberOfReplicas} {.status.robustness}'`.
- Fix (single-node mode): set replica count to 1.
  - New volumes: `kubectl patch settings.longhorn.io default-replica-count -n longhorn-system --type merge -p '{"value":"1"}'`.
  - Existing degraded volumes: `kubectl patch volumes.longhorn.io <vol> -n longhorn-system --type merge -p '{"spec":{"numberOfReplicas":1}}'` (repeat per volume) → they become `healthy`, then resize works.
  - This is a STORAGE mutation — state the impact (redundancy stays 1 until more nodes
    are added) and CONFIRM with the user before patching. The real long-term fix for
    redundancy is adding nodes; replica=1 is the correct setting for an intentional
    single-node setup.
  - After fixing, re-check `kubectl get volumes.longhorn.io -n longhorn-system` —
    don't claim healthy without re-reading.
