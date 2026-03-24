# Architecture

## Overview

NemoClaw on Azure deploys a single VM (or multiple independent VMs) running the NVIDIA NemoClaw agent platform. Inference is handled entirely by NVIDIA Cloud (build.nvidia.com), eliminating the need for GPU VMs.

## Architecture Diagram

```
                                    ┌─────────────────┐
                                    │  NVIDIA Cloud    │
                                    │ build.nvidia.com │
                                    │                  │
                                    │  LLM Inference   │
                                    └────────▲─────────┘
                                             │ HTTPS (443)
                                             │
┌────────────────────────────────────────────┼────────────────────────┐
│  Azure Resource Group                      │                        │
│                                            │                        │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  VNet (10.0.0.0/16)                                          │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │  Subnet: compute (10.0.1.0/24)      NSG: SSH + HTTPS   │  │  │
│  │  │                                                         │  │  │
│  │  │  ┌───────────────────────────────────────────────────┐  │  │  │
│  │  │  │  VM (Ubuntu 22.04)                                │  │  │  │
│  │  │  │                                                   │  │  │  │
│  │  │  │  Docker                                           │  │  │  │
│  │  │  │  ├── OpenShell Gateway                            │  │  │  │
│  │  │  │  │   └── Sandbox (Landlock + seccomp)             │  │  │  │
│  │  │  │  │       └── OpenClaw Agent ──────────────────────┼──┤  │  │
│  │  │  │  └── inference.local (proxy)                      │  │  │  │
│  │  │  │                                                   │  │  │  │
│  │  │  └───────────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌─────────────┐  ┌────────────────┐                                │
│  │  Key Vault   │  │  Storage Acct   │                               │
│  │  (secrets)   │  │  (logs/artifacts)│                              │
│  └─────────────┘  └────────────────┘                                │
└─────────────────────────────────────────────────────────────────────┘
```

## Azure Components

| Component | Resource | Purpose |
|-----------|----------|---------|
| **Compute** | Azure VM (D4s_v4 / D8s_v4) | Runs Docker, NemoClaw, and the agent sandbox |
| **Networking** | VNet + NSG | Isolates the VM; allows SSH inbound and HTTPS outbound |
| **Secrets** | Key Vault | Stores NVIDIA API key and other secrets |
| **Storage** | Storage Account | Persists logs (90-day retention) and artifacts |

## NemoClaw Stack

NemoClaw runs entirely inside Docker on the VM:

```
┌─────────────────────────────────────────┐
│  Docker                                 │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  OpenShell Gateway                │  │
│  │  Manages sandbox lifecycles and   │  │
│  │  routes agent ↔ tool requests     │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Sandbox                    │  │  │
│  │  │  Linux isolation:           │  │  │
│  │  │  • Landlock (filesystem)    │  │  │
│  │  │  • seccomp (syscall filter) │  │  │
│  │  │                             │  │  │
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │  OpenClaw Agent       │  │  │  │
│  │  │  │  AI agent that uses   │  │  │  │
│  │  │  │  tools in sandbox     │  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
│                                         │
│  inference.local (proxy container)      │
│  Routes LLM calls to NVIDIA Cloud       │
└─────────────────────────────────────────┘
```

## Security Model

### Network Security (NSG)

| Rule | Direction | Port | Source | Action |
|------|-----------|------|--------|--------|
| AllowSshInbound | Inbound | 22 | Configured IP | Allow |
| AllowHttpsOutbound | Outbound | 443 | Any | Allow |
| AllowHttpOutbound | Outbound | 80 | Any | Allow |
| DenyAllOtherOutbound | Outbound | * | Any | Deny |

### Sandbox Security

NemoClaw sandboxes run with multiple isolation layers:

- **Docker** — Container-level process and network isolation
- **Landlock** — Linux kernel filesystem access control (restricts which files the agent can touch)
- **seccomp** — Syscall filtering (restricts which kernel operations the agent can call)

This means even if the AI agent tries to do something malicious, it is confined within the sandbox.

## Inference Flow

```
Agent (in sandbox)
  → inference.local (Docker DNS)
    → OpenShell Gateway (proxy)
      → NVIDIA Cloud API (build.nvidia.com)
        → LLM response
      ← returned to gateway
    ← returned to proxy
  ← returned to agent
```

The agent never talks directly to the internet. All inference requests flow through the OpenShell Gateway, which proxies them to NVIDIA Cloud over HTTPS.

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| **No GPU VMs** | NVIDIA Cloud handles inference — CPU VMs are cheaper and simpler |
| **NVIDIA Cloud over Azure OpenAI** | Direct NVIDIA support, wider model selection, simpler setup |
| **Single VM per deployment** | Each VM is independent and self-contained; scale by adding VMs |
| **Key Vault for secrets** | RBAC-based secret management; VM accesses via managed identity |
| **Premium SSD (128 GB)** | Docker images and sandbox data need fast I/O |
| **Ubuntu 22.04 LTS** | Stable, well-supported, matches NemoClaw requirements |
| **Node.js via snap** | Ubuntu's default apt repos and NodeSource don't reliably provide Node 22; snap does |
