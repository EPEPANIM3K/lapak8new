'use strict';

const crypto = require('node:crypto');
const http = require('node:http');
const mysql = require('mysql2/promise');

const PORT = Number(process.env.PORT || 8788);
const JWT_SECRET = process.env.JWT_SECRET || '';
const TOKEN_TTL_SECONDS = 12 * 60 * 60;
const MAX_BODY_BYTES = 16 * 1024;
const RESERVING_STATUSES = ['approved', 'borrowed'];
const ALLOWED_ROLES = new Set(['student', 'teacher', 'admin', 'sarpras']);

class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function createPool() {
  const required = ['MYSQL_HOST', 'MYSQL_USER', 'MYSQL_DATABASE', 'MYSQL_PASSWORD'];
  const missing = required.filter((key) => process.env[key] === undefined);
  if (missing.length) {
    throw new Error(`Variabel database belum diatur: ${missing.join(', ')}`);
  }
  if (JWT_SECRET.length < 32) {
    throw new Error('JWT_SECRET harus memiliki minimal 32 karakter.');
  }
  return mysql.createPool({
    host: process.env.MYSQL_HOST,
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    connectionLimit: 10,
    timezone: 'Z',
    supportBigNumbers: true,
    dateStrings: false,
  });
}

function publicUser(user) {
  return {
    id: user.id,
    identifier: user.identifier,
    name: user.full_name,
    role: user.role,
    classroom: user.classroom,
  };
}

function createToken(user, secret = JWT_SECRET, now = Math.floor(Date.now() / 1000)) {
  const header = encodeBase64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = encodeBase64Url(
    JSON.stringify({
      sub: user.id,
      role: user.role,
      iat: now,
      exp: now + TOKEN_TTL_SECONDS,
    }),
  );
  const unsigned = `${header}.${payload}`;
  const signature = crypto
    .createHmac('sha256', secret)
    .update(unsigned)
    .digest('base64url');
  return `${unsigned}.${signature}`;
}

function verifyToken(token, secret = JWT_SECRET, now = Math.floor(Date.now() / 1000)) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) throw unauthorized();
  const unsigned = `${parts[0]}.${parts[1]}`;
  const expected = crypto
    .createHmac('sha256', secret)
    .update(unsigned)
    .digest();
  let actual;
  try {
    actual = Buffer.from(parts[2], 'base64url');
  } catch {
    throw unauthorized();
  }
  if (actual.length !== expected.length || !crypto.timingSafeEqual(actual, expected)) {
    throw unauthorized();
  }
  let payload;
  try {
    payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    throw unauthorized();
  }
  if (
    typeof payload.sub !== 'string' ||
    !ALLOWED_ROLES.has(payload.role) ||
    !Number.isInteger(payload.exp) ||
    payload.exp <= now
  ) {
    throw unauthorized();
  }
  return { id: payload.sub, role: payload.role };
}

function encodeBase64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const derived = crypto.scryptSync(password, salt, 64);
  return `scrypt$${salt.toString('base64url')}$${derived.toString('base64url')}`;
}

function verifyPassword(password, storedHash) {
  const [scheme, saltText, hashText] = String(storedHash || '').split('$');
  if (scheme !== 'scrypt' || !saltText || !hashText) return false;
  try {
    const salt = Buffer.from(saltText, 'base64url');
    const expected = Buffer.from(hashText, 'base64url');
    const actual = crypto.scryptSync(password, salt, expected.length);
    return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
  } catch {
    return false;
  }
}

