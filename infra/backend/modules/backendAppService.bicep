// ===========================================================================
// Module: backendAppService.bicep
// Purpose: Creates the Node.js backend App Service with:
//          - System-assigned Managed Identity
//          - VNet Integration (snet-appservice-backend)
//          - Public network access disabled
//          - HTTPS only, TLS 1.2 minimum
//          - App settings pointing to SQL and Key Vault (no secrets)
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the App Service')
param appServiceName string

@description('Resource ID of the App Service Plan')
param appServicePlanId string

@description('Resource ID of the backend VNet Integration subnet')
param vnetIntegrationSubnetId string

@description('FQDN of the SQL Server (private DNS)')
param sqlServerFqdn string

@description('Name of the SQL database')
param databaseName string

@description('URI of the Key Vault')
param keyVaultUri string

@description('Node.js version')
param nodeVersion string = '20-lts'

resource backendApp 'Microsoft.Web/sites@2024-04-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    publicNetworkAccess: 'Disabled'
    httpsOnly: true
    virtualNetworkSubnetId: vnetIntegrationSubnetId
    siteConfig: {
      linuxFxVersion: 'NODE|${nodeVersion}'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: true
      http20Enabled: true
      appSettings: [
        {
          name: 'DATABASE_HOST'
          value: sqlServerFqdn
        }
        {
          name: 'DATABASE_NAME'
          value: databaseName
        }
        {
          name: 'KEY_VAULT_URL'
          value: keyVaultUri
        }
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16' // Azure DNS for private endpoint resolution
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1' // Route all outbound traffic through VNet
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true' // Run npm install during zip deploy
        }
      ]
    }
  }
}

@description('Resource ID of the backend App Service')
output appServiceId string = backendApp.id

@description('Name of the backend App Service')
output appServiceName string = backendApp.name

@description('Default hostname of the backend App Service')
output defaultHostname string = backendApp.properties.defaultHostName

@description('Principal ID of the system-assigned Managed Identity')
output managedIdentityPrincipalId string = backendApp.identity.principalId

@description('Tenant ID of the system-assigned Managed Identity')
output managedIdentityTenantId string = backendApp.identity.tenantId
