// ===========================================================================
// Module: vnet.bicep
// Purpose: Creates the Azure Virtual Network with seven subnets:
//          - Servers (VMs), Frontend/Backend App Service (delegated),
//          - Dedicated PE subnets for App Service, SQL, Key Vault, Storage.
// ===========================================================================

@description('Azure region for the VNet')
param location string

@description('Name of the Virtual Network')
param vnetName string

@description('Address space for the VNet')
param vnetAddressPrefix string

@description('Address prefix for the servers subnet')
param serversSubnetPrefix string

@description('Address prefix for the frontend App Service subnet')
param frontendSubnetPrefix string

@description('Address prefix for the backend App Service subnet')
param backendSubnetPrefix string

@description('Address prefix for the App Service private endpoint subnet')
param peAppServiceSubnetPrefix string

@description('Address prefix for the SQL private endpoint subnet')
param peSqlSubnetPrefix string

@description('Address prefix for the Key Vault private endpoint subnet')
param peKeyvaultSubnetPrefix string

@description('Address prefix for the Storage private endpoint subnet')
param peStorageSubnetPrefix string

@description('Resource ID of the NSG for the servers subnet')
param serversNsgId string

@description('Resource ID of the NSG for the frontend subnet')
param frontendNsgId string

@description('Resource ID of the NSG for the backend subnet')
param backendNsgId string

@description('Resource ID of the NSG for the App Service PE subnet')
param peAppServiceNsgId string

@description('Resource ID of the NSG for the SQL PE subnet')
param peSqlNsgId string

@description('Resource ID of the NSG for the Key Vault PE subnet')
param peKeyvaultNsgId string

@description('Resource ID of the NSG for the Storage PE subnet')
param peStorageNsgId string

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-servers'
        properties: {
          addressPrefix: serversSubnetPrefix
          networkSecurityGroup: {
            id: serversNsgId
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-appservice-frontend'
        properties: {
          addressPrefix: frontendSubnetPrefix
          networkSecurityGroup: {
            id: frontendNsgId
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
      {
        name: 'snet-appservice-backend'
        properties: {
          addressPrefix: backendSubnetPrefix
          networkSecurityGroup: {
            id: backendNsgId
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
      {
        name: 'snet-pe-appservice'
        properties: {
          addressPrefix: peAppServiceSubnetPrefix
          networkSecurityGroup: {
            id: peAppServiceNsgId
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-pe-sql'
        properties: {
          addressPrefix: peSqlSubnetPrefix
          networkSecurityGroup: {
            id: peSqlNsgId
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-pe-keyvault'
        properties: {
          addressPrefix: peKeyvaultSubnetPrefix
          networkSecurityGroup: {
            id: peKeyvaultNsgId
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-pe-storage'
        properties: {
          addressPrefix: peStorageSubnetPrefix
          networkSecurityGroup: {
            id: peStorageNsgId
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

@description('Resource ID of the Virtual Network')
output vnetId string = vnet.id

@description('Name of the Virtual Network')
output vnetName string = vnet.name

@description('Resource ID of the servers subnet')
output serversSubnetId string = vnet.properties.subnets[0].id

@description('Resource ID of the frontend App Service subnet')
output frontendSubnetId string = vnet.properties.subnets[1].id

@description('Resource ID of the backend App Service subnet')
output backendSubnetId string = vnet.properties.subnets[2].id

@description('Resource ID of the App Service PE subnet')
output peAppServiceSubnetId string = vnet.properties.subnets[3].id

@description('Resource ID of the SQL PE subnet')
output peSqlSubnetId string = vnet.properties.subnets[4].id

@description('Resource ID of the Key Vault PE subnet')
output peKeyvaultSubnetId string = vnet.properties.subnets[5].id

@description('Resource ID of the Storage PE subnet')
output peStorageSubnetId string = vnet.properties.subnets[6].id