function routeOf(method, path) {
  const parts = path.split('?')[0].split('/').filter(Boolean);
  if (parts.some((part) => part.includes('\\'))) return null;
  if (method === 'GET' && parts.length === 1 && parts[0] === 'health') {
    return { name: 'health' };
  }
  if (parts[0] !== 'api' || parts[1] !== 'v1') return null;
  if (parts[2] === 'auth' && parts.length === 4 && parts[3] === 'login' && method === 'POST') {
    return { name: 'login' };
  }
  if (parts[2] === 'auth' && parts.length === 4 && parts[3] === 'me' && method === 'GET') {
    return { name: 'me' };
  }
  if (parts[2] === 'facilities' && parts.length === 3 && method === 'GET') {
    return { name: 'facilities' };
  }
  if (
    parts[2] === 'facilities' &&
    parts.length === 5 &&
    parts[4] === 'availability' &&
    method === 'GET'
  ) {
    return { name: 'availability', facilityId: parts[3] };
  }
  if (parts[2] === 'borrowings' && parts.length === 3 && method === 'GET') {
    return { name: 'listBorrowings' };
  }
  if (parts[2] === 'borrowings' && parts.length === 3 && method === 'POST') {
    return { name: 'createBorrowing' };
  }
  if (
    parts[2] === 'borrowings' &&
    parts.length === 5 &&
    parts[4] === 'status' &&
    method === 'PATCH'
  ) {
    return { name: 'updateBorrowingStatus', borrowingId: parts[3] };
  }
  if (
    parts[2] === 'borrowings' &&
    parts.length === 5 &&
    parts[4] === 'cancel' &&
    method === 'POST'
  ) {
    return { name: 'cancelBorrowing', borrowingId: parts[3] };
  }
  if (
    parts[2] === 'admin' &&
    parts[3] === 'users' &&
    parts.length === 4 &&
    method === 'POST'
  ) {
    return { name: 'createUser' };
  }
  return null;
}

function unauthorized() {
  return new ApiError(401, 'unauthorized', 'Sesi tidak valid atau sudah berakhir.');
}

function authenticate(req, secret) {
  const match = /^Bearer\s+(.+)$/i.exec(req.headers.authorization || '');
  if (!match) throw unauthorized();
  return verifyToken(match[1].trim(), secret);
}

function requireRole(user, roles) {
  if (!roles.includes(user.role)) {
    throw new ApiError(403, 'forbidden', 'Akun ini tidak memiliki izin untuk tindakan tersebut.');
  }
}

async function readJson(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) {
      throw new ApiError(413, 'payload_too_large', 'Ukuran permintaan terlalu besar.');
    }
    chunks.push(chunk);
  }
  try {
    const value = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error('JSON harus berupa object.');
    }
    return value;
  } catch {
    throw new ApiError(400, 'invalid_json', 'Format JSON tidak valid.');
  }
}

function sendJson(res, status, body) {
  const data = Buffer.from(JSON.stringify(body));
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': data.length,
    'cache-control': 'no-store',
  });
  res.end(data);
}

function sendError(res, error) {
  const status = error instanceof ApiError ? error.status : 500;
  const code = error instanceof ApiError ? error.code : 'internal_error';
  if (status >= 500) console.error('[lapak8-api]', error);
  sendJson(res, status, {
    ok: false,
    error: {
      code,
      message: error instanceof ApiError ? error.message : 'Terjadi kesalahan pada server.',
    },
  });
}

function parseDate(value, field) {
  if (typeof value !== 'string' || value.length > 40) {
    throw new ApiError(400, `invalid_${field}`, `${field} tidak valid.`);
  }
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new ApiError(400, `invalid_${field}`, `${field} tidak valid.`);
  }
  return date;
}

function toMysqlDate(date) {
  return date.toISOString().slice(0, 23).replace('T', ' ');
}

async function availableQuantity(connection, facilityId, startAt, endAt, excludeId) {
  const excludeQuery = excludeId ? 'AND b.id <> ?' : '';
  const params = [
    RESERVING_STATUSES[0],
    RESERVING_STATUSES[1],
    toMysqlDate(endAt),
    toMysqlDate(startAt),
  ];
  if (excludeId) params.push(excludeId);
  params.push(facilityId);
  const [rows] = await connection.execute(
    `SELECT f.stock - COALESCE(SUM(b.quantity), 0) AS available
       FROM facilities f
       LEFT JOIN borrowings b
         ON b.facility_id = f.id
        AND b.status IN (?, ?)
        AND b.start_at < ?
        AND b.end_at > ?
        ${excludeQuery}
      WHERE f.id = ? AND f.is_active = TRUE
      GROUP BY f.id, f.stock`,
    params,
  );
  return rows.length ? Number(rows[0].available) : null;
}

function borrowingDto(row) {
  return {
    id: row.id,
    code: row.code,
    userId: row.user_id,
    userName: row.user_name,
    userIdentifier: row.user_identifier,
    facilityId: row.facility_id,
    facilityName: row.facility_name,
    location: row.location,
    category: row.category,
    eventName: row.event_name,
    quantity: Number(row.quantity),
    startAt: new Date(row.start_at).toISOString(),
    endAt: new Date(row.end_at).toISOString(),
    status: row.status,
    decisionNote: row.decision_note,
    createdAt: new Date(row.created_at).toISOString(),
  };
}

