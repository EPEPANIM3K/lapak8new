import '../models/notification_record.dart';

List<String> selectUnreadTransactionIds({
  required Iterable<NotificationRecord> records,
  required String entity,
  required Iterable<String> visibleTransactionIds,
}) {
  final visible = visibleTransactionIds.toSet();
  final seen = <String>{};
  final result = <String>[];

  for (final record in records) {
    if (record.sudahDibaca || record.relatedEntity != entity) continue;
    final id = record.relatedId;
    if (id == null || !visible.contains(id) || !seen.add(id)) continue;
    result.add(id);
  }

  return result;
}

List<String> selectNotificationIds({
  required Iterable<NotificationRecord> records,
  required String entity,
  required Iterable<String> transactionIds,
}) {
  final ids = transactionIds.toSet();
  final result = <String>[];

  for (final record in records) {
    if (record.relatedEntity != entity) continue;
    final id = record.relatedId;
    if (id != null && ids.contains(id)) {
      result.add(record.id);
    }
  }

  return result;
}
