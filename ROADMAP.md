# Roadmap

RantAI-Copilot ships one skill family at a time. Names below are final — a skill lands at
`skill/<name>/` with no rename.

| Skill | Status | What the agent does |
|---|---|---|
| `hypervisor` | ✅ available | Operate a Hypervisor (Harvester HCI) cluster via `kubectl` — VMs, images, storage, networks, backups |
| `microvm` | 🚧 under development | Install Firecracker microVMs on a remote host |
| `microvm-operate` | 🚧 under development | Day-2 microVM operations |
| `suite` | 🚧 under development | Install / Q&A / troubleshoot the Analytics + Identity Portal stack |

Each new skill adds a playbook under `skill/` and a walkthrough under `tutorials/`; installation and
the web console stay the same.
