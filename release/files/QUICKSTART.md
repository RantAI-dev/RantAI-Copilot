# RantAI-Copilot — Quickstart (pre-set-up bundle)

This bundle contains everything to **operate a Hypervisor cluster from a prompt**: a prebuilt
**rantaiclaw** agent and the `hypervisor` skill. You only add your **LLM provider key** and a
**kubeconfig** for the cluster.

## 1. Set it up (once)

**One-liner (recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/RantAI-dev/RantAI-Copilot/master/get.sh | bash
rantaiclaw onboard      # set your LLM provider + key (OpenRouter / Anthropic / MiniMax)
```

**Or from this bundle** (if you downloaded the tarball):
```bash
tar xzf rantai-copilot-*-x86_64-linux.tar.gz
cd rantai-copilot-*-x86_64-linux
./setup.sh
```
Either way: installs `rantaiclaw` to `~/.local/bin` and deploys the skills (the one-liner
prints the `onboard` step; `setup.sh` runs it for you).

> Linux x86_64 only (the binary is static, runs on any modern distro). Other platforms: build
> from source — see the repo README.

## 2. Point it at a cluster

The `hypervisor` skill drives an existing **Hypervisor (Harvester HCI)** cluster **locally over
`kubectl`** — no SSH, no install. You need:

- `kubectl` on this machine.
- A kubeconfig for the cluster (from your cluster UI → **Download KubeConfig**).

Drop the kubeconfig into the workspace:
```bash
cp ~/Downloads/kubeconfig.yaml ~/.rantaiclaw/profiles/default/workspace/kubeconfig-hypervisor
chmod 600 ~/.rantaiclaw/profiles/default/workspace/kubeconfig-hypervisor
```

## 3. Operate it

```bash
rantaiclaw chat        # or: copilot-web  → http://localhost:3939
```
Ask in plain language:
```
which nodes are unhealthy?   ·   list all VMs   ·   list VM images   ·   show storage volumes
create a VM named web, 2 vCPU 2GB, ubuntu cloud image, on the lab network, with my SSH key
start web   ·   stop web   ·   delete web
```
The agent discovers the cluster at runtime (never from memory), asks before it creates anything,
and verifies every change with a follow-up `kubectl get`.

## Gotchas (the ones that matter)

- **SSH access needs a bridge NIC.** A pod-network-only VM gets an internal cluster IP you can't
  reach from your laptop. For SSH, attach a **bridge** interface on a VM network.
- **`no endpoints available for service "harvester-webhook"`** on create → the cluster's admission
  webhook is down (a cluster problem, not your manifest). The agent reports it and stops.
- **Provider strictness / credits.** A long session is many model calls. OpenRouter / Anthropic
  are lenient; keep credits topped up.

Full walkthrough + troubleshooting: `skill/hypervisor/SKILL.md`, `skill/hypervisor/RUNBOOK.md`,
and the repo `tutorials/hypervisor.md`.
