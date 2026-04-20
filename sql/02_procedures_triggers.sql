-- ============================================================
--  BANK MANAGEMENT SYSTEM  |  procedures_triggers.sql
--  Run this SECOND (after schema.sql)
-- ============================================================
USE bank_db;

DELIMITER $$

-- ╔══════════════════════════════════════════════════════════╗
-- ║  STORED PROCEDURE: sp_deposit                           ║
-- ║  Deposits money into an account.                        ║
-- ║  Creates a transaction record automatically.            ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE PROCEDURE sp_deposit (
    IN  p_account_id  INT,
    IN  p_amount      DECIMAL(15,2),
    IN  p_description VARCHAR(255),
    OUT p_message     VARCHAR(255)
)
BEGIN
    DECLARE v_status   VARCHAR(20);
    DECLARE v_balance  DECIMAL(15,2);
    DECLARE v_new_bal  DECIMAL(15,2);

    -- Validate amount
    IF p_amount <= 0 THEN
        SET p_message = 'ERROR: Deposit amount must be greater than zero.';
        LEAVE sp_deposit;
    END IF;

    -- Check account exists and is active
    SELECT status, balance INTO v_status, v_balance
    FROM accounts
    WHERE account_id = p_account_id;

    IF v_status IS NULL THEN
        SET p_message = 'ERROR: Account not found.';
    ELSEIF v_status != 'Active' THEN
        SET p_message = CONCAT('ERROR: Account is ', v_status, '. Cannot deposit.');
    ELSE
        SET v_new_bal = v_balance + p_amount;

        UPDATE accounts SET balance = v_new_bal WHERE account_id = p_account_id;

        INSERT INTO transactions (account_id, txn_type, amount, balance_after, description)
        VALUES (p_account_id, 'Deposit', p_amount, v_new_bal,
                IF(p_description = '' OR p_description IS NULL, 'Cash Deposit', p_description));

        SET p_message = CONCAT('SUCCESS: Deposited ₹', p_amount, '. New balance: ₹', v_new_bal);
    END IF;
END$$


-- ╔══════════════════════════════════════════════════════════╗
-- ║  STORED PROCEDURE: sp_withdraw                          ║
-- ║  Withdraws money. Fails if balance would drop below     ║
-- ║  the minimum (500 Savings / 1000 Current).              ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE PROCEDURE sp_withdraw (
    IN  p_account_id  INT,
    IN  p_amount      DECIMAL(15,2),
    IN  p_description VARCHAR(255),
    OUT p_message     VARCHAR(255)
)
BEGIN
    DECLARE v_status   VARCHAR(20);
    DECLARE v_balance  DECIMAL(15,2);
    DECLARE v_type     VARCHAR(20);
    DECLARE v_min_bal  DECIMAL(15,2);
    DECLARE v_new_bal  DECIMAL(15,2);

    IF p_amount <= 0 THEN
        SET p_message = 'ERROR: Withdrawal amount must be greater than zero.';
        LEAVE sp_withdraw;
    END IF;

    SELECT status, balance, account_type INTO v_status, v_balance, v_type
    FROM accounts WHERE account_id = p_account_id;

    IF v_status IS NULL THEN
        SET p_message = 'ERROR: Account not found.';
        LEAVE sp_withdraw;
    END IF;

    IF v_status != 'Active' THEN
        SET p_message = CONCAT('ERROR: Account is ', v_status, '. Cannot withdraw.');
        LEAVE sp_withdraw;
    END IF;

    SET v_min_bal = IF(v_type = 'Savings', 500.00, 1000.00);
    SET v_new_bal = v_balance - p_amount;

    IF v_new_bal < v_min_bal THEN
        SET p_message = CONCAT('ERROR: Insufficient balance. Minimum balance ₹', v_min_bal,
                               ' must be maintained. Available: ₹', v_balance - v_min_bal);
        LEAVE sp_withdraw;
    END IF;

    UPDATE accounts SET balance = v_new_bal WHERE account_id = p_account_id;

    INSERT INTO transactions (account_id, txn_type, amount, balance_after, description)
    VALUES (p_account_id, 'Withdrawal', p_amount, v_new_bal,
            IF(p_description = '' OR p_description IS NULL, 'Cash Withdrawal', p_description));

    SET p_message = CONCAT('SUCCESS: Withdrew ₹', p_amount, '. New balance: ₹', v_new_bal);
END$$


