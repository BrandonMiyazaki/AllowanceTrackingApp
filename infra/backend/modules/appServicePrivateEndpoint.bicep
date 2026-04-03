// ===========================================================================
// Module: appServicePrivateEndpoint.bicep
// Purpose: Creates a Private Endpoint for an App Service in the dedicated
//          App Service PE subnet, and registers it with the App Service
//          Private DNS Zone.
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the Private Endpoint')
param privateEndpointName string

@description('Resource ID of the App Service to connect to')
param appServiceId string

@description('Resource ID of the PE subnet (snet-pe-appservice)')
param subnetId string

@description('Resource ID of the App Service Private DNS Zone')
param webAppDnsZoneId string

resource appServicePe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
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
          privateLinkServiceId: appServiceId
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: appServicePe
  name: 'webAppDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'webAppDnsConfig'
        properties: {
          privateDnsZoneId: webAppDnsZoneId
        }
      }
    ]
  }
}

@description('Resource ID of the App Service Private Endpoint')
output privateEndpointId string = appServicePe.id
