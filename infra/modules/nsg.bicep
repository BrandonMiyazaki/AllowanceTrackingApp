// ============================================================================
// NSG Module — Creates Network Security Groups with subnet-specific rules
// ============================================================================

@description('Azure region for NSG deployment')
param location string

@description('Environment name (dev, staging, prod)')
param environmentName string

@description('VNet address space for internal references')
param vnetAddressSpace string = '10.30.0.0/16'

// Subnet CIDR references for NSG rules
var subnets = {
  servers: '10.30.1.0/24'
  appserviceFrontend: '10.30.2.0/24'
  appserviceBackend: '10.30.3.0/24'
  peAppservice: '10.30.4.0/24'
  peSql: '10.30.5.0/24'
  peKeyvault: '10.30.6.0/24'
  peStorage: '10.30.7.0/24'
}

// ── NSG: Servers (test VMs) ─────────────────────────────────────────────────
resource nsgServers 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-servers-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRdpFromTrusted'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.servers
          destinationPortRange: '3389'
          description: 'Allow RDP from within VNet only'
        }
      }
      {
        name: 'AllowSshFromTrusted'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.servers
          destinationPortRange: '22'
          description: 'Allow SSH from within VNet only'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
      {
        name: 'AllowOutboundToVNet'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: subnets.servers
          sourcePortRange: '*'
          destinationAddressPrefix: vnetAddressSpace
          destinationPortRange: '*'
          description: 'Allow outbound to entire VNet for testing PE connectivity'
        }
      }
    ]
  }
}

// ── NSG: App Service Frontend (VNet Integration subnet) ─────────────────────
resource nsgAppserviceFrontend 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-appservice-frontend-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowOutboundToAppServicePE'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceFrontend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peAppservice
          destinationPortRange: '443'
          description: 'Allow HTTPS to backend App Service private endpoint'
        }
      }
      {
        name: 'AllowOutboundToKeyvaultPE'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceFrontend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peKeyvault
          destinationPortRange: '443'
          description: 'Allow HTTPS to Key Vault private endpoint'
        }
      }
      {
        name: 'AllowOutboundToDNS'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: subnets.appserviceFrontend
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzurePlatformDNS'
          destinationPortRange: '53'
          description: 'Allow DNS resolution'
        }
      }
    ]
  }
}

// ── NSG: App Service Backend (VNet Integration subnet) ──────────────────────
resource nsgAppserviceBackend 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-appservice-backend-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowOutboundToSqlPE'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceBackend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peSql
          destinationPortRange: '1433'
          description: 'Allow SQL traffic to SQL private endpoint'
        }
      }
      {
        name: 'AllowOutboundToKeyvaultPE'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceBackend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peKeyvault
          destinationPortRange: '443'
          description: 'Allow HTTPS to Key Vault private endpoint'
        }
      }
      {
        name: 'AllowOutboundToStoragePE'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceBackend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peStorage
          destinationPortRange: '443'
          description: 'Allow HTTPS to Storage private endpoint'
        }
      }
      {
        name: 'AllowOutboundToDNS'
        properties: {
          priority: 130
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: subnets.appserviceBackend
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzurePlatformDNS'
          destinationPortRange: '53'
          description: 'Allow DNS resolution'
        }
      }
    ]
  }
}

// ── NSG: Private Endpoint — App Service ─────────────────────────────────────
resource nsgPeAppservice 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-pe-appservice-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsFromFrontend'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceFrontend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peAppservice
          destinationPortRange: '443'
          description: 'Allow HTTPS from frontend App Service'
        }
      }
      {
        name: 'AllowHttpsFromServers'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.servers
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peAppservice
          destinationPortRange: '443'
          description: 'Allow HTTPS from test VMs'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
    ]
  }
}

// ── NSG: Private Endpoint — SQL ─────────────────────────────────────────────
resource nsgPeSql 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-pe-sql-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSqlFromBackend'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceBackend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peSql
          destinationPortRange: '1433'
          description: 'Allow SQL from backend App Service'
        }
      }
      {
        name: 'AllowSqlFromServers'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.servers
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peSql
          destinationPortRange: '1433'
          description: 'Allow SQL from test VMs'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
    ]
  }
}

// ── NSG: Private Endpoint — Key Vault ───────────────────────────────────────
resource nsgPeKeyvault 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-pe-keyvault-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsFromFrontend'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceFrontend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peKeyvault
          destinationPortRange: '443'
          description: 'Allow HTTPS from frontend App Service'
        }
      }
      {
        name: 'AllowHttpsFromBackend'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceBackend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peKeyvault
          destinationPortRange: '443'
          description: 'Allow HTTPS from backend App Service'
        }
      }
      {
        name: 'AllowHttpsFromServers'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.servers
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peKeyvault
          destinationPortRange: '443'
          description: 'Allow HTTPS from test VMs'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
    ]
  }
}

// ── NSG: Private Endpoint — Storage ─────────────────────────────────────────
resource nsgPeStorage 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-pe-storage-${environmentName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsFromBackend'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.appserviceBackend
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peStorage
          destinationPortRange: '443'
          description: 'Allow HTTPS from backend App Service'
        }
      }
      {
        name: 'AllowHttpsFromServers'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.servers
          sourcePortRange: '*'
          destinationAddressPrefix: subnets.peStorage
          destinationPortRange: '443'
          description: 'Allow HTTPS from test VMs'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
    ]
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────
output nsgServersId string = nsgServers.id
output nsgAppserviceFrontendId string = nsgAppserviceFrontend.id
output nsgAppserviceBackendId string = nsgAppserviceBackend.id
output nsgPeAppserviceId string = nsgPeAppservice.id
output nsgPeSqlId string = nsgPeSql.id
output nsgPeKeyvaultId string = nsgPeKeyvault.id
output nsgPeStorageId string = nsgPeStorage.id
