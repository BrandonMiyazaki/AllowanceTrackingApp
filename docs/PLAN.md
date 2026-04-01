# Allowance Tracking App — Build & Deployment Plan

## Overview

A multi-tier, secure-by-design Azure application that allows multiple kids to log in (app-managed local auth), view their current allowance balance, and add/remove allowance transactions.

### Architecture Summary

```
┌────────────────────────────── VNet: 10.30.0.0/16 ──────────────────────────────────┐
│                                                                                    │
│  ┌─────────────────────┐  ┌─────────────────────┐                                  │
│  │ snet-appservice-     │  │ snet-appservice-     │   VNet Integration              │
│  │ frontend 10.30.2.0/24│  │ backend  10.30.3.0/24│   (outbound traffic)            │
│  │ (Blazor Server)      │  │ (Node.js API)        │                                 │
│  └─────────┬────────────┘  └──────────┬───────────┘                                 │
│            │                          │                                             │
│            ▼                          ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│  │                     Private Endpoint Subnets                                   │ │
│  │  ┌─────────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────────────┐  │ │
│  │  │ snet-pe-         │ │ snet-pe-sql  │ │ snet-pe-     │ │ snet-pe-storage    │  │ │
│  │  │ appservice       │ │ 10.30.5.0/24│ │ keyvault     │ │ 10.30.7.0/24       │  │ │
│  │  │ 10.30.4.0/24     │ │ (SQL PE)     │ │ 10.30.6.0/24│ │ (Storage PE)       │  │ │
│  │  │ (App Svc PEs)    │ │              │ │ (KV PE)      │ │                    │  │ │
│  │  └─────────────────┘ └──────────────┘ └──────────────┘ └────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                    │
│  ┌─────────────────────┐                                                           │
│  │ snet-servers         │  Test VMs for validating private connectivity             │
│  │ 10.30.1.0/24         │                                                           │
│  └─────────────────────┘                                                           │
└────────────────────────────────────────────────────────────────────────────────────┘
          ▲
          │ HTTPS (public endpoint on frontend App Service only)
    ┌─────┴─────┐
    │  Internet  │
    │  Users     │
    └───────────┘
```

**PE = Private Endpoint | All backend, SQL, KV, and Storage are private-only**

### Technology Stack

| Tier       | Technology             | Azure Service              |
|------------|------------------------|-----------------------------|
| Frontend   | Blazor Server (.NET 8) | Azure App Service (Windows/Linux) |
| Backend    | Node.js (Express)      | Azure App Service (Linux)  |
| Database   | SQL                    | Azure SQL Database         |
| Networking | VNet, Private Endpoints| Azure Virtual Network      |
| Secrets    | Key Vault              | Azure Key Vault            |

---

## Step 1: Azure Infrastructure Foundation (Networking & Security)

### Goal
Establish the secure network foundation that all other resources will reside in.

### Resources to Create
1. **Resource Group**: `rg-allowance-app-<env>` (e.g., `rg-allowance-app-dev`)
2. **Azure Virtual Network**: `vnet-allowance-<env>`
   - Address space: `10.30.0.0/16`
   - Subnets:

| Subnet Name | CIDR | Purpose | Delegation |
|---|---|---|---|
| `snet-servers` | `10.30.1.0/24` | VMs for testing and local access validation | None |
| `snet-appservice-frontend` | `10.30.2.0/24` | Blazor App Service VNet Integration (outbound) | `Microsoft.Web/serverFarms` |
| `snet-appservice-backend` | `10.30.3.0/24` | Node.js App Service VNet Integration (outbound) | `Microsoft.Web/serverFarms` |
| `snet-pe-appservice` | `10.30.4.0/24` | Private Endpoints for App Services (frontend & backend private link) | None |
| `snet-pe-sql` | `10.30.5.0/24` | Private Endpoint for Azure SQL Server | None |
| `snet-pe-keyvault` | `10.30.6.0/24` | Private Endpoint for Azure Key Vault | None |
| `snet-pe-storage` | `10.30.7.0/24` | Private Endpoint for Azure Storage Account | None |

