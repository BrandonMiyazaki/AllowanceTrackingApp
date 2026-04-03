// ===========================================================================
// Step 5: Monitoring & Operational Security
// Purpose: Deploys Log Analytics workspace, Application Insights for both
//          frontend and backend, then wires the connection strings into
//          the existing App Services. Also configures diagnostic settings
//          for the SQL database.
//          Requires outputs from Step 2 (SQL), Step 3 (backend), Step 4 (frontend).
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

@description('Log retention in days')
param logRetentionInDays int = 30

@description('Name of the backend App Service (from Step 3)')
param backendAppServiceName string

@description('Name of the frontend App Service (from Step 4)')
param frontendAppServiceName string

@description('Name of the SQL Server (from Step 2)')
param sqlServerName string

@description('Name of the SQL Database')
param databaseName string = 'allowance-db'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var nameSuffix = 'allowanceapp-${environmentName}'

// ---------------------------------------------------------------------------
// Module: Log Analytics Workspace
// ---------------------------------------------------------------------------
module logAnalytics 'modules/logAnalyticsWorkspace.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    location: location
    workspaceName: 'law-${nameSuffix}'
    retentionInDays: logRetentionInDays
  }
}

// ---------------------------------------------------------------------------
// Module: Application Insights — Backend API
// ---------------------------------------------------------------------------
module backendAppInsights 'modules/appInsights.bicep' = {
  name: 'deploy-ai-backend'
  params: {
    location: location
    appInsightsName: 'ai-api-${nameSuffix}'
    workspaceId: logAnalytics.outputs.workspaceId
  }
}

// ---------------------------------------------------------------------------
// Module: Application Insights — Frontend
// ---------------------------------------------------------------------------
module frontendAppInsights 'modules/appInsights.bicep' = {
  name: 'deploy-ai-frontend'
  params: {
    location: location
    appInsightsName: 'ai-web-${nameSuffix}'
    workspaceId: logAnalytics.outputs.workspaceId
  }
}

// ---------------------------------------------------------------------------
// Wire App Insights connection string into backend App Service
// ---------------------------------------------------------------------------
resource backendApp 'Microsoft.Web/sites@2024-04-01' existing = {
  name: backendAppServiceName
}

resource backendAppSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: backendApp
  name: 'appsettings'
  properties: union(backendApp.listApplicationSettings().properties, {
    APPLICATIONINSIGHTS_CONNECTION_STRING: backendAppInsights.outputs.connectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
  })
}

// ---------------------------------------------------------------------------
// Wire App Insights connection string into frontend App Service
// ---------------------------------------------------------------------------
resource frontendApp 'Microsoft.Web/sites@2024-04-01' existing = {
  name: frontendAppServiceName
}

resource frontendAppSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: frontendApp
  name: 'appsettings'
  properties: union(frontendApp.listApplicationSettings().properties, {
    APPLICATIONINSIGHTS_CONNECTION_STRING: frontendAppInsights.outputs.connectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
  })
}

// ---------------------------------------------------------------------------
// Diagnostic Settings: SQL Database → Log Analytics
// ---------------------------------------------------------------------------
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' existing = {
  name: sqlServerName
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' existing = {
  parent: sqlServer
  name: databaseName
}

resource sqlDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'sql-to-law'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalytics.outputs.workspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
      {
        category: 'SQLInsights'
        enabled: true
      }
      {
        category: 'Errors'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Alert Rule: High 5xx error rate on backend
// ---------------------------------------------------------------------------
resource backend5xxAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-5xx-api-${nameSuffix}'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [
      backendApp.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xxCount'
          metricName: 'Http5xx'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Alert Rule: High response time on backend
// ---------------------------------------------------------------------------
resource backendLatencyAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-latency-api-${nameSuffix}'
  location: 'global'
  properties: {
    severity: 3
    enabled: true
    scopes: [
      backendApp.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighLatency'
          metricName: 'HttpResponseTime'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Log Analytics workspace resource ID')
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId

@description('Backend Application Insights connection string')
output backendAiConnectionString string = backendAppInsights.outputs.connectionString

@description('Frontend Application Insights connection string')
output frontendAiConnectionString string = frontendAppInsights.outputs.connectionString
