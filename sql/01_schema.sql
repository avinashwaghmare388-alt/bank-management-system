-- ============================================================
--  BANK MANAGEMENT SYSTEM  |  schema.sql
--  Run this file FIRST in MySQL Workbench
-- ============================================================

DROP DATABASE IF EXISTS bank_db;
CREATE DATABASE bank_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE bank_db;

-- ── 1. BRANCHES ──────────────────────────────────────────────
CREATE TABLE branches (
    branch_id     INT           NOT NULL AUTO_INCREMENT,
    branch_name   VARCHAR(100)  NOT NULL,
    branch_code   VARCHAR(10)   NOT NULL UNIQUE,
    city          VARCHAR(60)   NOT NULL,
    state         VARCHAR(60)   NOT NULL,
    phone         VARCHAR(15)   NOT NULL,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (branch_id)
);

-- ── 2. CUSTOMERS ─────────────────────────────────────────────
CREATE TABLE customers (
    customer_id   INT           NOT NULL AUTO_INCREMENT,
    full_name     VARCHAR(100)  NOT NULL,
    email         VARCHAR(100)  NOT NULL UNIQUE,
    phone         VARCHAR(15)   NOT NULL UNIQUE,
    address       VARCHAR(255)  NOT NULL,
    dob           DATE          NOT NULL,
    gender        ENUM('Male','Female','Other') NOT NULL,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id)
);

-- ── 3. EMPLOYEES ─────────────────────────────────────────────
CREATE TABLE employees (
    employee_id   INT           NOT NULL AUTO_INCREMENT,
    branch_id     INT           NOT NULL,
    full_name     VARCHAR(100)  NOT NULL,
    email         VARCHAR(100)  NOT NULL UNIQUE,
    phone         VARCHAR(15)   NOT NULL UNIQUE,
    role          VARCHAR(50)   NOT NULL DEFAULT 'Clerk',
    salary        DECIMAL(12,2) NOT NULL CHECK (salary >= 0),
    joined_date   DATE          NOT NULL,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (employee_id),
    CONSTRAINT fk_emp_branch FOREIGN KEY (branch_id)
        REFERENCES branches(branch_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ── 4. ACCOUNTS ──────────────────────────────────────────────
CREATE TABLE accounts (
    account_id      INT             NOT NULL AUTO_INCREMENT,
    customer_id     INT             NOT NULL,
    branch_id       INT             NOT NULL,
    account_type    ENUM('Savings','Current') NOT NULL DEFAULT 'Savings',
    balance         DECIMAL(15,2)   NOT NULL DEFAULT 0.00,
    status          ENUM('Active','Frozen','Closed') NOT NULL DEFAULT 'Active',
    opened_date     DATE            NOT NULL DEFAULT (CURDATE()),
    -- Minimum balance: 500 for Savings, 1000 for Current
    CONSTRAINT chk_min_balance CHECK (
        (account_type = 'Savings'  AND balance >= 500.00) OR
        (account_type = 'Current'  AND balance >= 1000.00)
    ),
    PRIMARY KEY (account_id),
    CONSTRAINT fk_acc_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_acc_branch FOREIGN KEY (branch_id)
        REFERENCES branches(branch_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ── 5. TRANSACTIONS ──────────────────────────────────────────
CREATE TABLE transactions (
    txn_id          INT             NOT NULL AUTO_INCREMENT,
    account_id      INT             NOT NULL,
    txn_type        ENUM('Deposit','Withdrawal','Transfer-In','Transfer-Out') NOT NULL,
    amount          DECIMAL(15,2)   NOT NULL CHECK (amount > 0),
    balance_after   DECIMAL(15,2)   NOT NULL,
    reference_id    INT             NULL,      -- linked account for transfers
    description     VARCHAR(255)    NOT NULL DEFAULT '',
    txn_date        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (txn_id),
    CONSTRAINT fk_txn_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ── 6. LOANS ─────────────────────────────────────────────────
CREATE TABLE loans (
    loan_id         INT             NOT NULL AUTO_INCREMENT,
    customer_id     INT             NOT NULL,
    loan_type       ENUM('Personal','Home','Auto','Education','Business') NOT NULL,
    principal       DECIMAL(15,2)   NOT NULL CHECK (principal > 0),
    interest_rate   DECIMAL(5,2)    NOT NULL CHECK (interest_rate > 0),
    duration_months INT             NOT NULL CHECK (duration_months > 0),
    emi             DECIMAL(15,2)   NOT NULL,
    status          ENUM('Pending','Active','Closed','Defaulted') NOT NULL DEFAULT 'Pending',
    start_date      DATE            NOT NULL DEFAULT (CURDATE()),
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (loan_id),
    CONSTRAINT fk_loan_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ── 7. ADMIN LOGIN ───────────────────────────────────────────
CREATE TABLE admin_login (
    admin_id      INT           NOT NULL AUTO_INCREMENT,
    username      VARCHAR(50)   NOT NULL UNIQUE,
    password_hash VARCHAR(255)  NOT NULL,   -- store hashed passwords only
    full_name     VARCHAR(100)  NOT NULL,
    email         VARCHAR(100)  NOT NULL UNIQUE,
    last_login    TIMESTAMP     NULL,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (admin_id)
);

-- ── INDEXES ──────────────────────────────────────────────────
CREATE INDEX idx_accounts_customer   ON accounts(customer_id);
CREATE INDEX idx_accounts_branch     ON accounts(branch_id);
CREATE INDEX idx_transactions_account ON transactions(account_id);
CREATE INDEX idx_transactions_date   ON transactions(txn_date);
CREATE INDEX idx_loans_customer      ON loans(customer_id);
CREATE INDEX idx_employees_branch    ON employees(branch_id);
