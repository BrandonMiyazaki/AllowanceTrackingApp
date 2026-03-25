# Allowance Tracking App - Multi-Tier Azure Deployment Plan

## Context
Build a secure, multi-tier allowance tracking application for kids, hosted entirely on Azure. Each child authenticates via Microsoft Entra ID and can view/manage their allowance. The architecture follows secure-by-design principles with private endpoints and private link connectivity throughout.

### Decisions Made
- **Frontend:** Blazor Server (server-side rendering, API calls stay within VNet)
- **Infrastructure as Code:** Bicep
- **Identity:** Existing Entra ID users with App Roles (Parent/Child)

---

## Architecture Overview

```
                        ┌──────────────────────────────┐
                        │       Microsoft Entra ID      │
                        │    (Authentication / RBAC)    │
                        └──────────────┬───────────────┘
                                       │ OAuth 2.0 / OIDC
                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Azure Virtual Network                       │
│                        (10.0.0.0/16)                            │
│                                                                 │
│  ┌─────────────────┐    Private     ┌─────────────────────┐    │
│  │  Frontend Subnet │   Endpoint    │   Backend Subnet     │    │
│  │   (10.0.1.0/24) │──────────────▶│    (10.0.2.0/24)     │    │
│  │                  │               │                      │    │
│  │  Azure App Svc   │               │  Azure App Service   │    │
│  │  (Blazor Server) │               │  (Node.js API)       │    │
│  └─────────────────┘               └──────────┬───────────┘    │
│                                                │                │
│                                     Private    │ Endpoint       │
│                                                ▼                │
│                                    ┌───────────────────────┐    │
│                                    │   Data Subnet          │    │
│                                    │   (10.0.3.0/24)        │    │
│                                    │                         │    │
│                                    │  Azure SQL Database     │    │
│                                    │  (Private Endpoint)     │    │
│                                    └───────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Private Endpoint Subnet (10.0.4.0/24)                   │   │
│  │  - PE for Backend App Service                             │   │
│  │  - PE for Azure SQL                                       │   │
│  │  - PE for Key Vault                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Private DNS Zones                                        │   │
│  │  - privatelink.azurewebsites.net                          │   │
│  │  - privatelink.database.windows.net                       │   │
│  │  - privatelink.vaultcore.azure.net                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Network Traffic Flow

```
User (Internet)
  │
  │ HTTPS (443)
  ▼
Azure App Service (Blazor Frontend)  ← Public-facing, Entra ID auth required
  │
  │ HTTPS via Private Endpoint (VNet Integration → PE)
  ▼
Azure App Service (Node.js API)  ← No public access, PE only
  │
  │ TDS 1433 via Private Endpoint (VNet Integration → PE)
  ▼
