using '../main.bicep'

param location = 'centralus'
param environment = 'prod'
param vmName = 'vm-nemoclaw-prod-001'
param vmSize = 'Standard_D8s_v4'
param sshPublicKey = '' // REQUIRED: paste your SSH public key
param allowedSshSourceIp = '' // REQUIRED: set to your IP (e.g. '203.0.113.50')
