'use strict';

/**
 * LAPAK8 Storage Server
 * Object storage + metadata API untuk dokumentasi kondisi pengembalian barang.
 *
 * Stack : Node 18+ (core modules only, zero npm dependency)
 * Data  : <storageDir>/_manifest.json  (metadata dokumentasi)
 *         <storageDir>/<returnId>/<uuid>.<ext>  (file fisik)
 *
 * Jalankan:
 *   node server.js
 * Variabel lingkungan:
 *   PORT            (default 8787)
 *   HOST            (default 0.0.0.0)
 *   LAPAK8_STORAGE  (default ./storage)
 */

const http = require('node:http');
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

// ---------------------------------------------------------------------------
// Konfigurasi
// ---------------------------------------------------------------------------
const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '0.0.0.0';
const STORAGE_DIR = path.resolve(
  process.env.LAPAK8_STORAGE || path.join(__dirname, 'storage'),
);
const MANIFEST_PATH = path.join(STORAGE_DIR, '_manifest.json');
const TMP_DIR = path.join(STORAGE_DIR, '.tmp');

const MAX_PHOTOS = 6;
const MAX_VIDEOS = 1;
const MAX_PHOTO_BYTES = 8 * 1024 * 1024; // 8 MB / foto
const MAX_VIDEO_BYTES = 100 * 1024 * 1024; // 100 MB / video

// Ekstensi kanonik + tipe MIME yang diterima. Declared mime harus cocok.
const PHOTO_RULES = {
  jpg: ['image/jpeg'],
  jpeg: ['image/jpeg'],
  png: ['image/png'],
  webp: ['image/webp'],
};
const VIDEO_RULES = {
  mp4: ['video/mp4'],
  mov: ['video/quicktime'],
  webm: ['video/webm'],
};

// Header akses. Role admin/petugas boleh baca + tulis; peran lain read-only.
const ADMIN_ROLES = new Set(['admin', 'petugas', 'sarpras']);
const ALLOWED_ROLES = new Set(['admin', 'petugas', 'sarpras', 'siswa', 'guru', 'user']);

// ---------------------------------------------------------------------------
// Util HTTP
// ---------------------------------------------------------------------------
class HttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function sendJson(res, status, payload) {
  const body = Buffer.from(JSON.stringify(payload));
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': body.length,
    'cache-control': 'no-store',
  });
  res.end(body);
}

function sendError(res, err) {
  const status = err instanceof HttpError ? err.status : 500;
  const code = err instanceof HttpError ? err.code : 'internal_error';
  if (status >= 500) console.error('[lapak8-storage]', err);
  sendJson(res, status, { ok: false, error: { code, message: err.message } });
}

/** Identifier aman untuk segmen URL / nama folder: [A-Za-z0-9._-], 1..64 char. */
const ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
function safeId(value, field) {
  const v = String(value || '').trim();
  if (!ID_RE.test(v)) {
    throw new HttpError(
      400,
      'invalid_' + field,
      `${field} tidak valid (hanya huruf, angka, titik, strip, garis bawah).`,
    );
  }
  return v;
}

// ---------------------------------------------------------------------------
// Auth: token -> peran
//   LAPAK8_TOKENS = [{"token":"...","role":"admin","userId":"U-1"}]
//   fallback    : LAPAK8_ADMIN_TOKEN -> role admin
// ---------------------------------------------------------------------------
const tokenIndex = new Map();

