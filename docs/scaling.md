# Scaling

NemoClaw on Azure uses a simple scaling model: each VM is an independent, self-contained node. Scale by adding or removing VMs.

## Adding a Node

Use the provided script to add a new VM to the existing VNet:

```bash
# Usage: ./scripts/add-node.sh <vm-name> <ssh-key-path> [resource-group] [location]

./scripts/add-node.sh vm-nemoclaw-dev-002 ~/.ssh/id_ed25519.pub
```

The script will:
1. Look up the existing VNet and Key Vault in the resource group
2. Deploy a new VM into the `compute` subnet
3. Output the SSH command to connect

After the VM is provisioned, SSH in and run the install script:

```bash
ssh azureuser@<NEW_VM_IP>
curl -fsSL https://raw.githubusercontent.com/<your-repo>/main/scripts/install-nemoclaw.sh | sudo bash
sudo nemoclaw onboard
```

## Removing a Node

```bash
# Usage: ./scripts/remove-node.sh <vm-name> [resource-group]

./scripts/remove-node.sh vm-nemoclaw-dev-002
```

This deletes the VM, NIC, public IP, and OS disk. You'll be prompted to confirm.

## Architecture

Each VM is fully independent:

```
Resource Group
├── VNet (shared)
│   └── compute subnet
│       ├── VM 1 (NemoClaw) ──► NVIDIA Cloud
│       ├── VM 2 (NemoClaw) ──► NVIDIA Cloud
│       └── VM 3 (NemoClaw) ──► NVIDIA Cloud
├── Key Vault (shared)
└── Storage (shared)
```

- **VNet, Key Vault, and Storage** are shared across all nodes
- **Each VM** runs its own NemoClaw instance and connects independently to NVIDIA Cloud
- **No load balancer** — each node operates autonomously

## Capacity Planning

| VM Size | vCPUs | RAM | Concurrent Agents | Use Case |
|---------|-------|-----|--------------------|----------|
| `Standard_D4s_v4` | 4 | 16 GB | 2–4 | Dev / light workloads |
| `Standard_D8s_v4` | 8 | 32 GB | 6–10 | Production |
| `Standard_D16s_v4` | 16 | 64 GB | 12–20 | Heavy workloads |

Factors that affect capacity:
- **Number of concurrent sandboxes** — Each sandbox consumes ~2 GB RAM and ~0.5 vCPU
- **Docker overhead** — Base Docker + NemoClaw containers use ~2 GB RAM
- **Disk space** — Docker images + sandbox data; 128 GB is sufficient for most workloads

## Cost Optimization

- Use `Standard_D4s_v4` for development (cheapest, ~$140/month)
- Deallocate VMs when not in use: `az vm deallocate -g <rg> -n <vm>`
- NVIDIA Cloud charges are based on inference usage — no cost when idle
- Use lifecycle policies on the storage account to auto-delete old logs (configured at 90 days)
