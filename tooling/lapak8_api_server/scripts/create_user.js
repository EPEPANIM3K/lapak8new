'use strict';

const mysql = require('mysql2/promise');
const { randomUUID } = require('node:crypto');
const { hashPassword } = require('../server');

async function main() {
  const identifier = process.env.USER_IDENTIFIER?.trim();
  const name = process.env.USER_NAME?.trim();
  const role = process.env.USER_ROLE?.trim();
  const password = process.env.USER_PASSWORD;
  const missing = [
    ['USER_IDENTIFIER', identifier],
    ['USER_NAME', name],
    ['USER_ROLE', role],
    ['USER_PASSWORD', password],
    ['MYSQL_HOST', process.env.MYSQL_HOST],
    ['MYSQL_USER', process.env.MYSQL_USER],
    ['MYSQL_DATABASE', process.env.MYSQL_DATABASE],
    ['MYSQL_PASSWORD', process.env.MYSQL_PASSWORD],
  ]
    .filter(([, value]) => value === undefined || value === '')
    .map(([key]) => key);
  if (missing.length) {
    throw new Error(`Variabel wajib belum diatur: ${missing.join(', ')}`);
  }
  if (!['student', 'teacher', 'admin', 'sarpras'].includes(role)) {
    throw new Error('USER_ROLE harus student, teacher, admin, atau sarpras.');
  }
  if (password.length < 10 || password.length > 256) {
    throw new Error('USER_PASSWORD harus memiliki 10 sampai 256 karakter.');
  }

  const connection = await mysql.createConnection({
    host: process.env.MYSQL_HOST,
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    timezone: 'Z',
  });
  try {
    await connection.execute(
      `INSERT INTO users (id, identifier, password_hash, full_name, role)
       VALUES (?, ?, ?, ?, ?)`,
      [randomUUID(), identifier, hashPassword(password), name, role],
    );
    console.log(`Akun ${role} berhasil dibuat untuk ${identifier}.`);
  } finally {
    await connection.end();
  }
}

main().catch((error) => {
  console.error(`[lapak8-api] gagal membuat akun: ${error.message}`);
  process.exitCode = 1;
});