Azure SQL Database  ← No public access, PE only, Entra ID auth only
```

All inter-service communication stays within the Azure Virtual Network via private endpoints. Only the Blazor frontend is exposed to the internet, and it requires Entra ID authentication before any content is served.

---

## Execution Order

| Order | Step | Dependencies |
|-------|------|-------------|
| 1 | Step 1: Networking (VNet, Subnets, NSGs, DNS Zones) | None |
| 2 | Step 5: Entra ID App Registrations | None (can parallel with Step 1) |
| 3 | Step 6: Key Vault + Private Endpoint | Step 1 |
| 4 | Step 2: Azure SQL + Private Endpoint + Schema | Step 1 |
| 5 | Step 3: Node.js Backend + VNet Integration + PE | Steps 1, 2, 4 |
| 6 | Step 4: Blazor Frontend + VNet Integration | Steps 1, 2, 3, 5, 6 |
| 7 | Step 7: Monitoring + CI/CD | All previous steps |

---

## Step-by-Step Implementation Plan

### Step 1: Azure Infrastructure Foundation (Networking)

**Goal:** Create the VNet, subnets, NSGs, and Private DNS Zones that all services will rely on.

**Resources to create:**
- **Resource Group:** `rg-allowance-tracker-<env>` (e.g., `rg-allowance-tracker-dev`)
- **Virtual Network:** `vnet-allowance-tracker` — `10.0.0.0/16`
- **Subnets:**
  | Subnet | CIDR | Purpose |
  |--------|------|---------|
  | `snet-frontend` | `10.0.1.0/24` | Blazor App Service VNet integration |
  | `snet-backend` | `10.0.2.0/24` | Node.js App Service VNet integration |
  | `snet-data` | `10.0.3.0/24` | Reserved for future data services |
  | `snet-private-endpoints` | `10.0.4.0/24` | Private Endpoints for all services |
- **Network Security Groups (NSGs):**
  - `nsg-frontend`: Allow HTTPS inbound (443) from internet, deny all other inbound
  - `nsg-backend`: Allow HTTPS inbound (443) only from `snet-frontend`, deny all internet inbound
  - `nsg-data`: Deny all internet inbound, allow 1433 from `snet-backend` only
  - `nsg-private-endpoints`: Allow traffic from VNet only
- **Private DNS Zones:**
  - `privatelink.azurewebsites.net` (for App Services)
  - `privatelink.database.windows.net` (for Azure SQL)
  - `privatelink.vaultcore.azure.net` (for Key Vault)
  - Link all zones to the VNet

**Deployment method:** Bicep template (`infra/modules/networking.bicep`)

**Security validation checklist:**
- [ ] No subnets have default route to internet for backend/data
- [ ] NSGs enforce least-privilege traffic flow
- [ ] Private DNS zones are linked to VNet
- [ ] Subnet delegation is configured for App Service VNet integration subnets

---

### Step 2: Azure SQL Database (Data Tier)

**Goal:** Deploy Azure SQL with private endpoint only — no public network access.

**Resources to create:**
- **Azure SQL Server:** `sql-allowance-tracker-<env>`
  - **Authentication:** Entra ID-only authentication (disable SQL auth)
  - **Admin:** Set an Entra ID group as SQL admin
  - **Public network access:** Disabled
  - **Minimum TLS version:** 1.2
- **Azure SQL Database:** `sqldb-allowance-tracker`
  - **SKU:** Basic/S0 for dev, scale as needed
  - **Backup:** Geo-redundant backup storage
- **Private Endpoint:** `pe-sql-allowance-tracker`
  - Subnet: `snet-private-endpoints`
  - Target sub-resource: `sqlServer`
  - DNS: Register A record in `privatelink.database.windows.net`

**Database schema (initial):**
```sql
-- Users table (linked to Entra ID)
CREATE TABLE Users (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    EntraObjectId NVARCHAR(128) NOT NULL UNIQUE,  -- Entra ID object ID
    DisplayName NVARCHAR(256) NOT NULL,
    Email NVARCHAR(256),
    Role NVARCHAR(50) NOT NULL DEFAULT 'Child',   -- 'Child' or 'Parent'
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE()
);

-- Allowance balance and transactions
CREATE TABLE Transactions (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    UserId UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Users(Id),
    Amount DECIMAL(10,2) NOT NULL,          -- positive = add, negative = deduct
    Description NVARCHAR(500),
    TransactionType NVARCHAR(50) NOT NULL,  -- 'Deposit', 'Withdrawal', 'Adjustment'
    CreatedBy UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Users(Id),
    CreatedAt DATETIME2 DEFAULT GETUTCDATE()
);

