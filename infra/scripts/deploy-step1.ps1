<#
.SYNOPSIS
    Deploys Step 1 (Networking Foundation) for the Allowance Tracking App.

.DESCRIPTION
    Creates the resource group (if it doesn't exist) and deploys:
    - Virtual Network (10.30.0.0/16) with 7 subnets
    - Network Security Groups (one per subnet)
    - Private DNS Zones with VNet links

.PARAMETER ResourceGroupName
    Name of the resource group. Default: rg-allowance-app-dev

.PARAMETER Location
    Azure region. Default: eastus2

.PARAMETER EnvironmentName
    Environment name (dev, staging, prod). Default: dev

.EXAMPLE
    .\deploy-step1.ps1
    .\deploy-step1.ps1 -ResourceGroupName "rg-allowance-app-prod" -Location "westus2" -EnvironmentName "prod"
#>

param(
    [string]$ResourceGroupName = "rg-allowance-app-dev",
    [string]$Location = "westus2",
    [string]$EnvironmentName = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Step 1: Networking Foundation Deployment"   -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Verify Azure CLI is logged in ────────────────────────────────────────
Write-Host "[1/4] Checking Azure CLI login..." -ForegroundColor Yellow
$account = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged into Azure CLI. Run 'az login' first."
    exit 1
}
$accountInfo = $account | ConvertFrom-Json
Write-Host "  Subscription: $($accountInfo.name) ($($accountInfo.id))" -ForegroundColor Green

# ── 2. Create Resource Group ────────────────────────────────────────────────
Write-Host "[2/4] Creating resource group: $ResourceGroupName..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none
Write-Host "  Resource group ready." -ForegroundColor Green

# ── 3. Deploy Bicep template ────────────────────────────────────────────────
Write-Host "[3/4] Deploying Bicep template (VNet, NSGs, DNS Zones)..." -ForegroundColor Yellow

$deploymentName = "step1-networking-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$templateFile = Join-Path $PSScriptRoot "..\main.bicep"
$parametersFile = Join-Path $PSScriptRoot "..\parameters.$EnvironmentName.json"

if (-not (Test-Path $parametersFile)) {
    Write-Error "Parameters file not found: $parametersFile"
    exit 1
}

az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file $templateFile `
    --parameters "@$parametersFile" `
    --output table

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed. Check the Azure portal for details."
    exit 1
}

Write-Host "  Deployment succeeded." -ForegroundColor Green

# ── 4. Validation ───────────────────────────────────────────────────────────
Write-Host "[4/4] Validating deployment..." -ForegroundColor Yellow
Write-Host ""

# Check VNet
$vnet = az network vnet show --resource-group $ResourceGroupName --name "vnet-allowance-$EnvironmentName" --query "{name:name, addressSpace:addressSpace.addressPrefixes[0], subnets:subnets[].name}" --output json 2>&1
if ($LASTEXITCODE -eq 0) {
    $vnetInfo = $vnet | ConvertFrom-Json
    Write-Host "  VNet: $($vnetInfo.name) ($($vnetInfo.addressSpace))" -ForegroundColor Green
    Write-Host "  Subnets:" -ForegroundColor Green
    foreach ($subnet in $vnetInfo.subnets) {
        Write-Host "    - $subnet" -ForegroundColor Green
    }
} else {
    Write-Host "  WARNING: Could not verify VNet." -ForegroundColor Red
}

Write-Host ""

# Check NSGs
$nsgs = az network nsg list --resource-group $ResourceGroupName --query "[].name" --output json 2>&1
if ($LASTEXITCODE -eq 0) {
    $nsgList = $nsgs | ConvertFrom-Json
    Write-Host "  NSGs ($($nsgList.Count)):" -ForegroundColor Green
    foreach ($nsg in $nsgList) {
        Write-Host "    - $nsg" -ForegroundColor Green
    }
} else {
    Write-Host "  WARNING: Could not verify NSGs." -ForegroundColor Red
}

Write-Host ""

# Check Private DNS Zones
$dnsZones = az network private-dns zone list --resource-group $ResourceGroupName --query "[].name" --output json 2>&1
if ($LASTEXITCODE -eq 0) {
    $dnsZoneList = $dnsZones | ConvertFrom-Json
    Write-Host "  Private DNS Zones ($($dnsZoneList.Count)):" -ForegroundColor Green
    foreach ($zone in $dnsZoneList) {
        Write-Host "    - $zone" -ForegroundColor Green
    }
} else {
    Write-Host "  WARNING: Could not verify Private DNS Zones." -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Step 1 Deployment Complete!"                -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: Validate the checklist in docs/PLAN.md Step 1, then proceed to Step 2 (Azure SQL Database)." -ForegroundColor Yellow
