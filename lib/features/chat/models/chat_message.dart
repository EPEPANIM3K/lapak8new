enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({required this.text, required this.role});

  final String text;
  final ChatRole role;
}
