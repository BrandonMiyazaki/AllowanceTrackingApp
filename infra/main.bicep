// ============================================================================
// main.bicep — Orchestrator for Allowance Tracking App
// Deploys all modules in dependency order
// ============================================================================

targetScope = 'subscription'

@description('Azure region for all resources')
param location string

@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Tenant ID')
param tenantId string

@description('Entra ID admin group object ID for SQL Server admin')
param sqlAdminObjectId string

@description('Entra ID admin group display name for SQL Server admin')
param sqlAdminLoginName string

@description('Backend Entra ID App Registration Client ID')
param backendClientId string

@description('Frontend Entra ID App Registration Client ID')
param frontendClientId string

@description('Key Vault admin principal IDs')
param keyVaultAdminPrincipalIds array = []

@description('SQL Database SKU name')
@allowed(['Basic', 'S0', 'S1', 'S2', 'GP_S_Gen5_1'])
param sqlSkuName string = 'Basic'

@description('SQL Database SKU tier')
@allowed(['Basic', 'Standard', 'GeneralPurpose'])
param sqlSkuTier string = 'Basic'

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-allowance-tracker-${environmentName}'
  location: location
}

// ---------------------------------------------------------------------------
// Module 1: Monitoring (deploy first — Log Analytics needed by other modules)
// ---------------------------------------------------------------------------

module monitoring 'modules/monitoring.bicep' = {
  name: 'deploy-monitoring'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
  }
}

// ---------------------------------------------------------------------------
// Module 2: Networking (VNet, Subnets, NSGs, DNS Zones)
// ---------------------------------------------------------------------------

module networking 'modules/networking.bicep' = {
  name: 'deploy-networking'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
  }
}

// ---------------------------------------------------------------------------
// Module 3: Key Vault + Private Endpoint
// ---------------------------------------------------------------------------

module keyVault 'modules/keyvault.bicep' = {
  name: 'deploy-keyvault'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    tenantId: tenantId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    dnsZoneKeyVaultId: networking.outputs.dnsZoneKeyVaultId
    adminPrincipalIds: keyVaultAdminPrincipalIds
  }
}

// ---------------------------------------------------------------------------
// Module 4: Azure SQL + Private Endpoint
// ---------------------------------------------------------------------------

module sql 'modules/sql.bicep' = {
  name: 'deploy-sql'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    sqlAdminObjectId: sqlAdminObjectId
    sqlAdminLoginName: sqlAdminLoginName
    tenantId: tenantId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    dnsZoneSqlId: networking.outputs.dnsZoneSqlId
    sqlSkuName: sqlSkuName
    sqlSkuTier: sqlSkuTier
  }
}

// ---------------------------------------------------------------------------
// Module 5: Backend App Service + VNet Integration + Private Endpoint
// ---------------------------------------------------------------------------

module backend 'modules/backend.bicep' = {
  name: 'deploy-backend'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    backendSubnetId: networking.outputs.backendSubnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    dnsZoneAppServiceId: networking.outputs.dnsZoneAppServiceId
    sqlServerFqdn: sql.outputs.sqlServerFqdn
    sqlDatabaseName: sql.outputs.sqlDatabaseName
    tenantId: tenantId
    backendClientId: backendClientId
    keyVaultName: keyVault.outputs.keyVaultName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// ---------------------------------------------------------------------------
// Module 6: Frontend App Service + VNet Integration
// ---------------------------------------------------------------------------

module frontend 'modules/frontend.bicep' = {
  name: 'deploy-frontend'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    frontendSubnetId: networking.outputs.frontendSubnetId
    tenantId: tenantId
    frontendClientId: frontendClientId
    backendApiHostname: backend.outputs.appServiceDefaultHostname
    backendClientId: backendClientId
    keyVaultName: keyVault.outputs.keyVaultName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output resourceGroupName string = rg.name
output vnetName string = networking.outputs.vnetName
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output sqlDatabaseName string = sql.outputs.sqlDatabaseName
output backendAppServiceName string = backend.outputs.appServiceName
output backendHostname string = backend.outputs.appServiceDefaultHostname
output frontendAppServiceName string = frontend.outputs.appServiceName
output frontendHostname string = frontend.outputs.appServiceDefaultHostname
output keyVaultName string = keyVault.outputs.keyVaultName
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