-- ╔══════════════════════════════════════════════════════════╗
-- ║  STORED PROCEDURE: sp_transfer                          ║
-- ║  Transfers funds between two accounts atomically.       ║
-- ║  Both debit & credit records are inserted.              ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE PROCEDURE sp_transfer (
    IN  p_from_acc    INT,
    IN  p_to_acc      INT,
    IN  p_amount      DECIMAL(15,2),
    IN  p_description VARCHAR(255),
    OUT p_message     VARCHAR(255)
)
BEGIN
    DECLARE v_from_status  VARCHAR(20);
    DECLARE v_to_status    VARCHAR(20);
    DECLARE v_from_bal     DECIMAL(15,2);
    DECLARE v_to_bal       DECIMAL(15,2);
    DECLARE v_from_type    VARCHAR(20);
    DECLARE v_min_bal      DECIMAL(15,2);
    DECLARE v_from_new     DECIMAL(15,2);
    DECLARE v_to_new       DECIMAL(15,2);

    IF p_amount <= 0 THEN
        SET p_message = 'ERROR: Transfer amount must be greater than zero.';
        LEAVE sp_transfer;
    END IF;

    IF p_from_acc = p_to_acc THEN
        SET p_message = 'ERROR: Cannot transfer to the same account.';
        LEAVE sp_transfer;
    END IF;

    SELECT status, balance, account_type INTO v_from_status, v_from_bal, v_from_type
    FROM accounts WHERE account_id = p_from_acc;

    SELECT status, balance INTO v_to_status, v_to_bal
    FROM accounts WHERE account_id = p_to_acc;

    IF v_from_status IS NULL THEN
        SET p_message = 'ERROR: Source account not found.';
        LEAVE sp_transfer;
    END IF;

    IF v_to_status IS NULL THEN
        SET p_message = 'ERROR: Destination account not found.';
        LEAVE sp_transfer;
    END IF;

    IF v_from_status != 'Active' THEN
        SET p_message = 'ERROR: Source account is not active.';
        LEAVE sp_transfer;
    END IF;

    IF v_to_status != 'Active' THEN
        SET p_message = 'ERROR: Destination account is not active.';
        LEAVE sp_transfer;
    END IF;

    SET v_min_bal  = IF(v_from_type = 'Savings', 500.00, 1000.00);
    SET v_from_new = v_from_bal - p_amount;
    SET v_to_new   = v_to_bal + p_amount;

    IF v_from_new < v_min_bal THEN
        SET p_message = CONCAT('ERROR: Insufficient balance for transfer. Available to transfer: ₹', v_from_bal - v_min_bal);
        LEAVE sp_transfer;
    END IF;

    -- Atomic update
    START TRANSACTION;

    UPDATE accounts SET balance = v_from_new WHERE account_id = p_from_acc;
    UPDATE accounts SET balance = v_to_new   WHERE account_id = p_to_acc;

    INSERT INTO transactions (account_id, txn_type, amount, balance_after, reference_id, description)
    VALUES (p_from_acc, 'Transfer-Out', p_amount, v_from_new, p_to_acc,
            CONCAT(IFNULL(p_description,'Transfer'), ' → Acc#', p_to_acc));

    INSERT INTO transactions (account_id, txn_type, amount, balance_after, reference_id, description)
    VALUES (p_to_acc, 'Transfer-In', p_amount, v_to_new, p_from_acc,
            CONCAT(IFNULL(p_description,'Transfer'), ' ← Acc#', p_from_acc));

    COMMIT;

    SET p_message = CONCAT('SUCCESS: Transferred ₹', p_amount,
                           ' from Acc#', p_from_acc, ' to Acc#', p_to_acc);
END$$


-- ╔══════════════════════════════════════════════════════════╗
-- ║  STORED PROCEDURE: sp_open_account                      ║
-- ║  Opens a new account. Initial deposit must meet minimum.║
-- ╚══════════════════════════════════════════════════════════╝
CREATE PROCEDURE sp_open_account (
    IN  p_customer_id   INT,
    IN  p_branch_id     INT,
    IN  p_account_type  VARCHAR(20),
    IN  p_initial_dep   DECIMAL(15,2),
    OUT p_account_id    INT,
    OUT p_message       VARCHAR(255)
)
BEGIN
    DECLARE v_min_dep DECIMAL(15,2);

    SET v_min_dep = IF(p_account_type = 'Savings', 500.00, 1000.00);

    IF p_initial_dep < v_min_dep THEN
        SET p_message = CONCAT('ERROR: Minimum initial deposit for ', p_account_type, ' is ₹', v_min_dep);
        SET p_account_id = 0;
        LEAVE sp_open_account;
    END IF;

    INSERT INTO accounts (customer_id, branch_id, account_type, balance)
    VALUES (p_customer_id, p_branch_id, p_account_type, p_initial_dep);

    SET p_account_id = LAST_INSERT_ID();

    INSERT INTO transactions (account_id, txn_type, amount, balance_after, description)
    VALUES (p_account_id, 'Deposit', p_initial_dep, p_initial_dep, 'Account Opening Deposit');

    SET p_message = CONCAT('SUCCESS: Account #', p_account_id, ' opened with balance ₹', p_initial_dep);
