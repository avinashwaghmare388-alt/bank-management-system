// server.js  — Bank Management System Backend
require('dotenv').config();
const express    = require('express');
const cors       = require('cors');
const path       = require('path');
const bcrypt     = require('bcryptjs');
const db         = require('./db');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
// Serve frontend static files
app.use(express.static(path.join(__dirname, '..', 'frontend')));

// ─── helper ──────────────────────────────────────────────────
const q = (sql, params=[]) =>
    new Promise((resolve, reject) => {
        db.query(sql, params, (err, rows) => err ? reject(err) : resolve(rows));
    });

// ════════════════════════════════════════════════════════════
//  AUTH
// ════════════════════════════════════════════════════════════
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        if (!username || !password)
            return res.status(400).json({ ok: false, message: 'Username and password required.' });

        const rows = await q('SELECT * FROM admin_login WHERE username = ?', [username]);
        if (!rows.length)
            return res.status(401).json({ ok: false, message: 'Invalid credentials.' });

        const admin = rows[0];
        const match = await bcrypt.compare(password, admin.password_hash);
        if (!match)
            return res.status(401).json({ ok: false, message: 'Invalid credentials.' });

        // Touch last_login (trigger fires)
        await q('UPDATE admin_login SET password_hash = password_hash WHERE admin_id = ?', [admin.admin_id]);

        res.json({ ok: true, admin: { id: admin.admin_id, username: admin.username, name: admin.full_name } });
    } catch (e) {
        res.status(500).json({ ok: false, message: e.message });
    }
});

// ════════════════════════════════════════════════════════════
//  DASHBOARD STATS
// ════════════════════════════════════════════════════════════
app.get('/api/stats', async (req, res) => {
    try {
        const [[customers]] = [await q('SELECT COUNT(*) AS cnt FROM customers')];
        const [[accounts]]  = [await q('SELECT COUNT(*) AS cnt FROM accounts WHERE status="Active"')];
        const [[balance]]   = [await q('SELECT COALESCE(SUM(balance),0) AS total FROM accounts WHERE status="Active"')];
        const [[loans]]     = [await q('SELECT COUNT(*) AS cnt FROM loans WHERE status="Active"')];
        const [[txns]]      = [await q('SELECT COUNT(*) AS cnt FROM transactions WHERE DATE(txn_date)=CURDATE()')];
        const recent        = await q('SELECT * FROM vw_transaction_history ORDER BY txn_date DESC LIMIT 8');
        res.json({ ok: true, data: {
            customers: customers.cnt, accounts: accounts.cnt,
            total_balance: balance.total, active_loans: loans.cnt,
            todays_txns: txns.cnt, recent
        }});
    } catch (e) { res.status(500).json({ ok: false, message: e.message }); }
});

// ════════════════════════════════════════════════════════════
//  BRANCHES
// ════════════════════════════════════════════════════════════
app.get('/api/branches', async (req, res) => {
    try {
        const rows = await q('SELECT * FROM branches ORDER BY branch_name');
        res.json({ ok: true, data: rows });
    } catch (e) { res.status(500).json({ ok: false, message: e.message }); }
});

// ════════════════════════════════════════════════════════════
//  CUSTOMERS
// ════════════════════════════════════════════════════════════
app.get('/api/customers', async (req, res) => {
    try {
        const { search } = req.query;
        let sql = 'SELECT * FROM customers';
        const params = [];
        if (search) {
            sql += ' WHERE full_name LIKE ? OR email LIKE ? OR phone LIKE ?';
            const s = `%${search}%`;
            params.push(s, s, s);
        }
        sql += ' ORDER BY full_name';
        const rows = await q(sql, params);
        res.json({ ok: true, data: rows });
    } catch (e) { res.status(500).json({ ok: false, message: e.message }); }
});

