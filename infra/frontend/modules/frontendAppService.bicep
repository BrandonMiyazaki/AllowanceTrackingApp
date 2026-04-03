// ===========================================================================
// Module: frontendAppService.bicep
// Purpose: Creates the Blazor Server frontend App Service with:
//          - VNet Integration (snet-appservice-frontend)
//          - Public network access enabled (user-facing entry point)
//          - HTTPS only, TLS 1.2 minimum
//          - App setting pointing to backend API via private DNS
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the App Service')
param appServiceName string

@description('Resource ID of the App Service Plan')
param appServicePlanId string

@description('Resource ID of the frontend VNet Integration subnet')
param vnetIntegrationSubnetId string

@description('Private hostname of the backend API (resolved via VNet + Private DNS)')
param backendApiHostname string

@description('.NET version (e.g., 8.0, 9.0)')
param dotnetVersion string = '8.0'

resource frontendApp 'Microsoft.Web/sites@2024-04-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    publicNetworkAccess: 'Enabled'
    httpsOnly: true
    virtualNetworkSubnetId: vnetIntegrationSubnetId
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|${dotnetVersion}'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: true
      http20Enabled: true
      appSettings: [
        {
          name: 'ApiBaseUrl'
          value: 'https://${backendApiHostname}'
        }
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16' // Azure DNS for private endpoint resolution
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1' // Route all outbound traffic through VNet
        }
      ]
    }
  }
}

@description('Resource ID of the frontend App Service')
output appServiceId string = frontendApp.id

@description('Name of the frontend App Service')
output appServiceName string = frontendApp.name

@description('Default hostname of the frontend App Service')
output defaultHostname string = frontendApp.properties.defaultHostName

@description('Principal ID of the system-assigned Managed Identity')
output managedIdentityPrincipalId string = frontendApp.identity.principalId
