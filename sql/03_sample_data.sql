-- ============================================================
--  BANK MANAGEMENT SYSTEM  |  sample_data.sql
--  Run this THIRD (after procedures_triggers.sql)
-- ============================================================
USE bank_db;

-- ── BRANCHES ─────────────────────────────────────────────────
INSERT INTO branches (branch_name, branch_code, city, state, phone) VALUES
('MG Road Main Branch',   'MGRB01', 'Bengaluru', 'Karnataka',    '08044001000'),
('Connaught Place Branch','CPLB02', 'New Delhi',  'Delhi',        '01144002000'),
('Marine Lines Branch',   'MRLB03', 'Mumbai',    'Maharashtra',   '02244003000'),
('Anna Salai Branch',     'ANLB04', 'Chennai',   'Tamil Nadu',    '04444004000');

-- ── CUSTOMERS ────────────────────────────────────────────────
INSERT INTO customers (full_name, email, phone, address, dob, gender) VALUES
('Priya Sharma',   'priya.sharma@email.com',   '9876543210', '12 MG Road, Bengaluru',         '1992-05-14', 'Female'),
('Rahul Verma',    'rahul.verma@email.com',    '9123456789', '34 Lajpat Nagar, New Delhi',    '1988-11-23', 'Male'),
('Anjali Patel',   'anjali.patel@email.com',   '9988776655', '7 Marine Drive, Mumbai',        '1995-03-08', 'Female'),
('Suresh Kumar',   'suresh.kumar@email.com',   '9871234560', '56 Anna Salai, Chennai',        '1983-07-19', 'Male'),
('Meera Nair',     'meera.nair@email.com',     '9765432180', '88 Koramangala, Bengaluru',     '1997-01-30', 'Female'),
('Arjun Reddy',    'arjun.reddy@email.com',    '9654321807', '21 Jubilee Hills, Hyderabad',   '1990-09-05', 'Male');

-- ── EMPLOYEES ────────────────────────────────────────────────
INSERT INTO employees (branch_id, full_name, email, phone, role, salary, joined_date) VALUES
(1,'Vikram Bose',   'vikram.bose@bank.com',   '9010001001','Branch Manager', 85000.00,'2015-06-01'),
(1,'Deepa Rao',     'deepa.rao@bank.com',     '9010001002','Cashier',        35000.00,'2018-03-15'),
(2,'Naveen Gupta',  'naveen.gupta@bank.com',  '9010002001','Branch Manager', 90000.00,'2013-09-10'),
(2,'Sonia Mehta',   'sonia.mehta@bank.com',   '9010002002','Loan Officer',   45000.00,'2019-01-20'),
(3,'Rohan D''souza','rohan.dsouza@bank.com',  '9010003001','Branch Manager', 88000.00,'2016-04-05'),
(4,'Kavitha Iyer',  'kavitha.iyer@bank.com',  '9010004001','Branch Manager', 87000.00,'2017-08-12');

-- ── ADMIN LOGIN ──────────────────────────────────────────────
-- password_hash stores bcrypt hash of 'admin123'
INSERT INTO admin_login (username, password_hash, full_name, email) VALUES
('admin', '$2b$10$VHZyEjczG4m5f7bEanXpdeP7FEO9HaDEhkpk7Rc4B5G9TbVpNKoYO',
 'Bank Administrator', 'admin@bankms.com'),
('manager1', '$2b$10$VHZyEjczG4m5f7bEanXpdeP7FEO9HaDEhkpk7Rc4B5G9TbVpNKoYO',
 'Vikram Bose', 'vikram.bose@bank.com');

-- ── ACCOUNTS (via procedure for proper transaction records) ──
SET @msg = '';
CALL sp_open_account(1, 1, 'Savings',  125000.00, @acc_id, @msg); -- Priya  → Acc 1
CALL sp_open_account(2, 2, 'Current',   95000.00, @acc_id, @msg); -- Rahul  → Acc 2
CALL sp_open_account(3, 3, 'Savings',   48000.00, @acc_id, @msg); -- Anjali → Acc 3
CALL sp_open_account(4, 4, 'Current',  220000.00, @acc_id, @msg); -- Suresh → Acc 4
CALL sp_open_account(5, 1, 'Savings',   30000.00, @acc_id, @msg); -- Meera  → Acc 5
CALL sp_open_account(6, 2, 'Savings',   75000.00, @acc_id, @msg); -- Arjun  → Acc 6

