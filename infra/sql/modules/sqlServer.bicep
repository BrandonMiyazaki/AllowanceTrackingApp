// ===========================================================================
// Module: sqlServer.bicep
// Purpose: Creates an Azure SQL logical server and database with:
//          - Microsoft Entra-only authentication (no SQL admin password)
//          - Public network access disabled
//          - TDE enabled (default)
//          - Auditing to Log Analytics
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the SQL logical server')
param sqlServerName string

@description('Name of the database')
param databaseName string

@description('SKU name for the database (e.g., Basic, S0, S1)')
param databaseSkuName string

@description('SKU tier for the database')
param databaseSkuTier string

@description('Object ID of the Entra AD admin user or group')
param entraAdminObjectId string

@description('Login name for the Entra AD admin')
param entraAdminLogin string

@description('Tenant ID for Entra authentication')
param tenantId string

@description('Resource ID of the Log Analytics workspace for auditing')
param logAnalyticsWorkspaceId string = ''

// ---------------------------------------------------------------------------
// Azure SQL Logical Server
// ---------------------------------------------------------------------------
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: entraAdminLogin
      sid: entraAdminObjectId
      tenantId: tenantId
      azureADOnlyAuthentication: true
    }
  }
}

// ---------------------------------------------------------------------------
// Azure SQL Database
// ---------------------------------------------------------------------------
resource database 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: {
    name: databaseSkuName
    tier: databaseSkuTier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB
    zoneRedundant: false
  }
}

// ---------------------------------------------------------------------------
// Auditing Policy — send SQL audit logs to Log Analytics
// ---------------------------------------------------------------------------
resource sqlAuditSettings 'Microsoft.Sql/servers/auditingSettings@2023-08-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
}

// ---------------------------------------------------------------------------
// Diagnostic Settings — route to Log Analytics if workspace provided
// ---------------------------------------------------------------------------
resource sqlDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'sql-diagnostics'
  scope: database
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Resource ID of the SQL Server')
output sqlServerId string = sqlServer.id

@description('Fully qualified domain name of the SQL Server')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('Name of the SQL Server')
output sqlServerName string = sqlServer.name

@description('Resource ID of the database')
output databaseId string = database.id
