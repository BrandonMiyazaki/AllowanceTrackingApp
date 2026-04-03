// ===========================================================================
// Module: logAnalyticsWorkspace.bicep
// Purpose: Creates a Log Analytics workspace for centralized logging,
//          diagnostics, and Application Insights backend.
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the Log Analytics workspace')
param workspaceName string

@description('Retention period in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('SKU for the workspace')
param skuName string = 'PerGB2018'

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: skuName
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('Resource ID of the Log Analytics workspace')
output workspaceId string = workspace.id

@description('Name of the Log Analytics workspace')
output workspaceName string = workspace.name
