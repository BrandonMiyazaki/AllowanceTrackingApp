-- ============================================================================
-- 001-initial-schema.sql
-- Initial database schema for Allowance Tracking App
-- ============================================================================

-- Users table (linked to Entra ID)
CREATE TABLE Users (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    EntraObjectId NVARCHAR(128) NOT NULL UNIQUE,
    DisplayName NVARCHAR(256) NOT NULL,
    Email NVARCHAR(256),
    Role NVARCHAR(50) NOT NULL DEFAULT 'Child',
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE()
);

-- Allowance balance and transactions
CREATE TABLE Transactions (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    UserId UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Users(Id),
    Amount DECIMAL(10,2) NOT NULL,
    Description NVARCHAR(500),
    TransactionType NVARCHAR(50) NOT NULL,
    CreatedBy UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES Users(Id),
    CreatedAt DATETIME2 DEFAULT GETUTCDATE()
);

-- Index for fast balance lookups
CREATE INDEX IX_Transactions_UserId ON Transactions(UserId);

-- Index for querying by creator (parent viewing their actions)
CREATE INDEX IX_Transactions_CreatedBy ON Transactions(CreatedBy);
