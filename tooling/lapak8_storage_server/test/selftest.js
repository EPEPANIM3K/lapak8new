'use strict';

/**
 * Self-test end-to-end untuk LAPAK8 Storage Server.
 * Menjalankan server pada port acak dengan storage sementara, lalu:
 *   1. unggah foto PNG valid (multipart asli)
 *   2. menolak berkas palsu (magic bytes salah)
 *   3. menolak melebihi batas 6 foto
 *   4. unggah video MP4, ganti video (berkas lama terhapus)
 *   5. baca metadata, cek persistensi berkas
 *   6. streaming Range request
 *   7. hapus foto, cek hilang dari metadata & disk
 *   8. restart server -> metadata + berkas tetap ada (persistensi nyata)
 *
 * Jalankan: node test/selftest.js
 */

const { spawn } = require('node:child_process');
const fsp = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

const TOKEN = 'selftest-token';
const PORT = 8900 + Math.floor(Math.random() * 90);
const BASE = `http://127.0.0.1:${PORT}`;
const SERVER = path.join(__dirname, '..', 'server.js');

let storageDir;
let child;

function startServer() {
  return new Promise((resolve, reject) => {
    child = spawn(process.execPath, [SERVER], {
      env: {
        ...process.env,
        PORT: String(PORT),
        HOST: '127.0.0.1',
        LAPAK8_STORAGE: storageDir,
        LAPAK8_ADMIN_TOKEN: TOKEN,
        LAPAK8_TOKENS: '',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let out = '';
    const onData = (buf) => {
      out += buf.toString();
      if (out.includes('siap di')) resolve();
    };
    child.stdout.on('data', onData);
    child.stderr.on('data', (buf) => process.stderr.write(buf));
    child.on('exit', (code) => reject(new Error('server exit ' + code + '\n' + out)));
    setTimeout(() => reject(new Error('timeout start server\n' + out)), 8000);
  });
}

async function stopServer() {
  if (!child) return;
  const done = new Promise((r) => child.once('exit', r));
  child.kill();
  await done;
  child = null;
}

const checks = [];
function check(name, condition, detail) {
  checks.push({ name, ok: Boolean(condition), detail });
  console.log(`${condition ? 'PASS' : 'FAIL'}  ${name}${condition || !detail ? '' : '  -> ' + detail}`);
}

// ---- fixture berkas valid (signature benar) --------------------------------
function pngBuffer(seed) {
  // Header PNG + tEXt chunk berisi seed; cukup untuk validasi signature.
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const chunk = Buffer.from(`LAPAK8-${seed}`);
  const len = Buffer.alloc(4);
  len.writeUInt32BE(chunk.length);
  return Buffer.concat([sig, len, Buffer.from('tEXt'), chunk, Buffer.alloc(64, 7)]);
}

function mp4Buffer(seed) {
  const size = Buffer.alloc(4);
  size.writeUInt32BE(24);
  const head = Buffer.concat([size, Buffer.from('ftypisomisom')]);
  const payload = Buffer.alloc(2048, seed % 255);
  return Buffer.concat([head, payload]);
}

function multipart(fileName, contentType, data, fieldName = 'file') {
  const boundary = '----lapak8test' + crypto.randomUUID();
  const head = Buffer.from(
    `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="${fieldName}"; filename="${fileName}"\r\n` +
      `Content-Type: ${contentType}\r\n\r\n`,
  );
  const tail = Buffer.from(`\r\n--${boundary}--\r\n`);
  return { body: Buffer.concat([head, data, tail]), boundary };
}

async function upload(returnId, borrowingId, itemId, fileName, contentType, data) {
  const { body, boundary } = multipart(fileName, contentType, data);
  const res = await fetch(`${BASE}/api/v1/inspections/${returnId}/upload`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${TOKEN}`,
      'content-type': `multipart/form-data; boundary=${boundary}`,
      'x-borrowing-id': borrowingId,
      'x-item-id': itemId,
    },
    body,
  });
  const json = await res.json();
  return { status: res.status, json };
}

async function getDocs(returnId) {
  const res = await fetch(`${BASE}/api/v1/inspections/${returnId}/docs`, {
    headers: { authorization: `Bearer ${TOKEN}` },
  });
  return { status: res.status, json: await res.json() };
}

async function main() {
  storageDir = await fsp.mkdtemp(path.join(os.tmpdir(), 'lapak8-storage-'));
  await startServer();

  const RETURN_ID = 'KM-2024-031';
  const BORROW_ID = 'BK-2024-089';
  const ITEM_ID = 'SNY-A74-002';

  // 0. health
  const health = await (await fetch(`${BASE}/health`)).json();
  check('health endpoint', health.ok === true, JSON.stringify(health).slice(0, 120));

  // 0b. tanpa token -> 401
  const noAuth = await fetch(`${BASE}/api/v1/inspections/${RETURN_ID}/docs`);
  check('tanpa token ditolak 401', noAuth.status === 401, 'status ' + noAuth.status);

  // 1. unggah foto valid
  const p1 = await upload(RETURN_ID, BORROW_ID, ITEM_ID, 'kondisi-1.png', 'image/png', pngBuffer(1));
  check('upload foto PNG', p1.status === 201 && p1.json.data.file.kind === 'photo', JSON.stringify(p1.json).slice(0, 200));
  const photoId = p1.json.data && p1.json.data.file && p1.json.data.file.id;

  // 1b. berkas benar-benar ada di disk
  const diskFiles = await fsp.readdir(path.join(storageDir, RETURN_ID));
  check('berkas foto tersimpan di disk', diskFiles.some((f) => f.startsWith(photoId)), diskFiles.join(','));

  // 2. berkas palsu (.jpg tapi isi bukan JPEG)
  const fake = await upload(RETURN_ID, BORROW_ID, ITEM_ID, 'palsu.jpg', 'image/jpeg', Buffer.from('bukan gambar sama sekali'));
  check('berkas palsu ditolak 415', fake.status === 415, JSON.stringify(fake.json));

  // 2b. format tidak didukung
  const gif = await upload(RETURN_ID, BORROW_ID, ITEM_ID, 'x.gif', 'image/gif', pngBuffer(2));
  check('format GIF ditolak 415', gif.status === 415, JSON.stringify(gif.json));

  // 2c. mime tidak cocok dengan ekstensi
  const mimeBad = await upload(RETURN_ID, BORROW_ID, ITEM_ID, 'foto.png', 'image/jpeg', pngBuffer(3));
  check('mime tidak cocok ditolak 415', mimeBad.status === 415, JSON.stringify(mimeBad.json));

  // 3. isi sampai 6 foto, lalu foto ke-7 ditolak
  for (let i = 2; i <= 6; i++) {
    await upload(RETURN_ID, BORROW_ID, ITEM_ID, `kondisi-${i}.webp`, 'image/webp', webpBuffer(i));
  }
  const docs6 = await getDocs(RETURN_ID);
  check('6 foto tersimpan', docs6.json.data.photoCount === 6, 'count ' + docs6.json.data.photoCount);

  const seventh = await upload(RETURN_ID, BORROW_ID, ITEM_ID, 'kondisi-7.jpg', 'image/jpeg', jpegBuffer(7));
  check('foto ke-7 ditolak 409', seventh.status === 409, JSON.stringify(seventh.json));

  // 4. video: unggah + ganti
  const v1 = await upload(RETURN_ID, BORROW_ID, ITEM_ID, 'kondisi.mp4', 'video/mp4', mp4Buffer(1));
  check('upload video MP4', v1.status === 201 && v1.json.data.file.kind === 'video', JSON.stringify(v1.json).slice(0, 160));
  const videoId1 = v1.json.data && v1.json.data.file && v1.json.data.file.id;

  const v2 = await upload(RETURN_ID, BORROW_ID, ITEM_ID, 'kondisi-baru.mov', 'video/quicktime', mp4Buffer(2));
  check('ganti video (MOV) berhasil', v2.status === 201 && v2.json.data.entry.videoCount === 1, JSON.stringify(v2.json).slice(0, 120));
  const videoId2 = v2.json.data && v2.json.data.file && v2.json.data.file.id;
  const stillOld = await fsp
    .readdir(path.join(storageDir, RETURN_ID))
    .then((files) => files.some((f) => f.startsWith(videoId1)));
  check('video lama dihapus dari disk saat diganti', stillOld === false, String(stillOld));

  // 4b. video kedua (setelah ganti) tetap 1 video
  const docs = await getDocs(RETURN_ID);
  check('maksimal 1 video', docs.json.data.videoCount === 1, 'count ' + docs.json.data.videoCount);
  check('metadata terhubung ke borrowing & item', docs.json.data.borrowingId === BORROW_ID && docs.json.data.itemId === ITEM_ID, JSON.stringify(docs.json.data).slice(0, 120));

  // 5. streaming berkas + Range
  const fileRes = await fetch(`${BASE}/api/v1/inspections/${RETURN_ID}/file/${photoId}`, {
    headers: { authorization: `Bearer ${TOKEN}` },
  });
  const fileBuf = Buffer.from(await fileRes.arrayBuffer());
  check('stream berkas utuh', fileRes.status === 200 && fileBuf.equals(pngBuffer(1)), 'len ' + fileBuf.length);

  const rangeRes = await fetch(`${BASE}/api/v1/inspections/${RETURN_ID}/file/${videoId2}`, {
    headers: { authorization: `Bearer ${TOKEN}`, range: 'bytes=0-15' },
  });
  check('range request 206', rangeRes.status === 206 && rangeRes.headers.get('content-range') !== null, 'status ' + rangeRes.status);

  // 6. hapus foto
  const del = await fetch(`${BASE}/api/v1/inspections/${RETURN_ID}/files/${photoId}`, {
    method: 'DELETE',
    headers: { authorization: `Bearer ${TOKEN}` },
  });
  const delJson = await del.json();
  check('hapus foto', del.status === 200 && delJson.data.photoCount === 5, 'count ' + (delJson.data && delJson.data.photoCount));
  const goneFile = await fetch(`${BASE}/api/v1/inspections/${RETURN_ID}/file/${photoId}`, {
    headers: { authorization: `Bearer ${TOKEN}` },
  });
  check('berkas terhapus tidak bisa diakses', goneFile.status === 404, 'status ' + goneFile.status);

  // 7. persistensi lintas restart
  await stopServer();
  await startServer();
  const afterRestart = await getDocs(RETURN_ID);
  check(
    'dokumentasi tetap ada setelah server restart',
    afterRestart.json.data.photoCount === 5 && afterRestart.json.data.videoCount === 1,
    JSON.stringify({ p: afterRestart.json.data.photoCount, v: afterRestart.json.data.videoCount }),
  );

  // 8. path traversal: segmen ber-"../" tidak boleh lolos ke router.
  //    Node 24 menormalkan dot-segment pada spec URL (path jadi /etc/docs ->
  //    404), sedangkan klien HTTP mentah membiarkannya (-> 400 invalid_returnId).
  //    Dua-duanya menolak; yang dilarang adalah 200.
  const traversal = await fetch(
    `${BASE}/api/v1/inspections/..%2F..%2Fetc/docs`,
    { headers: { authorization: `Bearer ${TOKEN}` } },
  );
  check(
    'path traversal ditolak',
    traversal.status === 400 || traversal.status === 404,
    'status ' + traversal.status,
  );

  // 8b. id dengan karakter aneh langsung ditolak validasi id
  const badId = await fetch(`${BASE}/api/v1/inspections/${encodeURIComponent('a b/c')}/docs`, {
    headers: { authorization: `Bearer ${TOKEN}` },
  });
  check('id tidak valid ditolak', badId.status === 400 || badId.status === 404, 'status ' + badId.status);

  await stopServer();
  await fsp.rm(storageDir, { recursive: true, force: true });

  const failed = checks.filter((c) => !c.ok);
  console.log(`\n${checks.length - failed.length}/${checks.length} check lulus`);
  if (failed.length) process.exitCode = 1;
}

function jpegBuffer(seed) {
  return Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(64, seed % 255)]);
}

function webpBuffer(seed) {
  return Buffer.concat([
    Buffer.from('RIFF'),
    Buffer.from([0x20, 0, 0, 0]),
    Buffer.from('WEBP'),
    Buffer.from('VP8 '),
    Buffer.alloc(32, seed % 255),
  ]);
}

main().catch(async (err) => {
  console.error(err);
  await stopServer().catch(() => {});
  process.exitCode = 1;
});