app.post('/api/customers', async (req, res) => {
    try {
        const { full_name, email, phone, address, dob, gender } = req.body;
        if (!full_name || !email || !phone || !address || !dob || !gender)
            return res.status(400).json({ ok: false, message: 'All fields are required.' });

        const r = await q(
            'INSERT INTO customers (full_name,email,phone,address,dob,gender) VALUES (?,?,?,?,?,?)',
            [full_name, email, phone, address, dob, gender]
        );
        res.json({ ok: true, message: 'Customer added.', customer_id: r.insertId });
    } catch (e) {
        const msg = e.code === 'ER_DUP_ENTRY'
            ? 'Email or phone already registered.'
            : e.message;
        res.status(400).json({ ok: false, message: msg });
    }
});

app.put('/api/customers/:id', async (req, res) => {
    try {
        const { full_name, email, phone, address } = req.body;
        await q(
            'UPDATE customers SET full_name=?,email=?,phone=?,address=? WHERE customer_id=?',
            [full_name, email, phone, address, req.params.id]
        );
        res.json({ ok: true, message: 'Customer updated.' });
    } catch (e) { res.status(400).json({ ok: false, message: e.message }); }
});

// ════════════════════════════════════════════════════════════
//  ACCOUNTS
// ════════════════════════════════════════════════════════════
app.get('/api/accounts', async (req, res) => {
    try {
        const { customer_id, search } = req.query;
        let sql = 'SELECT * FROM vw_account_summary';
        const params = [];
        const where = [];
        if (customer_id) { where.push('customer_id = ?'); params.push(customer_id); }
        if (search) {
            where.push('(customer_name LIKE ? OR account_id = ?)');
            params.push(`%${search}%`, parseInt(search) || 0);
        }
        if (where.length) sql += ' WHERE ' + where.join(' AND ');
        sql += ' ORDER BY account_id DESC';
        const rows = await q(sql, params);
        res.json({ ok: true, data: rows });
    } catch (e) { res.status(500).json({ ok: false, message: e.message }); }
});

app.post('/api/accounts', async (req, res) => {
    try {
        const { customer_id, branch_id, account_type, initial_deposit } = req.body;
        if (!customer_id || !branch_id || !account_type || !initial_deposit)
            return res.status(400).json({ ok: false, message: 'All fields are required.' });

        await q('CALL sp_open_account(?,?,?,?,@acc_id,@msg)', [customer_id, branch_id, account_type, initial_deposit]);
        const [[result]] = [await q('SELECT @acc_id AS acc_id, @msg AS msg')];

        if (result.msg.startsWith('ERROR'))
            return res.status(400).json({ ok: false, message: result.msg });

        res.json({ ok: true, message: result.msg, account_id: result.acc_id });
    } catch (e) { res.status(400).json({ ok: false, message: e.message }); }
});

app.get('/api/accounts/:id', async (req, res) => {
    try {
        const rows = await q('SELECT * FROM vw_account_summary WHERE account_id = ?', [req.params.id]);
        if (!rows.length) return res.status(404).json({ ok: false, message: 'Account not found.' });
        res.json({ ok: true, data: rows[0] });
    } catch (e) { res.status(500).json({ ok: false, message: e.message }); }
});

// ════════════════════════════════════════════════════════════
//  TRANSACTIONS
// ════════════════════════════════════════════════════════════
app.get('/api/transactions', async (req, res) => {
    try {
        const { account_id, limit = 50 } = req.query;
        let sql = 'SELECT * FROM vw_transaction_history';
        const params = [];
        if (account_id) { sql += ' WHERE account_id = ?'; params.push(account_id); }
        sql += ' ORDER BY txn_date DESC LIMIT ?';
        params.push(parseInt(limit));
        const rows = await q(sql, params);
        res.json({ ok: true, data: rows });
    } catch (e) { res.status(500).json({ ok: false, message: e.message }); }
});

