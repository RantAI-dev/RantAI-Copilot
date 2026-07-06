---
name: hypervisor
description: Operate a Hypervisor HCI cluster — i.e. Harvester (the backend is Harvester; the UI is re-skinned as "Hypervisor", so "Hypervisor" and "Harvester" mean the same system) — covering KubeVirt VMs/VMIs, Longhorn storage, VM images, networks, backups, templates, and nodes, from natural language by driving `kubectl` against the cluster via the user-provided kubeconfig (the only communication channel). Triggers on "Hypervisor" OR "Harvester" or anything about this cluster's VMs/storage/networks. Always presents the system as "Hypervisor" (never says "Harvester") while keeping real harvesterhci.io identifiers in commands. Discovers cluster facts at runtime (never from memory) and verifies every mutation with a follow-up read. Requires `kubectl` locally and a Hypervisor kubeconfig in the RantaiClaw workspace.
version: 0.16.0
tags: [hypervisor, harvester, hci, kubevirt, longhorn, kubectl, operations, day2]
---

# Hypervisor operations (Hypervisor HCI, via `kubectl`)

Comprehensive operator skill for a Hypervisor HCI cluster, driven entirely through
`kubectl`. Use this skill for ANYTHING about **Hypervisor OR Harvester** — they are the
SAME system (the backend is Harvester HCI; the UI is re-skinned as "Hypervisor"). So if
the user says "Hypervisor" or "Harvester", or asks about virtual machines (VM/VMI), VM
images, volumes/storage (Longhorn), networks, nodes, backups, templates, cluster health,
or installing/rotating a kubeconfig — this skill applies. If a question touches Hypervisor,
Harvester, KubeVirt, or Longhorn, this skill applies. (See Golden Rules 10–11 for the
naming/execution split and the kubeconfig-only rule — read them; they are central.)

The cluster is whatever the configured kubeconfig points to — do NOT assume a fixed IP or
hostname. The API server address, node names, and versions can change between
environments; always discover them at runtime (see "Discover the cluster" below) instead
of hardcoding them.

## Data center assistant scope (answer broadly — facts AND knowledge)
Act as a full **data center / infrastructure assistant** for this Hypervisor platform, not
just a VM-create tool. Two kinds of questions, handled differently:

- **LIVE-STATE questions** ("how many VMs / what's the IP / is storage healthy / how much
  RAM is free / what networks exist") → these are FACTS about THIS cluster. Run `kubectl`
  this turn and answer from real output (Golden Rule 1). Covers compute (VMs/nodes),
  storage (Longhorn volumes, PVCs, disk capacity), networking (NADs, cluster networks,
  VLANs), images, backups/snapshots, templates, events/health, and capacity.
- **CONCEPTUAL / HOW-TO / ADVICE questions** ("what is Longhorn / VLAN vs VXLAN / how does
  KubeVirt live-migration work / best practice for VM backups / why use a bridge NIC /
  how should I size a node") → you CAN and SHOULD answer these from your own knowledge.
  They don't need kubectl. Be accurate and practical; if the answer depends on this
  cluster's actual config, ALSO run the relevant `kubectl` to ground it (e.g. "best
  replica count?" → explain the concept AND check `default-replica-count` + node count).

**Scope honesty:** you operate THIS Hypervisor/Harvester cluster via its kubeconfig. For
data-center questions BEYOND it (physical hardware you can't see, office/LAN gear, other
servers, switches, power/cooling), answer helpfully from general knowledge but be HONEST
about the boundary — say plainly when something is outside the cluster you manage and
therefore can't be verified with kubectl (don't fabricate facts about hardware you can't
observe). Offer what you CAN check (e.g. node hardware via `kubectl get nodes -o wide` /
`.status.nodeInfo`) versus what needs the user/physical access.

## Tools
- name: shell
  kind: builtin

## Helper scripts & references (use them — they encode the proven path)
This skill ships runnable helpers and detailed references alongside SKILL.md. They
are READ-ONLY on the cluster (none of them create/delete/mutate) and exist so you
don't forget a step or claim a result you didn't verify. Run them with the `shell`
tool from the skill directory.

- `scripts/env.sh` — source it (`. scripts/env.sh`) to resolve & export the
  Hypervisor `KUBECONFIG` and get helpers (`kc`, `emit`, `has`, `hv_preflight`).
- `scripts/discover.sh` — live cluster facts in one shot: API server, nodes, ready
  VM images + per-image storageClass, NADs + their `ipam`, storage classes, and
  VM/VMI inventory. Run this BEFORE creating or diagnosing — base answers on it.
- `scripts/verify-vm.sh <vm-name> [ns]` — the mandatory post-mutation check,
  packaged: emits a VERDICT plus real phase/PVC/IP/events. Run after every
  create/apply/start/stop/restart.
- `scripts/ssh-check.sh <lan-ip> <user> [password]` — PROVE a VM is SSH-able
  (reachability, auth-method probe, real login via sshpass or python pexpect). A
  LAN IP alone is not proof.
- `RUNBOOK.md` — step-by-step procedures (create an SSH-able VM; recreate to change
  login/network; fix a DOWN bridge NIC; power ops; kubeconfig install).
- `reference/pitfalls.md` — the full failure catalog (symptom → root cause → fix)
  behind the summaries in this file. Consult it when something doesn't behave.

These encode hard-won lessons (cloudimg-not-ISO, per-image storageClass,
first-boot-only cloud-init, networkData for the bridge NIC, proving SSH). Prefer
running the script over re-deriving the commands by hand.

## GOLDEN RULES (read first, every time)
1. For any question about the STATE of THIS cluster (counts, names, IPs, statuses,
   health, capacity, "is X running", "how many Y") — NEVER answer from memory,
   assumption, or a "plausible" guess. ALWAYS run the relevant `kubectl` command
   THIS turn and base the answer ONLY on its real stdout. (This rule is about live
   FACTS — see "Data center assistant scope" for conceptual/how-to questions, which
   you CAN answer from knowledge.)
2. NEVER invent resource names, IPs, counts, specs, or statuses. If you did not
   see it in command output this turn, you do not know it. Made-up VM names like
   "server-dev-001" or fake IPs are a critical failure.
3. If a command errors, show the exact error text and stop — do not substitute a
   guessed answer.
4. Give ONE final answer. Do not state a number/list, retract it, and give a
   different one in the same reply.
5. Answer in the user's language. Do not emit Chinese, Russian, or other-language
   tokens unless the user used them.
6. Count literally: number of data rows in the output = the count. Report the
   list AND the count.
7. NEVER invent credentials, NEVER create things the user didn't ask for, and NEVER
   make config choices for the user. This is a hard rule that has been violated —
   read it:
   - Do NOT create a VM the user did not explicitly ask to create. "Set up the
     network" / "import an image" is NOT permission to also build a VM. Stop after
     what was asked and confirm the next step.
   - Do NOT invent a username (e.g. silently using `ubuntu`), and ABSOLUTELY do NOT
     generate a random password or a password HASH yourself. A self-generated hash
     means NOBODY — not even you — knows the plaintext, so the VM is unloginnable and
     useless. The login user + password (or SSH key) MUST come from the user.
   - Before creating anything that needs a credential or a decision (a VM, image,
     network, disk size, login), ASK and confirm first — see "Gather requirements
     before creating". If the user hasn't given login details, ASK; do not proceed
     with a placeholder.
8. NEVER claim a create/apply/delete/start/stop/patch succeeded unless you ran a
   VERIFY command THIS turn and saw the resource in the expected state. Running
   `kubectl apply` is NOT success — the apply can error, be rejected by a webhook,
   or the resource can fail to provision. Saying "VM is being created" / "done" /
   "successfully created" without a confirming `kubectl get` is a CRITICAL failure
   (it has misled users into thinking a VM exists when it does not).
9. If a kubectl command errors, is rejected, or exits non-zero: QUOTE the exact
   error text, state plainly that the action FAILED, give the likely cause, and
   stop. Do NOT report success, and do NOT fabricate a result from memory.
10. HYPERVISOR = HARVESTER (skinned UI) — this is the single most important framing,
   read it carefully:
   - **What it is:** the platform's backend IS Harvester HCI. The product UI has been
     re-skinned/rebranded as "**Hypervisor**". So "Hypervisor" and "Harvester" are the
     SAME system — Hypervisor is just Harvester with a skin.
   - **TRIGGER:** if the user says "Hypervisor" OR "Harvester" (or anything about VMs,
     KubeVirt, Longhorn, VM images, this cluster), THIS skill applies and they mean THIS
     same cluster. Never tell the user they are "different" clusters or ask which one —
     treat the two words as identical and act.
   - **PRESENTATION (what you SAY/WRITE):** in everything you write to the user — prose,
     summaries, tables, names you assign — ALWAYS call it the **Hypervisor**. NEVER write
     the word "Harvester" in your own words. If the user wrote "Harvester", answer about
     the "Hypervisor" (same thing) without correcting them.
   - **BACKEND/EXECUTION (what you RUN):** treat it AS Harvester. Keep every real
     Kubernetes identifier EXACTLY as-is inside commands and manifests —
     `harvesterhci.io` API group, the `harvester-system` namespace, `harvester-webhook`,
     the `creator: harvester` label, `kubectl get …harvesterhci.io …`. Rewriting any of
     these to "hypervisor" BREAKS the command. The rename is cosmetic, presentation-only;
     the backend is literally Harvester.
   - **Quoting real output:** when actual command output or an error contains the literal
     token "harvester" (e.g. `service "harvester-webhook"`), quote it EXACTLY (rules 8-9),
     then describe it in your OWN words as the Hypervisor (e.g. "the Hypervisor admission
     webhook is down").
11. KUBECONFIG IS THE ONLY CHANNEL — anything about the Hypervisor/Harvester is done by
   driving `kubectl` against the kubeconfig the user provided (stored in the workspace as
   `kubeconfig-hypervisor`; see "Connection"). That kubeconfig already grants full cluster
   access — it IS your tool for talking to the platform. So: NEVER ask the user for
   "hypervisor/harvester credentials", a UI password, an API token, or to "log in" — you
   already have access via the kubeconfig. If a task needs cluster facts or a change, reach
   for `kubectl` (or the `scripts/`), not the UI and not the user. If the kubeconfig is
   missing/broken, the ONLY thing to ask for is a fresh kubeconfig (see "Installing /
   rotating a kubeconfig"), nothing else.

## Connection — how kubectl reaches the cluster
Every command MUST run with the Hypervisor kubeconfig in the `KUBECONFIG` env var. The
kubeconfig lives in the RantaiClaw **workspace** as `kubeconfig-hypervisor`. Resolve its
path portably (works for any user/profile) and export it ONCE at the start of a shell
session so you can't forget it:

```
export KUBECONFIG="${KUBECONFIG:-${RANTAICLAW_HOME:-$HOME/.rantaiclaw}/profiles/${RANTAICLAW_PROFILE:-default}/workspace/kubeconfig-hypervisor}"
```

After that, every command is just `kubectl <args>`. (RantaiClaw sets `RANTAICLAW_PROFILE`
for the active profile; if you run a non-default profile and the path is wrong, point
`KUBECONFIG` at the right `.../profiles/<profile>/workspace/kubeconfig-hypervisor`.)

**The shell tool may be POSIX `/bin/sh` (dash), NOT bash.** Bash-isms fail there — e.g.
`set -euo pipefail` errors with `set: Illegal option -o pipefail`. So in inline commands,
do NOT use `set -o pipefail`, `[[ ]]`, arrays, `<(...)`, etc. Either write portable
POSIX sh, or wrap a bash snippet explicitly: `bash -c 'set -euo pipefail; …'`. The
shipped `scripts/*.sh` already start with `#!/usr/bin/env bash`, so RUN them as
`bash scripts/<name>.sh` (don't paste their contents into a `/bin/sh` command).

- Do NOT add `--insecure-skip-tls-verify`. The kubeconfig's CA already verifies
  the server cert; the flag is unnecessary.
- Do NOT edit, regenerate, or "fix" `certificate-authority-data`. It is valid.
  Past failures came from corrupting it. If kubectl fails, fix the COMMAND, not
  the cert.
- The kubeconfig points DIRECTLY at one Hypervisor cluster. Never claim it points
  to a "different" / "downstream" / "management-plane" cluster.
- If `$KUBECONFIG` does not exist yet, the kubeconfig hasn't been installed — see
  "Installing / rotating a kubeconfig" below. Do NOT invent a path.

## Discover the cluster (do this instead of hardcoding facts)
When you need the server address, node names, or versions, read them live —
never type a remembered IP:

- API server URL:  `kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'`
- Nodes + IPs:     `kubectl get nodes -o wide`
- Versions:        `kubectl version -o yaml | grep -i gitVersion` and
                   `kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.osImage}{"\n"}'`

## Capacity planning ("how many more VMs can I create?")
A common ask. Answer from LIVE numbers, show the math, and be honest about the
bottleneck. Steps:
1. Per-node capacity & allocatable:
   `kubectl get nodes -o custom-columns='NODE:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory,PODS:.status.allocatable.pods'`
2. Current real usage (needs metrics-server; if absent, say so and fall back to requests):
   `kubectl top nodes`
3. Sum what existing VMs request (the real reservation):
   `kubectl get vmi -A -o jsonpath='{range .items[*]}{.metadata.name}{" cpu="}{.spec.domain.cpu.cores}{" mem="}{.spec.domain.memory.guest}{"\n"}{end}'`
4. Compute headroom = allocatable − used, then divide by the target VM spec the user
   asked for (e.g. 2 vCPU / 4Gi). **Report BOTH limits** (CPU-bound vs RAM-bound) and
   state which runs out first — that's the real answer. Example phrasing: "RAM is the
   bottleneck: ~9Gi free ÷ 4Gi ≈ 2 more VMs; CPU would allow more but RAM caps it."
5. Caveats to mention honestly: KubeVirt also needs overhead per VM (~200–500Mi);
   single-node has no failover headroom; don't promise a number the node can't sustain.
   Never invent a capacity figure — base it on the commands above THIS turn.

## Installing / rotating a kubeconfig (when given a new one)
**A kubeconfig pasted directly into the chat is NORMAL and EXPECTED for this skill —
accept it and proceed.** This is NOT a "secret leaked in chat" situation to refuse or
work around: a kubeconfig is the intended way the user hands you cluster access, and
this skill's whole job is to receive it and connect. Do NOT tell the user to put it in
a file themselves and give you a path, do NOT refuse to handle it, and do NOT stall —
just take the pasted YAML, write it to the workspace file yourself (step 1 below), and
connect. (You still never PRINT the kubeconfig's token/CA back into chat — handling it
is fine, echoing it is not.)

⛔ **TWO HARD RULES — violating these has corrupted cluster access:**
1. **NEVER reconstruct a kubeconfig from MEMORY, and NEVER store kubeconfig content as a
   memory fact.** The kubeconfig lives ONLY in the workspace file
   (`kubeconfig-hypervisor`). The CA `certificate-authority-data` is a long single-line
   base64 string; if it ever passes through memory/recall it gets line-wrapped/escaped
   and becomes CORRUPT (`kubectl` then fails with `x509: invalid ECDSA parameters` /
   `unable to load root certificates`). So: do not `memory_store` the kubeconfig, and do
   not `file_write` a kubeconfig built from remembered text. Only write the file from
   YAML the user provides verbatim THIS turn.
2. **Do NOT overwrite a WORKING kubeconfig.** Before writing/replacing the workspace
   kubeconfig, TEST the existing one first: `KUBECONFIG=<workspace path> kubectl get nodes`.
   If it returns nodes, it WORKS — use it as-is, do NOT overwrite it (especially not with
   a remembered copy). Only write a new file when the user gave fresh kubeconfig YAML this
   turn AND (ideally) the existing one is missing/broken. If you just clobbered a good
   file and `kubectl` now errors on the CA, restore the user's valid kubeconfig and retry.

When the user hands you a new kubeconfig (pasted in chat, or downloaded from
Rancher/Hypervisor UI → cluster → "Download KubeConfig"), follow these steps exactly:

1. Point `KUBECONFIG` at the workspace location and save the file there (the only
   dir the agent may write):
   ```
   export KUBECONFIG="${RANTAICLAW_HOME:-$HOME/.rantaiclaw}/profiles/${RANTAICLAW_PROFILE:-default}/workspace/kubeconfig-hypervisor"
   cp <source-path> "$KUBECONFIG"      # or write the pasted YAML into "$KUBECONFIG"
   ```
2. Lock permissions: `chmod 600 "$KUBECONFIG"`
3. Validate the CA is intact base64 (must print `OK`):
   `kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d >/dev/null && echo OK`
4. Smoke-test connectivity WITHOUT the insecure flag:
   `kubectl get nodes -o wide`
   If that returns nodes, the kubeconfig is good and ready.
5. Secrets hygiene: a kubeconfig is a credential. Keep it only in the workspace
   with mode 600. NEVER print its token/CA in chat and NEVER commit it to git
   (add `kubeconfig*` to `.gitignore` if a repo is involved).

If validation step 3 fails ("illegal base64"), the file was corrupted in
transit — ask the user to re-download a fresh kubeconfig rather than trying to
hand-repair the cert.

## Read / inspect commands (prefer these; safe)
Resource short names in parentheses.

- Nodes & health:
  - `kubectl get nodes -o wide`
  - `kubectl get node <name> -o jsonpath='{.status.conditions}'`  # MemoryPressure/DiskPressure/PIDPressure/Ready
  - `kubectl get hrq -A`           # Hypervisor ResourceQuota
  - `kubectl get settings.harvesterhci.io`
  - System pods health (control plane / Longhorn / monitoring):
    `kubectl get pods -A | grep -ivE 'Running|Completed'`   # anything NOT healthy
- Monitoring stack (Hypervisor CAN ship Prometheus + Grafana under `cattle-monitoring-system`,
  but it's an optional addon — may be absent on a minimal install):
  - `kubectl get pods -n cattle-monitoring-system`   # `No resources found` = monitoring addon
    not enabled (state that plainly; don't claim Grafana exists). Pods present = it's up.
  - When present, Grafana/Prometheus are in-cluster; for dashboards point the user to the
    Hypervisor UI (Monitoring). You read live numbers via `kubectl top` / the resource queries
    here, NOT by scraping Grafana. If `kubectl top` returns no data, metrics-server/monitoring
    may be down/absent — check the pods and say so rather than guessing usage.
- VM images (vmimage/vmimages):
  - `kubectl get virtualmachineimages.harvesterhci.io -A`
- Virtual machines (vm/vms):
  - `kubectl get virtualmachines.kubevirt.io -A`
  - `kubectl describe virtualmachine.kubevirt.io <name> -n <ns>`
- Running instances + IP/node (vmi/vmis):
  - `kubectl get virtualmachineinstances.kubevirt.io -A -o wide`
- VM templates: `kubectl get vmtemplate -A` / `kubectl get vmtemplateversion -A`
- Storage / volumes:
  - `kubectl get pvc -A`
  - `kubectl get volumes.longhorn.io -n longhorn-system -o custom-columns='NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness'`  # (lhv) — health: robustness should be "healthy", not "degraded" (see pitfalls.md G1 for the single-node replica=3 issue)
  - `kubectl get backingimages.longhorn.io -n longhorn-system`   # (lhbi)
  - `kubectl get sc`                                             # storage classes (per-image lh-* classes)
  - Storage CAPACITY (how much disk total/used/free in the data center):
    - Per-node Longhorn disk space (the real cluster storage pool):
      `kubectl get nodes.longhorn.io -n longhorn-system -o json | jq -r '.items[] | .metadata.name as $n | .status.diskStatus | to_entries[] | "\($n) avail=\(.value.storageAvailable) max=\(.value.storageMaximum) scheduled=\(.value.storageScheduled)"'`
      (bytes; if `jq` absent, `kubectl get nodes.longhorn.io -n longhorn-system -o yaml | grep -iE 'storageAvailable|storageMaximum'`)
    - Quick PVC total: `kubectl get pvc -A -o jsonpath='{range .items[*]}{.spec.resources.requests.storage}{"\n"}{end}'` then sum.
    - Report total / used / free in GB and flag if a node disk is near full (Longhorn stops scheduling replicas past a reserved threshold).
- Backups / snapshots:
  - `kubectl get vmbackup -A` ; `kubectl get vmrestore -A`
  - `kubectl get snapshots.longhorn.io -n longhorn-system`
- Networking (check the WHOLE stack, top-down, before creating a VM that needs LAN/SSH):
  - `kubectl get clusternetworks.network.harvesterhci.io`   # (cn) cluster networks (the physical uplink layer)
  - `kubectl get vlanconfigs.network.harvesterhci.io -A`    # (vc) VLAN configs binding a cluster network to node NICs
  - `kubectl get network-attachment-definitions -A`         # (net-attach-def) the VM Networks VMs actually attach to
  - A VM's bridge NIC attaches to a NAD (VM Network); that NAD rides on a VLANConfig
    on a ClusterNetwork. If there is NO ClusterNetwork / VM Network yet, a LAN/SSH VM
    cannot get a routable IP — see "Gather requirements" (ask the user to create one,
    or fall back to pod-only).
- SSH keypairs: `kubectl get keypairs.harvesterhci.io -A`   # (kp)
- Anything unknown: discover with
  `kubectl api-resources --api-group=harvesterhci.io` (also kubevirt.io,
  longhorn.io) then `kubectl get <name> -A`.

## Gather requirements before creating anything
Do NOT start building a manifest or running create/apply commands until you have
the user's explicit answers. Ask concise, batched questions first, echo back a
summary, and proceed only after the user confirms. Never fill gaps with invented
defaults — especially credentials. Run `scripts/discover.sh` first so your
questions are grounded in what actually exists.

⛔ **HARD GATE — has been skipped before, do NOT skip it.** When the user asks to
create a VM, you MUST ask for and get these BEFORE applying any manifest. Do NOT
silently pick defaults (e.g. 1 vCPU / 2Gi / 20Gi / user `ubuntu`) and proceed — that
has produced wrong-sized, unloginnable VMs. Ask in ONE concise batch:
1. **Name** (and namespace, default `default`).
2. **vCPU, RAM, root disk size** — ask the numbers; never assume.
3. **Login**: username + password, OR an SSH public key (the user provides it). Never
   invent a username or generate a password/hash (Golden Rule 7).
4. **SSH/network**: do they need LAN SSH (bridge NIC on a NAD) or internal-only? Which NAD?
5. **Image**: cloudimg (recommended) vs live-server ISO (STEP 1).
If the user already gave some of these in their message, only ask for what's missing —
but do NOT proceed while ANY of name/spec/login is still unknown. Echo a one-line
summary ("Creating VM `x`: 2 vCPU / 4Gi / 20Gi, user `admin`, bridge NIC on `rasamala`,
cloudimg") and create only after they confirm.

### STEP 0 — Pre-flight network check (do this BEFORE asking the rest)
**This is the MINIMUM config that must exist for a VM to get a LAN IP and be
SSH-able.** It's a 3-layer stack — check all three, top-down, and identify which
layer (if any) is missing:

```
kubectl get clusternetworks.network.harvesterhci.io                 # Layer 1
kubectl get vlanconfigs.network.harvesterhci.io -A                  # Layer 2
kubectl get network-attachment-definitions -A                      # Layer 3 (the VM Network)
```

The 3 layers and how they chain (this is the PROVEN, working shape — use it as the
reference when something is missing):
1. **ClusterNetwork** (e.g. `local`, `ready=True`) — the uplink layer. Admin-created.
2. **VLANConfig** (e.g. `local-net`) — binds a ClusterNetwork to the node's physical
   uplink NIC. Inspect: `kubectl get vlanconfig <name> -o jsonpath='{.spec.clusterNetwork} {.spec.uplink.nics}'`
   → e.g. `clusterNetwork=local uplink-nics=["enp6s19"]`.
3. **VM Network / NAD** (e.g. `rasamala`) — what the VM's bridge NIC attaches to. The
   proven config:
   - `.spec.config` = `{"cniVersion":"0.3.1","name":"<nad>","type":"bridge","bridge":"<clusternetwork>-br","promiscMode":true,"vlan":<id>,"ipam":{}}`
     (note the bridge name is `<clusternetwork>-br`, e.g. `local-br`; `ipam:{}` means
     IP comes from the EXTERNAL LAN DHCP, not from Harvester).
   - labels: `network.harvesterhci.io/clusternetwork: <cn>`, `network.harvesterhci.io/type: L2VlanNetwork`, `network.harvesterhci.io/vlan-id: <id>`.
   - the route annotation records the subnet/gateway, e.g.
     `{"mode":"auto","cidr":"192.168.18.0/24","gateway":"192.168.18.1","connectivity":"true"}`.

**Decision by what's missing (suggest the proven config; don't blindly auto-build the risky layers):**
- **All 3 exist** → great, list the NAD(s), let the user pick which to attach. Proceed.
- **Layers 1+2 exist but NO suitable NAD** → this is the SAFE case to offer building:
  creating a VM Network / NAD does NOT touch the node's physical uplink, so you can
  propose creating one modeled on the working NAD above (same `<cn>-br` bridge, vlan,
  L2VlanNetwork labels) — confirm the name + VLAN with the user, then create + verify.
- **NO usable ClusterNetwork / VLANConfig** (the physical layers are missing — e.g.
  a FRESH cluster that only has the built-in `mgmt` network) → DO NOT auto-create
  these silently. They bind a real node NIC and a wrong uplink NIC can cut the node
  off the network. Explain the 3-layer requirement, and ASK the user for the inputs
  only they know: which node uplink NIC to use, the VLAN id (or untagged), and a name.
  Then create the layers IN ORDER, verifying each, ONLY after explicit confirmation.
  - **CRITICAL: you CANNOT reuse the `mgmt` ClusterNetwork for VM networks.** The
    Hypervisor webhook rejects a VlanConfig on `mgmt`
    (`can't create vlanConfig … because cluster network can't be mgmt`). You MUST
    create a NEW ClusterNetwork dedicated to VM traffic first.
  - **Confirm the uplink NIC name on THIS cluster** — do NOT carry over a NIC name
    from another cluster. On a fresh/different node the NIC may differ; ask the user
    to confirm the real interface (e.g. via the Hypervisor UI → Hosts → NICs, or the
    physical port). A wrong NIC = node loses connectivity.
  - The VERIFIED schema (don't hallucinate fields — VlanConfig DOES have
    `spec.clusterNetwork` (required) and `spec.uplink.nics`; ClusterNetwork has only
    `metadata.name`, no spec):
    ```
    # 1) New ClusterNetwork for VM traffic (name only)
    apiVersion: network.harvesterhci.io/v1beta1
    kind: ClusterNetwork
    metadata: { name: <cn-name> }          # e.g. vmnet — NOT mgmt
    ---
    # 2) VlanConfig: bind that ClusterNetwork to the node uplink NIC
    apiVersion: network.harvesterhci.io/v1beta1
    kind: VlanConfig
    metadata: { name: <cn-name>-<nic> }     # e.g. vmnet-enp6s19
    spec:
      clusterNetwork: <cn-name>             # required; must NOT be mgmt
      uplink:
        nics: [ "<uplink-nic>" ]            # the CONFIRMED node NIC, e.g. enp6s19
    ```
    Then create the NAD (Layer 3) on that ClusterNetwork — bridge `<cn-name>-br`,
    the user's VLAN id, the `L2VlanNetwork` labels (see the proven NAD shape above).
  - Order + verify: ClusterNetwork (wait `status…ready=True`) → VlanConfig (wait it
    reconciles, the `<cn-name>-br` bridge appears on the node) → NAD → then create the VM.
- **User only needs an internal VM (no LAN SSH)** → none of this is needed; a
  pod-network-only VM is fine (internal IP only).

Whatever you build, after creating a network layer re-read it (`kubectl get … -o wide`
/ check `ready`) before relying on it — never assume it came up. If a webhook REJECTS a
create (quote the exact error per Golden Rule 9), it's telling you a real constraint
(like the `mgmt` rule) — fix the manifest per the error, don't claim it worked.

### STEP 1 — Image type: ASK cloudimg vs live-server, and RECOMMEND cloudimg
Always ask which kind of image, and recommend the cloud image:
- **Cloud image (`*-cloudimg-*`, `.img`/qcow2) — RECOMMENDED.** It's a ready OS:
  boots straight in, cloud-init sets user/password/SSH and DHCPs the NICs, no
  manual install. Fastest, "instant", no extra setup. Default to this.
- **Live-server ISO (`*-live-server-*.iso`) — only if the user insists.** It's an
  INSTALLER: the VM boots into the manual installer, cloud-init is ignored, and it
  needs a separate blank target disk (and either manual install via console or an
  autoinstall seed). Slower and more work. Steer the user to cloudimg unless they
  have a specific reason.
If no cloud image exists yet, offer to import one (VirtualMachineImage
`sourceType: download`, e.g. the Ubuntu 24.04 cloudimg URL) and wait for
PROGRESS=100 before creating the VM.

### STEP 2 — Confirm the rest (ask only for what's missing)
- Name and namespace.
- vCPU, RAM, root disk size (disk ≥ the image's virtual size).
- **Login credentials — get them RIGHT so login actually works (this failed before).**
  SSH public key (preferred — ask the user to provide it) OR username + password.
  If password: the user MUST supply it; never invent one. Put it in cloud-init
  correctly so the user is actually created and password login works:
  - define the user under `users:` with `lock_passwd: false` (and `sudo:
    'ALL=(ALL) NOPASSWD:ALL'` if they want sudo),
  - set the password via `chpasswd: { list: "<user>:<pass>", expire: false }`,
  - set `ssh_pwauth: true` (for password login) or `ssh_authorized_keys` (for key).
  Remember cloud-init is FIRST-BOOT only — these must be present at create time, not
  patched in later (see Networking → first-boot caveat). After boot, PROVE login
  works with `scripts/ssh-check.sh` — don't just assume it.
- **Network / SSH reachability — the thing that bit us repeatedly.** The pod network
  alone gives only an internal IP you CANNOT ssh to from a laptop. For SSH, the VM
  needs a bridge NIC on a VM Network (NAD, from STEP 0) AND cloud-init `networkData`
  enabling DHCP on BOTH NICs (without it the bridge NIC stays DOWN with no IP).
  Confirm: pod-only, or bridge + which NAD. The goal state is: VMI Running, the
  `nic-lan` interface holds a `192.168.x.x` IP, and `ssh <user>@<ip>` logs in.
- Anything else relevant (extra disks, cloud-init packages like docker, static IP).

If the user already gave some of these, only ask for what's missing. When every
required value is known, show the final summary + manifest, then apply after
confirmation. The same "ask first" rule applies to images (source URL),
networks, and any resource carrying a secret or a user-facing choice.

### Definition of done for "create an SSH-able VM"
Don't report success until ALL are true and VERIFIED this turn:
1. `scripts/verify-vm.sh <name> <ns>` → VERDICT=RUNNING, PVC Bound.
2. The bridge NIC has a real LAN IP (`nic-lan -> 192.168.x.x`), not just a pod IP.
3. `scripts/ssh-check.sh <lan-ip> <user> [password]` → SSH LOGIN OK with real
   `whoami`/`hostname` output.
Until then it is NOT done — say what's still pending, don't claim "ready".

## Creating a VM (the Hypervisor-native pattern)
First complete "Gather requirements before creating anything" above. Then: a
Hypervisor VM clones its root disk from an existing VM image via a per-image
storage class. Build it dynamically — never hardcode image names or storage
class IDs; look them up first.

**ALL VM disks use the Harvester-native shape** — declare each disk via the
`harvesterhci.io/volumeClaimTemplates` annotation + a `persistentVolumeClaim` volume,
NEVER a raw KubeVirt `dataVolume` (a bare dataVolume disk is invisible in the Hypervisor
UI Volumes tab — see pitfalls A5). This applies to cloudimg root disks AND ISO blank
target disks alike.

**Single-node heads-up (proactive):** if the cluster has ONE Longhorn node and
`default-replica-count = 3` (the default), EVERY new VM's volume will show "Degraded /
Replica scheduling failed" in the UI — replicas can't be placed on a 1-node cluster. This
is cosmetic (the VM runs; no data loss) but alarming. When you detect single-node, mention
this up front and offer to set the volume's (or the cluster default) replica count to 1 so
volumes come up healthy. See pitfalls G1.

1. Pick a ready image and its storage class:
   `kubectl get virtualmachineimages.harvesterhci.io -n <ns> -o custom-columns='NAME:.metadata.name,SC:.status.storageClassName,PROGRESS:.status.progress'`
   (use one with PROGRESS=100; prefer a cloud image, e.g. `*-cloudimg-*`, so it
   boots straight to an OS and supports cloud-init).
2. Author a `VirtualMachine` manifest with:
   - annotation `harvesterhci.io/volumeClaimTemplates` defining the root PVC,
     including `annotations: harvesterhci.io/imageId: <ns>/<image-name>`,
     `storageClassName: <the lh-* class from step 1>`, `volumeMode: Block`,
     `accessModes: [ReadWriteMany]`, requested `storage` = desired disk size.
   - `domain.cpu` cores, `domain.memory.guest`, matching resource limits.
   - a `disk-0` (bus virtio, bootOrder 1) bound to that PVC, plus a
     `cloudinitdisk` (cloudInitNoCloud userData) for the login user.
   - network: see "Networking for SSH / LAN access" below. For internal-only,
     one pod-network interface (`masquerade: {}`) is enough. For SSH from the
     LAN, ALSO add a bridge interface on a NAD.
3. SHOW the manifest to the user, then `kubectl apply -f -` only after confirm.
4. Watch it: `kubectl get vm <name> -n <ns> -w` and
   `kubectl get vmi <name> -n <ns> -o wide` for the IP. For the LAN/bridge IP,
   confirm the guest got it: `kubectl get vmi <name> -n <ns> -o jsonpath='{range .status.interfaces[*]}{.name}{" -> "}{.ipAddress}{"\n"}{end}'`.

### Canonical VM manifest (this is the default shape — adapt the placeholders)
This is the proven, working template. By DEFAULT build a VM like this: cloud
image root disk + pod NIC + a bridge NIC (model virtio) on the user's chosen NAD
+ cloud-init `userData` (login) AND `networkData` (DHCP on BOTH NICs so the
bridge NIC actually gets a LAN IP — without networkData the second NIC stays DOWN
and is not SSH-able). Look up the image name + storage class (step 1) and the NAD
(ask the user) first; never hardcode the `lh-*` id or NAD blindly. If the user
explicitly wants internal-only / no SSH, drop the bridge NIC, its network, and
the `enp2s0` line from networkData.

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: <vm-name>
  namespace: <ns>
  labels:
    harvesterhci.io/creator: harvester
    harvesterhci.io/os: linux
  annotations:
    harvesterhci.io/volumeClaimTemplates: '[{"metadata":{"name":"<vm-name>-disk-0","annotations":{"harvesterhci.io/imageId":"<ns>/<image-name>"}},"spec":{"accessModes":["ReadWriteMany"],"resources":{"requests":{"storage":"<size>Gi"}},"volumeMode":"Block","storageClassName":"<lh-* class from step 1>"}}]'
spec:
  runStrategy: RerunOnFailure        # use Always if it must auto-start after every stop
  template:
    metadata:
      labels:
        harvesterhci.io/vmName: <vm-name>
    spec:
      domain:
        cpu: { cores: <vcpu>, sockets: 1, threads: 1 }
        memory: { guest: <ram>Gi }
        resources:
          limits: { cpu: "<vcpu>", memory: <ram>Gi }
          requests: { cpu: 200m, memory: <~2/3 ram>Mi }
        devices:
          disks:
          - name: disk-0
            bootOrder: 1
            disk: { bus: virtio }
          - name: cloudinitdisk
            disk: { bus: virtio }
          interfaces:
          - name: default              # pod network (internal)
            masquerade: {}
            model: virtio
          - name: nic-lan              # bridge NIC for LAN/SSH (omit if internal-only)
            bridge: {}
            model: virtio
        machine: { type: q35 }
      networks:
      - name: default
        pod: {}
      - name: nic-lan                  # omit if internal-only
        multus:
          networkName: <ns>/<nad-name>   # the NAD the user chose
      volumes:
      - name: disk-0
        persistentVolumeClaim:
          claimName: <vm-name>-disk-0
      - name: cloudinitdisk
        cloudInitNoCloud:
          networkData: |
            version: 2
            ethernets:
              enp1s0: { dhcp4: true }
              enp2s0: { dhcp4: true }   # omit this line if internal-only
          userData: |
            #cloud-config
            user: <username from user>
            password: <password from user>
            chpasswd: { expire: false }
            ssh_pwauth: true
            # OR, preferred: ssh_authorized_keys: [ "<user's public key>" ]
            packages: [ qemu-guest-agent ]
            runcmd:
              - systemctl enable --now qemu-guest-agent
```

Guest NIC naming: the pod NIC is usually `enp1s0` and the bridge NIC `enp2s0`,
but verify from `ip a` / the console if DHCP doesn't land; adjust networkData
names to match.

Power field: prefer `spec.runStrategy: RerunOnFailure` (or `Always`). `spec.running:
true` still works but kubectl warns it is deprecated — use runStrategy in new
manifests. To stop/start via patch, set runStrategy `Halted` ↔ `RerunOnFailure`.

## Networking for SSH / LAN access
A VM on the pod network only gets an internal cluster IP (e.g. 10.52.x.x) via
`masquerade`. You CANNOT ssh to that from outside the cluster. To make a VM
reachable (and SSH-able) on the LAN, it needs a SECOND network interface of
type **bridge** attached to a Hypervisor network (a
`NetworkAttachmentDefinition` / VM network), so it gets a routable IP.

ALWAYS ask the user which network to use — do not assume. Discover the options:
`kubectl get network-attachment-definitions -A` and inspect one with
`kubectl get net-attach-def <name> -n <ns> -o jsonpath='{.spec.config}{"\n"}'`
to see its `type` (bridge), `vlan`, and `ipam` (host-local range / dhcp / none).
A NAD with an `ipam` range or `dhcp` hands the VM a routable IP automatically; a
NAD with no ipam needs a static IP set via cloud-init.

The bridge interface pattern (mirrors how existing LAN-reachable VMs are wired)
— add to the VM template a second interface + matching network:

```yaml
domain:
  devices:
    interfaces:
    - name: nic-0          # pod network (optional to keep)
      masquerade: {}
      model: virtio
    - name: <free-name>    # the bridge NIC — ASK the user for intent
      bridge: {}
      model: virtio        # model virtio
networks:
- name: nic-0
  pod: {}
- name: <free-name>
  multus:
    networkName: <ns>/<nad-name>   # the NAD the user chose
```

After it boots, the bridge IP shows in `kubectl get vmi <name> -n <ns> -o wide`
(or inside the guest via `ip a`). SSH to THAT IP, not the pod IP.

IMPORTANT — the guest must bring the bridge NIC up itself. Adding the interface
at the KubeVirt level is NOT enough: Ubuntu/most cloud images only auto-configure
the FIRST NIC, so the second (bridge) NIC comes up DOWN with no IP and is not
SSH-able, even though KubeVirt/CNI are ready to DHCP it. Symptom: `ip a` in the
guest shows e.g. `enp2s0 ... state DOWN` and no `inet`, and
`kubectl get vmi ... -o jsonpath='{.status.interfaces[*].ipAddress}'` is empty
for that NIC. Fix: provide cloud-init `networkData` enabling DHCP on every NIC,
on the SAME cloudinit disk as userData:

```yaml
      - name: cloudinitdisk
        cloudInitNoCloud:
          networkData: |
            version: 2
            ethernets:
              enp1s0: { dhcp4: true }
              enp2s0: { dhcp4: true }
          userData: |
            #cloud-config
            ...
```

### CRITICAL: cloud-init runs only on FIRST boot — patch+restart does NOT re-apply it
The ENTIRE cloud-init payload (userData AND networkData) — the login user, the
password, `ssh_pwauth`, SSH keys, and the per-NIC DHCP config — is processed by
cloud-init ONLY on the first boot of a new instance. The disk records that the
instance-id already ran, so on later boots cloud-init SKIPS the user/network
modules. Therefore:

- Editing a running VM's cloud-init (`kubectl patch` / `kubectl edit`) and then
  RESTARTING it does NOT change the login user, the password, or the NIC config.
  The read-back of `spec` will look correct, but the GUEST is unchanged.
- Symptom of getting this wrong: console login for the user you "set" fails with
  `Login incorrect` (the user was never created), or the bridge NIC stays DOWN,
  even though the VM `spec` shows the new cloud-init.
- The ONLY reliable way to apply new cloud-init (new user/password/network) is to
  DELETE + RECREATE the VM (and its root-disk PVC) so it boots fresh. Confirm with
  the user first (this destroys the current disk), then recreate with the correct
  userData + networkData from the start. This is the proven fix — do not waste
  turns patching+restarting and expecting credentials to change.

For an ALREADY-running VM whose bridge NIC is merely DOWN (cloud-init was correct
but the NIC didn't come up), the cleanest fix is still a recreate (or a full
reboot, which re-runs netplan from the already-written config). In-guest manual
recovery is a LAST RESORT and is fragile on modern cloud images — see the
in-guest note in Troubleshooting (`dhclient` is NOT present on Ubuntu 24.04
cloudimg; `networkctl renew` fails if the NIC isn't managed yet).

To add SSH/bridge connectivity to an EXISTING VM, you must edit its interfaces
+ networks (a `kubectl edit vm` / patch) and reboot the VM — confirm with the
user first, then restart so the new NIC attaches. (Note the first-boot caveat
above: if the change also needs cloud-init network/user changes, a reboot alone
may not apply them — a recreate is the reliable path.)

## Proving SSH actually works (don't claim "SSH-ready" without testing)
A VM having a LAN IP is NOT proof it is SSH-able. After the bridge NIC has an IP,
verify a real login before telling the user it works — and verify from a host on
the SAME LAN as the bridge IP (e.g. the box running RantaiClaw, if it shares that
subnet). Steps:

1. Reachability: `ping -c2 <lan-ip>` and `nc -z -w3 <lan-ip> 22` (or
   `timeout 5 bash -c 'cat </dev/null >/dev/tcp/<lan-ip>/22' && echo open`).
2. Confirm password auth is even enabled (catches the publickey-only trap):
   `ssh -o PreferredAuthentications=none -o StrictHostKeyChecking=no <user>@<lan-ip>`
   — read the `Authentications that can continue:` line. It must list `password`
   if you configured `ssh_pwauth: true`. If it shows only `publickey`, the server
   rejects passwords (password login is off, or cloud-init didn't apply — see the
   first-boot caveat); you'll need an SSH key instead.
3. Full login test. `sshpass` is the simple way but is often NOT installed (and
   installing it may need sudo). Prefer whichever is available:
   - If `sshpass` exists: `sshpass -p '<password>' ssh -o StrictHostKeyChecking=no <user>@<lan-ip> 'whoami; hostname; ip -4 addr show enp2s0 | grep inet'`
   - Otherwise drive it with Python `pexpect` (usually present): spawn
     `ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no <user>@<lan-ip> '<cmd>'`, `expect` the password prompt,
     `sendline` the password, then read the output.
4. Success criteria — the remote command actually returned: `whoami` == the user,
   `hostname` == the VM name, and `enp2s0` shows `inet <lan-ip>/...`. Only THEN
   report "SSH works" — quote the real output, never a guess.

Example (proven shape): a VM `<vm-name>` cloned from a `*-cloudimg-*` image, with
a bridge NIC on the chosen NAD + networkData DHCP on both NICs, came up with LAN
IP `192.168.18.x`, and `ssh <user>@192.168.18.x` logged in (password auth, sudo
via NOPASSWD). Use placeholders in real runs; never hardcode a real password.

## Installing software INSIDE a VM (SSH in and run it — you CAN do this)
After a VM is up and SSH-able, the user may ask to install software in it (Grafana,
Docker, nginx, a package, a script, etc.). **You CAN and SHOULD do this — you have an
`ssh` capability and you just used it to prove the VM is SSH-able.** Do NOT refuse with
"I have no network path / no direct SSH to the VM / I need a bastion" — that is FALSE
when you (and RantaiClaw) sit on the same LAN as the VM and already SSH'd to it this
session. Refusing and dumping a copy-paste tutorial instead of doing it is a failure.

How to do it:
1. SSH to the VM with the user's credentials (the same ones that already worked):
   `ssh -o StrictHostKeyChecking=no <user>@<lan-ip> '<commands>'` (password via the
   ssh tool's password auth, or a key if the user gave one). For multi-step installs,
   run them in one SSH command (`bash -lc '...'`) or drive an interactive session.
2. Run the real install on the VM (Ubuntu/Debian → `sudo apt-get update && sudo
   apt-get install -y <pkg>`; many tools have an official apt repo or install script —
   use the official one). The VM's `admin`-style user typically has NOPASSWD sudo.
3. **VERIFY on the VM, don't just claim done**: check the service is active and the
   port answers, e.g. `systemctl is-active <svc>` and `curl -sS -o /dev/null -w '%{http_code}' http://localhost:<port>`
   (Grafana → :3000, etc.). Report the real status + the URL `http://<lan-ip>:<port>`.
Only ask the user for a bastion/jump host if SSH genuinely fails (no route, port 22
closed) — and prove that with the actual error, never assume it. Note: a VM on a
pod-only network (internal 10.x IP, no bridge NIC) is NOT reachable from off-cluster —
that's the one real case where you'd need an in-cluster path; a VM with a LAN IP is
directly reachable.

## Mutating operations (CONFIRM before running)
For ANY create/delete/apply/scale/power action: first state in plain language
exactly what will change (which resource, which namespace), then run it only
after the user confirms.

- Start a VM:   `kubectl virt start <name> -n <ns>`  (or patch `spec.running=true`)
- Stop a VM:    `kubectl virt stop <name> -n <ns>`
- Restart a VM: `kubectl virt restart <name> -n <ns>`
  (if the `virt` plugin is absent, toggle the VM's `spec.runStrategy`/`running`
   field with `kubectl patch` instead.)
- Delete a VM:  `kubectl delete virtualmachine.kubevirt.io <name> -n <ns>`
  (the root-disk PVC may survive the VM; when recreating fresh, also delete it:
  `kubectl delete pvc <name>-disk-0 -n <ns> --ignore-not-found`, then confirm
  it's gone before re-applying — a leftover PVC can collide with the new clone.)
- Console/serial: `kubectl virt console <name> -n <ns>` (interactive — only if
  the user explicitly wants a console session).
- Never apply a manifest the user hasn't seen.

### VERIFY AFTER every mutation (MANDATORY — do not skip)
A create/apply/power command is NOT done when it returns — it is done when a
follow-up read confirms it. After running the mutation, in the SAME turn:

1. Look at the command's own output. `kubectl apply` prints `<kind>/<name> created`
   / `configured` on success, or an `error: ...` / webhook rejection on failure.
   If you see an error or a non-zero exit, the action FAILED — quote the exact
   error, say it failed, give the likely cause, and STOP (golden rules 8-9).
2. Then re-query to confirm the new state, e.g. for a VM:
   `kubectl get vm <name> -n <ns> -o wide` and `kubectl get vmi <name> -n <ns> -o wide`.
   - Resource present with the expected status — report success, with the real
     name/status/IP/node from THAT output.
   - `NotFound` / empty / wrong state — it did NOT get created/changed. Say so
     plainly; do not claim success. Then diagnose (events, describe).
3. For a freshly-created VM also check it actually provisions, don't stop at
   "VM object exists": `kubectl get pvc -n <ns>` (the `<name>-disk-0` PVC must go
   Bound — a root disk smaller than the source image will leave it Pending/failed),
   and `kubectl describe vm <name> -n <ns>` / `kubectl get events -n <ns> --sort-by=.lastTimestamp | tail`
   for any rejection. Report the real state, not the intended one.

Common create pitfalls to check for and report honestly (never silently "succeed"):
- Root disk smaller than the source image's virtual size — PVC won't provision.
  Look up the image size first and ensure the requested disk is ≥ it.
- An ISO/installer image (e.g. `*-live-server-*`, `*.iso`) cloned as the root
  disk — the disk then contains the INSTALLER, not an OS. The VM boots into the
  manual installer ("select your language"), and cloud-init (user/password/SSH)
  is IGNORED. Worse, if that ISO-clone is the only disk, the installer reports
  "Block probing did not discover any disks" because there is no separate blank
  target disk. For a cloud-init / SSH VM you MUST use a CLOUD image (`*-cloudimg-*`,
  a `.img`/qcow2), which is a ready OS. (If you genuinely must use an ISO, it is a
  different shape: attach the ISO as a CD-ROM `cdrom: {bus: sata}` boot device AND
  add a separate blank `harvester-longhorn` data disk as the install target, then
  install manually — or build an autoinstall seed. Default to cloudimg instead.)
  **CRITICAL — use the Harvester-NATIVE disk shape for the blank target disk, NOT a
  raw KubeVirt `dataVolume`.** The blank install-target disk MUST be declared the SAME
  way as a cloudimg root disk: a `persistentVolumeClaim` volume whose PVC comes from
  the VM's `harvesterhci.io/volumeClaimTemplates` annotation (a blank one — no
  `imageId`, storageClass `harvester-longhorn`, the wanted size). If you instead give
  the disk a `dataVolume: { name: … }` volume (the plain KubeVirt way), Harvester does
  NOT manage or DISPLAY it: the VM's "Volumes" tab in the UI shows up EMPTY (only
  `bootOrder`) even though the disk and data exist and the VM runs. That has confused
  users into thinking the volume was lost. So: every VM disk — cloudimg root OR ISO
  blank target — goes through `volumeClaimTemplates` + `persistentVolumeClaim`, never a
  bare `dataVolume`. (Verify after creating: `kubectl get vm <name> -o jsonpath` on the
  volumes should show `persistentVolumeClaim.claimName`, not `dataVolume`.)
  **CRITICAL for the ISO path — boot order after install:** during install the
  CD-ROM must boot first (`bootOrder: 1`) and the blank target disk second
  (`bootOrder: 2`). But ONCE the OS is installed, leaving the CD-ROM at
  `bootOrder: 1` makes the VM boot back into the INSTALLER on every reboot (there
  is no UI "eject" button in KubeVirt/Hypervisor). After install you MUST flip the
  order so the OS disk boots first — set the installed disk to `bootOrder: 1` and
  the CD-ROM to `bootOrder: 2` (or detach the CD-ROM volume entirely), then restart.
  Tell the user this up front when creating an ISO VM, and offer to flip it for them
  after they finish installing.
- Wrong storage class on the root PVC — cloning an image requires the image's
  OWN per-image `lh-*` storageClass (from `.status.storageClassName`), NOT the
  default `harvester-longhorn`. Using the default class gives a BLANK disk (no OS
  cloned), and pairing it with a bogus `claimName` like the image name yields
  `ErrorPvcNotFound` / `PVC <image> does not exist` and a permanently
  Unschedulable VM. Always read the per-image SC first and set the imageId
  annotation on the volumeClaimTemplate.
- Trying to CHANGE an existing VM's login/network by patching cloud-init and
  restarting — cloud-init is first-boot-only, so the guest is unchanged. Recreate
  instead (see the first-boot caveat under Networking). Symptom: console
  `Login incorrect` for the user you thought you set.
- Forgetting `networkData` (or omitting the `enp2s0` DHCP line) when a bridge NIC
  is present — the bridge NIC comes up DOWN with no IP and is not SSH-able.
- Bridge NAD with no `ipam` — the guest only gets a LAN IP via external DHCP; if
  none is served the bridge NIC has no IP and is not SSH-able. (Conversely, if a
  sibling VM on the same NAD DID get a `192.168.x.x` lease, DHCP works and the
  problem is on the VM side — usually missing networkData or first-boot.)

## Output & communication style
- Lead with the direct answer (the count or the list), then a short table.
- Tables for lists: include real Name, Status/Phase, IP, Node, Namespace as
  applicable — only columns you actually have from output.
- If the user asks "how many", give the number first, then the backing list.
- Offer a sensible next step (e.g. "lihat VM yang stop?", "detail volume?").
- When you ran a command, it's fine to note which kubectl you used; never claim
  to have used a tool you didn't, and never claim output you didn't get.

## Troubleshooting
- `error loading config file ... illegal base64` — kubeconfig file corrupted;
  re-install per the section above. Do NOT hand-edit the cert.
- `Unable to connect to the server` / `dial tcp <ip>:443: connect: no route to host`
  / timeout — BEFORE blaming the network, VERIFY the IP in the error is actually the
  API server from the kubeconfig:
  `kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'`.
  If the error mentions an IP that is NOT the kubeconfig's server address, you are
  hitting the WRONG endpoint (a stale/hallucinated/remembered IP) — do NOT report
  "the cluster is unreachable"; fix the command to use the kubeconfig (export
  `KUBECONFIG` to the workspace file and re-run; never type a server IP by hand).
  Only if the error IP DOES match the kubeconfig server and it still won't connect is
  the cluster genuinely unreachable from this host — then report it (don't fake data).
  Never invent or assume the API IP; it comes from the kubeconfig, always.
- `the server doesn't have a resource type "X"` — wrong resource name; list with
  `kubectl api-resources` and retry with the correct one.
- **Creating a VM fails with `no endpoints available for service "harvester-webhook"`
  (or `failed calling webhook validator.harvesterhci.io`)** — this is a CLUSTER
  problem, NOT a problem with your VM manifest. The Hypervisor admission webhook
  is down. Do NOT rewrite/retry the VM YAML and do NOT ask the user for
  "hypervisor credentials" — you already have full access via kubectl. Diagnose:
  - `kubectl get pods -n harvester-system | grep -E 'harvester-webhook|harvester-[0-9a-f]{6,}'`
  - Look for `ErrImagePull` / `ImagePullBackOff` / `CrashLoopBackOff`. A common
    cause is the `harvester`/`harvester-webhook` Deployment pointing at a
    non-existent image tag (e.g. a dev tag like `HEAD-head`) after a Helm/Fleet
    upgrade: `kubectl get deploy harvester harvester-webhook -n harvester-system -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.template.spec.containers[0].image}{"\n"}{end}'`
  - These are Fleet/Helm-managed control-plane components. Report the finding and
    let the user/admin decide the fix (roll back the Helm release / fix the Fleet
    managedchart). Do NOT patch system deployments without explicit confirmation.
  - The VM manifest is fine; it can be applied once the webhook is healthy
    (`harvester-webhook` pod `1/1 Running`).
- **VM created but stuck `Starting`/VMI `Scheduling`, never gets an IP, with
  `FailedCreatePodSandBox ... plugin type="multus" ... network "<nad>": cannot
  convert: no valid IP addresses`** — the VM and its disk are FINE; the bridge
  NIC's network (the NAD, e.g. a VM Network on a cluster-network/VLAN) cannot
  hand out an IP. This is a CLUSTER NETWORK config problem, not the VM manifest.
  Do NOT report the VM as "running" or "SSH ready" — it is not. Diagnose & report
  honestly: `kubectl get vmi <name> -n <ns> -o wide` (Scheduling, no IP),
  `kubectl describe pod -n <ns> virt-launcher-<name>-* | tail` (the multus error),
  and note the launcher pod retries forever (burns pod-network IPs). Tell the user:
  the VM is stuck on network "<nad>"; either (a) fix that VM network /
  cluster-network uplink in Hypervisor (Networks → Cluster/VM Networks — admin task),
  or (b) recreate the VM WITHOUT the bridge NIC (pod-network only) for an
  internal-IP VM. Offer to stop the stuck VM (`kubectl virt stop` / runStrategy
  Halted) to end the retry loop — disk is preserved.
- **Bridge NIC (e.g. `enp2s0`) is `state DOWN` / has no `inet` in the guest** —
  the second NIC never got configured. ROOT CAUSE is almost always missing
  cloud-init `networkData` (the VM `spec` may even look fine if it was patched
  AFTER first boot — see the first-boot caveat). The RELIABLE fix is to recreate
  the VM with `networkData` enabling DHCP on both NICs (or, if cloud-init is
  already correct on disk, a full `reboot` which re-runs netplan natively). Manual
  in-guest recovery is fragile on modern cloud images and often DOESN'T work:
  - `sudo dhclient enp2s0` → `dhclient: command not found` on Ubuntu 24.04 cloudimg
    (it ships systemd-networkd, not isc-dhcp-client).
  - `sudo networkctl renew enp2s0` → `Interface enp2s0 is not managed by
    systemd-networkd` (no netplan config exists for it yet).
  - `sudo ip link set enp2s0 up` brings the LINK up (`state UP`) but still gives
    NO IPv4 unless something then DHCPs it.
  - Writing `/etc/netplan/99-lan.yaml` (`renderer: networkd`, `enp2s0: {dhcp4: true}`)
    + `sudo systemctl enable --now systemd-networkd` + `sudo netplan apply` CAN work,
    but it's brittle mid-session. Prefer recreate/reboot, which uses the native
    cloud-init → netplan → networkd path that is known to lease an IP.
- **Cannot verify right now (LLM rate limit / transient error mid-task)** — say
  exactly that: "couldn't verify the result yet (rate limited)". NEVER report
  status "from previous results" or from memory as if it were current — re-run the
  `kubectl get` when able, and only then state the real state. NOTE: a "rate limit"
  message from the RantaiClaw tool layer (not the LLM API) usually means the
  per-hour action budget (`autonomy.max_actions_per_hour`, default low) was hit —
  a real, silent cap, not a cluster problem. It resets on daemon restart and the
  operator can raise the limit in config; don't mistake it for a cluster fault and
  don't use it as an excuse to skip a verify you CAN still run.
- **VM boots back into the INSTALLER on every reboot (after the OS was already
  installed from an ISO).** Root cause: the CD-ROM (ISO) still has `bootOrder: 1`,
  above the installed OS disk — so the VM keeps booting the installer instead of the
  OS. There is NO "eject CD" button in KubeVirt/Hypervisor; the fix is boot order.
  Diagnose:
  `kubectl get vm <name> -n <ns> -o jsonpath='{range .spec.template.spec.domain.devices.disks[*]}{.name}{" cdrom="}{.cdrom.bus}{" bootOrder="}{.bootOrder}{"\n"}{end}'`
  — if the `cdrom` disk has the lowest bootOrder, that's it. Fix: flip the order so the
  installed disk is `bootOrder: 1` and the CD-ROM is `bootOrder: 2` (a `kubectl patch`
  on `/spec/template/spec/domain/devices/disks`), or detach the CD-ROM volume, then
  restart the VM. Verify from the console that it now reaches the OS login, not the
  installer. (Confirm with the user first — it restarts the VM.)
- Empty result with rc=0 (only a header, no rows) — genuinely zero of that
  resource; say so plainly. (For VM images, never report 0 unless the command
  truly prints no data rows.)