function loadTokens() {
  const raw = process.env.LAPAK8_TOKENS;
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (!Array.isArray(parsed)) throw new Error('harus berupa array');
      for (const entry of parsed) {
        if (!entry || !entry.token) continue;
        const role = String(entry.role || 'user').toLowerCase();
        if (!ALLOWED_ROLES.has(role)) continue;
        tokenIndex.set(String(entry.token), {
          role,
          userId: entry.userId ? String(entry.userId) : null,
        });
      }
    } catch (e) {
      console.error('[lapak8-storage] LAPAK8_TOKENS tidak bisa dibaca:', e.message);
    }
  }
  if (tokenIndex.size === 0 && process.env.LAPAK8_ADMIN_TOKEN) {
    tokenIndex.set(String(process.env.LAPAK8_ADMIN_TOKEN), {
      role: 'admin',
      userId: 'env-admin',
    });
  }
  if (tokenIndex.size === 0) {
    // Mode pengembangan: token default, dicetak supaya jelas.
    const devToken = 'lapak8-dev-token';
    tokenIndex.set(devToken, { role: 'admin', userId: 'dev-admin' });
    console.warn(
      '[lapak8-storage] Tidak ada LAPAK8_TOKENS / LAPAK8_ADMIN_TOKEN. ' +
        `Memakai token pengembangan: ${devToken} (role admin).`,
    );
  }
}

console.log('[lapak8-storage] token terdaftar:', tokenIndex.size);

function authenticate(req) {
  const header = req.headers['authorization'] || '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    throw new HttpError(401, 'unauthenticated', 'Token akses tidak ditemukan.');
  }
  const entry = tokenIndex.get(match[1].trim());
  if (!entry) {
    throw new HttpError(401, 'invalid_token', 'Token akses tidak dikenali.');
  }
  return entry;
}

function requireWriter(principal) {
  if (!ADMIN_ROLES.has(principal.role)) {
    throw new HttpError(
      403,
      'forbidden',
      'Hanya petugas/admin yang dapat mengunggah atau menghapus dokumentasi.',
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata (manifest) — disimpan atomik, ditulis serialized agar tidak korup.
// ---------------------------------------------------------------------------
/** @type {{version:number, items: Object<string, {photos:Array, video:Object|null}>}} */
let manifest = { version: 1, items: {} };
let manifestWriteChain = Promise.resolve();

async function loadManifest() {
  await fsp.mkdir(STORAGE_DIR, { recursive: true });
  await fsp.mkdir(TMP_DIR, { recursive: true });
  try {
    const raw = await fsp.readFile(MANIFEST_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object' && parsed.items) {
      manifest = { version: 1, items: parsed.items };
    }
  } catch (e) {
    if (e.code !== 'ENOENT') {
      console.error('[lapak8-storage] manifest rusak, mulai baru:', e.message);
    }
    manifest = { version: 1, items: {} };
    await persistManifest();
  }
}

function persistManifest() {
  manifestWriteChain = manifestWriteChain.then(async () => {
    const tmp = MANIFEST_PATH + '.tmp';
    await fsp.writeFile(tmp, JSON.stringify(manifest, null, 0), 'utf8');
    await fsp.rename(tmp, MANIFEST_PATH);
  });
  return manifestWriteChain;
}

async function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > limit) {
        reject(
          new HttpError(
            413,
            'payload_too_large',
            `Ukuran berkas melebihi batas ${(limit / (1024 * 1024)).toFixed(0)} MB.`,
          ),
        );
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// Parser multipart/form-data (satu berkas + field teks)
// ---------------------------------------------------------------------------
function parseMultipart(buffer, contentType) {
  const boundaryMatch = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType || '');
  if (!boundaryMatch) {
    throw new HttpError(400, 'bad_multipart', 'Boundary multipart tidak ditemukan.');
  }
  const boundary = Buffer.from('--' + (boundaryMatch[1] || boundaryMatch[2]).trim());
  const delimiter = Buffer.concat([Buffer.from('\r\n'), boundary]);
  const body = Buffer.concat([Buffer.from('\r\n'), buffer]);
  const nextDelimiter = Buffer.concat([boundary, Buffer.from('--')]);

  const fields = {};
  let file = null;

  let start = body.indexOf(boundary);
  if (start === -1) {
    throw new HttpError(400, 'bad_multipart', 'Isi multipart tidak valid.');
  }

  while (start !== -1) {
    const partStart = start + boundary.length;
    if (body.slice(partStart, partStart + 2).toString() === '--') break;

    const headerEnd = body.indexOf(Buffer.from('\r\n\r\n'), partStart);
    if (headerEnd === -1) break;

    const rawHeaders = body.slice(partStart + 2, headerEnd).toString('utf8');
    const dataStart = headerEnd + 4;
    const dataEnd = body.indexOf(delimiter, dataStart);
    if (dataEnd === -1) break;
    const data = body.slice(dataStart, dataEnd);

    const headers = {};
    for (const line of rawHeaders.split('\r\n')) {
      const idx = line.indexOf(':');
      if (idx === -1) continue;
      headers[line.slice(0, idx).trim().toLowerCase()] = line.slice(idx + 1).trim();
    }

    const disposition = headers['content-disposition'] || '';
    const nameMatch = /name="([^"]*)"/i.exec(disposition);
    const fileNameMatch = /filename="([^"]*)"/i.exec(disposition);
    const fieldName = nameMatch ? nameMatch[1] : '';

    if (fileNameMatch) {
      file = {
        field: fieldName,
        fileName: fileNameMatch[1],
        contentType: (headers['content-type'] || 'application/octet-stream')
          .toLowerCase()
          .split(';')[0]
          .trim(),
        data,
      };
    } else if (fieldName) {
      fields[fieldName] = data.toString('utf8');
    }

    start = body.indexOf(boundary, dataEnd + 1);
  }

  return { fields, file };
}

