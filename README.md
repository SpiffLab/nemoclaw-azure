# NemoClaw on Azure

Deploy [NVIDIA NemoClaw](https://developer.nvidia.com/nemoclaw) — an AI agent sandbox platform — on a single Azure VM using **NVIDIA Cloud** (build.nvidia.com) for inference. No GPU required.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Azure VM (Ubuntu 22.04)                            │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  Docker                                       │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │  OpenShell Gateway                      │  │  │
│  │  │  ┌───────────────────────────────────┐  │  │  │
│  │  │  │  Sandbox (Landlock + seccomp)     │  │  │  │
│  │  │  │  ┌─────────────────────────────┐  │  │  │  │
│  │  │  │  │  OpenClaw Agent             │──┼──┼──┼──┼──► NVIDIA Cloud
│  │  │  │  │                             │  │  │  │  │    (build.nvidia.com)
│  │  │  │  └─────────────────────────────┘  │  │  │  │
│  │  │  └───────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  Key Vault (secrets)    Storage (logs/artifacts)    │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

- Azure subscription with Contributor access
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed
- SSH key pair (`ssh-keygen -t ed25519`)
- NVIDIA API key from [build.nvidia.com](https://build.nvidia.com)

## Quick Start

```bash
# 1. Deploy infrastructure
az group create -n rg-nemoclaw-dev -l centralus
az deployment group create \
  -g rg-nemoclaw-dev \
  -f infra/main.bicep \
  -p infra/parameters/dev.bicepparam \
  -p sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)"

# 2. SSH into the VM
ssh azureuser@<VM_PUBLIC_IP>

# 3. Install and onboard NemoClaw
curl -fsSL https://raw.githubusercontent.com/<your-repo>/main/scripts/install-nemoclaw.sh | sudo bash
sudo nemoclaw onboard
```

During onboard, select **cloud** as the inference provider and paste your NVIDIA API key.

## Compute Options

| Size | vCPUs | RAM | Use Case | Monthly Cost (est.) |
|------|-------|-----|----------|---------------------|
| `Standard_D4s_v4` | 4 | 16 GB | Development / Testing | ~$140 |
| `Standard_D8s_v4` | 8 | 32 GB | Production | ~$280 |

> **No GPU needed.** Inference runs on NVIDIA Cloud, so a standard CPU VM is sufficient.

## Repository Structure

```
nemoclaw-azure/
├── .github/workflows/
│   └── validate.yml          # CI: Bicep lint & build
├── infra/
│   ├── main.bicep            # Main deployment template
│   ├── bicepconfig.json      # Bicep linter config
│   ├── modules/
│   │   ├── vnet.bicep        # Virtual network + NSG
│   │   ├── vm.bicep          # Compute VM
│   │   ├── keyvault.bicep    # Key Vault for secrets
│   │   └── storage.bicep     # Storage for logs/artifacts
│   └── parameters/
│       ├── dev.bicepparam    # Dev environment params
│       └── prod.bicepparam   # Prod environment params
├── scripts/
│   ├── install-nemoclaw.sh   # VM bootstrap script
│   ├── add-node.sh           # Add a new VM node
│   └── remove-node.sh        # Remove a VM node
├── docs/
│   ├── getting-started.md    # Step-by-step setup guide
│   ├── architecture.md       # Architecture deep-dive
│   └── scaling.md            # Scaling guide
├── LICENSE                   # MIT License
└── README.md                 # This file
```

## Documentation

- [Getting Started](docs/getting-started.md) — Full setup walkthrough
- [Architecture](docs/architecture.md) — Design decisions and component details
- [Scaling](docs/scaling.md) — Adding and removing nodes

## License

[MIT](LICENSE)
