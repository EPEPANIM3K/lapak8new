import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lapak8new/features/chat/models/chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ChatFailure { unauthorized, rateLimited, timeout, network, other }

class ChatException implements Exception {
  const ChatException(this.message, {this.kind = ChatFailure.other});

  final String message;
  final ChatFailure kind;

  @override
  String toString() => message;
}

class ChatService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> sendMessage(List<ChatMessage> messages) async {
    if (messages.isEmpty) {
      throw const ChatException('Riwayat percakapan tidak boleh kosong.');
    }

    // Ambil maksimal 10 pesan terakhir.
    final recentMessages = messages.length > 10
        ? messages.sublist(messages.length - 10)
        : messages;

    // Buang pesan pembuka (sapaan asisten) agar riwayat diawali pesan user.
    final firstUserMessage = recentMessages.indexWhere(
      (message) => message.role == ChatRole.user,
    );
    if (firstUserMessage < 0) {
      throw const ChatException('Pesan terakhir harus berasal dari pengguna.');
    }

    final requestMessages = <Map<String, String>>[];
    for (final message in recentMessages.skip(firstUserMessage)) {
      final text = message.text.trim();
      if (text.isEmpty) {
        throw const ChatException('Pesan tidak boleh kosong.');
      }
      if (message.role == ChatRole.user && text.length > 1000) {
        throw const ChatException('Pesan tidak boleh melebihi 1.000 karakter.');
      }
      final historyText =
          message.role == ChatRole.assistant && text.length > 1000
          ? text.substring(0, 1000)
          : text;
      requestMessages.add({
        'role': message.role == ChatRole.user ? 'user' : 'assistant',
        'text': historyText,
      });
    }
    if (requestMessages.last['role'] != 'user') {
      throw const ChatException('Pesan terakhir harus berasal dari pengguna.');
    }

    try {
      final response = await _client.functions
          .invoke('alloc8-ai', body: {'messages': requestMessages})
          .timeout(const Duration(seconds: 55));
      final payload = response.data;
      final data = payload is Map ? payload['data'] : null;
      final text = data is Map ? data['text'] : null;
      if (text is! String || text.trim().isEmpty) {
        throw const ChatException(
          'ALLOC8 AI belum memberikan jawaban. Silakan coba lagi.',
        );
      }
      return text.trim();
    } on FunctionException catch (error) {
      debugPrint('alloc8-ai gagal: ${error.status} ${error.details}');
      throw switch (error.status) {
        401 => const ChatException(
          'Sesi login berakhir. Silakan masuk kembali.',
          kind: ChatFailure.unauthorized,
        ),
        429 => const ChatException(
          'Anda mengirim pesan terlalu sering. Coba lagi dalam satu jam.',
          kind: ChatFailure.rateLimited,
        ),
        0 => const ChatException(
          'Koneksi terputus. Periksa jaringan lalu coba lagi.',
          kind: ChatFailure.network,
        ),
        504 => const ChatException(
          'ALLOC8 AI membutuhkan waktu terlalu lama. Coba lagi.',
          kind: ChatFailure.timeout,
        ),
        400 => const ChatException(
          'Pesan tidak valid. Maksimal 1.000 karakter dan 10 pesan.',
        ),
        403 => const ChatException(
          'Akun tidak aktif atau tidak dapat menggunakan layanan bantuan.',
        ),
        _ => const ChatException(
          'ALLOC8 AI sedang mengalami kendala. Silakan coba lagi.',
        ),
      };
    } on TimeoutException {
      throw const ChatException(
        'Permintaan melewati batas waktu. Periksa koneksi lalu coba lagi.',
        kind: ChatFailure.timeout,
      );
    } on ChatException {
      rethrow;
    } on Exception catch (error) {
      debugPrint('alloc8-ai error: $error');
      throw const ChatException(
        'Koneksi ke ALLOC8 AI terganggu. Periksa jaringan lalu coba lagi.',
        kind: ChatFailure.network,
      );
    }
  }
}
