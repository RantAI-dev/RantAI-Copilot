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

- **A reachable LLM** — a cloud provider + API key, or a local/on-prem model. Needed for **every**
  mode; the agent is model-driven and does nothing without one. You set it with `rantaiclaw setup`
  right after install.
- **RantaiClaw** — the prebuilt bundle below ships it for you (Linux x86_64). Only *From source*
  asks you to install RantaiClaw yourself.
- **For the hypervisor skill only** — `kubectl` on your machine + a kubeconfig. The skill drives the
  cluster **locally** over `kubectl` (not SSH). Put the kubeconfig in the RantaiClaw workspace as
  `kubeconfig-hypervisor` (the skill can install/rotate it for you). Not needed just to install or chat.

## Install the agent

Pick the mode that matches your network — **every mode needs a reachable LLM** (a cloud API key or
a local model); only *how you get the software* differs. The prebuilt bundle is **Linux x86_64
(glibc)**; anything else uses *From source*.

| Mode | Use it when | What it fetches |
|---|---|---|
| **Online** | the machine has internet | binary + skills now; web console on first `copilot-web` |
| **Airgapped** | no GitHub / npm / bun.sh access | nothing — the bundle is fully pre-packaged |
| **From source** | other CPU/OS, or your own RantaiClaw build | this git repo |

### Online mode

**1 — Install.** Downloads the latest bundle, verifies its checksum, installs the binary + skills:
```bash
curl -fsSL https://raw.githubusercontent.com/RantAI-dev/RantAI-Copilot/main/get.sh | bash
```
The binary is installed to `~/.local/bin`. If the output warns it's **not on your PATH**, add it
(then open a new shell):
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && export PATH="$HOME/.local/bin:$PATH"
```

**2 — Configure your LLM** (once). The setup wizard walks you through the provider + key (and more):
```bash
rantaiclaw setup
```

**3 — Run it:**
```bash
rantaiclaw chat        # chat in the terminal
copilot-web            # web console → http://localhost:3939  (first run fetches claw-ui, ~1 min)
```

**Check it worked:** `rantaiclaw --version` prints a version, and `copilot-web` opens the console.
**Update later:** `copilot-update` refreshes everything (binary + skills + web console).

### Airgapped mode

No network at install **or** run — everything is pre-packaged. (Your LLM still has to be reachable:
a key, or a local model.) Since nothing is fetched, **you download the bundle on a connected machine
first** — that's also how you update.

**1 — On a machine with internet**, download the airgapped tarball from
[Releases](https://github.com/RantAI-dev/RantAI-Copilot/releases/latest) (Linux x86_64):
`rantai-copilot-airgapped-<version>-x86_64-linux.tar.gz`

**2 — Move it to the airgapped host** (USB / scp) and extract:
```bash
tar xzf rantai-copilot-airgapped-<version>-x86_64-linux.tar.gz
cd rantai-copilot-airgapped-<version>-x86_64-linux
```

**3 — Install** — no network needed. Installs rantaiclaw + skills + a bun runtime + the prebuilt
web console (it does not touch your config):
```bash
./setup-airgapped.sh
```

**4 — Configure your LLM, then run.** `setup provider` sets just the LLM and needs no network:
```bash
rantaiclaw setup provider     # provider + key, offline
rantaiclaw chat               # chat in the terminal
copilot-web                   # web console → http://localhost:3939  (runs offline)
```
> The full `rantaiclaw setup` also walks channels / MCP, and those sections need network — on a
> fully offline host stick to `rantaiclaw setup provider`.

**Update** (there is no online update): download a newer `rantai-copilot-airgapped-<version>`
bundle on a connected machine, transfer it, and re-run `./setup-airgapped.sh`. To build the bundle
yourself on a connected **same-arch** host: `release/pack-airgapped.sh <rantaiclaw-binary> <tag>`.

### From source (other platforms, or your own RantaiClaw)

For CPUs/OSes the prebuilt bundle doesn't cover, or to use a RantaiClaw you built yourself. Install
[RantaiClaw](https://github.com/RantAI-dev/RantAIClaw#install) first (it must be on your `PATH`), then:
```bash
git clone https://github.com/RantAI-dev/RantAI-Copilot
cd RantAI-Copilot
./install.sh            # deploy the skills into your RantaiClaw workspace
rantaiclaw setup        # set your LLM provider + key (if you haven't)
./web-ui.sh             # web console → http://localhost:3939  (later installed as: copilot-web)
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
is upstream [claw-ui](https://github.com/RantAI-dev/claw-ui), installed on demand into
`~/.copilot/web-ui` from a signed prebuilt release and served as a production build.

```bash
copilot-web         # first run: fetch (~1 min) + start → http://localhost:3939
copilot-web stop    # stop the console + gateway
```

From a source checkout (before `copilot-web` is on your PATH) use `./web-ui.sh` — it's the same launcher.

Notes:
- First run downloads claw-ui; later runs start instantly. Airgapped installs serve the bundled
  copy with no fetch.
- `copilot-web` / `web-ui.sh` bring up **both the gateway and the console** and always target
  `~/.copilot/web-ui` — use them rather than calling `rantaiclaw ui install` / `ui start` directly.

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
