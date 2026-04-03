// ===========================================================================
// keyvault.js
// Retrieves secrets from Azure Key Vault using Managed Identity.
// Falls back to environment variables for local development.
// ===========================================================================

const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

let jwtSecret = null;

async function getJwtSecret() {
  if (jwtSecret) return jwtSecret;

  const keyVaultUrl = process.env.KEY_VAULT_URL;

  if (keyVaultUrl) {
    const credential = new DefaultAzureCredential();
    const client = new SecretClient(keyVaultUrl, credential);
    const secret = await client.getSecret('jwt-signing-key');
    jwtSecret = secret.value;
  } else {
    // Local development fallback
    jwtSecret = process.env.JWT_SECRET || 'local-dev-secret-change-me';
  }

  return jwtSecret;
}

module.exports = { getJwtSecret };
