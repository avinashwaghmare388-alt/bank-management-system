// db.js — MySQL connection pool
require('dotenv').config();
const mysql = require('mysql2');

const pool = mysql.createPool({
    host:               process.env.DB_HOST     || 'localhost',
    port:               process.env.DB_PORT     || 3306,
    user:               process.env.DB_USER     || 'root',
    password:           process.env.DB_PASSWORD || '',
    database:           process.env.DB_NAME     || 'bank_db',
    waitForConnections: true,
    connectionLimit:    10,
    queueLimit:         0,
    multipleStatements: true,
});

pool.getConnection((err, conn) => {
    if (err) {
        console.error('  ✖  MySQL connection failed:', err.message);
        console.error('     Check your .env credentials and ensure MySQL is running.\n');
    } else {
        console.log('  ✔  MySQL connected to bank_db');
        conn.release();
    }
});

module.exports = pool;
