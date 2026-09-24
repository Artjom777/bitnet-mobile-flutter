import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../state/bitnet_state.dart';
import '../widgets/apple_pressable.dart';

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
            const Icon(Icons.done_rounded, size: 18, color: AppColors.appleGreen),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.appleLabel,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.appleGlassCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.appleGlassBorder, width: 0.6),
        ),
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
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
        backgroundColor: AppColors.appleGlassCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.appleGlassBorder, width: 0.6),
        ),
        title: const Text(
          'Каталог хранения моделей',
          style: TextStyle(
            color: AppColors.appleLabel,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выберите стандартный путь или задайте свой:',
              style: TextStyle(color: AppColors.appleSecondaryLabel, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...paths.map((p) => ApplePressable(
              onTap: () {
                controller.text = p;
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.folder_rounded, size: 18, color: AppColors.appleTeal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 11,
                          color: AppColors.appleLabel,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(
                fontFamily: AppTypography.monoFont,
                fontSize: 12,
                color: AppColors.appleLabel,
              ),
              decoration: InputDecoration(
                labelText: 'Путь к папке',
                labelStyle: const TextStyle(color: AppColors.appleSecondaryLabel, fontSize: 12),
                filled: true,
                fillColor: AppColors.appleGlassSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.appleGlassBorder, width: 0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          ApplePressable(
            onTap: () => Navigator.pop(ctx),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: const Text('Отмена', style: TextStyle(color: AppColors.appleBlue)),
            ),
          ),
          ApplePressable(
            onTap: () async {
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.appleBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Сохранить',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
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
        // Interactive Apple Header Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.appleGlassBorder,
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.tune_rounded, color: AppColors.appleTeal, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'BITNET LOW-RANK TUNING',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.appleTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Параметры инференса',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.appleLabel,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Тонкая калибровка 1.58-битного ядра под гетерогенные ядра Snapdragon & Dimensity',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  letterSpacing: -0.2,
                  color: AppColors.appleSecondaryLabel,
                ),
              ),
              const SizedBox(height: 14),
              // Micro Hardware Badge Strip
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.appleGlassSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.circle, size: 6, color: AppColors.appleTeal),
                        SizedBox(width: 5),
                        Text(
                          'ARMv9 NEON',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            color: AppColors.appleSecondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.appleGlassSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                    ),
                    child: const Text(
                      'INT8/FP16 Hyb',
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.appleOrange,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.appleGlassSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                    ),
                    child: const Text(
                      'Peak: ~1.2W',
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        color: AppColors.appleSecondaryLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SECTION 1: Engine bitnet.cpp
        _buildSectionHeader('Движок bitnet.cpp', Icons.memory_rounded, AppColors.appleBlue),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
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
                                color: AppColors.appleBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.reorder_rounded, size: 18, color: AppColors.appleBlue),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Количество потоков CPU',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    color: AppColors.appleLabel,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Оптимально для big.LITTLE архитектуры',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.appleSecondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.appleBlue.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${s.cpuThreads} cores',
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.appleBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: s.cpuThreads.toDouble(),
                      min: 1,
                      max: 8,
                      divisions: 7,
                      activeColor: AppColors.appleBlue,
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
                            color: AppColors.appleTertiaryLabel,
                          ),
                        ),
                        Text(
                          '4 (Рекомендуется)',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.appleTeal,
                          ),
                        ),
                        Text(
                          '8 (Max Core)',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            color: AppColors.appleTertiaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.appleGlassBorder),
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
                            color: AppColors.appleTeal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt_rounded, size: 18, color: AppColors.appleTeal),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Набор инструкций',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: AppColors.appleLabel,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'ARM NEON + I8MM ускорение',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.appleSecondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: s.instructionSetEnabled,
                      activeColor: AppColors.appleGreen,
                      onChanged: (v) {
                        widget.state.updateSettings(s.copyWith(instructionSetEnabled: v));
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.appleGlassBorder),
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
                            color: AppColors.appleOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storage_rounded, size: 18, color: AppColors.appleOrange),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Размер контекста',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: AppColors.appleLabel,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Буфер KV-кэша оперативной памяти',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.appleSecondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.appleGlassSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [2048, 4096, 8192].map((ctx) {
                          final isSel = s.contextSize == ctx;
                          return Expanded(
                            child: ApplePressable(
                              onTap: () {
                                widget.state.updateSettings(s.copyWith(contextSize: ctx));
                              },
                              borderRadius: BorderRadius.circular(11),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.appleBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text(
                                    ctx.toString(),
                                    style: TextStyle(
                                      fontFamily: AppTypography.monoFont,
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? Colors.white : AppColors.appleSecondaryLabel,
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
              const Divider(height: 1, color: AppColors.appleGlassBorder),
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
                            color: AppColors.appleBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.memory_rounded, size: 18, color: AppColors.appleBlue),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Аппаратный ускоритель',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: AppColors.appleLabel,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Вычислительный бэкенд (CPU / GPU / NPU)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.appleSecondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.appleGlassSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          {'id': 'cpu', 'name': 'CPU (NEON)'},
                          {'id': 'gpu', 'name': 'GPU (Vulkan)'},
                          {'id': 'npu', 'name': 'NPU (NNAPI)'},
                        ].map((b) {
                          final isSel = s.deviceBackend == b['id'];
                          return Expanded(
                            child: ApplePressable(
                              onTap: () {
                                widget.state.updateSettings(s.copyWith(deviceBackend: b['id']!));
                              },
                              borderRadius: BorderRadius.circular(11),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.appleBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text(
                                    b['name']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? Colors.white : AppColors.appleSecondaryLabel,
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
        const SizedBox(height: 20),

        // SECTION 2: Generation Hyperparameters
        _buildSectionHeader('Параметры генерации', Icons.psychology_rounded, AppColors.appleTeal),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
          ),
          child: Column(
            children: [
              // Temperature Slider
              _buildSliderRow(
                title: 'Temperature',
                subtitle: 'Степень креативности ответов',
                icon: Icons.thermostat_rounded,
                iconColor: AppColors.appleOrange,
                value: s.temperature,
                min: 0.1,
                max: 1.5,
                divisions: 28,
                displayValue: s.temperature.toStringAsFixed(2),
                onChanged: (v) => widget.state.updateSettings(s.copyWith(temperature: v)),
              ),
              const Divider(height: 1, color: AppColors.appleGlassBorder),
              // Top-P Slider
              _buildSliderRow(
                title: 'Top-P',
                subtitle: 'Вероятностная выборка токенов',
                icon: Icons.filter_list_rounded,
                iconColor: AppColors.appleBlue,
                value: s.topP,
                min: 0.1,
                max: 1.0,
                divisions: 18,
                displayValue: s.topP.toStringAsFixed(2),
                onChanged: (v) => widget.state.updateSettings(s.copyWith(topP: v)),
              ),
              const Divider(height: 1, color: AppColors.appleGlassBorder),
              // Repetition Penalty Slider
              _buildSliderRow(
                title: 'Repetition Penalty',
                subtitle: 'Штраф за цикличность фраз',
                icon: Icons.replay_rounded,
                iconColor: AppColors.appleTeal,
                value: s.repetitionPenalty,
                min: 1.0,
                max: 1.5,
                divisions: 25,
                displayValue: s.repetitionPenalty.toStringAsFixed(2),
                onChanged: (v) => widget.state.updateSettings(s.copyWith(repetitionPenalty: v)),
              ),
              const Divider(height: 1, color: AppColors.appleGlassBorder),
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
                                color: AppColors.appleTeal.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.short_text_rounded, size: 18, color: AppColors.appleTeal),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Максимум токенов',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    color: AppColors.appleLabel,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Длина генерации (128 — 4096 токенов)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.appleSecondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.appleTeal.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            s.maxTokens.toString(),
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.appleTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.appleGlassSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [256, 512, 1024, 2048, 4096].map((tok) {
                          final isSel = s.maxTokens == tok;
                          return Expanded(
                            child: ApplePressable(
                              onTap: () {
                                widget.state.updateSettings(s.copyWith(maxTokens: tok));
                              },
                              borderRadius: BorderRadius.circular(11),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.appleTeal : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text(
                                    tok.toString(),
                                    style: TextStyle(
                                      fontFamily: AppTypography.monoFont,
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? Colors.white : AppColors.appleSecondaryLabel,
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
              const Divider(height: 1, color: AppColors.appleGlassBorder),
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
                            color: AppColors.appleBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.appleBlue),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Системный промпт',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: AppColors.appleLabel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.appleGlassSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _promptController,
                            maxLines: 3,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.appleLabel,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Задайте роль ассистента...',
                              hintStyle: TextStyle(color: AppColors.appleTertiaryLabel),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                          Text(
                            '${_promptController.text.length} символов',
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 10,
                              color: AppColors.appleTertiaryLabel,
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
        ),
        const SizedBox(height: 20),

        // SECTION 2.5: Russian Polyglot Skill
        _buildSectionHeader('НАВЫК РУССКОГО ЯЗЫКА (POLYGLOT)', Icons.translate_rounded, AppColors.appleTeal),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
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
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.appleTeal.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.translate_rounded, size: 18, color: AppColors.appleTeal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Навык русского языка',
                                      style: AppTypography.appleBody.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.appleLabel,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.appleTeal.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'ACTIVE',
                                        style: AppTypography.appleCaption.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.appleTeal,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Позволяет англоязычным моделям BitNet понимать запросы на русском и отвечать на русском',
                                  style: AppTypography.appleCaption.copyWith(
                                    color: AppColors.appleSecondaryLabel,
                                    height: 1.2,
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
                      activeColor: AppColors.appleGreen,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.appleGlassBorder, indent: 64),
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
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.appleBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_stories_rounded, size: 18, color: AppColors.appleBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Автоперевод ответов в русский',
                                  style: AppTypography.appleBody.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.appleLabel,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Если модель генерирует ответ на английском, навык адаптирует его на чистый русский',
                                  style: AppTypography.appleCaption.copyWith(
                                    color: AppColors.appleSecondaryLabel,
                                    height: 1.2,
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
                      activeColor: AppColors.appleGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SECTION 3: Autonomy and Privacy
        _buildSectionHeader('АВТОНОМНОСТЬ И ПРИВАТНОСТЬ', Icons.shield_rounded, AppColors.appleGreen),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 100% Offline Switch
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.appleGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.airplanemode_active_rounded,
                              size: 18,
                              color: AppColors.appleGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '100% Офлайн режим',
                                      style: AppTypography.appleBody.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.appleLabel,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.appleGreen.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'SAFE',
                                        style: AppTypography.appleCaption.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.appleGreen,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Блокирует любые внешние сетевые сокеты',
                                  style: AppTypography.appleCaption.copyWith(
                                    color: AppColors.appleSecondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.offlineMode,
                      activeColor: AppColors.appleGreen,
                      onChanged: (v) {
                        widget.state.updateSettings(s.copyWith(offlineMode: v));
                        _showFloatingToast(v ? 'Офлайн режим включен' : 'Офлайн режим отключен');
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.appleGlassBorder, indent: 64),
              // Wakelock Switch
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.appleOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: AppColors.appleOrange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wakelock CPU',
                                  style: AppTypography.appleBody.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.appleLabel,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Держать CPU активным во время фоновых генераций',
                                  style: AppTypography.appleCaption.copyWith(
                                    color: AppColors.appleSecondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.wakelock,
                      activeColor: AppColors.appleGreen,
                      onChanged: (v) {
                        widget.state.updateSettings(s.copyWith(wakelock: v));
                        _showFloatingToast(v ? 'Wakelock CPU активирован' : 'Wakelock CPU отключен');
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.appleGlassBorder, indent: 64),
              // Model Storage Folder
              ApplePressable(
                onTap: _showChangeDirectoryDialog,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.appleBlue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.folder_rounded, size: 18, color: AppColors.appleBlue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Папка для моделей',
                                    style: AppTypography.appleBody.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.appleLabel,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.modelsDirectory,
                                    style: AppTypography.appleCaption.copyWith(
                                      fontFamily: AppTypography.monoFont,
                                      color: AppColors.appleBlue,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.appleTertiaryLabel, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Micro Diagnostics Glass Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.appleGlassSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.memory_rounded, color: AppColors.appleTeal, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated VRAM / Weights:',
                    style: AppTypography.appleCaption.copyWith(
                      fontFamily: AppTypography.monoFont,
                      color: AppColors.appleSecondaryLabel,
                    ),
                  ),
                ],
              ),
              Text(
                '1.18 GB',
                style: AppTypography.appleCaption.copyWith(
                  fontFamily: AppTypography.monoFont,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.appleTeal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Bottom CTA Actions
        ApplePressable(
          onTap: _applySettings,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.appleBlue, Color(0xFF0056B3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.appleBlue.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Применить настройки',
                  style: AppTypography.appleHeadline.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ApplePressable(
          onTap: _resetDefaults,
          borderRadius: BorderRadius.circular(23),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.appleGlassSurface,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restart_alt_rounded, size: 18, color: AppColors.appleSecondaryLabel),
                const SizedBox(width: 8),
                Text(
                  'Сбросить по умолчанию',
                  style: AppTypography.appleCallout.copyWith(
                    color: AppColors.appleSecondaryLabel,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTypography.appleCaption.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.appleSecondaryLabel,
            ),
          ),
        ],
      ),
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.appleBody.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.appleLabel,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTypography.appleCaption.copyWith(
                              color: AppColors.appleSecondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.appleGlassSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
                ),
                child: Text(
                  displayValue,
                  style: AppTypography.appleCaption.copyWith(
                    fontFamily: AppTypography.monoFont,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: iconColor,
              inactiveTrackColor: Colors.white.withOpacity(0.08),
              thumbColor: Colors.white,
              overlayColor: iconColor.withOpacity(0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

