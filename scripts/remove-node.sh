#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# remove-node.sh — Remove a NemoClaw VM and its associated resources
# Usage: ./remove-node.sh <vm-name> [resource-group]
# ---------------------------------------------------------------------------
set -euo pipefail

VM_NAME="${1:?Usage: $0 <vm-name> [resource-group]}"
RESOURCE_GROUP="${2:-rg-nemoclaw-dev}"

echo "This will delete the following resources from '$RESOURCE_GROUP':"
echo "  - VM:        $VM_NAME"
echo "  - NIC:       nic-$VM_NAME"
echo "  - Public IP:  pip-$VM_NAME"
echo "  - OS Disk:   osdisk-$VM_NAME"
echo ""
read -rp "Are you sure? (y/N): " CONFIRM

if [[ "${CONFIRM,,}" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

echo "Deleting VM '$VM_NAME'..."
az vm delete \
    -g "$RESOURCE_GROUP" \
    -n "$VM_NAME" \
    --yes \
    --force-deletion none

echo "Deleting NIC 'nic-$VM_NAME'..."
az network nic delete \
    -g "$RESOURCE_GROUP" \
    -n "nic-$VM_NAME" \
    2>/dev/null || echo "  NIC not found or already deleted."

echo "Deleting Public IP 'pip-$VM_NAME'..."
az network public-ip delete \
    -g "$RESOURCE_GROUP" \
    -n "pip-$VM_NAME" \
    2>/dev/null || echo "  Public IP not found or already deleted."

echo "Deleting OS Disk 'osdisk-$VM_NAME'..."
az disk delete \
    -g "$RESOURCE_GROUP" \
    -n "osdisk-$VM_NAME" \
    --yes \
    2>/dev/null || echo "  Disk not found or already deleted."

echo ""
echo "Done. VM '$VM_NAME' and associated resources removed."
