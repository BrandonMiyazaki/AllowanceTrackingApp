// ===========================================================================
// Module: keyVault.bicep
// Purpose: Creates an Azure Key Vault with:
//          - RBAC authorization (no access policies)
//          - Public network access disabled
//          - Soft delete and purge protection enabled
//          - Grants Key Vault Secrets User role to the backend Managed Identity
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the Key Vault')
param keyVaultName string

@description('Tenant ID')
param tenantId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

@description('Resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Key Vault name')
output keyVaultName string = keyVault.name