// ---------------------------------------------------------------------------
// Validasi berkas
// ---------------------------------------------------------------------------
function detectKind(fileName, contentType) {
  const ext = path.extname(fileName || '').replace('.', '').toLowerCase();
  if (PHOTO_RULES[ext]) return { kind: 'photo', ext };
  if (VIDEO_RULES[ext]) return { kind: 'video', ext };
  throw new HttpError(
    415,
    'unsupported_format',
    'Format tidak didukung. Foto: JPG/JPEG/PNG/WEBP. Video: MP4/MOV/WEBM.',
  );
}

function assertMime(kind, ext, contentType) {
  const allowed = kind === 'photo' ? PHOTO_RULES[ext] : VIDEO_RULES[ext];
  if (!allowed.includes(contentType)) {
    throw new HttpError(
      415,
      'mime_mismatch',
      `Tipe konten "${contentType}" tidak sesuai dengan ekstensi .${ext}.`,
    );
  }
}

/** Cek magic bytes: mencegah berkas yang hanya bernama .jpg tapi bukan gambar. */
function assertSignature(kind, ext, data) {
  const head = data.subarray(0, 16);
  const sniff = (signature, offset = 0) =>
    head.length >= offset + signature.length &&
    signature.every((b, i) => head[offset + i] === b);

  if (kind === 'photo') {
    if (ext === 'jpg' || ext === 'jpeg') {
      if (!sniff([0xff, 0xd8, 0xff])) throw signatureError();
      return;
    }
    if (ext === 'png') {
      if (!sniff([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) throw signatureError();
      return;
    }
    if (ext === 'webp') {
      const riff = data.subarray(0, 4).toString('ascii') === 'RIFF';
      const webp = data.subarray(8, 12).toString('ascii') === 'WEBP';
      if (!riff || !webp) throw signatureError();
      return;
    }
  } else {
    if (ext === 'mp4' || ext === 'mov') {
      if (data.subarray(4, 8).toString('ascii') !== 'ftyp') throw signatureError();
      return;
    }
    if (ext === 'webm') {
      if (!sniff([0x1a, 0x45, 0xdf, 0xa3])) throw signatureError();
      return;
    }
  }
}

function signatureError() {
  return new HttpError(
    415,
    'content_mismatch',
    'Isi berkas tidak sesuai dengan format yang dideklarasikan.',
  );
}

// ---------------------------------------------------------------------------
// Helper entri dokumentasi
// ---------------------------------------------------------------------------
function entryFor(returnId, borrowingId, itemId) {
  const current = manifest.items[returnId];
  if (current && current.borrowingId === borrowingId && current.itemId === itemId) {
    return current;
  }
  const fresh = {
    returnId,
    borrowingId,
    itemId,
    createdAt: new Date().toISOString(),
    photos: [],
    video: null,
  };
  manifest.items[returnId] = fresh;
  return fresh;
}

function publicFile(item) {
  return {
    id: item.id,
    kind: item.kind,
    fileName: item.fileName,
    mime: item.mime,
    size: item.size,
    url: `/api/v1/inspections/${encodeURIComponent(item.returnId)}/file/${item.id}`,
    uploadedAt: item.uploadedAt,
    uploadedBy: item.uploadedBy,
  };
}

function serializeEntry(entry) {
  if (!entry) {
    return {
      returnId: null,
      borrowingId: null,
      itemId: null,
      photos: [],
      video: null,
      photoCount: 0,
      videoCount: 0,
      updatedAt: null,
    };
  }
  return {
    returnId: entry.returnId,
    borrowingId: entry.borrowingId,
    itemId: entry.itemId,
    photos: entry.photos.map(publicFile),
    video: entry.video ? publicFile(entry.video) : null,
    photoCount: entry.photos.length,
    videoCount: entry.video ? 1 : 0,
    updatedAt: entry.updatedAt || entry.createdAt,
  };
}

function findFile(entry, fileId) {
  if (!entry) return null;
  const photo = entry.photos.find((p) => p.id === fileId);
  if (photo) return photo;
  if (entry.video && entry.video.id === fileId) return entry.video;
  return null;
}

// ---------------------------------------------------------------------------
// Router berbasis segmen path.
// Segmen mentah di-decode satu per satu, sehingga karakter "/" yang di-encode
// (%2F) TIDAK pernah berubah menjadi pemisah path. Ini menutup vektor
// path traversal (mis. /inspections/..%2F..%2Fetc/docs) dan tetap membuat
// id yang tidak valid ditolak oleh safeId().
// ---------------------------------------------------------------------------
const ROUTE_FILE_METHODS = { GET: true, HEAD: true };

function routeOf(method, rawPath) {
  const raw = (rawPath || '').split('?')[0];
  const segments = [];
  for (const seg of raw.split('/')) {
    if (seg === '') continue;
    let decoded;
    try {
      decoded = decodeURIComponent(seg);
    } catch {
      return null; // percent-encoding rusak
    }
    if (decoded === '.' || decoded === '..' || decoded.includes('/') || decoded.includes('\\')) {
      return null; // segmen relatif / tersisip pemisah path
    }
    segments.push(decoded);
  }

  if (method === 'GET' && segments.length === 1 && segments[0] === 'health') {
    return { name: 'health' };
  }
  if (
    segments.length < 4 ||
    segments[0] !== 'api' ||
    segments[1] !== 'v1' ||
    segments[2] !== 'inspections'
  ) {
    return null;
  }

  const returnId = segments[3];
  const rest = segments.slice(4);

  if (rest.length === 1 && rest[0] === 'docs' && method === 'GET') {
    return { name: 'docs', returnId };
  }
  if (rest.length === 1 && rest[0] === 'upload' && method === 'POST') {
    return { name: 'upload', returnId };
  }
  if (rest.length === 2 && rest[0] === 'file' && ROUTE_FILE_METHODS[method]) {
    return { name: 'file', returnId, fileId: rest[1] };
  }
  if (rest.length === 2 && rest[0] === 'files' && method === 'DELETE') {
    return { name: 'deleteFile', returnId, fileId: rest[1] };
  }
  return null;
}

async function handle(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const route = routeOf(req.method, req.url);

  // CORS: aplikasi Flutter web / desktop / mobile.
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader(
    'access-control-allow-headers',
    'authorization,content-type,x-borrowing-id,x-item-id,x-client-type',
  );
  res.setHeader('access-control-allow-methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('access-control-expose-headers', 'content-length,content-range,accept-ranges');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (route && route.name === 'health') {
    sendJson(res, 200, {
      ok: true,
      service: 'lapak8-storage',
      limits: {
        maxPhotos: MAX_PHOTOS,
        maxVideos: MAX_VIDEOS,
        maxPhotoBytes: MAX_PHOTO_BYTES,
        maxVideoBytes: MAX_VIDEO_BYTES,
        photoFormats: Object.keys(PHOTO_RULES),
        videoFormats: Object.keys(VIDEO_RULES),
      },
      // Supaya klien tahu batas sebelum memilih berkas.
      serverTime: new Date().toISOString(),
    });
    return;
  }

  const principal = authenticate(req);

  if (!route) {
    throw new HttpError(404, 'not_found', 'Endpoint tidak ditemukan.');
  }

  const returnIdFromRoute = safeId(route.returnId, 'returnId');

  // GET /api/v1/inspections/:returnId/docs -> metadata dokumentasi
  if (route.name === 'docs') {
    sendJson(res, 200, {
      ok: true,
      data: serializeEntry(manifest.items[returnIdFromRoute]),
    });
    return;
  }

  // POST /api/v1/inspections/:returnId/upload -> unggah 1 berkas
  if (route.name === 'upload') {
    requireWriter(principal);
    const returnId = returnIdFromRoute;
    const borrowingId = safeId(
      req.headers['x-borrowing-id'] || url.searchParams.get('borrowingId'),
      'borrowingId',
    );
    const itemId = safeId(
      req.headers['x-item-id'] || url.searchParams.get('itemId') || 'unknown-item',
      'itemId',
    );

    const declaredLength = Number(req.headers['content-length'] || 0);
    const hardLimit = MAX_VIDEO_BYTES + 1024 * 1024;
    if (declaredLength > hardLimit) {
      throw new HttpError(413, 'payload_too_large', 'Ukuran unggahan melebihi batas.');
    }

    const raw = await readBody(req, hardLimit);
    const { fields, file } = parseMultipart(raw, req.headers['content-type']);
    if (!file || !file.data.length) {
      throw new HttpError(400, 'file_missing', 'Berkas tidak ditemukan pada permintaan.');
    }

    const declaredName = file.fileName || fields.fileName || '';
    const { kind, ext } = detectKind(declaredName, file.contentType);
    assertMime(kind, ext, file.contentType);
    assertSignature(kind, ext, file.data);

    const limit = kind === 'photo' ? MAX_PHOTO_BYTES : MAX_VIDEO_BYTES;
    if (file.data.length > limit) {
      throw new HttpError(
        413,
        'file_too_large',
        `Ukuran ${kind === 'photo' ? 'foto' : 'video'} melebihi batas ` +
          `${(limit / (1024 * 1024)).toFixed(0)} MB.`,
      );
    }

    const entry = entryFor(returnId, borrowingId, itemId);
    await fsp.mkdir(path.join(STORAGE_DIR, returnId), { recursive: true });

    const id = crypto.randomUUID();
    const storedName = `${id}.${ext}`;
    const target = path.join(STORAGE_DIR, returnId, storedName);
    const tmpFile = path.join(TMP_DIR, `${id}.part`);

    let replaced = null;
    if (kind === 'photo') {
      if (entry.photos.length >= MAX_PHOTOS) {
        throw new HttpError(
          409,
          'photo_limit_reached',
          `Maksimal ${MAX_PHOTOS} foto per pemeriksaan pengembalian.`,
        );
      }
    } else if (entry.video) {
      replaced = entry.video;
    }

    await fsp.writeFile(tmpFile, file.data);
    await fsp.rename(tmpFile, target);

    const record = {
      id,
      kind,
      returnId,
      borrowingId,
      itemId,
      fileName: declaredName || storedName,
      storedName,
      mime: file.contentType,
      size: file.data.length,
      uploadedAt: new Date().toISOString(),
      uploadedBy: principal.userId,
    };

    if (kind === 'photo') {
      entry.photos.push(record);
    } else {
      entry.video = record;
    }
    entry.updatedAt = record.uploadedAt;

    try {
      await persistManifest();
    } catch (e) {
      // Rollback supaya metadata dan berkas tetap konsisten.
      if (kind === 'photo') {
        entry.photos = entry.photos.filter((p) => p.id !== id);
      } else {
        entry.video = replaced;
      }
      await fsp.rm(target, { force: true });
      throw e;
    }

    if (replaced) {
      await fsp.rm(path.join(STORAGE_DIR, returnId, replaced.storedName), { force: true });
    }

    sendJson(res, 201, {
      ok: true,
      data: { file: publicFile(record), entry: serializeEntry(entry) },
    });
    return;
  }

  // DELETE /api/v1/inspections/:returnId/files/:fileId
  if (route.name === 'deleteFile') {
    requireWriter(principal);
    const returnId = returnIdFromRoute;
    const fileId = safeId(route.fileId, 'fileId');
    const entry = manifest.items[returnId];
    const record = findFile(entry, fileId);
    if (!record) {
      throw new HttpError(404, 'file_not_found', 'Dokumentasi tidak ditemukan.');
    }
    if (record.kind === 'photo') {
      entry.photos = entry.photos.filter((p) => p.id !== fileId);
    } else {
      entry.video = null;
    }
    entry.updatedAt = new Date().toISOString();
    await persistManifest();
    await fsp.rm(path.join(STORAGE_DIR, returnId, record.storedName), { force: true });
    sendJson(res, 200, { ok: true, data: serializeEntry(entry) });
    return;
  }

  // GET /api/v1/inspections/:returnId/file/:fileId -> stream berkas (dukung Range)
  if (route.name === 'file') {
    const returnId = returnIdFromRoute;
    const fileId = safeId(route.fileId, 'fileId');
    const record = findFile(manifest.items[returnId], fileId);
    if (!record) {
      throw new HttpError(404, 'file_not_found', 'Dokumentasi tidak ditemukan.');
    }
    const filePath = path.join(STORAGE_DIR, returnId, record.storedName);
    let stat;
    try {
      stat = await fsp.stat(filePath);
    } catch {
      throw new HttpError(410, 'file_missing', 'Berkas tidak lagi tersedia di storage.');
    }

    const baseHeaders = {
      'content-type': record.mime,
      'accept-ranges': 'bytes',
      'cache-control': 'private, max-age=300',
      'content-disposition':
        `inline; filename="${record.fileName.replace(/["\\]/g, '_')}"`,
    };

    const range = req.headers.range;
    if (range) {
      const m = /^bytes=(\d*)-(\d*)$/.exec(range);
      if (m) {
        let start = m[1] === '' ? null : Number(m[1]);
        let end = m[2] === '' ? null : Number(m[2]);
        if (start === null && end === null) {
          throw new HttpError(416, 'bad_range', 'Rentang tidak valid.');
        }
        if (start === null) {
          start = Math.max(0, stat.size - end);
          end = stat.size - 1;
        } else if (end === null || end >= stat.size) {
          end = stat.size - 1;
        }
        if (start > end || start >= stat.size) {
          res.writeHead(416, { 'content-range': `bytes */${stat.size}` });
          res.end();
          return;
        }
        res.writeHead(206, {
          ...baseHeaders,
          'content-range': `bytes ${start}-${end}/${stat.size}`,
          'content-length': end - start + 1,
        });
        if (req.method === 'HEAD') {
          res.end();
          return;
        }
        fs.createReadStream(filePath, { start, end }).pipe(res);
        return;
      }
    }

    res.writeHead(200, { ...baseHeaders, 'content-length': stat.size });
    if (req.method === 'HEAD') {
      res.end();
      return;
    }
    fs.createReadStream(filePath).pipe(res);
    return;
  }

  throw new HttpError(404, 'not_found', 'Endpoint tidak ditemukan.');
}

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------
loadTokens();

const server = http.createServer((req, res) => {
  handle(req, res).catch((err) => {
    if (res.headersSent) {
      res.destroy();
      return;
    }
    sendError(res, err);
  });
});

server.on('clientError', (err, socket) => {
  if (socket.writable) socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
});

loadManifest()
  .then(() => {
    server.listen(PORT, HOST, () => {
      console.log(`[lapak8-storage] siap di http://${HOST}:${PORT}`);
      console.log(`[lapak8-storage] storage: ${STORAGE_DIR}`);
    });
  })
  .catch((err) => {
    console.error('[lapak8-storage] gagal start:', err);
    process.exit(1);
  });

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
  });
}