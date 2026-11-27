// Diverifikasi untuk web saja (lihat local_media_url.dart).
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Membuat blob URL dari bytes berkas video agar bisa diputar di `<video>`.
String? createLocalMediaUrl(Object file) {
  final bytes = switch (file) {
    Uint8List value => value,
    List<int> value => Uint8List.fromList(value),
    _ => null,
  };
  if (bytes == null) return null;
  final blob = web.Blob([bytes.toJS].toJS);
  return web.URL.createObjectURL(blob);
}

/// Mencabut blob URL sebelumnya supaya tidak terjadi memory leak.
void revokeLocalMediaUrl(String? url) {
  if (url == null || url.isEmpty) return;
  web.URL.revokeObjectURL(url);
}
