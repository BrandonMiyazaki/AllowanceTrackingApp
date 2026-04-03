// ===========================================================================
// routes/auth.js
// Handles user authentication (login) and registration (parent-only).
// Passwords are hashed with bcrypt (cost factor 12).
// ===========================================================================

const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { query, sql } = require('../config/database');
const { getJwtSecret } = require('../config/keyvault');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

const BCRYPT_ROUNDS = 12;
const TOKEN_EXPIRY = '1h';

// ---------------------------------------------------------------------------
// POST /api/auth/login
// Public — authenticates a user and returns a JWT
// ---------------------------------------------------------------------------
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    const result = await query(
      'SELECT Id, Username, PasswordHash, DisplayName, Role FROM Users WHERE Username = @username',
      [{ name: 'username', type: sql.NVarChar(50), value: username }]
    );

    if (result.recordset.length === 0) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }

    const user = result.recordset[0];
    const passwordValid = await bcrypt.compare(password, user.PasswordHash);

    if (!passwordValid) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }

    const secret = await getJwtSecret();
    const token = jwt.sign(
      {
        id: user.Id,
        username: user.Username,
        role: user.Role,
        displayName: user.DisplayName,
      },
      secret,
      { algorithm: 'HS256', expiresIn: TOKEN_EXPIRY }
    );

    res.json({
      token,
      user: {
        id: user.Id,
        username: user.Username,
        displayName: user.DisplayName,
        role: user.Role,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ---------------------------------------------------------------------------
// POST /api/auth/register
// Parent-only — registers a new kid or parent account
// ---------------------------------------------------------------------------
router.post('/register', authenticate, requireRole('parent'), async (req, res) => {
  try {
    const { username, password, displayName, role } = req.body;

    if (!username || !password || !displayName) {
      return res.status(400).json({ error: 'Username, password, and displayName are required' });
    }

    if (role && !['kid', 'parent'].includes(role)) {
      return res.status(400).json({ error: 'Role must be "kid" or "parent"' });
    }

    // Check for existing username
    const existing = await query(
      'SELECT Id FROM Users WHERE Username = @username',
      [{ name: 'username', type: sql.NVarChar(50), value: username }]
    );

    if (existing.recordset.length > 0) {
      return res.status(409).json({ error: 'Username already exists' });
    }

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const userRole = role || 'kid';

    const result = await query(
      `INSERT INTO Users (Username, PasswordHash, DisplayName, Role)
       OUTPUT INSERTED.Id, INSERTED.Username, INSERTED.DisplayName, INSERTED.Role
       VALUES (@username, @passwordHash, @displayName, @role)`,
      [
        { name: 'username', type: sql.NVarChar(50), value: username },
        { name: 'passwordHash', type: sql.NVarChar(256), value: passwordHash },
        { name: 'displayName', type: sql.NVarChar(100), value: displayName },
        { name: 'role', type: sql.NVarChar(20), value: userRole },
      ]
    );

    const newUser = result.recordset[0];
    res.status(201).json({
      id: newUser.Id,
      username: newUser.Username,
      displayName: newUser.DisplayName,
      role: newUser.Role,
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ---------------------------------------------------------------------------
// GET /api/auth/me
// Authenticated — returns current user info
// ---------------------------------------------------------------------------
router.get('/me', authenticate, (req, res) => {
  res.json(req.user);
});

// ---------------------------------------------------------------------------
// GET /api/auth/users
// Parent-only — lists all users (for managing kids)
// ---------------------------------------------------------------------------
router.get('/users', authenticate, requireRole('parent'), async (req, res) => {
  try {
    const result = await query(
      'SELECT Id, Username, DisplayName, Role, CreatedAt FROM Users ORDER BY DisplayName'
    );
    res.json(result.recordset);
  } catch (err) {
    console.error('List users error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
