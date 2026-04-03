// ===========================================================================
// Step 1: Networking Foundation
// Purpose: Deploys VNet, subnets, NSGs, and Private DNS zones for the
//          Allowance Tracking App secure multi-tier architecture.
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

@description('VNet address space')
param vnetAddressPrefix string

@description('Servers subnet CIDR')
param serversSubnetPrefix string

@description('Frontend App Service subnet CIDR')
param frontendSubnetPrefix string

@description('Backend App Service subnet CIDR')
param backendSubnetPrefix string

@description('App Service PE subnet CIDR')
param peAppServiceSubnetPrefix string

@description('SQL PE subnet CIDR')
param peSqlSubnetPrefix string

@description('Key Vault PE subnet CIDR')
param peKeyvaultSubnetPrefix string

@description('Storage PE subnet CIDR')
param peStorageSubnetPrefix string

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var nameSuffix = 'allowanceapp-${environmentName}'

// ---------------------------------------------------------------------------
// Module: Network Security Groups
// Must be created before VNet so subnet references are valid.
// ---------------------------------------------------------------------------
module nsgs 'modules/nsgs.bicep' = {
  name: 'deploy-nsgs'
  params: {
    location: location
    environmentName: environmentName
  }
}

// ---------------------------------------------------------------------------
// Module: Virtual Network + Subnets
// ---------------------------------------------------------------------------
module vnet 'modules/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    location: location
    vnetName: 'vnet-${nameSuffix}'
    vnetAddressPrefix: vnetAddressPrefix
    serversSubnetPrefix: serversSubnetPrefix
    frontendSubnetPrefix: frontendSubnetPrefix
    backendSubnetPrefix: backendSubnetPrefix
    peAppServiceSubnetPrefix: peAppServiceSubnetPrefix
    peSqlSubnetPrefix: peSqlSubnetPrefix
    peKeyvaultSubnetPrefix: peKeyvaultSubnetPrefix
    peStorageSubnetPrefix: peStorageSubnetPrefix
    serversNsgId: nsgs.outputs.serversNsgId
    frontendNsgId: nsgs.outputs.frontendNsgId
    backendNsgId: nsgs.outputs.backendNsgId
    peAppServiceNsgId: nsgs.outputs.peAppServiceNsgId
    peSqlNsgId: nsgs.outputs.peSqlNsgId
    peKeyvaultNsgId: nsgs.outputs.peKeyvaultNsgId
    peStorageNsgId: nsgs.outputs.peStorageNsgId
  }
}

// ---------------------------------------------------------------------------
// Module: Private DNS Zones + VNet Links
// ---------------------------------------------------------------------------
module privateDns 'modules/privateDnsZones.bicep' = {
  name: 'deploy-private-dns'
  params: {
    vnetId: vnet.outputs.vnetId
    vnetName: vnet.outputs.vnetName
  }
}

// ---------------------------------------------------------------------------
// Outputs — consumed by subsequent steps (SQL, App Service, Key Vault, Storage)
// ---------------------------------------------------------------------------
@description('VNet resource ID')
output vnetId string = vnet.outputs.vnetId

@description('VNet name')
output vnetName string = vnet.outputs.vnetName

@description('Servers subnet resource ID')
output serversSubnetId string = vnet.outputs.serversSubnetId

@description('Frontend App Service subnet resource ID')
output frontendSubnetId string = vnet.outputs.frontendSubnetId

@description('Backend App Service subnet resource ID')
output backendSubnetId string = vnet.outputs.backendSubnetId

@description('App Service PE subnet resource ID')
output peAppServiceSubnetId string = vnet.outputs.peAppServiceSubnetId

@description('SQL PE subnet resource ID')
output peSqlSubnetId string = vnet.outputs.peSqlSubnetId

@description('Key Vault PE subnet resource ID')
output peKeyvaultSubnetId string = vnet.outputs.peKeyvaultSubnetId

@description('Storage PE subnet resource ID')
output peStorageSubnetId string = vnet.outputs.peStorageSubnetId

@description('SQL Private DNS Zone ID')
output sqlDnsZoneId string = privateDns.outputs.sqlDnsZoneId

@description('App Service Private DNS Zone ID')
output webAppDnsZoneId string = privateDns.outputs.webAppDnsZoneId

@description('Key Vault Private DNS Zone ID')
output kvDnsZoneId string = privateDns.outputs.kvDnsZoneId

@description('Storage Blob Private DNS Zone ID')
output storageBlobDnsZoneId string = privateDns.outputs.storageBlobDnsZoneId

@description('Storage File Private DNS Zone ID')
output storageFileDnsZoneId string = privateDns.outputs.storageFileDnsZoneId
