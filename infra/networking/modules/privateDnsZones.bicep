// ===========================================================================
// Module: privateDnsZones.bicep
// Purpose: Creates Private DNS Zones for Azure SQL, App Service, and Key Vault,
//          then links each zone to the VNet for in-network name resolution.
// ===========================================================================

@description('Resource ID of the VNet to link DNS zones to')
param vnetId string

@description('Name of the VNet (used in DNS zone link naming)')
param vnetName string

// ---------------------------------------------------------------------------
// Private DNS Zone: Azure SQL Database
// Uses environment() to avoid hardcoded cloud-specific hostnames.
// ---------------------------------------------------------------------------
var sqlSuffix = environment().suffixes.sqlServerHostname // .database.windows.net
resource sqlDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink${sqlSuffix}'
  location: 'global'
}

resource sqlDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: sqlDnsZone
  name: '${vnetName}-sql-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Private DNS Zone: Azure App Service (for backend private endpoint)
// ---------------------------------------------------------------------------
resource webAppDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}

resource webAppDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: webAppDnsZone
  name: '${vnetName}-webapp-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Private DNS Zone: Azure Key Vault
// ---------------------------------------------------------------------------
resource kvDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
}

resource kvDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: kvDnsZone
  name: '${vnetName}-kv-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Private DNS Zone: Azure Storage — Blob
// ---------------------------------------------------------------------------
resource storageBlobDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
}

resource storageBlobDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: storageBlobDnsZone
  name: '${vnetName}-storageblob-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Private DNS Zone: Azure Storage — File
// ---------------------------------------------------------------------------
resource storageFileDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
}

resource storageFileDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: storageFileDnsZone
  name: '${vnetName}-storagefile-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Outputs — DNS zone IDs needed by later steps for PE DNS group associations
// ---------------------------------------------------------------------------
@description('Resource ID of the SQL Private DNS Zone')
output sqlDnsZoneId string = sqlDnsZone.id

@description('Resource ID of the App Service Private DNS Zone')
output webAppDnsZoneId string = webAppDnsZone.id

@description('Resource ID of the Key Vault Private DNS Zone')
output kvDnsZoneId string = kvDnsZone.id

@description('Resource ID of the Storage Blob Private DNS Zone')
output storageBlobDnsZoneId string = storageBlobDnsZone.id

@description('Resource ID of the Storage File Private DNS Zone')
output storageFileDnsZoneId string = storageFileDnsZone.id
