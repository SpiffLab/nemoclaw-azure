# Getting Started

Step-by-step guide to deploy NemoClaw on Azure with NVIDIA Cloud inference.

## Prerequisites

- **Azure CLI** — [Install](https://learn.microsoft.com/cli/azure/install-azure-cli) and log in with `az login`
- **SSH key pair** — Generate one if you don't have it:
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
  ```
- **NVIDIA API key** — From [build.nvidia.com](https://build.nvidia.com)

## 1. Get Your NVIDIA API Key

1. Go to [build.nvidia.com](https://build.nvidia.com)
2. Sign in or create an account
3. Navigate to any model (e.g., `meta/llama-3.1-70b-instruct`)
4. Click **Get API Key**
5. Copy the key — you'll paste it during `nemoclaw onboard`

## 2. Deploy Infrastructure

Create a resource group and deploy:

```bash
# Create resource group
az group create --name rg-nemoclaw-dev --location centralus

# Deploy (pass your SSH public key inline)
az deployment group create \
  --resource-group rg-nemoclaw-dev \
  --template-file infra/main.bicep \
  --parameters infra/parameters/dev.bicepparam \
  --parameters sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)"
```

Note the `vmPublicIpAddress` in the outputs.

## 3. SSH into the VM

```bash
ssh azureuser@<VM_PUBLIC_IP>
```

## 4. Install NemoClaw

**Option A:** Run the install script (recommended):

```bash
# From the VM:
curl -fsSL https://raw.githubusercontent.com/<your-repo>/main/scripts/install-nemoclaw.sh | sudo bash
```

**Option B:** Install manually:

```bash
# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable docker && sudo systemctl start docker

# Docker cgroup v2 fix
sudo mkdir -p /etc/docker
echo '{"default-cgroupns-mode":"host"}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

# Node.js 22
sudo snap install node --channel=22/stable --classic
sudo ln -sf /snap/bin/node /usr/local/bin/node
sudo ln -sf /snap/bin/npm /usr/local/bin/npm
sudo ln -sf /snap/bin/npx /usr/local/bin/npx

# jq
sudo apt-get install -y jq

# NemoClaw
curl -fsSL https://nvidia.com/nemoclaw.sh | sudo bash
```

## 5. Onboard NemoClaw

```bash
sudo nemoclaw onboard
```

When prompted:
1. **Inference provider** → Select `cloud`
2. **API key** → Paste your NVIDIA API key from build.nvidia.com
3. **Model** → Pick a model (e.g., `meta/llama-3.1-70b-instruct`)

## 6. Connect Your Assistant

```bash
sudo nemoclaw my-assistant connect
```

## 7. Launch the Agent

**Terminal UI:**

```bash
openclaw tui
```

**Web UI (via SSH tunnel):**

From your local machine, open an SSH tunnel:

```bash
ssh -L 18789:127.0.0.1:18789 azureuser@<VM_PUBLIC_IP>
```

Then open [http://127.0.0.1:18789](http://127.0.0.1:18789) in your browser.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `docker: permission denied` | Run `sudo usermod -aG docker $USER` and re-login |
| `node: command not found` | Run `sudo ln -sf /snap/bin/node /usr/local/bin/node` |
| `nemoclaw onboard` fails | Check Docker is running: `sudo systemctl status docker` |
| Can't reach NVIDIA Cloud | Check NSG allows HTTPS outbound (port 443) |

## Next Steps

- [Architecture](architecture.md) — Understand the design
- [Scaling](scaling.md) — Add more VM nodes
