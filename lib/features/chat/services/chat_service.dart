import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lapak8new/core/storage/storage_config.dart';
import 'package:lapak8new/features/chat/models/chat_message.dart';

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatService {
  Future<String> sendMessage(List<ChatMessage> messages) async {
    final response = await _post(messages);
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const ChatException('Respons server tidak dapat dibaca.');
    } on TypeError {
      throw const ChatException('Format respons server tidak valid.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message = error is Map<String, dynamic> ? error['message'] : null;
      throw ChatException(
        message is String ? message : 'Chatbot tidak dapat memproses pesan.',
      );
    }

    final data = payload['data'];
    final text = data is Map<String, dynamic> ? data['text'] : null;
    if (text is! String || text.trim().isEmpty) {
      throw const ChatException('Chatbot mengirim respons kosong.');
    }
    return text.trim();
  }

  Future<http.Response> _post(List<ChatMessage> messages) async {
    final recentMessages = messages.length > 10
        ? messages.sublist(messages.length - 10)
        : messages;
    try {
      return await http
          .post(
            Lapak8StorageConfig.uri('/api/v1/chat'),
            headers: {
              'authorization': 'Bearer ${Lapak8StorageConfig.authToken}',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'messages': recentMessages
                  .map(
                    (message) => {
                      'role': message.role == ChatRole.user ? 'user' : 'model',
                      'text': message.text,
                    },
                  )
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 35));
    } on TimeoutException {
      throw const ChatException('Permintaan terlalu lama. Coba lagi.');
    } on http.ClientException {
      throw const ChatException(
        'Tidak dapat terhubung ke server LAPAK8. Periksa koneksi dan alamat server.',
      );
    }
  }
}
