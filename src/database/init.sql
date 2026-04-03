-- ===========================================================================
-- init.sql
-- Initial database schema for the Allowance Tracking App.
-- Run this from a machine with VNet access (jump box or self-hosted runner).
-- ===========================================================================

-- Users table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
BEGIN
    CREATE TABLE Users (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Username NVARCHAR(50) NOT NULL,
        PasswordHash NVARCHAR(256) NOT NULL,
        DisplayName NVARCHAR(100) NOT NULL,
        Role NVARCHAR(20) NOT NULL DEFAULT 'kid',
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_Users_Username UNIQUE (Username),
        CONSTRAINT CK_Users_Role CHECK (Role IN ('parent', 'kid'))
    );
END
GO

-- Transactions table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Transactions')
BEGIN
    CREATE TABLE Transactions (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NOT NULL,
        Amount DECIMAL(10,2) NOT NULL,
        Description NVARCHAR(200) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy INT NOT NULL,
        CONSTRAINT FK_Transactions_UserId FOREIGN KEY (UserId) REFERENCES Users(Id),
        CONSTRAINT FK_Transactions_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES Users(Id)
    );

    CREATE INDEX IX_Transactions_UserId ON Transactions(UserId);
    CREATE INDEX IX_Transactions_CreatedAt ON Transactions(CreatedAt DESC);
END
GO

-- Seed: Create a default parent account
-- Generate a bcrypt hash (cost 12) for your chosen password and replace the
-- placeholder below before running this script.
--   node -e "const b=require('bcrypt');b.hash('YOUR_PASSWORD',12).then(console.log)"
IF NOT EXISTS (SELECT * FROM Users WHERE Username = 'parent')
BEGIN
    INSERT INTO Users (Username, PasswordHash, DisplayName, Role)
    VALUES (
        'parent',
        '<GENERATE_BCRYPT_HASH>',
        'Mom/Dad',
        'parent'
    );
END
GO