const BORROWING_SELECT = `
  SELECT b.*, u.full_name AS user_name, u.identifier AS user_identifier,
         f.name AS facility_name, f.location
    FROM borrowings b
    JOIN users u ON u.id = b.user_id
    JOIN facilities f ON f.id = b.facility_id`;

function createHandler({ pool, secret = JWT_SECRET }) {
  return async function handle(req, res) {
    res.setHeader('access-control-allow-origin', process.env.LAPAK8_CORS_ORIGIN || '*');
    res.setHeader('access-control-allow-headers', 'authorization,content-type');
    res.setHeader('access-control-allow-methods', 'GET,POST,PATCH,OPTIONS');
    res.setHeader('access-control-expose-headers', 'content-length');
    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }
    try {
      const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
      const route = routeOf(req.method, req.url);
      if (!route) throw new ApiError(404, 'not_found', 'Endpoint tidak ditemukan.');
      if (route.name === 'health') {
        await pool.query('SELECT 1');
        sendJson(res, 200, { ok: true, service: 'lapak8-api', database: 'connected' });
        return;
      }
      if (route.name === 'login') {
        const body = await readJson(req);
        const identifier = typeof body.identifier === 'string' ? body.identifier.trim() : '';
        const password = typeof body.password === 'string' ? body.password : '';
        if (!identifier || !password || identifier.length > 120 || password.length > 256) {
          throw new ApiError(400, 'invalid_credentials', 'Identifier dan kata sandi wajib diisi.');
        }
        const [rows] = await pool.execute(
          `SELECT id, identifier, password_hash, full_name, role, classroom
             FROM users WHERE identifier = ? AND is_active = TRUE LIMIT 1`,
          [identifier],
        );
        const user = rows[0];
        if (!user || !verifyPassword(password, user.password_hash)) {
          throw new ApiError(401, 'invalid_credentials', 'Nomor induk/email atau kata sandi salah.');
        }
        sendJson(res, 200, {
          ok: true,
          data: { token: createToken(user, secret), user: publicUser(user) },
        });
        return;
      }

      const claims = authenticate(req, secret);
      const [accounts] = await pool.execute(
        'SELECT id, identifier, full_name, role, classroom FROM users WHERE id = ? AND is_active = TRUE LIMIT 1',
        [claims.id],
      );
      if (!accounts[0]) throw unauthorized();
      const principal = {
        id: accounts[0].id,
        role: accounts[0].role,
      };
      if (route.name === 'me') {
        sendJson(res, 200, { ok: true, data: { user: publicUser(accounts[0]) } });
        return;
      }
      if (route.name === 'facilities') {
        const [rows] = await pool.execute(
          `SELECT id, name, location, stock
             FROM facilities WHERE is_active = TRUE ORDER BY name`,
        );
        sendJson(res, 200, {
          ok: true,
          data: rows.map((row) => ({ ...row, stock: Number(row.stock) })),
        });
        return;
      }
      if (route.name === 'availability') {
        const facilityId = route.facilityId;
        const startAt = parseDate(url.searchParams.get('startAt'), 'startAt');
        const endAt = parseDate(url.searchParams.get('endAt'), 'endAt');
        if (endAt <= startAt || startAt < new Date()) {
          throw new ApiError(400, 'invalid_schedule', 'Waktu peminjaman harus berada di masa depan.');
        }
        const available = await availableQuantity(
          pool,
          facilityId,
          startAt,
          endAt,
          null,
        );
        if (available === null) throw new ApiError(404, 'facility_not_found', 'Fasilitas tidak ditemukan.');
        sendJson(res, 200, { ok: true, data: { facilityId, available } });
        return;
      }
      if (route.name === 'listBorrowings') {
        const isAdmin = ['admin', 'sarpras'].includes(principal.role);
        const [rows] = isAdmin
          ? await pool.execute(
              `${BORROWING_SELECT} ORDER BY b.created_at DESC LIMIT 200`,
            )
          : await pool.execute(
              `${BORROWING_SELECT} WHERE b.user_id = ? ORDER BY b.created_at DESC LIMIT 200`,
              [principal.id],
            );
        sendJson(res, 200, { ok: true, data: rows.map(borrowingDto) });
        return;
      }
      if (route.name === 'createBorrowing') {
        requireRole(principal, ['student', 'teacher']);
        const body = await readJson(req);
        const facilityId = typeof body.facilityId === 'string' ? body.facilityId : '';
        const category = body.category;
        const eventName = typeof body.eventName === 'string' ? body.eventName.trim() : '';
        const quantity = Number(body.quantity);
        const startAt = parseDate(body.startAt, 'startAt');
        const endAt = parseDate(body.endAt, 'endAt');
        if (!facilityId || facilityId.length > 36) {
          throw new ApiError(400, 'invalid_facility', 'Fasilitas tidak valid.');
        }
        if (!['praktik', 'ekskul', 'lainnya'].includes(category)) {
          throw new ApiError(400, 'invalid_category', 'Kategori peminjaman tidak valid.');
        }
        if (!eventName || eventName.length > 160) {
          throw new ApiError(400, 'invalid_event_name', 'Nama kegiatan wajib diisi (maksimal 160 karakter).');
        }
        if (!Number.isSafeInteger(quantity) || quantity < 1) {
          throw new ApiError(400, 'invalid_quantity', 'Jumlah harus berupa bilangan positif.');
        }
        if (startAt < new Date() || endAt <= startAt) {
          throw new ApiError(400, 'invalid_schedule', 'Jadwal harus valid dan berada di masa depan.');
        }

        const connection = await pool.getConnection();
        let id;
        try {
          await connection.beginTransaction();
          const [facilities] = await connection.execute(
            'SELECT id, stock FROM facilities WHERE id = ? AND is_active = TRUE FOR UPDATE',
            [facilityId],
          );
          if (!facilities[0]) throw new ApiError(404, 'facility_not_found', 'Fasilitas tidak ditemukan.');
          if (quantity > Number(facilities[0].stock)) {
            throw new ApiError(409, 'quantity_exceeded', 'Jumlah melebihi stok fasilitas.');
          }
          const available = await availableQuantity(
            connection,
            facilityId,
            startAt,
            endAt,
            null,
          );
          if (available === null) {
            throw new ApiError(404, 'facility_not_found', 'Fasilitas tidak ditemukan.');
          }
          if (quantity > available) {
            throw new ApiError(409, 'schedule_conflict', 'Stok pada jadwal tersebut sudah tidak mencukupi.');
          }
          id = crypto.randomUUID();
          const code = `BK-${new Date().toISOString().slice(0, 10).replaceAll('-', '')}-${id.slice(0, 6).toUpperCase()}`;
          await connection.execute(
            `INSERT INTO borrowings
              (id, code, user_id, facility_id, category, event_name, quantity, start_at, end_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
              id,
              code,
              principal.id,
              facilityId,
              category,
              eventName,
              quantity,
              toMysqlDate(startAt),
              toMysqlDate(endAt),
            ],
          );
          await connection.commit();
        } catch (error) {
          await connection.rollback();
          throw error;
        } finally {
          connection.release();
        }
        const [rows] = await pool.execute(`${BORROWING_SELECT} WHERE b.id = ?`, [id]);
        sendJson(res, 201, { ok: true, data: borrowingDto(rows[0]) });
        return;
      }
      if (route.name === 'cancelBorrowing') {
        const [result] = await pool.execute(
          `UPDATE borrowings SET status = 'cancelled'
            WHERE id = ? AND user_id = ? AND status = 'pending'`,
          [route.borrowingId, principal.id],
        );
        if (result.affectedRows !== 1) {
          throw new ApiError(409, 'cannot_cancel', 'Hanya pengajuan yang masih menunggu yang dapat dibatalkan.');
        }
        sendJson(res, 200, { ok: true, data: { id: route.borrowingId, status: 'cancelled' } });
        return;
      }
      if (route.name === 'updateBorrowingStatus') {
        requireRole(principal, ['admin', 'sarpras']);
        const body = await readJson(req);
        const nextStatus = body.status;
        const allowed = {
          pending: ['approved', 'rejected'],
          approved: ['borrowed'],
          borrowed: ['returned'],
        };
        const connection = await pool.getConnection();
        let updated;
        try {
          await connection.beginTransaction();
          const [rows] = await connection.execute(
            'SELECT * FROM borrowings WHERE id = ? FOR UPDATE',
            [route.borrowingId],
          );
          const borrowing = rows[0];
          if (!borrowing) throw new ApiError(404, 'borrowing_not_found', 'Peminjaman tidak ditemukan.');
          if (!allowed[borrowing.status]?.includes(nextStatus)) {
            throw new ApiError(409, 'invalid_transition', 'Perubahan status ini tidak diizinkan.');
          }
          if (nextStatus === 'approved') {
            await connection.execute(
              'SELECT id FROM facilities WHERE id = ? FOR UPDATE',
              [borrowing.facility_id],
            );
            const available = await availableQuantity(
              connection,
              borrowing.facility_id,
              new Date(borrowing.start_at),
              new Date(borrowing.end_at),
              borrowing.id,
            );
            if (available === null || available < Number(borrowing.quantity)) {
              throw new ApiError(409, 'schedule_conflict', 'Stok pada jadwal tersebut sudah tidak mencukupi.');
            }
          }
          const note = typeof body.note === 'string' ? body.note.trim().slice(0, 500) : null;
          await connection.execute(
            `UPDATE borrowings
                SET status = ?, decision_note = ?,
                    decided_by = ?, decided_at = CURRENT_TIMESTAMP(3),
                    checked_out_at = IF(? = 'borrowed', CURRENT_TIMESTAMP(3), checked_out_at),
                    returned_at = IF(? = 'returned', CURRENT_TIMESTAMP(3), returned_at)
              WHERE id = ?`,
            [
              nextStatus,
              note,
              principal.id,
              nextStatus,
              nextStatus,
              borrowing.id,
            ],
          );
          await connection.commit();
          updated = { id: borrowing.id, code: borrowing.code, status: nextStatus };
        } catch (error) {
          await connection.rollback();
          throw error;
        } finally {
          connection.release();
        }
        sendJson(res, 200, { ok: true, data: updated });
        return;
      }
      if (route.name === 'createUser') {
        requireRole(principal, ['admin']);
        const body = await readJson(req);
        const identifier = typeof body.identifier === 'string' ? body.identifier.trim() : '';
        const name = typeof body.name === 'string' ? body.name.trim() : '';
        const password = typeof body.password === 'string' ? body.password : '';
        const role = body.role;
        if (!identifier || identifier.length > 120 || !name || name.length > 160) {
          throw new ApiError(400, 'invalid_user', 'Identifier dan nama wajib diisi.');
        }
        if (!ALLOWED_ROLES.has(role) || password.length < 10 || password.length > 256) {
          throw new ApiError(400, 'invalid_user', 'Role atau kata sandi tidak valid (minimal 10 karakter).');
        }
        const id = crypto.randomUUID();
        try {
          await pool.execute(
            `INSERT INTO users (id, identifier, password_hash, full_name, role, classroom)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [
              id,
              identifier,
              hashPassword(password),
              name,
              role,
              typeof body.classroom === 'string' ? body.classroom.trim().slice(0, 80) : null,
            ],
          );
        } catch (error) {
          if (error.code === 'ER_DUP_ENTRY') {
            throw new ApiError(409, 'identifier_exists', 'Nomor induk/email sudah digunakan.');
          }
          throw error;
        }
        sendJson(res, 201, {
          ok: true,
          data: { id, identifier, name, role },
        });
        return;
      }
      throw new ApiError(404, 'not_found', 'Endpoint tidak ditemukan.');
    } catch (error) {
      if (res.headersSent) {
        res.destroy();
        return;
      }
      sendError(res, error);
    }
  };
}

async function start() {
  const pool = createPool();
  await pool.query('SELECT 1');
  const server = http.createServer(createHandler({ pool }));
  server.listen(PORT, process.env.HOST || '0.0.0.0', () => {
    console.log(`[lapak8-api] siap di http://${process.env.HOST || '0.0.0.0'}:${PORT}`);
  });
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => {
      server.close(async () => {
        await pool.end();
        process.exit(0);
      });
    });
  }
}

if (require.main === module) {
  start().catch((error) => {
    console.error('[lapak8-api] gagal start:', error.message);
    process.exitCode = 1;
  });
}

module.exports = {
  ApiError,
  createHandler,
  createToken,
  hashPassword,
  routeOf,
  verifyPassword,
  verifyToken,
};