-- ── EXTRA TRANSACTIONS ────────────────────────────────────────
CALL sp_deposit  (1, 25000.00, 'Monthly Salary Credit',         @msg);
CALL sp_deposit  (3, 10000.00, 'FD Maturity Credited',          @msg);
CALL sp_withdraw (2, 15000.00, 'ATM Withdrawal',                @msg);
CALL sp_withdraw (4, 50000.00, 'Cheque Payment',                @msg);
CALL sp_transfer (1, 3,  8000.00, 'Family Transfer',            @msg);
CALL sp_transfer (4, 6, 20000.00, 'Business Payment',           @msg);
CALL sp_deposit  (5,  5000.00, 'Self Deposit',                  @msg);
CALL sp_withdraw (5,  2000.00, 'Bill Payment',                  @msg);

-- ── LOANS ────────────────────────────────────────────────────
-- EMI is auto-calculated by trigger
INSERT INTO loans (customer_id, loan_type, principal, interest_rate, duration_months, emi, status, start_date) VALUES
(1, 'Home',      2500000.00, 8.50,  240, 0, 'Active',  '2023-01-01'),
(2, 'Personal',    150000.00,12.00,  36,  0, 'Active',  '2024-03-01'),
(3, 'Education',   500000.00, 9.00,  60,  0, 'Active',  '2023-07-01'),
(4, 'Auto',        800000.00, 9.50,  60,  0, 'Pending', '2024-11-01'),
(5, 'Business',    300000.00,11.00,  48,  0, 'Active',  '2024-01-01');

-- ═══════════════════════════════════════════════════════════════
--  USEFUL DEMO QUERIES
-- ═══════════════════════════════════════════════════════════════

-- Q1: Full account summary (uses view)
SELECT * FROM vw_account_summary ORDER BY account_id;

-- Q2: Transaction history for account 1
SELECT txn_id, txn_type, amount, balance_after, description, txn_date
FROM vw_transaction_history
WHERE account_id = 1
ORDER BY txn_date DESC;

-- Q3: Search customer by name or phone
SELECT customer_id, full_name, email, phone, address
FROM customers
WHERE full_name LIKE '%Priya%' OR phone LIKE '%9876%';

-- Q4: All transactions today
SELECT * FROM vw_transaction_history
WHERE DATE(txn_date) = CURDATE()
ORDER BY txn_date DESC;

-- Q5: Total balance per branch
SELECT b.branch_name, b.branch_code,
       COUNT(a.account_id)  AS total_accounts,
       SUM(a.balance)       AS total_balance
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name, b.branch_code
ORDER BY total_balance DESC;

-- Q6: Customers with more than one account
SELECT c.full_name, c.email, COUNT(a.account_id) AS account_count
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name, c.email
HAVING account_count > 0
ORDER BY account_count DESC;

-- Q7: Loan summary
SELECT * FROM vw_loan_summary ORDER BY loan_id;

-- Q8: Highest balance accounts
SELECT account_id, customer_name, account_type, balance, branch_name
FROM vw_account_summary
ORDER BY balance DESC
LIMIT 5;

-- Q9: Monthly transaction volume
SELECT DATE_FORMAT(txn_date, '%Y-%m') AS month,
       COUNT(*)                        AS total_txns,
       SUM(amount)                     AS total_volume,
       SUM(CASE WHEN txn_type='Deposit'      THEN amount ELSE 0 END) AS deposits,
       SUM(CASE WHEN txn_type='Withdrawal'   THEN amount ELSE 0 END) AS withdrawals
FROM transactions
GROUP BY month
ORDER BY month DESC;

-- Q10: Active loans with EMI and total repayment
SELECT loan_id, customer_name, loan_type,
       FORMAT(principal,2) AS principal,
       interest_rate,
       duration_months,
       FORMAT(emi,2) AS monthly_emi,
       FORMAT(total_repayment,2) AS total_repayment,
       FORMAT(total_interest,2)  AS total_interest_paid,
       status
FROM vw_loan_summary
WHERE status = 'Active';