-- Index for fast balance lookups
CREATE INDEX IX_Transactions_UserId ON Transactions(UserId);
```

**Deployment method:** Bicep template (`infra/modules/sql.bicep`) + SQL migration scripts (`db/migrations/`)

**Security validation checklist:**
- [ ] Public network access is **disabled** on the SQL Server
- [ ] SQL authentication is **disabled** — Entra ID only
- [ ] Private Endpoint is created and DNS resolves correctly from within VNet
- [ ] TLS 1.2 minimum enforced
- [ ] Transparent Data Encryption (TDE) is enabled (default)
- [ ] Auditing is enabled to Log Analytics or Storage Account

---

### Step 3: Node.js Backend API (Application Tier)

**Goal:** Build and deploy the Express.js REST API on Azure App Service with VNet integration and private endpoint for the frontend.

**Application structure:**
```
backend/
├── src/
│   ├── server.js              # Express app entry point
│   ├── config/
│   │   ├── database.js        # Azure SQL connection (mssql + managed identity)
│   │   └── auth.js            # Entra ID token validation config
│   ├── middleware/
│   │   ├── authenticate.js    # Validate JWT from Entra ID
│   │   └── authorize.js       # Role-based access (Parent vs Child)
│   ├── routes/
│   │   ├── users.js           # GET /api/users, GET /api/users/:id
│   │   ├── transactions.js    # GET/POST /api/transactions
│   │   └── balance.js         # GET /api/balance/:userId
│   └── services/
│       ├── userService.js     # User CRUD operations
│       └── transactionService.js  # Transaction logic + balance calc
├── package.json
└── .env.example
```

**Key design decisions:**
- **Database auth:** Use **Managed Identity** to connect to Azure SQL — no passwords stored
- **API auth:** Validate Entra ID JWT tokens using `passport-azure-ad` or `@azure/identity`
- **Authorization rules:**
  - **Children** can only view their OWN balance and transactions
  - **Parents** can view all children, add/deduct allowance for any child
- **CORS:** Restrict to frontend App Service domain only

**Azure resources to create:**
- **App Service Plan:** `asp-backend-allowance-tracker` (Linux, Node 20 LTS, B1 or higher)
- **App Service:** `app-api-allowance-tracker-<env>`
  - **VNet Integration:** Outbound via `snet-backend` (for reaching SQL private endpoint)
  - **Managed Identity:** System-assigned (for SQL auth + Key Vault access)
  - **Public network access:** Disabled (only accessible via private endpoint)
  - **HTTPS Only:** Enabled
  - **Minimum TLS:** 1.2
  - **App Settings:**
    - `AZURE_SQL_SERVER`: `sql-allowance-tracker-<env>.database.windows.net`
    - `AZURE_SQL_DATABASE`: `sqldb-allowance-tracker`
    - `AZURE_TENANT_ID`: `<your-tenant-id>`
    - `AZURE_CLIENT_ID`: `<backend-app-registration-client-id>`
- **Private Endpoint:** `pe-app-api-allowance-tracker`
  - Subnet: `snet-private-endpoints`
  - Target sub-resource: `sites`
  - DNS: Register in `privatelink.azurewebsites.net`

**Grant SQL access to Managed Identity (run in SQL):**
```sql
CREATE USER [app-api-allowance-tracker-dev] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [app-api-allowance-tracker-dev];
ALTER ROLE db_datawriter ADD MEMBER [app-api-allowance-tracker-dev];
```

**Deployment method:**
- Code: GitHub Actions CI/CD → deploy to App Service
- Infrastructure: Bicep template (`infra/modules/backend.bicep`)

**Security validation checklist:**
- [ ] App Service public access is **disabled**
- [ ] Only reachable via private endpoint from within VNet
- [ ] Managed Identity has least-privilege SQL roles (reader/writer only, NOT db_owner)
- [ ] Entra ID JWT validation is enforced on all API endpoints
- [ ] No secrets/passwords in app settings — all auth via Managed Identity
- [ ] CORS whitelist restricted to frontend domain only
- [ ] HTTPS only, TLS 1.2+
- [ ] Input validation on all API endpoints (parameterized queries, no raw SQL concatenation)

---

### Step 4: Blazor Frontend (Presentation Tier)

**Goal:** Build and deploy a Blazor Server app on Azure App Service with Entra ID authentication.

**Why Blazor Server:**
- Simpler Entra ID integration (server-side auth)
- Keeps API calls server-to-server within the VNet (more secure)
- No API keys exposed to the browser

**Application structure:**
```
frontend/
├── AllowanceTracker.Web/
│   ├── Program.cs
│   ├── appsettings.json
│   ├── Components/
│   │   ├── Layout/
│   │   │   ├── MainLayout.razor
│   │   │   └── NavMenu.razor
│   │   ├── Pages/
│   │   │   ├── Home.razor              # Dashboard / balance overview
│   │   │   ├── Transactions.razor      # Transaction history
│   │   │   ├── AddTransaction.razor    # Parent-only: add/deduct allowance
│   │   │   └── Login.razor             # Entra ID login redirect
│   │   └── Shared/
│   │       ├── BalanceCard.razor        # Balance display component
│   │       └── TransactionList.razor    # Transaction list component
│   ├── Services/
│   │   └── AllowanceApiService.cs      # HttpClient to call backend API
│   └── Models/
│       ├── User.cs
│       └── Transaction.cs
├── AllowanceTracker.Web.csproj
└── Dockerfile (optional)
```

**Key design decisions:**
- **Auth:** `Microsoft.Identity.Web` for Entra ID OIDC integration
- **API calls:** `HttpClient` with `IDownstreamApi` or token-attached calls to the backend private endpoint
- **Authorization in UI:**
  - **Child view:** See own balance, view own transaction history
  - **Parent view:** See all children, add/remove funds, view all transactions
- **Role claims:** Map Entra ID App Roles (`Parent`, `Child`) to Blazor `[Authorize(Roles = "Parent")]`

**Azure resources to create:**
- **App Service Plan:** `asp-frontend-allowance-tracker` (Linux, .NET 8/9, B1 or higher)
  - Can share the same plan as backend if cost is a concern
- **App Service:** `app-web-allowance-tracker-<env>`
  - **VNet Integration:** Outbound via `snet-frontend` (for reaching backend private endpoint)
  - **Public network access:** Enabled (this is the user-facing app)
  - **HTTPS Only:** Enabled
  - **Minimum TLS:** 1.2
  - **Managed Identity:** System-assigned
  - **Custom domain + TLS cert:** Configure later with Azure-managed cert or Key Vault cert
  - **App Settings:**
    - `AzureAd:TenantId`: `<tenant-id>`
    - `AzureAd:ClientId`: `<frontend-app-registration-client-id>`
    - `AzureAd:ClientSecret`: Reference from Key Vault
    - `BackendApi:BaseUrl`: `https://app-api-allowance-tracker-<env>.azurewebsites.net`
    - `BackendApi:Scope`: `api://<backend-client-id>/.default`

