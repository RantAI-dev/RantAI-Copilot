# RantAI-Copilot

An AI agent that **operates infrastructure from natural language** — powered by
[RantaiClaw](https://github.com/RantAI-dev/RantAIClaw). It ships RantaiClaw **skills**, one family
at a time, plus a browser **web console** that's the easiest way to drive the agent.

This repo ships **only the skills** (playbooks + helper scripts); the underlying capabilities live
in RantaiClaw itself (the `shell` tool). You drive it in plain language — in the
[web console](#web-console) or a terminal:

```
list all VMs on the Hypervisor cluster   ·   which nodes are unhealthy?   ·   list VM images
```

## Skills

| Skill | Status | What the agent does | Tutorial |
|---|---|---|---|
| **hypervisor** — KubeVirt + Longhorn (Harvester HCI) | ✅ available | **operate** an existing cluster via `kubectl` (list/create/start/stop VMs, images, storage, networks, backups) | [tutorials/hypervisor.md](tutorials/hypervisor.md) |
| **microvm** | 🚧 under development | install Firecracker microVMs on a remote host | — |
| **microvm-operate** | 🚧 under development | day-2 microVM operations | — |
| **suite** | 🚧 under development | install / Q&A / troubleshoot the Analytics + Identity Portal stack | — |

See [ROADMAP.md](ROADMAP.md). Each new skill adds a playbook under `skill/` and a tutorial under
`tutorials/`; installation and the web console below stay the same.

## How it works

- You run **RantaiClaw** (the agent) on your machine. It's a general-purpose agent — this repo just
  teaches it products via **skills** (Markdown playbooks the model follows).
- For the Hypervisor, the agent uses RantaiClaw's **`shell`** tool to run `kubectl` locally against
  the cluster.
- The skills don't re-implement anything; they add discovery, recommendations, verification, and
  reporting on top of `kubectl`.

## Prerequisites

1. **RantaiClaw** — the prebuilt bundle (below) ships it; from source see *From source*.
2. **An LLM provider** configured in RantaiClaw (`rantaiclaw onboard`) — the agent is model-driven.
3. **`kubectl` on your machine + a kubeconfig.** The hypervisor skill drives the cluster **locally**
   over `kubectl` (not over SSH). Drop the kubeconfig in the RantaiClaw workspace as
   `kubeconfig-hypervisor` (the skill can install/rotate it for you).

## Install the agent

Two modes — pick your network situation. Both need a reachable **LLM** (cloud API by key, or a
local/on-prem model); only the install/fetch differs.

### Online mode (has internet)

```bash
curl -fsSL https://raw.githubusercontent.com/RantAI-dev/RantAI-Copilot/master/get.sh | bash
rantaiclaw onboard      # set your LLM provider + key
rantaiclaw chat         # CLI agent
copilot-web             # web console → http://localhost:3939 (fetches claw-ui on first run)
copilot-update          # update everything later (binary + skills + web console)
```

### Airgapped mode (no GitHub/npm/bun.sh access)

Nothing is fetched at install or run — everything is pre-packaged (the LLM API still needs to be
reachable, e.g. by key or a local model). Because there's no fetch, **you download the bundle
first** — for both install *and* updates.

1. On a machine **with** internet, download from
   [Releases](https://github.com/RantAI-dev/RantAI-Copilot/releases/latest) (Linux x86_64):
   `rantai-copilot-airgapped-<version>-x86_64-linux.tar.gz`
2. Transfer it to the airgapped host (USB/scp), then:
   ```bash
   tar xzf rantai-copilot-airgapped-<version>-x86_64-linux.tar.gz
   cd rantai-copilot-airgapped-<version>-x86_64-linux
   ./setup-airgapped.sh        # installs rantaiclaw + skills + bun + prebuilt web console — no network
   export OPENROUTER_API_KEY="sk-..."   # or point ~/.rantaiclaw/config.toml at your local model
   rantaiclaw chat
   copilot-web                 # web console → http://localhost:3939 (offline)
   ```

**Updating (airgapped)** — there's no fetch, so updating means downloading again: grab the newer
`rantai-copilot-airgapped-<version>` bundle on a connected machine, transfer it, and re-run
`./setup-airgapped.sh`. You can also rebuild the bundle on a connected **same-arch** host:
`release/pack-airgapped.sh <rantaiclaw-binary> <tag>`.

### From source (other platforms, or your own RantaiClaw)

```bash
git clone https://github.com/RantAI-dev/RantAI-Copilot
cd RantAI-Copilot
./install.sh            # deploy the skills into your RantaiClaw workspace
./web-ui.sh             # web console → http://localhost:3939
```

## Hypervisor

Operate an existing **Hypervisor** cluster (KubeVirt VMs + Longhorn storage) over `kubectl` — no
SSH, no install. **Full walkthrough → [tutorials/hypervisor.md](tutorials/hypervisor.md).**

Put a kubeconfig in the workspace (or let the agent install/rotate it):
```bash
cp ~/Downloads/kubeconfig.yaml ~/.rantaiclaw/profiles/default/workspace/kubeconfig-hypervisor
```
Then, in the **web console** (or `rantaiclaw chat`), just ask:
```
list all VMs on the Hypervisor cluster   ·   which nodes are unhealthy?   ·   list VM images
create a VM named web, 2 vCPU 2GB, ubuntu cloud image, on the lab network, with my SSH key
stop web   ·   show storage volumes
```

The `hypervisor` skill discovers the cluster at runtime (never from memory), gathers requirements
before creating anything (it won't invent credentials or pick a network), and verifies every
mutation with a follow-up `kubectl get`. Needs `kubectl` locally (see Prerequisites).

## Web console

**The easiest way to use the agent** — chat with it and watch it work, in your browser. The console
is upstream [claw-ui](https://github.com/RantAI-dev/claw-ui) (RantaiClaw), fetched on demand into
`~/.copilot/web-ui` and served as-is.

```bash
./web-ui.sh        # fetch + deps + start → http://localhost:3939   (installed: copilot-web)
./web-ui.sh stop   # stop console + gateway
```

Notes:
- `rantaiclaw ui start` brings up **both the gateway and the console** — no separate step.
- `web-ui.sh` always passes `--dir ~/.copilot/web-ui`; run it rather than `rantaiclaw ui install`
  directly.

## What's in here

```
skill/hypervisor/     # Hypervisor (HCI) ops playbook: SKILL.md, RUNBOOK.md, reference/, scripts/
tutorials/            # hands-on walkthroughs (hypervisor.md)
install.sh            # deploy the skills into your RantaiClaw workspace (from source)
web-ui.sh             # one-command launcher for the web console (copilot-web)
get.sh                # online installer (downloads the prebuilt bundle)
copilot-uninstall     # remove the Copilot extension (keeps rantaiclaw unless --all)
release/              # build-bundle.sh + pack-airgapped.sh + bundle files (setup, QUICKSTART)
ROADMAP.md            # planned skills
```

## Troubleshooting

- **Hypervisor** — see the gotchas in [tutorials/hypervisor.md](tutorials/hypervisor.md) and the
  troubleshooting section of `skill/hypervisor/SKILL.md` / `skill/hypervisor/RUNBOOK.md`.
- **Web console** — run it from the repo root with `./web-ui.sh`; don't call `rantaiclaw ui install`
  without `--dir`. See *Web console* above.
