// ============================================================================
// VNet Module — Creates the Virtual Network with all subnets
// ============================================================================

@description('Azure region for VNet deployment')
param location string

@description('Environment name (dev, staging, prod)')
param environmentName string

// NSG Resource IDs (passed from NSG module)
@description('NSG resource ID for the servers subnet')
param nsgServersId string

@description('NSG resource ID for the frontend App Service subnet')
param nsgAppserviceFrontendId string

@description('NSG resource ID for the backend App Service subnet')
param nsgAppserviceBackendId string

@description('NSG resource ID for the App Service private endpoint subnet')
param nsgPeAppserviceId string

@description('NSG resource ID for the SQL private endpoint subnet')
param nsgPeSqlId string

@description('NSG resource ID for the Key Vault private endpoint subnet')
param nsgPeKeyvaultId string

@description('NSG resource ID for the Storage private endpoint subnet')
param nsgPeStorageId string

// ── Virtual Network ─────────────────────────────────────────────────────────
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-allowance-${environmentName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.30.0.0/16'
      ]
    }
    subnets: [
      // ── snet-servers: VMs for testing private connectivity ──────────────
      {
        name: 'snet-servers'
        properties: {
          addressPrefix: '10.30.1.0/24'
          networkSecurityGroup: {
            id: nsgServersId
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      // ── snet-appservice-frontend: Blazor VNet Integration ──────────────
      {
        name: 'snet-appservice-frontend'
        properties: {
          addressPrefix: '10.30.2.0/24'
          networkSecurityGroup: {
            id: nsgAppserviceFrontendId
          }
          delegations: [
            {
              name: 'delegation-appservice'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      // ── snet-appservice-backend: Node.js VNet Integration ──────────────
      {
        name: 'snet-appservice-backend'
        properties: {
          addressPrefix: '10.30.3.0/24'
          networkSecurityGroup: {
            id: nsgAppserviceBackendId
          }
          delegations: [
            {
              name: 'delegation-appservice'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      // ── snet-pe-appservice: Private Endpoints for App Services ─────────
      {
        name: 'snet-pe-appservice'
        properties: {
          addressPrefix: '10.30.4.0/24'
          networkSecurityGroup: {
            id: nsgPeAppserviceId
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      // ── snet-pe-sql: Private Endpoint for Azure SQL ────────────────────
      {
        name: 'snet-pe-sql'
        properties: {
          addressPrefix: '10.30.5.0/24'
          networkSecurityGroup: {
            id: nsgPeSqlId
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      // ── snet-pe-keyvault: Private Endpoint for Key Vault ───────────────
      {
        name: 'snet-pe-keyvault'
        properties: {
          addressPrefix: '10.30.6.0/24'
          networkSecurityGroup: {
            id: nsgPeKeyvaultId
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      // ── snet-pe-storage: Private Endpoint for Storage Account ──────────
      {
        name: 'snet-pe-storage'
        properties: {
          addressPrefix: '10.30.7.0/24'
          networkSecurityGroup: {
            id: nsgPeStorageId
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────
output vnetId string = vnet.id
output vnetName string = vnet.name

output snetServersId string = vnet.properties.subnets[0].id
output snetAppserviceFrontendId string = vnet.properties.subnets[1].id
output snetAppserviceBackendId string = vnet.properties.subnets[2].id
output snetPeAppserviceId string = vnet.properties.subnets[3].id
output snetPeSqlId string = vnet.properties.subnets[4].id
output snetPeKeyvaultId string = vnet.properties.subnets[5].id
output snetPeStorageId string = vnet.properties.subnets[6].id
