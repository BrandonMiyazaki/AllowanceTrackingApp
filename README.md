# Allowance Tracking App

A family allowance tracker that lets parents manage their kids' allowance balances — add funds, track spending, and view transaction history. Built with a Blazor Server frontend, Node.js/Express API backend, and Azure SQL Database, all deployed to Azure App Services with private networking.

> **Disclaimer:** This project was built primarily as a learning exercise and personal tool. While it follows sound architectural patterns, it has not been through formal code review or production hardening. Use at your own risk and discretion.

## Architecture

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   Blazor Server  │──────▶│  Node.js API     │──────▶│   Azure SQL     │
│   (.NET 8)       │ VNet  │  (Express)       │ VNet  │   Database      │
│   Public-facing  │       │  Private (PE)    │       │   Private (PE)  │
└─────────────────┘       └────────┬──────────┘       └─────────────────┘
                                   │
                           ┌───────▼───────┐
                           │  Azure Key    │
                           │  Vault (PE)   │
                           └───────────────┘
```

- **Frontend** — Blazor Server app (public and placed behind Azure Front Door), VNet-integrated for outbound calls to backend
- **Backend** — Node.js Express API, accessible only via private endpoint
- **Database** — Azure SQL, accessible only via private endpoint
- **Key Vault** — Stores JWT signing secret, accessible only via private endpoint
- **Networking** — VNet with dedicated subnets, NSGs, and private DNS zones

## Project Structure

```
├── .github/workflows/     # GitHub Actions CI/CD (OIDC auth)
├── infra/                 # Bicep IaC (modular, deploy in order)
│   ├── networking/        # VNet, subnets, NSGs, private DNS zones
│   ├── sql/               # Azure SQL Server + database + private endpoint
│   ├── backend/           # App Service Plan, backend app, Key Vault + PEs
│   ├── frontend/          # Blazor frontend App Service
│   └── monitoring/        # Log Analytics, App Insights, alerts
├── src/
│   ├── frontend/          # Blazor Server (.NET 8)
│   ├── backend/           # Node.js Express API
│   └── database/          # SQL schema (init.sql)
```

## Getting Started

For prerequisites, local development setup, infrastructure deployment, and application deployment steps, see **[INSTRUCTIONS.md](INSTRUCTIONS.md)**.

## Security

- All inter-service communication uses private endpoints over VNet
- JWT authentication with secrets stored in Key Vault
- Managed Identity for Key Vault access (no credentials in code)
- Rate limiting on auth endpoints (20 requests / 15 min)
- HTTPS-only, TLS 1.2 minimum, FTPS disabled
- NSGs with least-privilege rules on all subnets

## License

See [LICENSE](LICENSE).