app.post('/api/transactions/deposit', async (req, res) => {
    try {
        const { account_id, amount, description } = req.body;
        await q('CALL sp_deposit(?,?,?,@msg)', [account_id, amount, description || '']);
        const [[result]] = [await q('SELECT @msg AS msg')];
        if (result.msg.startsWith('ERROR'))
            return res.status(400).json({ ok: false, message: result.msg });
        res.json({ ok: true, message: result.msg });
    } catch (e) { res.status(400).json({ ok: false, message: e.message }); }
});

app.post('/api/transactions/withdraw', async (req, res) => {
    try {
        const { account_id, amount, description } = req.body;
        await q('CALL sp_withdraw(?,?,?,@msg)', [account_id, amount, description || '']);
        const [[result]] = [await q('SELECT @msg AS msg')];
        if (result.msg.startsWith('ERROR'))
            return res.status(400).json({ ok: false, message: result.msg });
        res.json({ ok: true, message: result.msg });
    } catch (e) { res.status(400).json({ ok: false, message: e.message }); }
});

app.post('/api/transactions/transfer', async (req, res) => {
    try {
        const { from_account, to_account, amount, description } = req.body;
        await q('CALL sp_transfer(?,?,?,?,@msg)', [from_account, to_account, amount, description || '']);
        const [[result]] = [await q('SELECT @msg AS msg')];
        if (result.msg.startsWith('ERROR'))
            return res.status(400).json({ ok: false, message: result.msg });
        res.json({ ok: true, message: result.msg });
    } catch (e) { res.status(400).json({ ok: false, message: e.message }); }
});

// ════════════════════════════════════════════════════════════
//  LOANS
// ════════════════════════════════════════════════════════════
app.get('/api/loans', async (req, res) => {
    try {
        const rows = await q('SELECT * FROM vw_loan_summary ORDER BY loan_id DESC');
        res.json({ ok: true, data: rows });
    } catch (e) { res.status(500).json({ ok: false, message: e.message }); }
});

app.post('/api/loans', async (req, res) => {
    try {
        const { customer_id, loan_type, principal, interest_rate, duration_months, start_date } = req.body;
        if (!customer_id || !loan_type || !principal || !interest_rate || !duration_months)
            return res.status(400).json({ ok: false, message: 'All loan fields are required.' });

        // emi=0 here — trigger auto-calculates it
        await q(
            'INSERT INTO loans (customer_id,loan_type,principal,interest_rate,duration_months,emi,start_date) VALUES (?,?,?,?,?,0,?)',
            [customer_id, loan_type, principal, interest_rate, duration_months, start_date || new Date().toISOString().split('T')[0]]
        );
        const [[loan]] = [await q('SELECT * FROM vw_loan_summary WHERE loan_id = LAST_INSERT_ID()')];
        res.json({ ok: true, message: `Loan created. Monthly EMI: ₹${loan.emi}`, loan });
    } catch (e) { res.status(400).json({ ok: false, message: e.message }); }
});

app.put('/api/loans/:id/status', async (req, res) => {
    try {
        const { status } = req.body;
        await q('UPDATE loans SET status=? WHERE loan_id=?', [status, req.params.id]);
        res.json({ ok: true, message: 'Loan status updated.' });
    } catch (e) { res.status(400).json({ ok: false, message: e.message }); }
});

// ════════════════════════════════════════════════════════════
//  EMPLOYEES
// ════════════════════════════════════════════════════════════
app.get('/api/employees', async (req, res) => {
    try {
        const rows = await q('SELECT * FROM vw_employee_list ORDER BY employee_name');
        res.json({ ok: true, data: rows });
    } catch (e) { res.status(500).json({ ok: false, message: e.message }); }
});

// ════════════════════════════════════════════════════════════
//  CATCH-ALL → index.html
// ════════════════════════════════════════════════════════════
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '..', 'frontend', 'index.html'));
});

app.listen(PORT, () => {
    console.log(`\n  Bank Management System running at http://localhost:${PORT}\n`);
});
