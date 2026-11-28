import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/auth/providers/auth_provider.dart';
import 'package:lapak8new/features/chat/models/chat_message.dart';
import 'package:lapak8new/features/chat/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.passwordResetHelp = false});

  final bool passwordResetHelp;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _quickPrompts = [
    'Cara meminjam barang',
    'QR tidak bisa dipakai',
    'Peminjaman saya ditolak',
    'Cara mengembalikan barang',
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _service = ChatService();
  late final List<ChatMessage> _messages;
  bool _isSending = false;
  String? _errorMessage;
  ChatFailure? _errorKind;
  String? _retryText;

  @override
  void initState() {
    super.initState();
    _messages = widget.passwordResetHelp
        ? [
            _welcomeMessage(),
            const ChatMessage(
              role: ChatRole.user,
              text: 'reset-password-request',
            ),
            const ChatMessage(
              role: ChatRole.assistant,
              text: 'Reset sandi, mohon hubungi WA admin di 0859-6029-7134.',
            ),
          ]
        : [_welcomeMessage()];
  }

  ChatMessage _welcomeMessage() => ChatMessage(
    role: ChatRole.assistant,
    text: authProvider.isAdminAtauStaf
        ? 'Halo! Saya ALLOC8 AI. Saya bisa membantu panduan admin seperti menyetujui atau menolak peminjaman, memindai QR, dan mencatat pengembalian.'
        : 'Halo! Saya ALLOC8 AI, asisten bantuan aplikasi LAPAK8. Tanyakan cara meminjam barang, status peminjaman, QR, pengembalian, atau akun.',
  );

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? retryText}) async {
    final isRetry = retryText != null;
    final text = (retryText ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;
    if (text.length > 1000) {
      setState(() {
        _errorMessage = 'Pesan tidak boleh melebihi 1.000 karakter.';
        _errorKind = null;
        _retryText = null;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _errorKind = null;
      _isSending = true;
      if (!isRetry) {
        _controller.clear();
        _retryText = null;
        _messages.add(ChatMessage(role: ChatRole.user, text: text));
      }
    });
    _scrollToBottom();

    try {
      final answer = await _service.sendMessage(_messages);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: ChatRole.assistant, text: answer));
        _retryText = null;
      });
    } on ChatException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _errorKind = error.kind;
        _retryText = text;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _retryLastMessage() async {
    if (_errorKind == ChatFailure.unauthorized) {
      await authProvider.signOut();
      if (mounted) context.go('/login');
      return;
    }
    final text = _retryText;
    if (text != null) await _sendMessage(retryText: text);
  }

  Future<void> _clearConversation() async {
    if (_isSending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus percakapan?'),
        content: const Text('Semua pesan di layar ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(_welcomeMessage());
      _errorMessage = null;
      _errorKind = null;
      _retryText = null;
      _controller.clear();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendPrompt(String prompt) {
    _controller.text = prompt;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final showPrompts = _messages.length == 1;
    final promptIndex = _messages.length;
    final typingIndex = _messages.length + (showPrompts ? 1 : 0);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'Gemini_Generated_Image_nrvldpnrvldpnrvl.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALLOC8 AI',
                    style: AppTextStyles.headlineSm(color: AppColors.onSurface),
                  ),
                  Text(
                    'Pusat Bantuan LAPAK8',
                    style: AppTextStyles.bodySm(color: AppColors.slate600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: widget.passwordResetHelp
            ? null
            : [
                IconButton(
                  tooltip: 'Hapus percakapan',
                  onPressed: _isSending ? null : _clearConversation,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount:
                  _messages.length +
                  (showPrompts ? 1 : 0) +
                  (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  return _MessageBubble(message: _messages[index]);
                }
                if (showPrompts && index == promptIndex) {
                  return _QuickPromptChips(
                    prompts: _quickPrompts,
                    onSelected: _sendPrompt,
                  );
                }
                if (_isSending && index == typingIndex) {
                  return const _TypingIndicator();
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.base),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySm(color: AppColors.error),
                    ),
                  ),
                  if (_retryText != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    TextButton(
                      onPressed: _isSending ? null : _retryLastMessage,
                      child: Text(
                        _errorKind == ChatFailure.unauthorized
                            ? 'Masuk kembali'
                            : 'Coba lagi',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (!widget.passwordResetHelp)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        textInputAction: TextInputAction.send,
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                              _errorKind = null;
                              _retryText = null;
                            });
                          }
                        },
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Tulis pertanyaan...',
                          filled: true,
                          fillColor: AppColors.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton.filled(
                      tooltip: 'Kirim pesan',
                      onPressed: _isSending ? null : _sendMessage,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
        child: Text(
          message.text,
          style: AppTextStyles.bodyMd(
            color: isUser ? colorScheme.onPrimary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _QuickPromptChips extends StatelessWidget {
  const _QuickPromptChips({required this.prompts, required this.onSelected});

  final List<String> prompts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final prompt in prompts)
          ActionChip(label: Text(prompt), onPressed: () => onSelected(prompt)),
      ],
    ),
  );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.xs),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'ALLOC8 AI sedang mengetik...',
          style: AppTextStyles.bodySm(color: AppColors.slate600),
        ),
      ],
    ),
  );
}
