import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/chat_message.dart';
import '../state/bitnet_state.dart';
import '../widgets/status_banner.dart';
import '../widgets/code_block_view.dart';
import '../services/russian_skill_service.dart';
import 'file_picker_screen.dart';

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
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
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
    if (text.isEmpty || widget.state.isGenerating) return;

    if (!widget.state.hasActiveModel || !widget.state.activeModel.isLoaded) {
      final loaded = widget.state.loadBuiltinModel();
      if (!loaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Загрузите модель в память для начала генерации'),
            action: SnackBarAction(
              label: 'Модели',
              onPressed: () => widget.state.setTab(1),
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: AppColors.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    _textController.clear();
    widget.state.sendMessage(text);
    _scrollToBottom();
  }

  void _showAttachDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Прикрепить контекст к запросу',
                style: TextStyle(
                  fontFamily: AppTypography.sansFont,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.psychology, color: AppColors.primary),
                title: const Text('Системный промпт', style: TextStyle(color: AppColors.onSurface)),
                subtitle: Text(
                  widget.state.settings.systemPrompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _textController.text = '[Системный контекст: ${widget.state.settings.systemPrompt}]\n' + _textController.text;
                },
              ),
              ListTile(
                leading: const Icon(Icons.code, color: AppColors.secondary),
                title: const Text('Структурированные входные данные (JSON)', style: TextStyle(color: AppColors.onSurface)),
                subtitle: const Text('Добавить шаблон JSON для анализа ИИ', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _textController.text = _textController.text + '\n```json\n{"mode": "ternary", "quantization": "1.58b", "arch": "arm64-v8a"}\n```';
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open, color: AppColors.tertiary),
                title: const Text('Выбрать модель / веса (SAF)', style: TextStyle(color: AppColors.onSurface)),
                subtitle: const Text('Открыть менеджер локальных моделей', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FilePickerScreen(state: widget.state),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleVoiceInput() {
    final sampleVoicePrompts = [
      'Объясни троичное квантование 1.58-бит и векторные сложения GEMM ADD',
      'Как оптимизировать работу BitNet на процессорах ARM Cortex-X4?',
      'Напиши пример кода на C++ для загрузки весов GGUF в память',
      'Сравни энергопотребление BitNet b1.58 и стандартных моделей FP16',
    ];
    final selectedPrompt = sampleVoicePrompts[DateTime.now().second % sampleVoicePrompts.length];
    _textController.text = selectedPrompt;
    _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.mic, color: AppColors.secondary, size: 18),
            SizedBox(width: 8),
            Text(
              'Распознан голосовой запрос',
              style: TextStyle(
                fontFamily: AppTypography.monoFont,
                fontSize: 12,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildEmptyChatView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'BitNet On-Device AI',
              style: TextStyle(
                fontFamily: AppTypography.sansFont,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                if (widget.state.hasActiveModel && !widget.state.activeModel.isLoaded) {
                  if (widget.state.activeModel.filename.startsWith('builtin://')) {
                    widget.state.loadBuiltinModel();
                  } else {
                    final file = File(widget.state.activeModel.filename);
                    if (file.existsSync()) {
                      widget.state.loadModel(widget.state.activeModel);
                    } else {
                      widget.state.setTab(1);
                    }
                  }
                } else {
                  widget.state.setTab(1);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (widget.state.hasActiveModel && widget.state.activeModel.isLoaded)
                        ? AppColors.secondary.withOpacity(0.35)
                        : AppColors.error.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: (widget.state.hasActiveModel && widget.state.activeModel.isLoaded)
                            ? AppColors.secondary
                            : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      !widget.state.hasActiveModel
                          ? 'Модель не выбрана • Нажмите для выбора'
                          : (widget.state.activeModel.isLoaded
                              ? '${widget.state.activeModel.name} • В памяти'
                              : '${widget.state.activeModel.name} • Не загружена в ОЗУ'),
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Чат чист. Локальная нейросеть выполняется на архитектуре arm64-v8a без обращения к внешним серверам. Отправьте запрос или выберите тему ниже.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.sansFont,
                fontSize: 13,
                height: 1.45,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.state.setTab(1),
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Модели'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    side: const BorderSide(color: AppColors.outlineVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => widget.state.setTab(3),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Настройки'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    side: const BorderSide(color: AppColors.outlineVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Dynamic Hardware & Inference Status Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            children: [
              StatusBanner(state: widget.state),
              if (widget.state.messages.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      widget.state.clearMessages();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('История чата очищена'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_sweep, size: 16, color: AppColors.onSurfaceVariant),
                    label: const Text(
                      'Очистить чат',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Messages Scroll Area or Empty View
        Expanded(
          child: widget.state.messages.isEmpty
              ? _buildEmptyChatView()
              : ListView.builder(
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
                          setState(() {});
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach button
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: IconButton(
                    onPressed: _showAttachDialog,
                    icon: const Icon(
                      Icons.attach_file,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                    tooltip: 'Прикрепить контекст',
                  ),
                ),
                // Text Field
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
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
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                    ),
                  ),
                ),
                // Voice input button
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: IconButton(
                    onPressed: _handleVoiceInput,
                    icon: const Icon(
                      Icons.mic,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                    tooltip: 'Голосовой ввод',
                  ),
                ),
                // Send / Stop button
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.state.isGenerating
                          ? AppColors.error
                          : (_textController.text.trim().isNotEmpty
                              ? AppColors.primary
                              : AppColors.surfaceContainerHighest),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: widget.state.isGenerating
                          ? widget.state.stopGeneration
                          : (_textController.text.trim().isNotEmpty ? _submitMessage : null),
                      icon: Icon(
                        widget.state.isGenerating ? Icons.stop_rounded : Icons.arrow_upward,
                        size: 20,
                        color: widget.state.isGenerating
                            ? AppColors.onError
                            : (_textController.text.trim().isNotEmpty
                                ? AppColors.onPrimary
                                : AppColors.onSurfaceVariant.withOpacity(0.38)),
                      ),
                      tooltip: widget.state.isGenerating ? 'Остановить' : 'Отправить',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label скопирован в буфер обмена'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 14, color: AppColors.onSurfaceVariant),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Копировать',
                  onPressed: () => _copyToClipboard(msg.text, 'Запрос'),
                ),
                const SizedBox(width: 6),
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
            const SizedBox(height: 4),
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
              child: SelectableText(
                msg.text,
                style: const TextStyle(
                  fontFamily: AppTypography.sansFont,
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(ChatMessage msg) {
    // Dynamic markdown code block parsing
    final codeBlockRegex = RegExp(r'```(\w*)\n([\s\S]*?)```');
    final hasCodeBlock = codeBlockRegex.hasMatch(msg.text);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bot header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                IconButton(
                  icon: const Icon(Icons.copy, size: 14, color: AppColors.onSurfaceVariant),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Копировать ответ',
                  onPressed: () => _copyToClipboard(msg.text, 'Ответ нейросети'),
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
                  if (msg.isTranslated || msg.originalText != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.translate, size: 12, color: AppColors.secondary),
                          const SizedBox(width: 5),
                          Text(
                            msg.isTranslated ? 'Русский перевод' : 'Оригинал (English)',
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                          if (msg.originalText != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => widget.state.toggleTranslation(msg.id),
                              child: Text(
                                msg.isTranslated ? 'Показать оригинал' : 'Вернуть русский',
                                style: const TextStyle(
                                  fontFamily: AppTypography.monoFont,
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (!hasCodeBlock)
                    SelectableText(
                      msg.text.isEmpty && msg.isStreaming ? '▍' : msg.text,
                      style: const TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.onSurface,
                      ),
                    )
                  else ...[
                    // Render segmented text and code blocks
                    ..._buildParsedContent(msg.text),
                  ],
                  if (msg.codeSnippet != null && !hasCodeBlock) ...[
                    const SizedBox(height: 12),
                    CodeBlockView(
                      filename: msg.codeFilename ?? 'kernel.cpp',
                      code: msg.codeSnippet!,
                    ),
                  ],
                  if (msg.isStreaming && msg.text.isEmpty) ...[
                    Container(
                      width: 8,
                      height: 16,
                      color: AppColors.primary,
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

  List<Widget> _buildParsedContent(String text) {
    final widgets = <Widget>[];
    final regex = RegExp(r'```(\w*)\n([\s\S]*?)```');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        final plain = text.substring(lastIndex, match.start).trim();
        if (plain.isNotEmpty) {
          widgets.add(
            SelectableText(
              plain,
              style: const TextStyle(
                fontFamily: AppTypography.sansFont,
                fontSize: 14,
                height: 1.5,
                color: AppColors.onSurface,
              ),
            ),
          );
          widgets.add(const SizedBox(height: 10));
        }
      }
      final lang = match.group(1) ?? 'code';
      final code = match.group(2) ?? '';
      widgets.add(
        CodeBlockView(
          filename: lang.isEmpty ? 'snippet.txt' : 'snippet.$lang',
          code: code.trim(),
        ),
      );
      widgets.add(const SizedBox(height: 10));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        widgets.add(
          SelectableText(
            remaining,
            style: const TextStyle(
              fontFamily: AppTypography.sansFont,
              fontSize: 14,
              height: 1.5,
              color: AppColors.onSurface,
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
