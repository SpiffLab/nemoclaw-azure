#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# add-node.sh — Add a new NemoClaw VM to an existing deployment
# Usage: ./add-node.sh <vm-name> <ssh-key-path> [resource-group] [location]
# ---------------------------------------------------------------------------
set -euo pipefail

VM_NAME="${1:?Usage: $0 <vm-name> <ssh-key-path> [resource-group] [location]}"
SSH_KEY_PATH="${2:?Usage: $0 <vm-name> <ssh-key-path> [resource-group] [location]}"
RESOURCE_GROUP="${3:-rg-nemoclaw-dev}"
LOCATION="${4:-centralus}"

if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "ERROR: SSH key file not found: $SSH_KEY_PATH"
    exit 1
fi

SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH")

echo "Adding VM '$VM_NAME' to resource group '$RESOURCE_GROUP'..."

# Query existing VNet subnet ID
echo "Looking up existing VNet..."
VNET_NAME=$(az network vnet list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [[ -z "$VNET_NAME" ]]; then
    echo "ERROR: No VNet found in resource group '$RESOURCE_GROUP'."
    echo "Deploy the full infrastructure first with main.bicep."
    exit 1
fi

SUBNET_ID=$(az network vnet subnet show \
    -g "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    -n compute \
    --query id -o tsv)

# Query existing Key Vault name
echo "Looking up existing Key Vault..."
KV_NAME=$(az keyvault list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [[ -z "$KV_NAME" ]]; then
    echo "WARNING: No Key Vault found. VM will be deployed without Key Vault tag."
    KV_NAME="none"
fi

# Deploy the VM module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BICEP_FILE="$SCRIPT_DIR/../infra/modules/vm.bicep"

if [[ ! -f "$BICEP_FILE" ]]; then
    echo "ERROR: Bicep file not found: $BICEP_FILE"
    exit 1
fi

echo "Deploying VM..."
az deployment group create \
    -g "$RESOURCE_GROUP" \
    -f "$BICEP_FILE" \
    -p vmName="$VM_NAME" \
       vmSize="Standard_D4s_v4" \
       location="$LOCATION" \
       subnetId="$SUBNET_ID" \
       sshPublicKey="$SSH_PUBLIC_KEY" \
       keyVaultName="$KV_NAME" \
    --no-wait

echo ""
echo "VM deployment started. Check status with:"
echo "  az deployment group list -g $RESOURCE_GROUP -o table"
echo ""
echo "Once deployed, SSH in and run the install script:"
echo "  ssh azureuser@\$(az vm show -g $RESOURCE_GROUP -n $VM_NAME -d --query publicIps -o tsv)"
