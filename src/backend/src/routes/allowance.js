// ===========================================================================
// routes/allowance.js
// Handles allowance operations: view balance, transaction history,
// add funds (parent), and deduct funds (kid or parent).
// ===========================================================================

const express = require('express');
const { query, sql } = require('../config/database');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

// ---------------------------------------------------------------------------
// GET /api/allowance/:userId
// Authenticated — get balance and recent transactions for a user
// Kids can only view their own; parents can view any.
// ---------------------------------------------------------------------------
router.get('/:userId', authenticate, async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);

    if (isNaN(userId)) {
      return res.status(400).json({ error: 'Invalid user ID' });
    }

    // Kids can only view their own balance
    if (req.user.role === 'kid' && req.user.id !== userId) {
      return res.status(403).json({ error: 'You can only view your own allowance' });
    }

    // Get balance (sum of all transactions)
    const balanceResult = await query(
      'SELECT ISNULL(SUM(Amount), 0) AS Balance FROM Transactions WHERE UserId = @userId',
      [{ name: 'userId', type: sql.Int, value: userId }]
    );

    // Get recent transactions (last 50)
    const txResult = await query(
      `SELECT t.Id, t.Amount, t.Description, t.CreatedAt,
              u.DisplayName AS CreatedByName
       FROM Transactions t
       LEFT JOIN Users u ON t.CreatedBy = u.Id
       WHERE t.UserId = @userId
       ORDER BY t.CreatedAt DESC
       OFFSET 0 ROWS FETCH NEXT 50 ROWS ONLY`,
      [{ name: 'userId', type: sql.Int, value: userId }]
    );

    // Get user info
    const userResult = await query(
      'SELECT Id, Username, DisplayName, Role FROM Users WHERE Id = @userId',
      [{ name: 'userId', type: sql.Int, value: userId }]
    );

    if (userResult.recordset.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      user: userResult.recordset[0],
      balance: balanceResult.recordset[0].Balance,
      transactions: txResult.recordset,
    });
  } catch (err) {
    console.error('Get allowance error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ---------------------------------------------------------------------------
// POST /api/allowance/:userId/add
// Parent-only — adds allowance to a kid's account
// ---------------------------------------------------------------------------
router.post('/:userId/add', authenticate, requireRole('parent'), async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    const { amount, description } = req.body;

    if (isNaN(userId)) {
      return res.status(400).json({ error: 'Invalid user ID' });
    }

    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({ error: 'Amount must be a positive number' });
    }

    if (parsedAmount > 10000) {
      return res.status(400).json({ error: 'Amount cannot exceed 10,000' });
    }

    // Verify user exists
    const userCheck = await query(
      'SELECT Id FROM Users WHERE Id = @userId',
      [{ name: 'userId', type: sql.Int, value: userId }]
    );

    if (userCheck.recordset.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const result = await query(
      `INSERT INTO Transactions (UserId, Amount, Description, CreatedBy)
       OUTPUT INSERTED.Id, INSERTED.Amount, INSERTED.Description, INSERTED.CreatedAt
       VALUES (@userId, @amount, @description, @createdBy)`,
      [
        { name: 'userId', type: sql.Int, value: userId },
        { name: 'amount', type: sql.Decimal(10, 2), value: parsedAmount },
        { name: 'description', type: sql.NVarChar(200), value: description || 'Allowance added' },
        { name: 'createdBy', type: sql.Int, value: req.user.id },
      ]
    );

    const tx = result.recordset[0];

    // Get updated balance
    const balanceResult = await query(
      'SELECT ISNULL(SUM(Amount), 0) AS Balance FROM Transactions WHERE UserId = @userId',
      [{ name: 'userId', type: sql.Int, value: userId }]
    );

    res.status(201).json({
      transaction: tx,
      newBalance: balanceResult.recordset[0].Balance,
    });
  } catch (err) {
    console.error('Add allowance error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ---------------------------------------------------------------------------
// POST /api/allowance/:userId/deduct
// Authenticated — deducts from allowance. Kids can deduct from their own;
// parents can deduct from any account.
// ---------------------------------------------------------------------------
router.post('/:userId/deduct', authenticate, async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    const { amount, description } = req.body;

    if (isNaN(userId)) {
      return res.status(400).json({ error: 'Invalid user ID' });
    }

    // Kids can only deduct from their own account
    if (req.user.role === 'kid' && req.user.id !== userId) {
      return res.status(403).json({ error: 'You can only deduct from your own allowance' });
    }

    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({ error: 'Amount must be a positive number' });
    }

    if (parsedAmount > 10000) {
      return res.status(400).json({ error: 'Amount cannot exceed 10,000' });
    }

    // Check current balance
    const balanceResult = await query(
      'SELECT ISNULL(SUM(Amount), 0) AS Balance FROM Transactions WHERE UserId = @userId',
      [{ name: 'userId', type: sql.Int, value: userId }]
    );

    const currentBalance = balanceResult.recordset[0].Balance;
    if (parsedAmount > currentBalance) {
      return res.status(400).json({
        error: 'Insufficient balance',
        currentBalance,
      });
    }

    const result = await query(
      `INSERT INTO Transactions (UserId, Amount, Description, CreatedBy)
       OUTPUT INSERTED.Id, INSERTED.Amount, INSERTED.Description, INSERTED.CreatedAt
       VALUES (@userId, @amount, @description, @createdBy)`,
      [
        { name: 'userId', type: sql.Int, value: userId },
        { name: 'amount', type: sql.Decimal(10, 2), value: -parsedAmount },
        { name: 'description', type: sql.NVarChar(200), value: description || 'Allowance deducted' },
        { name: 'createdBy', type: sql.Int, value: req.user.id },
      ]
    );

    const tx = result.recordset[0];

    res.status(201).json({
      transaction: tx,
      newBalance: currentBalance - parsedAmount,
    });
  } catch (err) {
    console.error('Deduct allowance error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
