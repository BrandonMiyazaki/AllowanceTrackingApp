// ===========================================================================
// Module: sqlPrivateEndpoint.bicep
// Purpose: Creates a Private Endpoint for the Azure SQL Server in the
//          dedicated SQL PE subnet, and registers it with the SQL Private
//          DNS Zone for in-VNet name resolution.
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the Private Endpoint')
param privateEndpointName string

@description('Resource ID of the SQL Server to connect to')
param sqlServerId string

@description('Resource ID of the PE subnet (snet-pe-sql)')
param subnetId string

@description('Resource ID of the SQL Private DNS Zone')
param sqlDnsZoneId string

// ---------------------------------------------------------------------------
// Private Endpoint for SQL Server
// ---------------------------------------------------------------------------
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
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
          privateLinkServiceId: sqlServerId
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// DNS Zone Group — auto-registers the PE IP in the Private DNS Zone
// ---------------------------------------------------------------------------
resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: sqlPrivateEndpoint
  name: 'sqlDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sqlDnsConfig'
        properties: {
          privateDnsZoneId: sqlDnsZoneId
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Resource ID of the SQL Private Endpoint')
output privateEndpointId string = sqlPrivateEndpoint.id
