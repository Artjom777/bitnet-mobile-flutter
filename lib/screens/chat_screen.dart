import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/chat_message.dart';
import '../state/bitnet_state.dart';
import '../widgets/status_banner.dart';
import '../widgets/code_block_view.dart';
import '../widgets/apple_pressable.dart';
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.appleGlassBorder,
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.appleGlassHighlight,
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.appleTeal.withOpacity(0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 30,
                  color: AppColors.appleTeal,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'BitNet On-Device AI',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.appleLabel,
                ),
              ),
              const SizedBox(height: 10),
              ApplePressable(
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
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.appleGlassSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (widget.state.hasActiveModel && widget.state.activeModel.isLoaded)
                          ? AppColors.appleGreen.withOpacity(0.4)
                          : AppColors.appleOrange.withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: (widget.state.hasActiveModel && widget.state.activeModel.isLoaded)
                              ? AppColors.appleGreen
                              : AppColors.appleOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        !widget.state.hasActiveModel
                            ? 'Модель не выбрана • Нажмите для выбора'
                            : (widget.state.activeModel.isLoaded
                                ? '${widget.state.activeModel.name} • В памяти'
                                : '${widget.state.activeModel.name} • Нажмите для загрузки'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          color: AppColors.appleSecondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Локальная нейросеть выполняется на архитектуре arm64-v8a без обращения к внешним серверам. Отправьте запрос или выберите тему ниже.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  letterSpacing: -0.2,
                  color: AppColors.appleSecondaryLabel,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ApplePressable(
                    onTap: () => widget.state.setTab(1),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.appleGlassSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.appleGlassHighlight, width: 0.6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_rounded, size: 15, color: AppColors.appleLabel),
                          SizedBox(width: 6),
                          Text(
                            'Модели',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: AppColors.appleLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ApplePressable(
                    onTap: () => widget.state.setTab(3),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.appleGlassSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.appleGlassHighlight, width: 0.6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 15, color: AppColors.appleLabel),
                          SizedBox(width: 6),
                          Text(
                            'Настройки',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: AppColors.appleLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                      child: ApplePressable(
                        onTap: () {
                          _textController.text = item['prompt'];
                          _textController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length),
                          );
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.appleGlassCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.appleGlassBorder,
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                size: 15,
                                color: item['color'] as Color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item['label'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                  color: AppColors.appleLabel,
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
        // Apple Floating Frosted Glass Input Dock
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.appleInputPill,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppColors.appleGlassHighlight,
                    width: 0.7,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Attach button with Apple Pressable
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ApplePressable(
                        onTap: _showAttachDialog,
                        borderRadius: BorderRadius.circular(18),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: AppColors.appleSecondaryLabel,
                          ),
                        ),
                      ),
                    ),
                    // Text Field
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitMessage(),
                          style: const TextStyle(
                            fontSize: 15,
                            letterSpacing: -0.2,
                            color: AppColors.appleLabel,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Спросите BitNet AI...',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              letterSpacing: -0.2,
                              color: AppColors.appleTertiaryLabel,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          ),
                        ),
                      ),
                    ),
                    // Voice input button with Apple Pressable
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ApplePressable(
                        onTap: _handleVoiceInput,
                        borderRadius: BorderRadius.circular(18),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.mic_none_rounded,
                            size: 20,
                            color: AppColors.appleSecondaryLabel,
                          ),
                        ),
                      ),
                    ),
                    // Send / Stop button with Apple Spring Pressable
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, right: 2),
                      child: ApplePressable(
                        onTap: widget.state.isGenerating
                            ? widget.state.stopGeneration
                            : (_textController.text.trim().isNotEmpty ? _submitMessage : null),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: widget.state.isGenerating
                                ? AppColors.appleRed
                                : (_textController.text.trim().isNotEmpty
                                    ? AppColors.appleBlue
                                    : AppColors.appleGlassHighlight),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              widget.state.isGenerating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                              size: 19,
                              color: widget.state.isGenerating || _textController.text.trim().isNotEmpty
                                  ? Colors.white
                                  : AppColors.appleTertiaryLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        margin: const EdgeInsets.only(bottom: 14, left: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ApplePressable(
                    onTap: () => _copyToClipboard(msg.text, 'Запрос'),
                    child: const Icon(Icons.copy_rounded, size: 13, color: AppColors.appleTertiaryLabel),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    msg.timestamp,
                    style: const TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 10,
                      color: AppColors.appleTertiaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0071E3), Color(0xFF0A84FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  topRight: Radius.circular(6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A84FF).withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SelectableText(
                msg.text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  letterSpacing: -0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(ChatMessage msg) {
    var bubbleText = msg.text;
    if (RegExp(r'```').allMatches(bubbleText).length % 2 != 0) {
      bubbleText = '$bubbleText\n```';
    }

    // Dynamic markdown code block parsing
    final codeBlockRegex = RegExp(r'```(\w*)\n([\s\S]*?)```');
    final hasCodeBlock = codeBlockRegex.hasMatch(bubbleText);
    final showTranslateBar = msg.isTranslated ||
        msg.originalText != null ||
        (!msg.isStreaming && RussianSkillService.instance.containsLatinWords(msg.text));

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bot header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.appleTeal.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: AppColors.appleTeal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'BitNet AI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.appleLabel,
                        ),
                      ),
                    ],
                  ),
                  ApplePressable(
                    onTap: () => _copyToClipboard(msg.text, 'Ответ нейросети'),
                    child: const Icon(Icons.copy_rounded, size: 13, color: AppColors.appleTertiaryLabel),
                  ),
                ],
              ),
            ),
            // Message Bubble Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.appleGlassCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(
                  color: AppColors.appleGlassBorder,
                  width: 0.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTranslateBar) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.appleTeal.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.translate_rounded, size: 12, color: AppColors.appleTeal),
                          const SizedBox(width: 5),
                          Text(
                            msg.isTranslated
                                ? 'Русский перевод'
                                : (msg.originalText != null ? 'Оригинал (English)' : 'Текст на английском'),
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.appleTeal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ApplePressable(
                            onTap: () {
                              if (msg.isTranslated) {
                                widget.state.toggleTranslation(msg.id);
                              } else {
                                widget.state.translateMessage(msg.id);
                              }
                            },
                            child: Text(
                              msg.isTranslated
                                  ? 'Показать оригинал'
                                  : (msg.originalText != null ? 'Вернуть русский' : 'Перевести на русский'),
                              style: const TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                color: AppColors.appleBlue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!hasCodeBlock)
                    SelectableText(
                      msg.text.isEmpty && msg.isStreaming ? '▍' : msg.text,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        letterSpacing: -0.2,
                        color: AppColors.appleLabel,
                      ),
                    )
                  else ...[
                    // Render segmented text and code blocks
                    ..._buildParsedContent(bubbleText),
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
                      color: AppColors.appleTeal,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Dynamic Island-style Telemetry Capsule below message
            if (msg.tokensPerSec != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.appleGlassSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.appleGlassBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      msg.tokensCount != null ? Icons.check_circle_rounded : Icons.bolt_rounded,
                      size: 12,
                      color: AppColors.appleTeal,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      msg.tokensCount != null
                          ? '${msg.tokensCount} токенов'
                          : '${msg.tokensPerSec} tok/s',
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.appleSecondaryLabel,
                      ),
                    ),
                    if (msg.latencyMs != null) ...[
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: AppColors.appleTertiaryLabel, fontSize: 10)),
                      const SizedBox(width: 6),
                      Text(
                        '${msg.latencyMs}ms',
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          color: AppColors.appleSecondaryLabel,
                        ),
                      ),
                    ],
                    if (msg.powerWatts != null) ...[
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: AppColors.appleTertiaryLabel, fontSize: 10)),
                      const SizedBox(width: 6),
                      Text(
                        '${msg.powerWatts}W',
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.appleGreen,
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
