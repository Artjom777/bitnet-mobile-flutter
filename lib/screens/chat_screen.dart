import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/chat_message.dart';
import '../state/bitnet_state.dart';
import '../widgets/status_banner.dart';
import '../widgets/code_block_view.dart';

class ChatScreen extends StatefulWidget {
  final BitNetState state;

  const ChatScreen({super.key, required this.state});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _quickPrompts = [
    {
      'label': 'Код на Python',
      'icon': Icons.terminal,
      'color': AppColors.secondary,
      'prompt': 'Напиши функцию на Python для обработки потока данных'
    },
    {
      'label': 'Объясни квантование',
      'icon': Icons.school,
      'color': AppColors.tertiary,
      'prompt': 'Как работает троичное квантование 1.58-бит в BitNet?'
    },
    {
      'label': 'Анализ логов',
      'icon': Icons.analytics,
      'color': AppColors.secondary,
      'prompt': 'Проанализируй задержку инференса и потребление памяти'
    },
    {
      'label': 'Сгенерируй идею',
      'icon': Icons.lightbulb,
      'color': AppColors.primary,
      'prompt': 'Предложи идеи применения BitNet на смартфонах'
    },
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _submitMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.state.sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Dynamic Hardware & Inference Status Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: StatusBanner(state: widget.state),
        ),
        // Messages Scroll Area
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: widget.state.messages.length,
            itemBuilder: (context, index) {
              final msg = widget.state.messages[index];
              if (msg.isUser) {
                return _buildUserBubble(msg);
              } else {
                return _buildAssistantBubble(msg);
              }
            },
          ),
        ),
        // Quick Prompts Chips
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Text(
                  'Быстрые запросы',
                  style: TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: _quickPrompts.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          _textController.text = item['prompt'];
                          _textController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                size: 16,
                                color: item['color'] as Color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item['label'] as String,
                                style: const TextStyle(
                                  fontFamily: AppTypography.monoFont,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        // Material 3 Floating Input Dock
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Attach button
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Прикрепление контекста или файла к сессии'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.attach_file,
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                  tooltip: 'Прикрепить контекст',
                ),
                // Text Field
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (_) => _submitMessage(),
                    style: const TextStyle(
                      fontFamily: AppTypography.sansFont,
                      fontSize: 14,
                      color: AppColors.onSurface,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Спросите BitNet без доступа в сеть...',
                      hintStyle: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    ),
                  ),
                ),
                // Voice input button
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Голосовой ввод на базе офлайн-распознавания'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.mic,
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                  tooltip: 'Голосовой ввод',
                ),
                // Send button
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _submitMessage,
                    icon: const Icon(
                      Icons.arrow_upward,
                      size: 20,
                      color: AppColors.onPrimary,
                    ),
                    tooltip: 'Отправить',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  fontFamily: AppTypography.sansFont,
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                msg.timestamp,
                style: const TextStyle(
                  fontFamily: AppTypography.monoFont,
                  fontSize: 10,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bot header
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology,
                    size: 14,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'BitNet 1.58b',
                  style: TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Message Bubble Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: const TextStyle(
                      fontFamily: AppTypography.sansFont,
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.onSurface,
                    ),
                  ),
                  if (msg.codeSnippet != null) ...[
                    const SizedBox(height: 12),
                    CodeBlockView(
                      filename: msg.codeFilename ?? 'parser.py',
                      code: msg.codeSnippet!,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Готово! Функция безопасно перехватывает сбои синтаксиса',
                          style: TextStyle(
                            fontFamily: AppTypography.sansFont,
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                  if (msg.isStreaming) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Генерация локальным ядром...',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Telemetry Badge below message
            if (msg.tokensPerSec != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      msg.tokensCount != null ? Icons.check_circle : Icons.bolt,
                      size: 13,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      msg.tokensCount != null
                          ? '${msg.tokensCount} токенов сгенерировано'
                          : '${msg.tokensPerSec} токенов/сек',
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('•', style: TextStyle(color: AppColors.outlineVariant, fontSize: 10)),
                    const SizedBox(width: 6),
                    Text(
                      msg.latencyMs != null ? 'задержка ${msg.latencyMs}мс' : '${msg.tokensPerSec} tok/s',
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (msg.powerWatts != null) ...[
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: AppColors.outlineVariant, fontSize: 10)),
                      const SizedBox(width: 6),
                      Text(
                        '${msg.powerWatts} Вт',
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
