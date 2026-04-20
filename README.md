# 🏦 Bank Management System

A working college-level DBMS project — MySQL + Node.js + Vanilla JS frontend.

---

## 📁 Folder Structure

```
bank-management/
├── sql/
│   ├── 01_schema.sql              ← All CREATE TABLE statements
│   ├── 02_procedures_triggers.sql ← Stored procedures, triggers, views
│   └── 03_sample_data.sql         ← INSERT data + demo queries
│
├── backend/
│   ├── server.js                  ← Express REST API
│   ├── db.js                      ← MySQL connection pool
│   ├── .env                       ← DB credentials (edit this)
│   └── package.json
│
└── frontend/
    └── index.html                 ← Complete single-file frontend
```

---

## ⚙️ Prerequisites

- [MySQL 8.0+](https://dev.mysql.com/downloads/mysql/) installed and running
- [Node.js 18+](https://nodejs.org/) installed

---

## 🚀 Step-by-Step Setup

### Step 1 — Set up the MySQL Database

Open **MySQL Workbench** (or any MySQL client) and run these three files **in order**:

```
1. sql/01_schema.sql
2. sql/02_procedures_triggers.sql
3. sql/03_sample_data.sql
```

**In MySQL Workbench:**
- File → Open SQL Script → select the file → click ⚡ (Execute All)
- Repeat for each file in order

### Step 2 — Configure the Backend

Open `backend/.env` and set your MySQL password:

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_actual_password_here
DB_NAME=bank_db
PORT=3000
```

### Step 3 — Install Backend Dependencies

Open a terminal in the `backend/` folder:

```bash
cd bank-management/backend
npm install
```

### Step 4 — Start the Backend Server

```bash
npm start
```

You should see:
```
  ✔  MySQL connected to bank_db
  Bank Management System running at http://localhost:3000
```

### Step 5 — Open the Frontend

Open your browser and go to:

```
http://localhost:3000
```

**Login credentials:**
- Username: `admin`
- Password: `admin123`

---

## 🔧 What Each SQL File Does

| File | Purpose |
|------|---------|
| `01_schema.sql` | Creates the database and all 7 tables with constraints, FKs, and indexes |
| `02_procedures_triggers.sql` | Creates 4 stored procedures, 3 triggers, and 4 views |
| `03_sample_data.sql` | Inserts sample branches, customers, employees, accounts, loans, and 10+ transactions |

---

## 📋 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login` | Admin login |
| GET | `/api/stats` | Dashboard statistics |
| GET | `/api/customers` | List all customers (supports `?search=`) |
| POST | `/api/customers` | Add new customer |
| GET | `/api/accounts` | List all accounts |
| POST | `/api/accounts` | Open new account |
| POST | `/api/transactions/deposit` | Deposit money |
| POST | `/api/transactions/withdraw` | Withdraw money |
| POST | `/api/transactions/transfer` | Transfer between accounts |
| GET | `/api/transactions` | Transaction history |
| GET | `/api/loans` | All loans |
| POST | `/api/loans` | Add new loan |
| GET | `/api/employees` | All employees |
| GET | `/api/branches` | All branches |

---

## 🧪 Testing Stored Procedures Directly in MySQL

```sql
USE bank_db;

-- Test deposit
SET @msg = '';
CALL sp_deposit(1, 5000.00, 'Test Deposit', @msg);
SELECT @msg;

-- Test withdrawal
CALL sp_withdraw(1, 2000.00, 'Test Withdrawal', @msg);
SELECT @msg;

-- Test transfer
CALL sp_transfer(1, 2, 1000.00, 'Test Transfer', @msg);
SELECT @msg;

-- Try to overdraw (should fail)
CALL sp_withdraw(1, 9999999.00, 'Overdraw test', @msg);
SELECT @msg;  -- Should show ERROR: Insufficient balance
```

---

## 📸 Screenshots to Take (for report/viva)

1. MySQL Workbench showing all 7 tables in the schema panel
2. Result of `SELECT * FROM vw_account_summary;`
3. Result of `SELECT * FROM vw_transaction_history;`
4. Result of `SELECT * FROM vw_loan_summary;`
5. A stored procedure CALL with result `@msg` showing SUCCESS
6. A failed withdrawal CALL showing the ERROR message
7. Browser — Login page
8. Browser — Dashboard with stats
9. Browser — Customers table
10. Browser — Accounts table
11. Browser — Deposit/Withdraw modal
12. Browser — Loans page

---

## 🗄️ Database Design Summary

| Table | Primary Key | Foreign Keys |
|-------|-------------|--------------|
| `branches` | branch_id | — |
| `customers` | customer_id | — |
| `employees` | employee_id | branch_id → branches |
| `accounts` | account_id | customer_id → customers, branch_id → branches |
| `transactions` | txn_id | account_id → accounts |
| `loans` | loan_id | customer_id → customers |
| `admin_login` | admin_id | — |

### Business Rules Enforced

| Rule | Mechanism |
|------|-----------|
| Minimum balance (₹500 Savings / ₹1000 Current) | CHECK constraint + trigger |
| Withdrawal fails if balance insufficient | Stored procedure logic |
| Transfer is atomic (both sides update) | START TRANSACTION / COMMIT |
| EMI auto-calculated on loan insert | BEFORE INSERT trigger |
| Every transaction creates a record | Inside each stored procedure |
| Account type-specific minimum enforced | CHECK + procedure validation |
