// ============================================================================
// Step 2: Azure SQL Database + Private Endpoint
// ============================================================================

@description('Azure region')
param location string

@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Entra ID admin group object ID for SQL Server')
param sqlAdminObjectId string

@description('Entra ID admin group display name')
param sqlAdminLoginName string

@description('Tenant ID')
param tenantId string

@description('Subnet ID for private endpoint')
param privateEndpointSubnetId string

@description('Private DNS Zone ID for SQL')
param dnsZoneSqlId string

@description('SQL Database SKU name')
@allowed(['Basic', 'S0', 'S1', 'S2', 'GP_S_Gen5_1'])
param sqlSkuName string = 'Basic'

@description('SQL Database SKU tier')
@allowed(['Basic', 'Standard', 'GeneralPurpose'])
param sqlSkuTier string = 'Basic'

// ---------------------------------------------------------------------------
// Azure SQL Server (Entra ID-only auth)
// ---------------------------------------------------------------------------

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: 'sql-allowance-tracker-${environmentName}'
  location: location
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: sqlAdminLoginName
      sid: sqlAdminObjectId
      tenantId: tenantId
      principalType: 'User'
    }
  }
}

// ---------------------------------------------------------------------------
// Azure SQL Database
// ---------------------------------------------------------------------------

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: 'sqldb-allowance-tracker'
  location: location
  sku: {
    name: sqlSkuName
    tier: sqlSkuTier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    requestedBackupStorageRedundancy: 'Local'
  }
}

// ---------------------------------------------------------------------------
// Transparent Data Encryption (enabled by default, explicit for clarity)
// ---------------------------------------------------------------------------

resource tde 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Auditing to Azure SQL audit logs
// ---------------------------------------------------------------------------

resource sqlAudit 'Microsoft.Sql/servers/auditingSettings@2023-08-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
}

// ---------------------------------------------------------------------------
// Private Endpoint
// ---------------------------------------------------------------------------

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pe-sql-allowance-tracker-${environmentName}'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'sql-connection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
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
        name: 'config-sql'
        properties: {
          privateDnsZoneId: dnsZoneSqlId
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name
output sqlServerId string = sqlServer.id