3. **Network Security Groups (NSGs)**: One per subnet with least-privilege rules

| NSG | Key Rules |
|---|---|
| `nsg-servers` | Allow RDP/SSH inbound from trusted IPs only; allow outbound to VNet |
| `nsg-appservice-frontend` | Allow outbound to `snet-pe-appservice` (port 443), `snet-pe-keyvault` (port 443) |
| `nsg-appservice-backend` | Allow outbound to `snet-pe-sql` (port 1433), `snet-pe-keyvault` (port 443), `snet-pe-storage` (port 443) |
| `nsg-pe-appservice` | Allow inbound 443 from `snet-appservice-frontend`, `snet-servers` |
| `nsg-pe-sql` | Allow inbound 1433 from `snet-appservice-backend`, `snet-servers` |
| `nsg-pe-keyvault` | Allow inbound 443 from `snet-appservice-frontend`, `snet-appservice-backend`, `snet-servers` |
| `nsg-pe-storage` | Allow inbound 443 from `snet-appservice-backend`, `snet-servers` |

4. **Azure Private DNS Zones**:
   - `privatelink.database.windows.net` (for Azure SQL)
   - `privatelink.vaultcore.azure.net` (for Key Vault)
   - `privatelink.azurewebsites.net` (for App Service private endpoints)
   - `privatelink.blob.core.windows.net` (for Storage Account blob)
   - `privatelink.file.core.windows.net` (for Storage Account file shares, if needed)

### Security Design Principles
- All inter-service communication uses private endpoints inside the VNet.
- NSGs restrict traffic between subnets to only required ports/protocols.
- No public IP addresses on backend or database resources.
- The Blazor frontend is the only tier with a public-facing endpoint (or optionally behind an Application Gateway/WAF).

### Deployment Method
- **Bicep** templates with modular structure for all networking resources.
- Deploy via `az deployment group create` or `azd up`.

### Configuration Steps
1. Create the resource group in your target region.
2. Deploy the VNet (`10.30.0.0/16`) with all 7 subnets.
3. Create and attach NSGs to each subnet with least-privilege rules.
4. Delegate `snet-appservice-frontend` and `snet-appservice-backend` to `Microsoft.Web/serverFarms` for VNet Integration.
5. Create all Private DNS Zones and link them to the VNet.
6. (Optional) Deploy a test VM in `snet-servers` to validate private connectivity in later steps.

### Validation Checkpoint ✅
- [ ] VNet is created with address space `10.30.0.0/16`.
- [ ] All 7 subnets are created with correct CIDR ranges and no overlap.
- [ ] NSGs are attached to each subnet with deny-all-inbound default (except explicitly allowed flows).
- [ ] All 5 Private DNS Zones are created and linked to the VNet.
- [ ] Subnet delegation is configured on `snet-appservice-frontend` and `snet-appservice-backend`.
- [ ] Private endpoint subnets have `privateEndpointNetworkPolicies` set to `Enabled` (to allow NSG enforcement on PEs).
- [ ] No public IPs are assigned to any resource except the frontend App Service.
- [ ] (Optional) Test VM in `snet-servers` can resolve Private DNS Zone records.

---

## Step 2: Azure SQL Database (Data Tier)

### Goal
Deploy a secure Azure SQL Database accessible only via private endpoint.

### Resources to Create
1. **Azure SQL Server**: `sql-allowance-<env>`
   - Azure AD admin enabled (for admin access)
   - Public network access: **Disabled**
2. **Azure SQL Database**: `sqldb-allowance-<env>`
   - SKU: Basic/S0 for dev, S1+ for production
   - Backup redundancy: Local (dev) / Geo (prod)
3. **Private Endpoint**: `pe-sql-allowance` in `snet-pe-sql`
   - Target: Azure SQL Server
   - DNS: Register A record in `privatelink.database.windows.net`

