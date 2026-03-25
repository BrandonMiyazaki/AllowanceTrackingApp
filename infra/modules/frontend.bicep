// ============================================================================
// Step 4: Frontend App Service (Blazor Server) + VNet Integration
// ============================================================================

@description('Azure region')
param location string

@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Subnet ID for VNet integration (outbound)')
param frontendSubnetId string

@description('Tenant ID for Entra ID auth')
param tenantId string

@description('Frontend Entra ID App Registration Client ID')
param frontendClientId string

@description('Backend API App Service hostname')
param backendApiHostname string

@description('Backend Entra ID App Registration Client ID (for scope)')
param backendClientId string

@description('Key Vault name for secret references')
param keyVaultName string

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

// ---------------------------------------------------------------------------
// App Service Plan (Linux, .NET 9)
// ---------------------------------------------------------------------------

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-frontend-allowance-tracker-${environmentName}'
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
}

// ---------------------------------------------------------------------------
// App Service (Blazor Server)
// ---------------------------------------------------------------------------

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: 'app-web-allowance-tracker-${environmentName}'
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled' // Public-facing frontend
    virtualNetworkSubnetId: frontendSubnetId
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|9.0'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: true
      appSettings: [
        {
          name: 'AzureAd__TenantId'
          value: tenantId
        }
        {
          name: 'AzureAd__ClientId'
          value: frontendClientId
        }
        {
          name: 'AzureAd__ClientSecret'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=frontend-entra-client-secret)'
        }
        {
          name: 'AzureAd__Instance'
          #disable-next-line no-hardcoded-env-urls
          value: 'https://login.microsoftonline.com/'
        }
        {
          name: 'AzureAd__CallbackPath'
          value: '/signin-oidc'
        }
        {
          name: 'BackendApi__BaseUrl'
          value: 'https://${backendApiHostname}'
        }
        {
          name: 'BackendApi__Scope'
          value: 'api://${backendClientId}/.default'
        }
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Diagnostics (conditional on Log Analytics)
// ---------------------------------------------------------------------------

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'diag-frontend-${environmentName}'
  scope: appService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Key Vault RBAC: Grant Managed Identity "Key Vault Secrets User"
// ---------------------------------------------------------------------------

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultName, appService.id, keyVaultSecretsUserRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output appServiceName string = appService.name
output appServiceDefaultHostname string = appService.properties.defaultHostName
output appServicePrincipalId string = appService.identity.principalId
output appServiceId string = appService.id
