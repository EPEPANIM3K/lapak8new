// Diverifikasi untuk web saja (lihat local_media_url.dart).
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Membuat blob URL dari bytes berkas video agar bisa diputar di `<video>`.
String? createLocalMediaUrl(Object file) {
  if (file is! List<int>) return null;
  final blob = html.Blob([file]);
  return html.Url.createObjectUrlFromBlob(blob);
}

/// Mencabut blob URL sebelumnya supaya tidak terjadi memory leak.
void revokeLocalMediaUrl(String? url) {
  if (url == null || url.isEmpty) return;
  html.Url.revokeObjectUrl(url);
}