**Deployment method:**
- Code: GitHub Actions CI/CD → deploy to App Service
- Infrastructure: Bicep template (`infra/modules/frontend.bicep`)

**Security validation checklist:**
- [ ] Entra ID authentication is enforced — no anonymous access to app pages
- [ ] VNet integration routes outbound traffic to backend via private endpoint
- [ ] Client secret stored in Key Vault, referenced via Key Vault reference in App Settings
- [ ] HTTPS only, TLS 1.2+
- [ ] Anti-forgery tokens enabled for Blazor Server
- [ ] Content Security Policy headers configured
- [ ] Role-based UI rendering (children cannot see parent controls)

---

### Step 5: Microsoft Entra ID Configuration (Identity)

**Goal:** Configure Entra ID app registrations, app roles, and user assignments.

**App Registrations to create:**

1. **Backend API App Registration:** `app-reg-allowance-tracker-api`
   - **Expose an API:**
     - Application ID URI: `api://<client-id>`
     - Scopes: `Transactions.Read`, `Transactions.Write`, `Balance.Read`
   - **App Roles:**
     - `Parent` — can manage all children's allowances
     - `Child` — can view own allowance only
   - **No redirect URIs** (API only)

2. **Frontend Web App Registration:** `app-reg-allowance-tracker-web`
   - **Redirect URIs:** `https://app-web-allowance-tracker-<env>.azurewebsites.net/signin-oidc`
   - **API Permissions:**
     - `app-reg-allowance-tracker-api` → `Transactions.Read`, `Transactions.Write`, `Balance.Read`
     - `Microsoft Graph` → `User.Read`
   - **Client secret:** Generate and store in Key Vault
   - **Token configuration:** Include `roles` claim in ID token

**User setup:**
- Use existing Entra ID accounts
- Assign `Parent` or `Child` app role to each user via Enterprise Application

**Security validation checklist:**
- [ ] App roles properly defined and assigned
- [ ] API permissions require admin consent where appropriate
- [ ] Client secret rotated regularly (Key Vault handles this)
- [ ] Token lifetime policies are reasonable (1 hour access, 24 hour refresh)
- [ ] Conditional Access policies considered (e.g., MFA for parents)

