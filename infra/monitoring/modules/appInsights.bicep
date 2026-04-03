// ===========================================================================
// Module: appInsights.bicep
// Purpose: Creates an Application Insights instance backed by a Log Analytics
//          workspace, then configures it on an existing App Service.
// ===========================================================================

@description('Azure region')
param location string

@description('Name of the Application Insights resource')
param appInsightsName string

@description('Resource ID of the Log Analytics workspace')
param workspaceId string

@description('Application type')
@allowed(['web', 'other'])
param applicationType string = 'web'

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: workspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('Resource ID of the Application Insights instance')
output appInsightsId string = appInsights.id

@description('Instrumentation key')
output instrumentationKey string = appInsights.properties.InstrumentationKey

@description('Connection string for Application Insights')
output connectionString string = appInsights.properties.ConnectionString
