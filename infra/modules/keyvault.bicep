// ============================================================================
// Step 6: Key Vault + Private Endpoint
// ============================================================================

@description('Azure region')
param location string

@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Tenant ID for RBAC')
param tenantId string

@description('Subnet ID for the private endpoint')
param privateEndpointSubnetId string

@description('Private DNS Zone ID for Key Vault')
param dnsZoneKeyVaultId string

@description('Principal IDs to grant Key Vault Administrator role')
param adminPrincipalIds array = []

// ---------------------------------------------------------------------------
// Key Vault
// ---------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-allowtrack-${environmentName}'
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
      bypass: 'None'
    }
  }
}

// ---------------------------------------------------------------------------
// Private Endpoint
// ---------------------------------------------------------------------------

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pe-kv-allowance-tracker-${environmentName}'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'kv-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource privateDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config-keyvault'
        properties: {
          privateDnsZoneId: dnsZoneKeyVaultId
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// RBAC: Key Vault Administrator for admins
// ---------------------------------------------------------------------------

// Key Vault Administrator role definition ID
var keyVaultAdminRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

resource adminRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (principalId, i) in adminPrincipalIds: {
    name: guid(keyVault.id, principalId, keyVaultAdminRoleId)
    scope: keyVault
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdminRoleId)
      principalId: principalId
      principalType: 'User'
    }
  }
]

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