---

### Step 6: Azure Key Vault (Secrets Management)

**Goal:** Centralize secret storage with private endpoint access only.

**Resources to create:**
- **Key Vault:** `kv-allowance-tracker-<env>`
  - **Public network access:** Disabled
  - **RBAC authorization:** Enabled (not access policies)
  - **Soft delete:** Enabled (default)
  - **Purge protection:** Enabled
- **Private Endpoint:** `pe-kv-allowance-tracker`
  - Subnet: `snet-private-endpoints`
  - DNS: `privatelink.vaultcore.azure.net`
- **Private DNS Zone:** `privatelink.vaultcore.azure.net` linked to VNet

**Secrets to store:**
- `frontend-entra-client-secret` — Frontend app registration client secret

**RBAC assignments:**
- Frontend App Service Managed Identity → `Key Vault Secrets User` role
- Backend App Service Managed Identity → `Key Vault Secrets User` role (if needed later)
- Admin users/group → `Key Vault Administrator` role

**Deployment method:** Bicep template (`infra/modules/keyvault.bicep`)

**Security validation checklist:**
- [ ] Public access disabled
- [ ] Private endpoint resolves correctly
- [ ] RBAC mode (not legacy access policies)
- [ ] Soft delete + purge protection enabled
- [ ] Managed Identities have least-privilege roles

---

### Step 7: Monitoring, Logging & CI/CD

**Goal:** Add observability and automated deployment pipelines.

**Monitoring resources:**
- **Application Insights:** `appi-allowance-tracker-<env>`
  - Connected to both frontend and backend App Services
  - Track request rates, failures, response times, exceptions
- **Log Analytics Workspace:** `log-allowance-tracker-<env>`
  - Collect diagnostic logs from SQL, App Services, Key Vault
- **Azure Monitor Alerts:**
  - 5xx error rate threshold
  - SQL DTU utilization
  - App Service health check failures

**CI/CD Pipeline (GitHub Actions):**
```
.github/
└── workflows/
    ├── deploy-infrastructure.yml   # Bicep deployment
    ├── deploy-backend.yml          # Build Node.js → deploy to App Service
    └── deploy-frontend.yml         # Build Blazor → deploy to App Service
```

**Pipeline security:**
- Use GitHub OIDC federated credentials to authenticate to Azure (no stored secrets)
- Separate deployment slots for staging → production swap
- Branch protection on `main`

**Deployment method:** Bicep template (`infra/modules/monitoring.bicep`)

**Security validation checklist:**
- [ ] Application Insights sampling configured to avoid logging PII
- [ ] Diagnostic settings enabled on all resources
- [ ] GitHub Actions uses OIDC federation (no long-lived secrets)
- [ ] Deployment slots used for zero-downtime deployments

---

## Project File Structure (Final)

```
AllowanceTrackingApp/
├── plan.md                          # This file
├── infra/
│   ├── main.bicep                   # Orchestrator template
│   ├── main.bicepparam              # Parameters file
│   └── modules/
│       ├── networking.bicep         # Step 1: VNet, subnets, NSGs, DNS
│       ├── keyvault.bicep           # Step 6: Key Vault + PE
│       ├── sql.bicep                # Step 2: Azure SQL + PE
│       ├── backend.bicep            # Step 3: Backend App Service + PE
│       ├── frontend.bicep           # Step 4: Frontend App Service
│       └── monitoring.bicep         # Step 7: App Insights, Log Analytics
├── db/
│   └── migrations/
│       └── 001-initial-schema.sql   # Step 2: Database schema
├── backend/
│   ├── src/
│   │   ├── server.js
│   │   ├── config/
│   │   ├── middleware/
│   │   ├── routes/
│   │   └── services/
│   ├── package.json
│   └── .env.example
├── frontend/
│   └── AllowanceTracker.Web/
│       ├── Program.cs
│       ├── appsettings.json
│       ├── Components/
│       ├── Services/
│       └── Models/
└── .github/
    └── workflows/
        ├── deploy-infrastructure.yml
        ├── deploy-backend.yml
        └── deploy-frontend.yml
```
