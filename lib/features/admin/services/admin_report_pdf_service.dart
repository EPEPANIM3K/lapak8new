import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdminReportPdfService {
  const AdminReportPdfService._();

  static String _pdfText(String value) => value
      .replaceAll('•', '-')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('’', "'");

  static Future<void> export({
    required String title,
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final bytes = await generate(title: title, headers: headers, rows: rows);
    final name = filename.endsWith('.pdf')
        ? filename.substring(0, filename.length - 4)
        : filename;
    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<Uint8List> generate({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final document = pw.Document();
    final generatedAt = DateTime.now().toLocal();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'LAPAK8 | Rekap Admin',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (_) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Dibuat: ${generatedAt.day.toString().padLeft(2, '0')}/'
            '${generatedAt.month.toString().padLeft(2, '0')}/'
            '${generatedAt.year} '
            '${generatedAt.hour.toString().padLeft(2, '0')}:'
            '${generatedAt.minute.toString().padLeft(2, '0')}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          if (rows.isEmpty)
            pw.Text('Tidak ada data untuk ditampilkan.')
          else
            pw.TableHelper.fromTextArray(
              headers: headers.map(_pdfText).toList(growable: false),
              data: rows
                  .map((row) => row.map(_pdfText).toList(growable: false))
                  .toList(growable: false),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF0037B0),
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
                ),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 6,
              ),
            ),
        ],
      ),
    );

    return document.save();
  }
}
