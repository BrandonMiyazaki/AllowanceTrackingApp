using './main.bicep'

param location = 'eastus'
param environmentName = 'dev'
param tenantId = 'c49d98d9-c647-45b1-97c7-6ae2976f8e9a'
param sqlAdminObjectId = '678b856a-e8fe-4f12-9ff6-4d675b49feae'       // brandon_admin@miyazaki.dev
param sqlAdminLoginName = 'brandon admin'
param backendClientId = '28027375-e1c7-4c06-84eb-95fb76c55d85'        // app-reg-allowance-tracker-api
param frontendClientId = '038099c6-6f75-4961-acf5-d4dfc2c62b3a'       // app-reg-allowance-tracker-web
param keyVaultAdminPrincipalIds = [
  '678b856a-e8fe-4f12-9ff6-4d675b49feae'                              // brandon_admin@miyazaki.dev
]
param sqlSkuName = 'Basic'
param sqlSkuTier = 'Basic'
