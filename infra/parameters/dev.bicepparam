using '../main.bicep'

param location = 'centralus'
param environment = 'dev'
param vmName = 'vm-nemoclaw-dev-001'
param vmSize = 'Standard_D4s_v4'
param sshPublicKey = '' // REQUIRED: paste your SSH public key
param allowedSshSourceIp = '*'
