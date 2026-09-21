import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../state/bitnet_state.dart';

class SettingsScreen extends StatefulWidget {
  final BitNetState state;

  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(
      text: widget.state.settings.systemPrompt,
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _showFloatingToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.done, size: 18, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                fontFamily: AppTypography.monoFont,
                fontSize: 12,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applySettings() {
    widget.state.updateSettings(
      widget.state.settings.copyWith(systemPrompt: _promptController.text),
    );
    _showFloatingToast('Параметры инференса обновлены');
  }

  void _resetDefaults() {
    widget.state.resetSettings();
    _promptController.text = widget.state.settings.systemPrompt;
    _showFloatingToast('Значения возвращены по умолчанию');
  }

  void _showChangeDirectoryDialog() {
    final paths = [
      '/sdcard/Download/BitNet',
      '/sdcard/BitNet/models',
      '/data/data/com.bitnet.ai/files/models',
      '${Directory.systemTemp.path}/bitnet_models',
    ];
    final controller = TextEditingController(text: widget.state.settings.modelsDirectory);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Каталог хранения моделей', style: TextStyle(color: AppColors.onSurface, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите стандартный путь или задайте свой:', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 8),
            ...paths.map((p) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder, size: 18, color: AppColors.primary),
              title: Text(p, style: const TextStyle(fontFamily: AppTypography.monoFont, fontSize: 11, color: AppColors.onSurface)),
              onTap: () {
                controller.text = p;
              },
            )),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(fontFamily: AppTypography.monoFont, fontSize: 12, color: AppColors.onSurface),
              decoration: InputDecoration(
                labelText: 'Путь к папке',
                labelStyle: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPath = controller.text.trim();
              if (newPath.isNotEmpty) {
                try {
                  final d = Directory(newPath);
                  if (!await d.exists()) {
                    await d.create(recursive: true);
                  }
                } catch (_) {}
                widget.state.updateSettings(widget.state.settings.copyWith(modelsDirectory: newPath));
                widget.state.scanLocalModelFiles();
                Navigator.pop(ctx);
                _showFloatingToast('Каталог обновлен: $newPath');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Interactive Header Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: -10,
                child: Opacity(
                  opacity: 0.12,
                  child: const Icon(
                    Icons.developer_board,
                    size: 90,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.tune, color: AppColors.secondary, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'BITNET LOW-RANK TUNING',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Параметры инференса',
                    style: TextStyle(
                      fontFamily: AppTypography.sansFont,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Тонкая калибровка 1.58-битного ядра под гетерогенные ядра Snapdragon & Dimensity',
                    style: TextStyle(
                      fontFamily: AppTypography.sansFont,
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Micro Hardware Badge Strip
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.circle, size: 6, color: AppColors.secondary),
                            SizedBox(width: 4),
                            Text(
                              'ARMv9 NEON',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'INT8/FP16 Hyb',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            color: AppColors.tertiary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Peak: ~1.2W',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // SECTION 1: Engine bitnet.cpp
        _buildSectionHeader('Движок bitnet.cpp', Icons.memory, AppColors.primary),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // CPU Threads Slider
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.reorder, size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Количество потоков CPU',
                                  style: TextStyle(
                                    fontFamily: AppTypography.sansFont,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Оптимально для big.LITTLE архитектуры',
                                  style: TextStyle(
                                    fontFamily: AppTypography.sansFont,
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${s.cpuThreads} cores',
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: s.cpuThreads.toDouble(),
                      min: 1,
                      max: 8,
                      divisions: 7,
                      onChanged: (v) {
                        widget.state.updateSettings(s.copyWith(cpuThreads: v.toInt()));
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '1 (Энергоэффект)',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '4 (Рекомендуется)',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                        Text(
                          '8 (Max Core)',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // Instruction Set Toggle
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt, size: 18, color: AppColors.secondary),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Набор инструкций',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'ARM NEON + I8MM ускорение',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: s.instructionSetEnabled,
                      onChanged: (v) {
                        widget.state.updateSettings(s.copyWith(instructionSetEnabled: v));
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // Context Size Pill Selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storage, size: 18, color: AppColors.tertiary),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Размер контекста',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'Буфер KV-кэша оперативной памяти',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [2048, 4096, 8192].map((ctx) {
                          final isSel = s.contextSize == ctx;
                          return Expanded(
                            child: InkWell(
                              onTap: () {
                                widget.state.updateSettings(s.copyWith(contextSize: ctx));
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primaryContainer : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    ctx.toString(),
                                    style: TextStyle(
                                      fontFamily: AppTypography.monoFont,
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      color: isSel ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                                    ),
                                  ),
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
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // Accelerator Backend Selector (CPU / GPU / NPU)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.memory, size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Аппаратный ускоритель',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'Вычислительный бэкенд (CPU / GPU / NPU)',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          {'id': 'cpu', 'name': 'CPU (NEON)'},
                          {'id': 'gpu', 'name': 'GPU (Vulkan)'},
                          {'id': 'npu', 'name': 'NPU (NNAPI)'},
                        ].map((b) {
                          final isSel = s.deviceBackend == b['id'];
                          return Expanded(
                            child: InkWell(
                              onTap: () {
                                widget.state.updateSettings(s.copyWith(deviceBackend: b['id']!));
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primaryContainer : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    b['name']!,
                                    style: TextStyle(
                                      fontFamily: AppTypography.monoFont,
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      color: isSel ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                                    ),
                                  ),
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
            ],
          ),
        ),
        const SizedBox(height: 18),

        // SECTION 2: Generation Hyperparameters
        _buildSectionHeader('Параметры генерации', Icons.psychology, AppColors.secondary),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Temperature Slider
              _buildSliderRow(
                title: 'Temperature',
                subtitle: 'Степень креативности ответов',
                icon: Icons.thermostat,
                iconColor: AppColors.secondary,
                value: s.temperature,
                min: 0.1,
                max: 1.5,
                divisions: 28,
                displayValue: s.temperature.toStringAsFixed(2),
                onChanged: (v) => widget.state.updateSettings(s.copyWith(temperature: v)),
              ),
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // Top-P Slider
              _buildSliderRow(
                title: 'Top-P',
                subtitle: 'Вероятностная выборка токенов',
                icon: Icons.filter_list,
                iconColor: AppColors.primary,
                value: s.topP,
                min: 0.1,
                max: 1.0,
                divisions: 18,
                displayValue: s.topP.toStringAsFixed(2),
                onChanged: (v) => widget.state.updateSettings(s.copyWith(topP: v)),
              ),
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // Repetition Penalty Slider
              _buildSliderRow(
                title: 'Repetition Penalty',
                subtitle: 'Штраф за цикличность фраз',
                icon: Icons.replay,
                iconColor: AppColors.tertiary,
                value: s.repetitionPenalty,
                min: 1.0,
                max: 1.5,
                divisions: 25,
                displayValue: s.repetitionPenalty.toStringAsFixed(2),
                onChanged: (v) => widget.state.updateSettings(s.copyWith(repetitionPenalty: v)),
              ),
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // Max Output Tokens Selector (128 .. 4096)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.short_text, size: 18, color: AppColors.secondary),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Максимум токенов',
                                  style: TextStyle(
                                    fontFamily: AppTypography.sansFont,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Длина генерации (128 — 4096 токенов)',
                                  style: TextStyle(
                                    fontFamily: AppTypography.sansFont,
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          s.maxTokens.toString(),
                          style: const TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [256, 512, 1024, 2048, 4096].map((tok) {
                          final isSel = s.maxTokens == tok;
                          return Expanded(
                            child: InkWell(
                              onTap: () {
                                widget.state.updateSettings(s.copyWith(maxTokens: tok));
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.secondaryContainer : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    tok.toString(),
                                    style: TextStyle(
                                      fontFamily: AppTypography.monoFont,
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      color: isSel ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                                    ),
                                  ),
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
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // System Prompt
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.smart_toy, size: 18, color: AppColors.primaryFixedDim),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Системный промпт',
                          style: TextStyle(
                            fontFamily: AppTypography.sansFont,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _promptController,
                            maxLines: 3,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontFamily: AppTypography.sansFont,
                              fontSize: 13,
                              color: AppColors.onSurface,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Задайте роль ассистента...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                          Text(
                            '${_promptController.text.length} символов',
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 18),

        // SECTION 2.5: Russian Polyglot Skill
        _buildSectionHeader('Навык русского языка (Polyglot)', Icons.language, AppColors.secondary),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Russian Skill Switch
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.translate, size: 18, color: AppColors.secondary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Навык русского языка',
                                      style: TextStyle(
                                        fontFamily: AppTypography.sansFont,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Active',
                                        style: TextStyle(
                                          fontFamily: AppTypography.monoFont,
                                          fontSize: 9,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Позволяет англоязычным моделям BitNet понимать запросы на русском и отвечать на русском',
                                  style: TextStyle(
                                    fontFamily: AppTypography.sansFont,
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.russianSkillEnabled,
                      onChanged: (v) {
                        widget.state.updateSettings(s.copyWith(russianSkillEnabled: v));
                      },
                      activeColor: AppColors.secondary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // Auto-Translate Output Switch
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_stories, size: 18, color: AppColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Автоперевод ответов в русский',
                                  style: TextStyle(
                                    fontFamily: AppTypography.sansFont,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Если модель генерирует ответ на английском, навык адаптирует его на чистый русский',
                                  style: TextStyle(
                                    fontFamily: AppTypography.sansFont,
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.autoTranslateToRussian,
                      onChanged: (v) {
                        widget.state.updateSettings(s.copyWith(autoTranslateToRussian: v));
                      },
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // SECTION 3: Autonomy and Privacy
        _buildSectionHeader('Автономность и приватность', Icons.verified_user, AppColors.tertiary),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // 100% Offline Switch
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.airplanemode_active,
                            size: 18,
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '100% Офлайн режим',
                                  style: TextStyle(
                                    fontFamily: AppTypography.sansFont,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Safe',
                                    style: TextStyle(
                                      fontFamily: AppTypography.monoFont,
                                      fontSize: 9,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Блокирует любые внешние сетевые сокеты',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: s.offlineMode,
                      activeColor: AppColors.secondary,
                      onChanged: (v) {
                        widget.state.updateSettings(s.copyWith(offlineMode: v));
                        _showFloatingToast(v ? 'Офлайн режим включен' : 'Офлайн режим отключен');
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // Wakelock Switch
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.screen_lock_portrait,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Wakelock',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'Держать CPU активным во время длинных генераций',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: s.wakelock,
                      onChanged: (v) {
                        widget.state.updateSettings(s.copyWith(wakelock: v));
                        _showFloatingToast(v ? 'Wakelock CPU активирован' : 'Wakelock CPU отключен');
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              // Model Storage Folder
              InkWell(
                onTap: _showChangeDirectoryDialog,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.folder_open, size: 18, color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Папка для моделей',
                                style: TextStyle(
                                  fontFamily: AppTypography.sansFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                s.modelsDirectory,
                                style: const TextStyle(
                                  fontFamily: AppTypography.monoFont,
                                  fontSize: 10,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Micro Diagnostics Floating Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.terminal, color: AppColors.secondary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Estimated VRAM / Weights:',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Text(
                '1.18 GB',
                style: TextStyle(
                  fontFamily: AppTypography.monoFont,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Bottom CTA Actions
        ElevatedButton.icon(
          onPressed: _applySettings,
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text(
            'Применить настройки',
            style: TextStyle(
              fontFamily: AppTypography.sansFont,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _resetDefaults,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text(
            'Сбросить по умолчанию',
            style: TextStyle(
              fontFamily: AppTypography.sansFont,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerHigh,
            foregroundColor: AppColors.onSurfaceVariant,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTypography.monoFont,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppTypography.sansFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: AppTypography.sansFont,
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: iconColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
