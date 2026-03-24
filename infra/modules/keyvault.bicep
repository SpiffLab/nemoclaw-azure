// ---------------------------------------------------------------------------
// Key Vault — RBAC authorization, soft delete, purge protection
// ---------------------------------------------------------------------------

param location string
param nameSuffix string
param vmPrincipalId string = ''
param tags object

// Key Vault names must be 3-24 chars, alphanumeric and hyphens only
var keyVaultName = 'kv-${replace(nameSuffix, '-', '')}${uniqueString(resourceGroup().id)}'
var truncatedKeyVaultName = length(keyVaultName) > 24 ? substring(keyVaultName, 0, 24) : keyVaultName

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: truncatedKeyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
  }
}

// Grant VM managed identity the Key Vault Secrets User role
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(vmPrincipalId)) {
  name: guid(keyVault.id, vmPrincipalId, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultName string = keyVault.name
