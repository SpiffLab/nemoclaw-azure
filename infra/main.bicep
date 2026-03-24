// ---------------------------------------------------------------------------
// NemoClaw on Azure — Main deployment template
// Deploys a single VM with supporting infrastructure for NemoClaw.
// Inference is handled by NVIDIA Cloud (build.nvidia.com), no GPU required.
// ---------------------------------------------------------------------------

targetScope = 'resourceGroup'

// Parameters
@description('Azure region for all resources.')
param location string

@description('Deployment environment.')
@allowed(['dev', 'prod'])
param environment string

@description('Name of the compute VM.')
param vmName string

@description('VM size. GPU not required — inference runs on NVIDIA Cloud.')
param vmSize string = 'Standard_D4s_v4'

@secure()
@description('SSH public key for VM access.')
param sshPublicKey string

@description('Source IP address allowed to SSH into the VM. Use * for any (dev only).')
param allowedSshSourceIp string = '*'

// Variables
var projectName = 'nemoclaw'
var nameSuffix = '${projectName}-${environment}'
var tags = {
  project: projectName
  environment: environment
  managedBy: 'bicep'
}

// Modules
module vnet 'modules/vnet.bicep' = {
  name: 'deploy-vnet-${nameSuffix}'
  params: {
    location: location
    nameSuffix: nameSuffix
    allowedSshSourceAddress: allowedSshSourceIp
    tags: tags
  }
}

module vm 'modules/vm.bicep' = {
  name: 'deploy-vm-${nameSuffix}'
  params: {
    location: location
    vmName: vmName
    vmSize: vmSize
    subnetId: vnet.outputs.computeSubnetId
    sshPublicKey: sshPublicKey
    keyVaultName: keyvault.outputs.keyVaultName
    tags: tags
  }
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'deploy-kv-${nameSuffix}'
  params: {
    location: location
    nameSuffix: nameSuffix
    vmPrincipalId: ''
    tags: tags
  }
}

module keyvaultAccess 'modules/keyvault.bicep' = {
  name: 'deploy-kv-access-${nameSuffix}'
  params: {
    location: location
    nameSuffix: nameSuffix
    vmPrincipalId: vm.outputs.principalId
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'deploy-st-${nameSuffix}'
  params: {
    location: location
    nameSuffix: nameSuffix
    tags: tags
  }
}

// Outputs
output vmPublicIpAddress string = vm.outputs.publicIpAddress
output vmName string = vm.outputs.vmName
output keyVaultUri string = keyvault.outputs.keyVaultUri
