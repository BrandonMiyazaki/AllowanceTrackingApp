// ===========================================================================
// Step 4: Blazor Frontend (Presentation Tier)
// Purpose: Deploys the Blazor Server frontend App Service with VNet
//          Integration. This is the only publicly accessible resource.
//          Requires outputs from Step 1 (networking) and Step 3 (backend).
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

@description('Resource ID of the App Service Plan (from Step 3, or create a new one)')
param appServicePlanId string

@description('Resource ID of the frontend VNet Integration subnet (from Step 1)')
param frontendSubnetId string

@description('Default hostname of the backend API App Service (from Step 3)')
param backendApiHostname string

@description('.NET version for Blazor Server')
param dotnetVersion string = '8.0'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var nameSuffix = 'allowanceapp-${environmentName}'

// ---------------------------------------------------------------------------
// Module: Frontend App Service (Blazor Server)
// ---------------------------------------------------------------------------
module frontendApp 'modules/frontendAppService.bicep' = {
  name: 'deploy-frontend-app'
  params: {
    location: location
    appServiceName: 'app-web-${nameSuffix}'
    appServicePlanId: appServicePlanId
    vnetIntegrationSubnetId: frontendSubnetId
    backendApiHostname: backendApiHostname
    dotnetVersion: dotnetVersion
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Frontend App Service resource ID')
output frontendAppServiceId string = frontendApp.outputs.appServiceId

@description('Frontend App Service name')
output frontendAppServiceName string = frontendApp.outputs.appServiceName

@description('Frontend public URL')
output frontendUrl string = 'https://${frontendApp.outputs.defaultHostname}'

@description('Frontend Managed Identity Principal ID')
output frontendPrincipalId string = frontendApp.outputs.managedIdentityPrincipalId