### Database Schema (Initial)
```sql
-- Users table (parent admin + kids)
CREATE TABLE Users (
    UserId INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) NOT NULL UNIQUE,
    DisplayName NVARCHAR(100) NOT NULL,
    PasswordHash NVARCHAR(256) NOT NULL,
    Salt NVARCHAR(128) NOT NULL,
    Role NVARCHAR(20) NOT NULL DEFAULT 'child',  -- 'admin' or 'child'
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    IsActive BIT DEFAULT 1
);

-- Transactions table
CREATE TABLE Transactions (
    TransactionId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL FOREIGN KEY REFERENCES Users(UserId),
    Amount DECIMAL(10,2) NOT NULL,       -- positive = add, negative = deduct
    Description NVARCHAR(255),
    TransactionType NVARCHAR(20) NOT NULL, -- 'CREDIT' or 'DEBIT'
    CreatedAt DATETIME2 DEFAULT GETUTCDATE()
);

-- Index for fast balance lookups
CREATE INDEX IX_Transactions_UserId ON Transactions(UserId);

-- Seed accounts (passwords will be bcrypt-hashed by the backend seed script)
-- 1. Parent/Admin account — can view ALL kids, add/remove allowance for any child
-- 2. Dylan — can only view and manage own allowance
-- 3. Evan — can only view and manage own allowance
```

### User Account Model

| Account   | Username | Role    | Can See         | Can Add/Remove      |
|-----------|----------|---------|-----------------|---------------------|
| Parent    | `admin`  | `admin` | All kids' data  | All kids' allowance |
| Dylan     | `dylan`  | `child` | Own data only   | Own allowance only  |
| Evan      | `evan`   | `child` | Own data only   | Own allowance only  |

**Data isolation** is enforced at the API layer:
- All queries for `child` role users include `WHERE UserId = @authenticatedUserId`.
- The `admin` role bypasses the user filter and can query/modify any child's data.
- The JWT token contains the `UserId` and `Role`; the backend verifies these on every request.

### Security Design Principles
- **No public access** — SQL Server firewall denies all public traffic.
- **Private Endpoint only** — accessible only from within the VNet.
- **Managed Identity** — the Node.js backend will authenticate to SQL using a Managed Identity (no connection string passwords stored).
- **TDE** (Transparent Data Encryption) enabled by default.
- **Passwords hashed with bcrypt** (salt + hash stored, never plaintext).

### Deployment Method
- Bicep for the SQL Server, Database, and Private Endpoint.
- SQL schema applied via a migration script (`sqlcmd` or a migration tool like `knex` in the Node.js backend).
- Seed script creates the 3 default accounts (admin, dylan, evan) with bcrypt-hashed passwords.

### Configuration Steps
1. Deploy SQL Server with public access disabled.
2. Create the database with appropriate SKU.
3. Create Private Endpoint in `snet-pe-sql`, targeting the SQL Server.
4. Register DNS in the `privatelink.database.windows.net` Private DNS Zone.
5. Create a Managed Identity for the backend App Service (done in Step 4).
6. Grant that identity `db_datareader` and `db_datawriter` on the database.
7. Run schema migration scripts.

### Validation Checkpoint ✅
- [ ] SQL Server has public network access **disabled**.
- [ ] Private Endpoint is created and healthy (connection state: Approved).
- [ ] DNS resolution from within the VNet resolves `sql-allowance-<env>.database.windows.net` to the private IP.
- [ ] Cannot connect to the SQL Server from the public internet.
- [ ] Schema tables (`Users`, `Transactions`) are created successfully.
- [ ] TDE is enabled on the database.

---

## Step 3: Azure Key Vault (Secrets Management)

### Goal
Centralize secrets and configuration securely, accessible only via private endpoint.

### Resources to Create
1. **Azure Key Vault**: `kv-allowance-<env>`
   - SKU: Standard
   - Public network access: **Disabled**
   - Soft delete: Enabled
   - Purge protection: Enabled (production)
2. **Private Endpoint**: `pe-kv-allowance` in `snet-pe-keyvault`
   - DNS: Register in `privatelink.vaultcore.azure.net`

### Secrets to Store
| Secret Name               | Purpose                                   |
|---------------------------|-------------------------------------------|
| `jwt-signing-key`         | Signing key for app-managed JWT tokens     |
| `sql-connection-string`   | Fallback/admin connection string (if needed)|
| `app-admin-password`      | Initial admin/parent password              |

