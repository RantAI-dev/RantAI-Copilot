# Tutorial — Operate a Hypervisor cluster with the agent

A goal-oriented walkthrough. By the end you'll have pointed a RantaiClaw agent at an existing
**Hypervisor** cluster (KubeVirt VMs + Longhorn storage) and driven it — list, create, and SSH
into a VM — entirely from natural-language prompts. The agent runs `kubectl` on your machine
against the cluster; it never invents data and confirms before it changes anything.

## 0. Mental model

- You run **RantaiClaw** (the agent) on your machine.
- It drives the cluster with **`kubectl`** (the `shell` tool) against the kube-apiserver —
  **locally**, no SSH, no install. The `hypervisor` skill is the playbook.
- Auth is a **kubeconfig** kept in the RantaiClaw workspace as `kubeconfig-hypervisor`.
- The agent **discovers everything at runtime** (never from memory) and **verifies every change**
  with a follow-up `kubectl get` — a "created" claim is always backed by real output.

## 1. Prerequisites

- `kubectl` on your machine (the agent runs it locally).
- A kubeconfig for the cluster — from your cluster UI (Rancher) → cluster → **Download KubeConfig**.
- RantaiClaw with an LLM provider (`rantaiclaw setup`) and the `hypervisor` skill
  deployed (`./install.sh`).

## 2. Give the agent the kubeconfig

Drop it into the workspace (or paste it to the agent and let it install/rotate it for you):

```bash
cp ~/Downloads/kubeconfig.yaml ~/.rantaiclaw/profiles/default/workspace/kubeconfig-hypervisor
chmod 600 ~/.rantaiclaw/profiles/default/workspace/kubeconfig-hypervisor
```

## 3. Connect & explore (read-only, safe)

```bash
rantaiclaw chat
```
Ask in plain language:
```
which nodes are in the cluster, and are they healthy?
list all VMs
list VM images   ·   show storage volumes   ·   list the VM networks
```
The agent runs the matching `kubectl` and answers ONLY from real output (with a count).

## 4. Create a VM (it asks first)

The skill **gathers requirements before creating** — it won't invent a password, pick a network,
or guess a disk size. Tell it what you want:
```
create a VM named web: 2 vCPU, 2 GB RAM, 20 GB disk, from an ubuntu cloud image,
on the <your-network> network, login with my SSH key <paste public key>
```
It will pick a ready cloud image + its storage class, **show you the manifest**, and apply it
**only after you confirm** — then verify the VM, its disk (PVC `Bound`), and its IP.

> **SSH access needs a bridge NIC.** A pod-network-only VM gets an internal cluster IP you can't
> SSH to from your laptop. For SSH, attach a **bridge** interface on a VM network; the skill adds
> cloud-init `networkData` so the second NIC actually comes up with a routable LAN IP.

## 5. Operate it

```
start web   ·   stop web   ·   restart web   ·   delete web
show web's IP   ·   open web's console   ·   list backups / snapshots
```

## Gotchas (the ones that bite)

- **`no endpoints available for service "harvester-webhook"`** on create → the cluster's
  admission webhook is down (a cluster problem, not your manifest). The agent reports it and
  stops — it does not retry blindly or ask for "credentials" (it already has full kubectl access).
- **VM stuck `Scheduling`, no IP, `multus … no valid IP addresses`** → the chosen VM network
  can't hand out an IP (cluster-network config), not the VM. Fix the network, or recreate the VM
  pod-network-only for an internal IP.
- **Bridge NIC `DOWN`, no `inet`** → the guest didn't bring the second NIC up; the skill's
  cloud-init `networkData` (DHCP on every NIC) handles this on a fresh VM.

See [`skill/hypervisor/SKILL.md`](../skill/hypervisor/SKILL.md) for the full command
reference and recipes.
