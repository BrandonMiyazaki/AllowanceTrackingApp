// ===========================================================================
// Module: nsgs.bicep
// Purpose: Creates Network Security Groups for each subnet with least-privilege
//          rules. These NSGs are associated with subnets in the VNet module.
// ===========================================================================

@description('Azure region')
param location string

@description('Environment name for resource naming')
param environmentName string

// ---------------------------------------------------------------------------
// NSG: Servers Subnet (VMs for local testing)
// Allows RDP/SSH only from within the VNet. No internet inbound.
// ---------------------------------------------------------------------------
resource serversNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-snet-servers-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowRdpFromVNet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowSshFromVNet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// NSG: Frontend App Service Subnet
// Allows inbound HTTPS (443) from the internet for the Blazor app.
// ---------------------------------------------------------------------------
resource frontendNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-snet-appservice-frontend-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowHttpInboundForRedirect'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// NSG: Backend App Service Subnet
// Denies all inbound from internet. Only VNet traffic allowed.
// ---------------------------------------------------------------------------
resource backendNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-snet-appservice-backend-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVNetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// NSG: App Service PE Subnet
// ---------------------------------------------------------------------------
resource peAppServiceNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-snet-pe-appservice-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVNetHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// NSG: SQL PE Subnet
// ---------------------------------------------------------------------------
resource peSqlNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-snet-pe-sql-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVNetSqlInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// NSG: Key Vault PE Subnet
// ---------------------------------------------------------------------------
resource peKeyvaultNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-snet-pe-keyvault-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVNetHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// NSG: Storage PE Subnet
// ---------------------------------------------------------------------------
resource peStorageNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-snet-pe-storage-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVNetHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Resource ID of the servers NSG')
output serversNsgId string = serversNsg.id

@description('Resource ID of the frontend NSG')
output frontendNsgId string = frontendNsg.id

@description('Resource ID of the backend NSG')
output backendNsgId string = backendNsg.id

@description('Resource ID of the App Service PE NSG')
output peAppServiceNsgId string = peAppServiceNsg.id

@description('Resource ID of the SQL PE NSG')
output peSqlNsgId string = peSqlNsg.id

@description('Resource ID of the Key Vault PE NSG')
output peKeyvaultNsgId string = peKeyvaultNsg.id

@description('Resource ID of the Storage PE NSG')
output peStorageNsgId string = peStorageNsg.id