### Security Design Principles
- **Private Endpoint only** — no public access.
- **RBAC-based access** — use Azure RBAC (Key Vault Secrets User role) instead of access policies.
- **Managed Identity** — App Services access Key Vault via their System-Assigned Managed Identity.
- **No secrets in code or app settings** — all secrets fetched from Key Vault at runtime or via Key Vault References.

### Deployment Method
- Bicep/Terraform for Key Vault and Private Endpoint.
- Secrets populated via `az keyvault secret set` or IaC.

### Configuration Steps
1. Deploy Key Vault with public access disabled.
2. Create Private Endpoint and DNS registration.
3. Assign `Key Vault Secrets User` role to the App Service Managed Identities.
4. Populate initial secrets.

### Validation Checkpoint ✅
- [ ] Key Vault has public network access **disabled**.
- [ ] Private Endpoint is connected and DNS resolves correctly.
- [ ] RBAC roles assigned (not legacy access policies).
- [ ] Secrets are accessible from within the VNet only.

---

## Step 4: Node.js Backend API (Middle Tier)

### Goal
Deploy the Node.js Express API that handles authentication, business logic, and database operations.

### Resources to Create
1. **App Service Plan**: `asp-backend-allowance-<env>` (Linux, B1+)
2. **App Service**: `app-api-allowance-<env>` (Node.js 20 LTS)
   - System-Assigned Managed Identity: **Enabled**
   - VNet Integration: `snet-backend`
   - Public network access: **Disabled** (only accessible via Private Endpoint)
3. **Private Endpoint**: `pe-api-allowance` in `snet-private-endpoints`
   - DNS: Register in `privatelink.azurewebsites.net`

### API Endpoints Design
```
POST   /api/auth/login          — Authenticate a kid (username/password)
POST   /api/auth/logout         — Invalidate session/token
GET    /api/users/:id/balance   — Get current allowance balance
GET    /api/users/:id/history   — Get transaction history
POST   /api/transactions        — Add a credit or debit
```

### Application Architecture
```
src/
├── server.js               # Express app entry point
├── config/
│   └── database.js         # SQL connection (Managed Identity via @azure/identity)
├── middleware/
│   ├── auth.js             # JWT verification middleware
│   └── validation.js       # Input validation & sanitization
├── routes/
│   ├── auth.routes.js      # Login/logout
│   └── transaction.routes.js # Balance, history, add/remove
├── services/
│   ├── auth.service.js     # Password hashing (bcrypt), JWT generation
│   └── transaction.service.js # Business logic
├── models/
│   └── db.js               # SQL queries (parameterized)
└── package.json
```

### Security Design Principles
- **No public access** — backend is only reachable via its Private Endpoint from within the VNet.
- **Managed Identity** for SQL and Key Vault access — no stored credentials.
- **Input validation** on all endpoints (express-validator or joi).
- **Parameterized queries only** — prevent SQL injection.
- **JWT-based session tokens** — signed with a key from Key Vault.
- **bcrypt password hashing** with unique salts.
- **Rate limiting** on auth endpoints to prevent brute force.
- **CORS** restricted to the frontend App Service origin only.
- **Helmet.js** for security headers.
- **HTTPS only** (enforced by App Service).

### Key Dependencies
```json
{
  "dependencies": {
    "express": "^4.18",
    "@azure/identity": "^4.0",
    "@azure/keyvault-secrets": "^4.7",
    "mssql": "^10.0",
    "bcrypt": "^5.1",
    "jsonwebtoken": "^9.0",
    "express-validator": "^7.0",
    "helmet": "^7.1",
    "express-rate-limit": "^7.1",
    "cors": "^2.8"
  }
}
```

### Deployment Method
- App code deployed via **GitHub Actions** CI/CD to the App Service.
- Infrastructure (App Service Plan, App Service, PE) via Bicep/Terraform.
- App settings configured as Key Vault References: `@Microsoft.KeyVault(SecretUri=...)`.

