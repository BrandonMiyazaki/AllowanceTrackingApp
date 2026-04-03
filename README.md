# Allowance Tracking App

A family allowance tracker that lets parents manage their kids' allowance balances — add funds, track spending, and view transaction history. Built with a Blazor Server frontend, Node.js/Express API backend, and Azure SQL Database, all deployed to Azure App Services with private networking.

<img width="357" height="397" alt="image" src="https://github.com/user-attachments/assets/f6a262ae-cd3f-4eed-b976-ea8a94b98daa" /> <br>



<img width="215" height="334" alt="image" src="https://github.com/user-attachments/assets/228e24db-2008-4743-836a-6d92b46e5ab9" />

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
- **Optional edge protection** — The web app can be placed behind **Azure Front Door** (e.g., with WAF) to secure and control inbound connectivity to the web app.

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

## License

See [LICENSE](LICENSE).
