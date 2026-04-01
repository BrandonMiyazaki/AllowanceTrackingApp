// ============================================================================
// Step 1: Networking Foundation — Main Deployment
// Deploys: VNet, Subnets, NSGs, Private DNS Zones
// ============================================================================

targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string

@description('Environment name (dev, staging, prod)')
param environmentName string

// ── Module: Network Security Groups ─────────────────────────────────────────
module nsgs 'modules/nsg.bicep' = {
  name: 'deploy-nsgs-${environmentName}'
  params: {
    location: location
    environmentName: environmentName
  }
}

// ── Module: Virtual Network & Subnets ───────────────────────────────────────
module vnet 'modules/vnet.bicep' = {
  name: 'deploy-vnet-${environmentName}'
  params: {
    location: location
    environmentName: environmentName
    nsgServersId: nsgs.outputs.nsgServersId
    nsgAppserviceFrontendId: nsgs.outputs.nsgAppserviceFrontendId
    nsgAppserviceBackendId: nsgs.outputs.nsgAppserviceBackendId
    nsgPeAppserviceId: nsgs.outputs.nsgPeAppserviceId
    nsgPeSqlId: nsgs.outputs.nsgPeSqlId
    nsgPeKeyvaultId: nsgs.outputs.nsgPeKeyvaultId
    nsgPeStorageId: nsgs.outputs.nsgPeStorageId
  }
}

// ── Module: Private DNS Zones ───────────────────────────────────────────────
module privateDns 'modules/private-dns.bicep' = {
  name: 'deploy-private-dns-${environmentName}'
  params: {
    vnetId: vnet.outputs.vnetId
    environmentName: environmentName
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────
// VNet
output vnetId string = vnet.outputs.vnetId
output vnetName string = vnet.outputs.vnetName

// Subnets
output snetServersId string = vnet.outputs.snetServersId
output snetAppserviceFrontendId string = vnet.outputs.snetAppserviceFrontendId
output snetAppserviceBackendId string = vnet.outputs.snetAppserviceBackendId
output snetPeAppserviceId string = vnet.outputs.snetPeAppserviceId
output snetPeSqlId string = vnet.outputs.snetPeSqlId
output snetPeKeyvaultId string = vnet.outputs.snetPeKeyvaultId
output snetPeStorageId string = vnet.outputs.snetPeStorageId

// DNS Zones
output dnsZoneSqlId string = privateDns.outputs.dnsZoneSqlId
output dnsZoneKeyvaultId string = privateDns.outputs.dnsZoneKeyvaultId
output dnsZoneAppserviceId string = privateDns.outputs.dnsZoneAppserviceId
output dnsZoneBlobId string = privateDns.outputs.dnsZoneBlobId
output dnsZoneFileId string = privateDns.outputs.dnsZoneFileId
