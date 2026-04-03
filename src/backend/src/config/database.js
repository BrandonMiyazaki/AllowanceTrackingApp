// ===========================================================================
// database.js
// Configures and exports an mssql connection pool.
// In Azure: uses DefaultAzureCredential (Managed Identity) — no passwords.
// Locally: uses SQL auth from environment variables.
// ===========================================================================

const sql = require('mssql');
const { DefaultAzureCredential } = require('@azure/identity');

let pool = null;

async function getPool() {
  if (pool) return pool;

  const isAzure = !!process.env.KEY_VAULT_URL;

  if (isAzure) {
    // Azure: use Managed Identity token for SQL
    const credential = new DefaultAzureCredential();
    const tokenResponse = await credential.getToken('https://database.windows.net/.default');

    const config = {
      server: process.env.DATABASE_HOST,
      database: process.env.DATABASE_NAME,
      port: parseInt(process.env.DATABASE_PORT || '1433', 10),
      options: {
        encrypt: true,
        trustServerCertificate: false,
      },
      authentication: {
        type: 'azure-active-directory-access-token',
        options: {
          token: tokenResponse.token,
        },
      },
    };
    pool = await sql.connect(config);
  } else {
    // Local development: SQL auth
    const config = {
      server: process.env.DATABASE_HOST || 'localhost',
      database: process.env.DATABASE_NAME || 'allowance-db',
      port: parseInt(process.env.DATABASE_PORT || '1433', 10),
      user: process.env.DATABASE_USER,
      password: process.env.DATABASE_PASSWORD,
      options: {
        encrypt: true,
        trustServerCertificate: true,
      },
    };
    pool = await sql.connect(config);
  }

  return pool;
}

async function query(queryString, params = []) {
  const p = await getPool();
  const request = p.request();
  params.forEach(({ name, type, value }) => {
    request.input(name, type, value);
  });
  return request.query(queryString);
}

module.exports = { getPool, query, sql };
