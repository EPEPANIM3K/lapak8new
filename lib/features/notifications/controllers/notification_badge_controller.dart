import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/notification_record.dart';
import '../utils/notification_selection.dart';

class NotificationBadgeController extends ChangeNotifier {
  RealtimeChannel? _channel;
  String? _userId;
  List<NotificationRecord> _unreadRecords = const [];
  int _generation = 0;

  SupabaseClient get _client => Supabase.instance.client;

  int get unreadCount => _unreadRecords.length;
  List<NotificationRecord> get unreadRecords =>
      List.unmodifiable(_unreadRecords);

  void bind(String? userId) {
    _generation++;
    final generation = _generation;

    final previous = _channel;
    _channel = null;
    if (previous != null) unawaited(previous.unsubscribe());

    _userId = userId;
    _setRecords(const []);

    if (userId == null || !SupabaseConfig.isConfigured) return;
    unawaited(_bindAfterRefresh(userId, generation));
  }

  Future<void> _bindAfterRefresh(String userId, int generation) async {
    await refresh();
    if (_generation != generation || _userId != userId) return;

    final channel = _client.channel('notifications:$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => unawaited(refresh()),
    ).subscribe();
    _channel = channel;
  }

  Future<void> refresh() async {
    final userId = _userId;
    final generation = _generation;
    if (userId == null || !SupabaseConfig.isConfigured) {
      _setRecords(const []);
      return;
    }

    try {
      final rows = await _client
          .from('notifications')
          .select(
            'id, user_id, judul, isi, related_entity, related_id, sudah_dibaca, created_at',
          )
          .eq('user_id', userId)
          .eq('sudah_dibaca', false)
          .order('created_at', ascending: false);

      final records = rows
          .map(
            (row) => NotificationRecord.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      if (_generation != generation || _userId != userId) return;
      _setRecords(records);
    } catch (_) {
      // Pertahankan state terakhir baca gagal; jangan mengubah badge.
    }
  }

  Future<void> markRead(Iterable<String> notificationIds) async {
    final ids = notificationIds
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final userId = _userId;
    if (ids.isEmpty || userId == null || !SupabaseConfig.isConfigured) return;

    final generation = _generation;
    try {
      await _client.rpc(
        'tandai_notifikasi_dibaca',
        params: {'p_id': null, 'p_ids': ids},
      );
    } catch (_) {
      // State lokal tidak diubah bila RPC gagal.
      return;
    }

    if (_generation != generation || _userId != userId) return;
    final removed = ids.toSet();
    _setRecords(
      _unreadRecords.where((record) => !removed.contains(record.id)).toList(),
    );
  }

  List<String> unreadRelatedIds(String entity) {
    return selectUnreadTransactionIds(
      records: _unreadRecords,
      entity: entity,
      visibleTransactionIds:
          _unreadRecords.map((record) => record.relatedId).whereType<String>(),
    );
  }

  List<String> notificationIdsFor(
    String entity,
    Iterable<String> transactionIds,
  ) {
    return selectNotificationIds(
      records: _unreadRecords,
      entity: entity,
      transactionIds: transactionIds,
    );
  }

  void _setRecords(List<NotificationRecord> records) {
    _unreadRecords = records;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(channel.unsubscribe());
    super.dispose();
  }
}

final notificationBadgeController = NotificationBadgeController();
