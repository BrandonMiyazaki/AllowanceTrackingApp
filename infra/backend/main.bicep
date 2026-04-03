// ===========================================================================
// Step 3: Node.js Backend API + Key Vault
// Purpose: Deploys the backend App Service (Node.js), its Private Endpoint,
//          Azure Key Vault with Private Endpoint, and RBAC role assignments.
//          Requires outputs from Step 1 (networking) and Step 2 (SQL).
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

@description('App Service Plan SKU name')
param aspSkuName string

@description('App Service Plan SKU tier')
param aspSkuTier string

@description('Resource ID of the backend VNet Integration subnet (from Step 1)')
param backendSubnetId string

@description('Resource ID of the App Service PE subnet (from Step 1)')
param peAppServiceSubnetId string

@description('Resource ID of the Key Vault PE subnet (from Step 1)')
param peKeyvaultSubnetId string

@description('Resource ID of the App Service Private DNS Zone (from Step 1)')
param webAppDnsZoneId string

@description('Resource ID of the Key Vault Private DNS Zone (from Step 1)')
param kvDnsZoneId string

@description('SQL Server FQDN (from Step 2)')
param sqlServerFqdn string

@description('SQL database name')
param databaseName string = 'allowance-db'

@description('Tenant ID for Key Vault and RBAC')
param tenantId string

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var nameSuffix = 'allowanceapp-${environmentName}'

// ---------------------------------------------------------------------------
// Module: App Service Plan (Linux)
// ---------------------------------------------------------------------------
module appServicePlan 'modules/appServicePlan.bicep' = {
  name: 'deploy-asp-backend'
  params: {
    location: location
    appServicePlanName: 'asp-backend-${nameSuffix}'
    skuName: aspSkuName
    skuTier: aspSkuTier
  }
}

// ---------------------------------------------------------------------------
// Module: Key Vault (deploy first — no dependency on backend)
// ---------------------------------------------------------------------------
module keyVault 'modules/keyVault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    location: location
    keyVaultName: 'kv-${nameSuffix}'
    tenantId: tenantId
  }
}

// ---------------------------------------------------------------------------
// Module: Backend App Service (Node.js)
// Depends on Key Vault for its URI in app settings.
// ---------------------------------------------------------------------------
module backendApp 'modules/backendAppService.bicep' = {
  name: 'deploy-backend-app'
  params: {
    location: location
    appServiceName: 'app-api-${nameSuffix}'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    vnetIntegrationSubnetId: backendSubnetId
    sqlServerFqdn: sqlServerFqdn
    databaseName: databaseName
    keyVaultUri: keyVault.outputs.keyVaultUri
  }
}

// ---------------------------------------------------------------------------
// RBAC: Key Vault Secrets User for the backend Managed Identity
// Depends on both Key Vault and backend App Service — no cycle.
// Role definition ID: 4633458b-17de-408a-b874-0445c86b69e6
// ---------------------------------------------------------------------------
resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('kv-${nameSuffix}', 'app-api-${nameSuffix}', '4633458b-17de-408a-b874-0445c86b69e6')
  scope: kvResource
  properties: {
    principalId: backendApp.outputs.managedIdentityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'ServicePrincipal'
  }
}

// Reference to the deployed Key Vault for scoping the role assignment
resource kvResource 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: 'kv-${nameSuffix}'
}

// ---------------------------------------------------------------------------
// Module: Backend App Service Private Endpoint
// ---------------------------------------------------------------------------
module backendPe 'modules/appServicePrivateEndpoint.bicep' = {
  name: 'deploy-backend-pe'
  params: {
    location: location
    privateEndpointName: 'pe-api-${nameSuffix}'
    appServiceId: backendApp.outputs.appServiceId
    subnetId: peAppServiceSubnetId
    webAppDnsZoneId: webAppDnsZoneId
  }
}

// ---------------------------------------------------------------------------
// Module: Key Vault Private Endpoint
// ---------------------------------------------------------------------------
module kvPe 'modules/keyVaultPrivateEndpoint.bicep' = {
  name: 'deploy-kv-pe'
  params: {
    location: location
    privateEndpointName: 'pe-kv-${nameSuffix}'
    keyVaultId: keyVault.outputs.keyVaultId
    subnetId: peKeyvaultSubnetId
    kvDnsZoneId: kvDnsZoneId
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Backend App Service resource ID')
output backendAppServiceId string = backendApp.outputs.appServiceId

@description('Backend App Service name')
output backendAppServiceName string = backendApp.outputs.appServiceName

@description('Backend App Service default hostname')
output backendDefaultHostname string = backendApp.outputs.defaultHostname

@description('Backend Managed Identity Principal ID')
output backendPrincipalId string = backendApp.outputs.managedIdentityPrincipalId

@description('Key Vault resource ID')
output keyVaultId string = keyVault.outputs.keyVaultId

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Key Vault name')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Backend PE resource ID')
output backendPeId string = backendPe.outputs.privateEndpointId

@description('Key Vault PE resource ID')
output kvPeId string = kvPe.outputs.privateEndpointId

@description('App Service Plan resource ID (reuse for frontend in Step 4)')
output appServicePlanId string = appServicePlan.outputs.appServicePlanId
