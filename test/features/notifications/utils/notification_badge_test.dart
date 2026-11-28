import 'package:flutter_test/flutter_test.dart';
import 'package:lapak8new/features/notifications/models/notification_record.dart';
import 'package:lapak8new/features/notifications/utils/badge_count.dart';
import 'package:lapak8new/features/notifications/utils/notification_selection.dart';

NotificationRecord _record({
  required String id,
  String? relatedEntity,
  String? relatedId,
  bool sudahDibaca = false,
}) {
  return NotificationRecord.fromMap({
    'id': id,
    'user_id': 'user-1',
    'judul': 'Judul',
    'isi': 'Isi',
    'related_entity': relatedEntity,
    'related_id': relatedId,
    'sudah_dibaca': sudahDibaca ? 1 : 0,
  });
}

void main() {
  group('NotificationRecord.fromMap', () {
    test('mengonversi sudah_dibaca int dan created_at string', () {
      final record = NotificationRecord.fromMap({
        'id': 'n1',
        'judul': 'Pengajuan Peminjaman Baru',
        'isi': 'Isi notifikasi',
        'sudah_dibaca': 1,
        'created_at': '2026-11-28T10:00:00.000Z',
      });

      expect(record.id, 'n1');
      expect(record.sudahDibaca, isTrue);
      expect(record.createdAt, DateTime.utc(2026, 11, 28, 10));
      expect(record.relatedEntity, isNull);
      expect(record.relatedId, isNull);
    });

    test('membaca created_at yang sudah bertipe DateTime', () {
      final createdAt = DateTime.utc(2026, 11, 28, 11);
      final record = NotificationRecord.fromMap({
        'id': 'n2',
        'sudah_dibaca': false,
        'created_at': createdAt,
      });

      expect(record.createdAt, createdAt);
      expect(record.sudahDibaca, isFalse);
    });
  });

  group('formatBadgeCount', () {
    test('menampilkan angka dan membatasi 99+', () {
      expect(formatBadgeCount(0), '0');
      expect(formatBadgeCount(3), '3');
      expect(formatBadgeCount(99), '99');
      expect(formatBadgeCount(100), '99+');
    });
  });

  group('selectUnreadTransactionIds', () {
    test('hanya ID unik untuk entity sama yang terlihat dan belum dibaca', () {
      final records = [
        _record(
          id: 'n1',
          relatedEntity: 'pengajuan_peminjaman',
          relatedId: 'tx-1',
        ),
        _record(
          id: 'n2',
          relatedEntity: 'pengajuan_peminjaman',
          relatedId: 'tx-1',
        ),
        _record(
          id: 'n3',
          relatedEntity: 'pengajuan_peminjaman',
          relatedId: 'tx-2',
        ),
        _record(
          id: 'n4',
          relatedEntity: 'pengajuan_peminjaman',
          relatedId: 'tx-3',
          sudahDibaca: true,
        ),
        _record(id: 'n5', relatedEntity: 'pengajuan_peminjaman'),
        _record(
          id: 'n6',
          relatedEntity: 'pengajuan_pengembalian',
          relatedId: 'tx-4',
        ),
      ];

      final result = selectUnreadTransactionIds(
        records: records,
        entity: 'pengajuan_peminjaman',
        visibleTransactionIds: ['tx-1', 'tx-2', 'tx-3', 'tx-4', 'tx-5'],
      );

      expect(result, ['tx-1', 'tx-2']);
    });

    test('menghormati filter/pencarian lewat visible ids', () {
      final records = [
        _record(
          id: 'n1',
          relatedEntity: 'pengajuan_peminjaman',
          relatedId: 'tx-1',
        ),
        _record(
          id: 'n2',
          relatedEntity: 'pengajuan_peminjaman',
          relatedId: 'tx-2',
        ),
      ];

      expect(
        selectUnreadTransactionIds(
          records: records,
          entity: 'pengajuan_peminjaman',
          visibleTransactionIds: const ['tx-2'],
        ),
        ['tx-2'],
      );
    });
  });

  group('selectNotificationIds', () {
    test('mengembalikan semua notifikasi untuk transaksi yang diberikan', () {
      final records = [
        _record(
          id: 'n1',
          relatedEntity: 'pengajuan_peminjaman',
          relatedId: 'tx-1',
        ),
        _record(
          id: 'n2',
          relatedEntity: 'pengajuan_peminjaman',
          relatedId: 'tx-1',
        ),
        _record(
          id: 'n3',
          relatedEntity: 'pengajuan_peminjaman',
          relatedId: 'tx-2',
        ),
        _record(
          id: 'n4',
          relatedEntity: 'pengajuan_pengembalian',
          relatedId: 'tx-1',
        ),
      ];

      final result = selectNotificationIds(
        records: records,
        entity: 'pengajuan_peminjaman',
        transactionIds: ['tx-1'],
      );

      expect(result, ['n1', 'n2']);
    });
  });
}
