// ===========================================================================
// Module: appServicePlan.bicep
// Purpose: Creates a Linux App Service Plan for hosting App Services.
//          Can be shared between backend and frontend, or used independently.
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the App Service Plan')
param appServicePlanName string

@description('SKU name (e.g., B1, B2, S1, P1v3)')
param skuName string

@description('SKU tier (e.g., Basic, Standard, PremiumV3)')
param skuTier string

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  properties: {
    reserved: true // required for Linux
  }
  sku: {
    name: skuName
    tier: skuTier
  }
}

@description('Resource ID of the App Service Plan')
output appServicePlanId string = appServicePlan.id
