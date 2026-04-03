// ===========================================================================
// auth.js (middleware)
// JWT verification middleware. Extracts user info from token and attaches
// it to req.user. Also provides a requireRole() guard.
// ===========================================================================

const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../config/keyvault');

async function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid authorization header' });
  }

  const token = authHeader.substring(7);

  try {
    const secret = await getJwtSecret();
    const decoded = jwt.verify(token, secret, { algorithms: ['HS256'] });
    req.user = {
      id: decoded.id,
      username: decoded.username,
      role: decoded.role,
      displayName: decoded.displayName,
    };
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

module.exports = { authenticate, requireRole };