END$$


-- ╔══════════════════════════════════════════════════════════╗
-- ║  TRIGGER: trg_prevent_direct_balance_below_min          ║
-- ║  Secondary guard — fires on any direct UPDATE to        ║
-- ║  accounts.balance (bypassing stored procedures).        ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE TRIGGER trg_block_underbalance
BEFORE UPDATE ON accounts
FOR EACH ROW
BEGIN
    DECLARE v_min DECIMAL(15,2);
    SET v_min = IF(NEW.account_type = 'Savings', 500.00, 1000.00);
    IF NEW.balance < v_min AND NEW.status = 'Active' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Balance cannot go below minimum required balance.';
    END IF;
END$$


-- ╔══════════════════════════════════════════════════════════╗
-- ║  TRIGGER: trg_set_loan_emi                              ║
-- ║  Auto-calculates EMI before inserting a loan.           ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE TRIGGER trg_set_loan_emi
BEFORE INSERT ON loans
FOR EACH ROW
BEGIN
    DECLARE v_monthly_rate DECIMAL(15,8);
    DECLARE v_emi          DECIMAL(15,2);
    -- EMI = P × r(1+r)^n / ((1+r)^n − 1)
    SET v_monthly_rate = NEW.interest_rate / 12 / 100;
    IF v_monthly_rate = 0 THEN
        SET v_emi = NEW.principal / NEW.duration_months;
    ELSE
        SET v_emi = NEW.principal * v_monthly_rate * POW(1 + v_monthly_rate, NEW.duration_months)
                    / (POW(1 + v_monthly_rate, NEW.duration_months) - 1);
    END IF;
    SET NEW.emi = ROUND(v_emi, 2);
END$$


-- ╔══════════════════════════════════════════════════════════╗
-- ║  TRIGGER: trg_update_last_login                         ║
-- ║  Updates last_login on admin record when password_hash  ║
-- ║  column is "touched" (simulate login stamp).            ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE TRIGGER trg_admin_last_login
BEFORE UPDATE ON admin_login
FOR EACH ROW
BEGIN
    SET NEW.last_login = CURRENT_TIMESTAMP;
END$$

DELIMITER ;

-- ╔══════════════════════════════════════════════════════════╗
-- ║  VIEWS                                                  ║
-- ╚══════════════════════════════════════════════════════════╝

-- Full account summary joining customer + branch
CREATE OR REPLACE VIEW vw_account_summary AS
SELECT
    a.account_id,
    c.customer_id,
    c.full_name          AS customer_name,
    c.phone              AS customer_phone,
    a.account_type,
    a.balance,
    a.status,
    b.branch_name,
    b.branch_code,
    b.city,
    a.opened_date
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
JOIN branches  b ON b.branch_id   = a.branch_id;

-- Transaction history with account and customer info
CREATE OR REPLACE VIEW vw_transaction_history AS
SELECT
    t.txn_id,
    t.account_id,
    c.full_name          AS customer_name,
    t.txn_type,
    t.amount,
    t.balance_after,
    t.reference_id,
    t.description,
    t.txn_date
FROM transactions t
JOIN accounts  a ON a.account_id   = t.account_id
JOIN customers c ON c.customer_id  = a.customer_id;

-- Active loans with customer name
CREATE OR REPLACE VIEW vw_loan_summary AS
SELECT
    l.loan_id,
    c.full_name          AS customer_name,
    c.phone              AS customer_phone,
    l.loan_type,
    l.principal,
    l.interest_rate,
    l.duration_months,
    l.emi,
    ROUND(l.emi * l.duration_months, 2) AS total_repayment,
    ROUND((l.emi * l.duration_months) - l.principal, 2) AS total_interest,
    l.status,
    l.start_date
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id;

-- Employee list with branch name
CREATE OR REPLACE VIEW vw_employee_list AS
SELECT
    e.employee_id,
    e.full_name          AS employee_name,
    e.email,
    e.phone,
    e.role,
    e.salary,
    e.joined_date,
    b.branch_name,
    b.branch_code,
    b.city
FROM employees e
JOIN branches b ON b.branch_id = e.branch_id;
