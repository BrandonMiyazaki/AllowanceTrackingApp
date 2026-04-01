// ============================================================================
// Private DNS Zones Module — Creates all Private DNS Zones and links to VNet
// ============================================================================

@description('VNet resource ID to link DNS zones to')
param vnetId string

@description('Environment name (dev, staging, prod)')
param environmentName string

// ── Private DNS Zone: Azure SQL ─────────────────────────────────────────────
resource dnsZoneSql 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  properties: {}
}

resource dnsZoneSqlLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dnsZoneSql
  name: 'link-sql-${environmentName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ── Private DNS Zone: Key Vault ─────────────────────────────────────────────
resource dnsZoneKeyvault 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  properties: {}
}

resource dnsZoneKeyvaultLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dnsZoneKeyvault
  name: 'link-keyvault-${environmentName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ── Private DNS Zone: App Service ───────────────────────────────────────────
resource dnsZoneAppservice 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  properties: {}
}

resource dnsZoneAppserviceLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dnsZoneAppservice
  name: 'link-appservice-${environmentName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ── Private DNS Zone: Storage Blob ──────────────────────────────────────────
resource dnsZoneBlob 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  properties: {}
}

resource dnsZoneBlobLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dnsZoneBlob
  name: 'link-blob-${environmentName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ── Private DNS Zone: Storage File ──────────────────────────────────────────
resource dnsZoneFile 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
  properties: {}
}

resource dnsZoneFileLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dnsZoneFile
  name: 'link-file-${environmentName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────
output dnsZoneSqlId string = dnsZoneSql.id
output dnsZoneKeyvaultId string = dnsZoneKeyvault.id
output dnsZoneAppserviceId string = dnsZoneAppservice.id
output dnsZoneBlobId string = dnsZoneBlob.id
output dnsZoneFileId string = dnsZoneFile.id

output dnsZoneSqlName string = dnsZoneSql.name
output dnsZoneKeyvaultName string = dnsZoneKeyvault.name
output dnsZoneAppserviceName string = dnsZoneAppservice.name
output dnsZoneBlobName string = dnsZoneBlob.name
output dnsZoneFileName string = dnsZoneFile.name
