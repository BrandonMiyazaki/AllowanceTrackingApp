// ===========================================================================
// Module: keyVaultPrivateEndpoint.bicep
// Purpose: Creates a Private Endpoint for Key Vault in the dedicated
//          Key Vault PE subnet, and registers it with the Key Vault
//          Private DNS Zone.
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the Private Endpoint')
param privateEndpointName string

@description('Resource ID of the Key Vault')
param keyVaultId string

@description('Resource ID of the PE subnet (snet-pe-keyvault)')
param subnetId string

@description('Resource ID of the Key Vault Private DNS Zone')
param kvDnsZoneId string

resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: kvPrivateEndpoint
  name: 'kvDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kvDnsConfig'
        properties: {
          privateDnsZoneId: kvDnsZoneId
        }
      }
    ]
  }
}

@description('Resource ID of the Key Vault Private Endpoint')
output privateEndpointId string = kvPrivateEndpoint.id
