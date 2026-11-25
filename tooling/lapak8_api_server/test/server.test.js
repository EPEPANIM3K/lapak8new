'use strict';

const assert = require('node:assert/strict');
const http = require('node:http');
const { after, before, test } = require('node:test');
const {
  createHandler,
  createToken,
  hashPassword,
  routeOf,
  verifyPassword,
  verifyToken,
} = require('../server');

const SECRET = 'unit-test-secret-that-is-long-enough-123456';
const user = {
  id: 'user-test-1',
  identifier: '20250001',
  password_hash: hashPassword('correct-horse-battery'),
  full_name: 'Pengguna Tes',
  role: 'student',
  classroom: 'XI RPL',
};

let server;
let baseUrl;

const fakePool = {
  async query() {
    return [[{ ok: 1 }]];
  },
  async execute(sql, values) {
    if (sql.includes('FROM users WHERE identifier')) {
      return [values[0] === user.identifier ? [user] : []];
    }
    if (sql.includes('FROM users WHERE id')) {
      return [values[0] === user.id ? [user] : []];
    }
    if (sql.includes('FROM borrowings b')) return [[]];
    throw new Error(`Query tak terduga dalam pengujian: ${sql}`);
  },
};

before(async () => {
  server = http.createServer(createHandler({ pool: fakePool, secret: SECRET }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve, reject) =>
    server.close((error) => (error ? reject(error) : resolve())),
  );
});

test('password scrypt hanya cocok untuk kata sandi yang benar', () => {
  const hash = hashPassword('rahasia-aman-123');
  assert.notEqual(hash, 'rahasia-aman-123');
  assert.equal(verifyPassword('rahasia-aman-123', hash), true);
  assert.equal(verifyPassword('kata-sandi-salah', hash), false);
});

test('JWT valid diverifikasi dan token yang kedaluwarsa ditolak', () => {
  const token = createToken(user, SECRET, 1000);
  assert.deepEqual(verifyToken(token, SECRET, 1001), {
    id: user.id,
    role: user.role,
  });
  assert.throws(() => verifyToken(token, SECRET, 1000 + 12 * 60 * 60));
  assert.throws(() => verifyToken(`${token.slice(0, -1)}x`, SECRET, 1001));
});

test('router mengenali login, status peminjaman, dan pembatalan', () => {
  assert.deepEqual(routeOf('POST', '/api/v1/auth/login'), { name: 'login' });
  assert.deepEqual(routeOf('PATCH', '/api/v1/borrowings/loan-1/status'), {
    name: 'updateBorrowingStatus',
    borrowingId: 'loan-1',
  });
  assert.deepEqual(routeOf('POST', '/api/v1/borrowings/loan-1/cancel'), {
    name: 'cancelBorrowing',
    borrowingId: 'loan-1',
  });
});

test('login mengembalikan JWT tanpa membocorkan password hash', async () => {
  const response = await fetch(`${baseUrl}/api/v1/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      identifier: user.identifier,
      password: 'correct-horse-battery',
    }),
  });
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.data.user.id, user.id);
  assert.equal(body.data.user.role, 'student');
  assert.equal(typeof body.data.token, 'string');
  assert.equal(JSON.stringify(body).includes(user.password_hash), false);
});

test('endpoint daftar peminjaman menolak permintaan tanpa token', async () => {
  const response = await fetch(`${baseUrl}/api/v1/borrowings`);
  assert.equal(response.status, 401);
});

test('siswa tidak boleh mengubah status peminjaman', async () => {
  const response = await fetch(`${baseUrl}/api/v1/borrowings/loan-1/status`, {
    method: 'PATCH',
    headers: {
      authorization: `Bearer ${createToken(user, SECRET)}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ status: 'approved' }),
  });
  assert.equal(response.status, 403);
});

test('siswa tidak boleh membuat akun admin', async () => {
  const response = await fetch(`${baseUrl}/api/v1/admin/users`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${createToken(user, SECRET)}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({}),
  });
  assert.equal(response.status, 403);
});