### Configuration Steps
1. Deploy App Service Plan (Linux) and App Service (Node.js 20).
2. Enable System-Assigned Managed Identity.
3. Configure VNet Integration to `snet-appservice-backend`.
4. Disable public network access on the App Service.
5. Create Private Endpoint in `snet-pe-appservice`.
6. Register DNS in `privatelink.azurewebsites.net`.
7. Grant Managed Identity:
   - `Key Vault Secrets User` on the Key Vault.
   - `db_datareader` + `db_datawriter` on the SQL Database.
8. Set app settings (non-secret config: SQL server name, database name, Key Vault URI).
9. Deploy application code via GitHub Actions.

### Validation Checkpoint ✅
- [ ] App Service is NOT publicly accessible (returns 403 from internet).
- [ ] App Service can reach Azure SQL via Private Endpoint (test connection).
- [ ] App Service can reach Key Vault via Private Endpoint.
- [ ] Managed Identity is enabled and has correct RBAC roles.
- [ ] API endpoints respond correctly when called from within the VNet.
- [ ] No secrets are stored in App Settings (all via Key Vault References).
- [ ] Input validation rejects malformed requests.
- [ ] SQL queries are all parameterized (code review).

---

## Step 5: Blazor Server Frontend (Presentation Tier)

### Goal
Deploy the Blazor Server frontend that provides the kid-facing UI.

### Resources to Create
1. **App Service Plan**: `asp-frontend-allowance-<env>` (Linux or Windows, B1+)
2. **App Service**: `app-web-allowance-<env>` (.NET 8)
   - System-Assigned Managed Identity: **Enabled**
   - VNet Integration: `snet-frontend`
   - Public network access: **Enabled** (this is the user-facing tier)
   - HTTPS Only: **Enabled**
   - Minimum TLS Version: **1.2**

### Application Architecture
```
AllowanceTracker.Web/
├── Program.cs                    # App startup, DI, HttpClient config
├── Components/
│   ├── App.razor                 # Root component
│   ├── Layout/
│   │   ├── MainLayout.razor      # Shared layout
│   │   └── NavMenu.razor         # Navigation
│   └── Pages/
│       ├── Login.razor           # Login page
│       ├── Dashboard.razor       # Balance overview
│       ├── History.razor         # Transaction history
│       └── AddTransaction.razor  # Add/remove allowance
├── Services/
│   ├── ApiClient.cs              # HttpClient wrapper for Node.js API
│   └── AuthStateProvider.cs      # Custom AuthenticationStateProvider
├── Models/
│   ├── LoginRequest.cs
│   ├── Transaction.cs
│   └── UserBalance.cs
└── appsettings.json              # API base URL (private endpoint URL)
```

### Security Design Principles
- **HTTPS only** with TLS 1.2+ enforced.
- **Anti-forgery tokens** for form submissions (built into Blazor).
- **Custom AuthenticationStateProvider** — validates JWT from the backend.
- **HttpClient** calls to the Node.js API go through the VNet (private endpoint) — never over the public internet.
- **Content Security Policy (CSP)** headers configured.
- **No sensitive data stored client-side** — Blazor Server keeps state on the server.
- Optional: Place behind **Azure Application Gateway with WAF** for production (DDoS protection, OWASP rule sets).

### Deployment Method
- App code deployed via **GitHub Actions** CI/CD.
- Infrastructure via Bicep/Terraform.

### Configuration Steps
1. Deploy App Service Plan and App Service (.NET 8 runtime).
2. Enable System-Assigned Managed Identity.
3. Configure VNet Integration to `snet-appservice-frontend`.
4. Set HTTPS Only = true, Minimum TLS = 1.2.
5. Configure app setting: `ApiBaseUrl` = `https://app-api-allowance-<env>.azurewebsites.net` (resolves to private IP via VNet + Private DNS).
6. Deploy application code via GitHub Actions.
7. (Optional) Configure custom domain + managed certificate.
8. (Optional) Deploy Application Gateway with WAF in front.

