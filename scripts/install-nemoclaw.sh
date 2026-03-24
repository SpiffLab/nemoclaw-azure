#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# install-nemoclaw.sh — Bootstrap a VM for NemoClaw
# Run as root: curl ... | sudo bash
# ---------------------------------------------------------------------------
set -euo pipefail

echo "=========================================="
echo " NemoClaw VM Bootstrap"
echo "=========================================="

# 1. System updates
echo "[1/6] Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq

# 2. Install Docker
echo "[2/6] Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    usermod -aG docker azureuser
else
    echo "  Docker already installed."
fi

# 3. Configure Docker cgroup v2
echo "[3/6] Configuring Docker for cgroup v2..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "default-cgroupns-mode": "host",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF
systemctl restart docker

# 4. Install Node.js 22 via snap
echo "[4/6] Installing Node.js 22 via snap..."
if ! command -v node &>/dev/null || [[ "$(node --version 2>/dev/null)" != v22* ]]; then
    snap install node --channel=22/stable --classic
    # Symlink snap binaries to /usr/local/bin for PATH visibility
    ln -sf /snap/bin/node /usr/local/bin/node
    ln -sf /snap/bin/npm /usr/local/bin/npm
    ln -sf /snap/bin/npx /usr/local/bin/npx
else
    echo "  Node.js 22 already installed."
fi
echo "  Node version: $(node --version)"

# 5. Install jq
echo "[5/6] Installing jq..."
apt-get install -y -qq jq

# 6. Install NemoClaw
echo "[6/6] Installing NemoClaw..."
if ! command -v nemoclaw &>/dev/null; then
    curl -fsSL https://nvidia.com/nemoclaw.sh | bash
else
    echo "  NemoClaw already installed."
fi

echo ""
echo "=========================================="
echo " Bootstrap complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Run:  sudo nemoclaw onboard"
echo "  2. Select 'cloud' as the inference provider"
echo "  3. Paste your NVIDIA API key from build.nvidia.com"
echo "  4. Pick a model (e.g. meta/llama-3.1-70b-instruct)"
echo "  5. Connect: sudo nemoclaw my-assistant connect"
echo "  6. Start:   openclaw tui"
echo ""
