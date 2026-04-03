# Instructions

Setup, deployment, and configuration guide for the Allowance Tracking App.

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Node.js 20+](https://nodejs.org/)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- An Azure subscription

## Local Development

### Backend

```bash
cd src/backend
cp .env.example .env       # Edit with your local settings
npm install
npm start                  # Runs on http://localhost:3000
```

### Frontend

```bash
cd src/frontend
dotnet run                 # Runs on http://localhost:5000
```

The frontend reads `ApiBaseUrl` from `appsettings.json` (defaults to `http://localhost:3000`).

## Infrastructure Deployment

Infrastructure is defined in Bicep and deployed in 5 steps. Each step has a `parameters.bicepparam.example` — copy it to `parameters.bicepparam` and fill in your values before deploying.

```bash
# 1. Copy and configure parameters for each step
cp infra/networking/parameters.bicepparam.example infra/networking/parameters.bicepparam
cp infra/sql/parameters.bicepparam.example infra/sql/parameters.bicepparam
cp infra/backend/parameters.bicepparam.example infra/backend/parameters.bicepparam
cp infra/frontend/parameters.bicepparam.example infra/frontend/parameters.bicepparam
cp infra/monitoring/parameters.bicepparam.example infra/monitoring/parameters.bicepparam

# 2. Deploy in order (each step depends on outputs from the previous)
az deployment group create --resource-group rg-allowanceapp-dev \
  --template-file infra/networking/main.bicep \
  --parameters infra/networking/parameters.bicepparam

az deployment group create --resource-group rg-allowanceapp-dev \
  --template-file infra/sql/main.bicep \
  --parameters infra/sql/parameters.bicepparam

az deployment group create --resource-group rg-allowanceapp-dev \
  --template-file infra/backend/main.bicep \
  --parameters infra/backend/parameters.bicepparam

az deployment group create --resource-group rg-allowanceapp-dev \
  --template-file infra/frontend/main.bicep \
  --parameters infra/frontend/parameters.bicepparam

az deployment group create --resource-group rg-allowanceapp-dev \
  --template-file infra/monitoring/main.bicep \
  --parameters infra/monitoring/parameters.bicepparam
```

Or use the GitHub Actions workflow (`.github/workflows/deploy-infra.yml`) which supports deploying individual steps or all at once via `workflow_dispatch`.

## Application Deployment

### Backend (Node.js → Linux App Service)

```bash
cd src/backend
tar.exe -a -cf backend-deploy.zip src/ package.json package-lock.json
az webapp deploy --resource-group rg-allowanceapp-dev \
  --name app-api-allowanceapp-dev \
  --src-path backend-deploy.zip --type zip
```

### Frontend (Blazor → Linux App Service)

```bash
dotnet publish src/frontend/AllowanceTracker.csproj -c Release -o ./deploy-frontend
cd deploy-frontend
tar.exe -a -cf ../frontend-deploy.zip *
cd ..
az webapp deploy --resource-group rg-allowanceapp-dev \
  --name app-web-allowanceapp-dev \
  --src-path frontend-deploy.zip --type zip
```

> **Note:** Use `tar.exe` (not `Compress-Archive`) to create zips — Linux App Service requires forward-slash paths.

## Initial Setup

The database seed script (`src/database/init.sql`) creates a default `parent` account. Before running the script, generate a bcrypt hash for your chosen password and replace the `<GENERATE_BCRYPT_HASH>` placeholder:

```bash
cd src/backend
node -e "const b=require('bcrypt');b.hash('YOUR_PASSWORD',12).then(console.log)"
```

After logging in as the parent, create child accounts through the app.