### Validation Checkpoint ✅
- [ ] Frontend is accessible from the internet over HTTPS.
- [ ] HTTP requests are redirected to HTTPS.
- [ ] Frontend can communicate with the Node.js backend via Private Endpoint (not public internet).
- [ ] Login flow works end-to-end: UI → API → SQL → response.
- [ ] Blazor anti-forgery protection is active.
- [ ] No secrets are stored in frontend app settings.
- [ ] TLS 1.2+ is enforced.

---

## Step 6: CI/CD Pipeline (GitHub Actions)

### Goal
Automate build, test, and deployment for both the frontend and backend.

### Pipeline Structure
```
.github/
└── workflows/
    ├── backend-ci-cd.yml     # Node.js: lint, test, deploy to App Service
    └── frontend-ci-cd.yml    # Blazor: build, test, deploy to App Service
```

### Backend Pipeline (`backend-ci-cd.yml`)
```yaml
# Triggers: push to main, PR to main
# Steps:
# 1. Checkout code
# 2. Setup Node.js 20
# 3. npm ci
# 4. npm run lint
# 5. npm test (unit tests)
# 6. Deploy to Azure App Service (using azure/webapps-deploy action)
```

### Frontend Pipeline (`frontend-ci-cd.yml`)
```yaml
# Triggers: push to main, PR to main
# Steps:
# 1. Checkout code
# 2. Setup .NET 8
# 3. dotnet restore
# 4. dotnet build
# 5. dotnet test
# 6. dotnet publish
# 7. Deploy to Azure App Service (using azure/webapps-deploy action)
```

### Security Design Principles
- **OIDC authentication** (federated credentials) — no long-lived secrets in GitHub.
- **Environment protection rules** — require approval for production deployments.
- **Dependency scanning** — enable Dependabot for both Node.js and .NET.
- **SAST** — integrate code scanning (e.g., CodeQL) in PRs.

### Configuration Steps
1. Create Azure AD App Registration for GitHub Actions OIDC.
2. Assign `Contributor` role on the resource group to the service principal.
3. Configure GitHub repository secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
4. Create workflow files for both tiers.
5. Enable Dependabot for npm and NuGet.
6. Enable branch protection on `main`.

### Validation Checkpoint ✅
- [ ] Pushing to `main` triggers both pipelines.
- [ ] Builds fail on lint errors or test failures.
- [ ] Deployment uses OIDC (no stored passwords/secrets in GitHub).
- [ ] Dependabot is enabled and creating PRs for vulnerable packages.
- [ ] Branch protection requires passing CI before merge.

---

## Step 7: Monitoring & Logging

### Goal
Ensure observability across all tiers for troubleshooting and security monitoring.

### Resources to Create
1. **Application Insights**: `appi-allowance-<env>`
   - Connected to both App Services.
2. **Log Analytics Workspace**: `log-allowance-<env>`
   - Central log sink for all resources.
3. **Azure SQL Auditing**: Enabled, logs to Log Analytics.

### What to Monitor
| Signal                | Source            | Alert Threshold             |
|-----------------------|-------------------|-----------------------------|
| Failed login attempts | Node.js API logs  | > 10 in 5 minutes           |
| HTTP 5xx errors       | App Insights      | > 5 in 5 minutes            |
| Response latency      | App Insights      | P95 > 2 seconds             |
| SQL DTU usage         | Azure SQL metrics  | > 80% sustained             |
| Private Endpoint health| VNet diagnostics  | Connection failures          |

### Security Design Principles
- **No PII in logs** — mask usernames and sensitive data in application logs.
- **Diagnostic settings** enabled on all resources, flowing to Log Analytics.
- **Alerts** configured for suspicious activity (brute force login attempts).
- **SQL Auditing** enabled for compliance.

### Configuration Steps
1. Create Log Analytics Workspace.
2. Create Application Insights connected to the workspace.
3. Enable Application Insights on both App Services.
4. Enable diagnostic settings on SQL Server, Key Vault, and App Services.
5. Enable SQL Auditing to Log Analytics.
6. Create alert rules for key signals.

