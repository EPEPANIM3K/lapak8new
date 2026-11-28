import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lapak8new/features/admin/services/admin_report_pdf_service.dart';

void main() {
  group('AdminReportPdfService.generate', () {
    test('creates a PDF containing the requested report', () async {
      final bytes = await AdminReportPdfService.generate(
        title: 'Rekap Peminjaman',
        headers: const ['Kode', 'Peminjam', 'Detail'],
        rows: const [
          ['L8-001', 'Pengguna LAPAK8', '1 unit • Item — Kategori'],
        ],
      );

      expect(latin1.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(500));
    });

    test('creates an empty report when there are no rows', () async {
      final bytes = await AdminReportPdfService.generate(
        title: 'Rekap Pengembalian',
        headers: const ['Kode', 'Status'],
        rows: const [],
      );

      expect(latin1.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(500));
    });
  });
}
