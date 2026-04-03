// ===========================================================================
// Step 2: Azure SQL Database
// Purpose: Deploys Azure SQL logical server, database, private endpoint,
//          and DNS registration. Requires Step 1 networking outputs.
//
// Deploy with:
//   az deployment group create \
//     --resource-group rg-allowanceapp-dev \
//     --template-file main.bicep \
//     --parameters parameters.bicepparam
// ===========================================================================

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
@description('Azure region for all resources')
param location string

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Resource ID of the SQL PE subnet (from Step 1)')
param peSqlSubnetId string

@description('Resource ID of the SQL Private DNS Zone (from Step 1)')
param sqlDnsZoneId string

@description('Database SKU name')
param databaseSkuName string

@description('Database SKU tier')
param databaseSkuTier string

@description('Object ID of the Entra AD admin user or group')
param entraAdminObjectId string

@description('Login name for the Entra AD admin')
param entraAdminLogin string

@description('Tenant ID for Entra authentication')
param tenantId string

@description('Resource ID of Log Analytics workspace (optional)')
param logAnalyticsWorkspaceId string = ''

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var nameSuffix = 'allowanceapp-${environmentName}'

// ---------------------------------------------------------------------------
// Module: SQL Server + Database
// ---------------------------------------------------------------------------
module sqlServer 'modules/sqlServer.bicep' = {
  name: 'deploy-sql-server'
  params: {
    location: location
    sqlServerName: 'sql-${nameSuffix}'
    databaseName: 'allowance-db'
    databaseSkuName: databaseSkuName
    databaseSkuTier: databaseSkuTier
    entraAdminObjectId: entraAdminObjectId
    entraAdminLogin: entraAdminLogin
    tenantId: tenantId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ---------------------------------------------------------------------------
// Module: SQL Private Endpoint + DNS Registration
// ---------------------------------------------------------------------------
module sqlPrivateEndpoint 'modules/sqlPrivateEndpoint.bicep' = {
  name: 'deploy-sql-pe'
  params: {
    location: location
    privateEndpointName: 'pe-sql-${nameSuffix}'
    sqlServerId: sqlServer.outputs.sqlServerId
    subnetId: peSqlSubnetId
    sqlDnsZoneId: sqlDnsZoneId
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('SQL Server resource ID')
output sqlServerId string = sqlServer.outputs.sqlServerId

@description('SQL Server FQDN (use for connection strings)')
output sqlServerFqdn string = sqlServer.outputs.sqlServerFqdn

@description('SQL Server name')
output sqlServerName string = sqlServer.outputs.sqlServerName

@description('Database resource ID')
output databaseId string = sqlServer.outputs.databaseId

@description('SQL Private Endpoint resource ID')
output sqlPrivateEndpointId string = sqlPrivateEndpoint.outputs.privateEndpointId