### Validation Checkpoint ✅
- [ ] Application Insights shows telemetry from both App Services.
- [ ] Logs flow to the central Log Analytics Workspace.
- [ ] SQL Auditing is enabled and logs appear.
- [ ] Alerts fire when thresholds are exceeded (test with synthetic load).
- [ ] No PII is visible in log entries.

---

## Network Flow Diagram (End-to-End)

```
Internet User
      │
      │ HTTPS (TLS 1.2+)
      ▼
┌──────────────────────────┐
│ App Service               │  ◄── Public endpoint (or behind App Gateway/WAF)
│ Blazor Frontend           │
│ VNet Int: snet-appservice- │
│ frontend (10.30.2.0/24)   │
└─────────┬────────────────┘
          │ Outbound via VNet Integration
          │ ──▶ PE in snet-pe-appservice (10.30.4.0/24)
          ▼
┌──────────────────────────┐
│ App Service               │  ◄── NO public access (PE only)
│ Node.js API               │
│ VNet Int: snet-appservice- │
│ backend (10.30.3.0/24)    │
└─────────┬────────────────┘
          │ Outbound via VNet Integration
          │ ──▶ PE in snet-pe-sql (10.30.5.0/24)
          ▼
┌──────────────────────────┐
│ Azure SQL Database        │  ◄── NO public access (PE only)
│ PE in snet-pe-sql         │
└──────────────────────────┘

Also via Private Endpoints (all NO public access):
  - Azure Key Vault ──▶ PE in snet-pe-keyvault (10.30.6.0/24)
  - Azure Storage   ──▶ PE in snet-pe-storage (10.30.7.0/24)
  - Application Insights (via VNet)

Test/Validation:
  - VMs in snet-servers (10.30.1.0/24) can reach all PE subnets for testing
```

---

## Execution Order Summary

| Step | Component               | Public Access | Private Endpoint | Depends On   |
|------|-------------------------|---------------|------------------|--------------|
| 1    | VNet + Networking       | N/A           | N/A              | —            |
| 2    | Azure SQL Database      | **No**        | **Yes**          | Step 1       |
| 3    | Azure Key Vault         | **No**        | **Yes**          | Step 1       |
| 4    | Node.js Backend API     | **No**        | **Yes**          | Steps 1,2,3  |
| 5    | Blazor Frontend         | **Yes** (user-facing) | No (outbound via VNet) | Steps 1,4 |
| 6    | CI/CD Pipelines         | N/A           | N/A              | Steps 4,5    |
| 7    | Monitoring & Logging    | N/A           | N/A              | Steps 2-5    |

---

## Security Summary (OWASP & Azure Well-Architected)

| Security Control                  | Implementation                              |
|-----------------------------------|---------------------------------------------|
| A01 - Broken Access Control       | JWT auth, per-user data scoping, RBAC       |
| A02 - Cryptographic Failures      | TLS 1.2+, bcrypt hashing, Key Vault secrets |
| A03 - Injection                   | Parameterized SQL queries, input validation  |
| A05 - Security Misconfiguration   | NSGs, private endpoints, no public DB/API   |
| A07 - Auth Failures               | Rate limiting, bcrypt, secure JWT            |
| A09 - Logging & Monitoring        | App Insights, SQL Audit, alert rules         |
| Network Isolation                 | VNet, Private Endpoints, Private DNS Zones   |
| Identity                          | Managed Identities (no stored credentials)   |
| Secrets Management                | Azure Key Vault with RBAC                    |
| Data at Rest                      | TDE on SQL, Key Vault encryption             |
| Data in Transit                   | HTTPS/TLS everywhere                         |

---

## Next Steps

After reviewing this plan, we will proceed **one step at a time**:

1. **Step 1** — Build the networking foundation (VNet, subnets, NSGs, DNS).
2. Validate Step 1 before moving on.
3. **Step 2** — Deploy Azure SQL with private endpoint.
4. Validate Step 2 before moving on.
5. Continue through each step sequentially.

For each step, I will provide:
- Complete IaC code (Bicep or Terraform)
- CLI commands for any manual configuration
- Validation tests to confirm the step works correctly and securely
