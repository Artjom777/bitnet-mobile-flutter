import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../state/bitnet_state.dart';
import '../widgets/waveform_equalizer.dart';
import '../widgets/apple_pressable.dart';

class MonitoringScreen extends StatefulWidget {
  final BitNetState state;

  const MonitoringScreen({super.key, required this.state});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _logCopied = false;

  void _copyLog() async {
    final buffer = StringBuffer();
    for (final log in widget.state.terminalLogs) {
      buffer.writeln('${log['tag']}: ${log['text']}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    setState(() => _logCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Лог инференса скопирован в буфер обмена'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.appleGlassCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _logCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // 1. Generation Speed Live Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.appleGlassBorder,
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bolt_rounded, color: AppColors.appleTeal, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'СКОРОСТЬ ГЕНЕРАЦИИ',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.appleSecondaryLabel,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.appleGlassSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.appleGreen.withOpacity(0.35),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.circle, size: 6, color: AppColors.appleGreen),
                        SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.appleGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Speed & TTFT
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        widget.state.liveTokSpeed.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          color: AppColors.appleLabel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ток/сек',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.appleSecondaryLabel,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TTFT (отклик)',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          color: AppColors.appleTertiaryLabel,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.state.ttftMs} мс',
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.appleTeal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Animated Waveform Equalizer
              WaveformEqualizer(heights: widget.state.waveformHeights),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.circle, size: 6, color: AppColors.appleTeal),
                      SizedBox(width: 5),
                      Text(
                        'Квантование: i1_s (Ternary)',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          color: AppColors.appleSecondaryLabel,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Слот контекста: 142 / 2048',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 10,
                      color: AppColors.appleSecondaryLabel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. RAM Consumption Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.appleGlassBorder,
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.memory_rounded, color: AppColors.appleTeal, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Оперативная память',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: AppColors.appleLabel,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.appleGreen.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '-78% экономия',
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.appleGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text.rich(
                    TextSpan(
                      text: '${widget.state.ramUsedGb} ГБ ',
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.appleLabel,
                      ),
                      children: [
                        TextSpan(
                          text: '/ ${widget.state.ramTotalGb.toInt()}.0 ГБ',
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                            color: AppColors.appleSecondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${((widget.state.ramUsedGb / widget.state.ramTotalGb) * 100).toStringAsFixed(1)}% занято',
                    style: const TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.appleTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Segmented Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: AppColors.appleGlassHighlight,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (widget.state.ramUsedGb / widget.state.ramTotalGb).clamp(0.0, 1.0),
                    child: Container(
                      color: AppColors.appleTeal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Comparison container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.appleGlassSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.circle, size: 6, color: AppColors.appleTeal),
                            SizedBox(width: 8),
                            Text(
                              'Модель BitNet b1.58 (3B)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.appleSecondaryLabel,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          '1.42 ГБ',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.appleLabel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.circle, size: 6, color: AppColors.appleTertiaryLabel),
                            SizedBox(width: 8),
                            Text(
                              'Аналог FP16 (Без тернарности)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.appleTertiaryLabel,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          '6.80 ГБ',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.appleTertiaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. 2-Column Grid (Temperature & Instructions)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.appleGlassCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Icon(Icons.device_thermostat_rounded, color: AppColors.appleOrange, size: 20),
                        Text(
                          'Холодный',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.appleGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Температура',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.appleSecondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '34.2°C',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                        color: AppColors.appleLabel,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Без перегрева при вычислениях i2_s',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.appleTertiaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.appleGlassCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Icon(Icons.hardware_rounded, color: AppColors.appleBlue, size: 20),
                        Text(
                          'ARM Neon',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.appleBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Инструкции',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.appleSecondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'GEMM ADD',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                        color: AppColors.appleLabel,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Сложение весов без умножения',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.appleTertiaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. CPU Threads Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.hub_rounded, color: AppColors.appleBlue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Потоки процессора',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: AppColors.appleLabel,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '4 / 8 ядер',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 11,
                      color: AppColors.appleSecondaryLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildCoreRow('Поток 0 (Cortex-X4 Prime)', 0.74, '74%', AppColors.appleBlue),
              const SizedBox(height: 10),
              _buildCoreRow('Поток 1 (Cortex-A720 Perf)', 0.68, '68%', AppColors.appleTeal),
              const SizedBox(height: 10),
              _buildCoreRow('Поток 2 (Cortex-A720 Perf)', 0.62, '62%', AppColors.appleTeal),
              const SizedBox(height: 10),
              _buildCoreRow('Поток 3 (Cortex-A720 Perf)', 0.59, '59%', AppColors.appleTeal),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. bitnet.cpp Terminal Log
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.terminal_rounded, color: AppColors.appleSecondaryLabel, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Лог bitnet.cpp',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: AppColors.appleLabel,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ApplePressable(
                        onTap: () {
                          widget.state.clearLogs();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Логи очищены'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.appleGlassSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.delete_sweep_rounded, size: 13, color: AppColors.appleSecondaryLabel),
                              SizedBox(width: 4),
                              Text(
                                'Очистить',
                                style: TextStyle(
                                  fontFamily: AppTypography.monoFont,
                                  fontSize: 10,
                                  color: AppColors.appleSecondaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ApplePressable(
                        onTap: _copyLog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.appleGlassSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _logCopied ? Icons.check_rounded : Icons.content_copy_rounded,
                                size: 13,
                                color: _logCopied ? AppColors.appleGreen : AppColors.appleSecondaryLabel,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _logCopied ? 'Скопировано' : 'Копия',
                                style: TextStyle(
                                  fontFamily: AppTypography.monoFont,
                                  fontSize: 10,
                                  color: _logCopied ? AppColors.appleGreen : AppColors.appleSecondaryLabel,
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
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.appleBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.appleGlassBorder,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.state.terminalLogs.map((log) {
                    Color tagColor = AppColors.appleTeal;
                    if (log['color'] == 'primary') tagColor = AppColors.appleBlue;
                    if (log['color'] == 'tertiary') tagColor = AppColors.appleOrange;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '${log['tag']}: ',
                            style: TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tagColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              log['text']!,
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
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 6. Inference Optimization Toggles
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.appleGlassCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Оптимизация инференса',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: AppColors.appleLabel,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: widget.state.settings.cpuFreqLock,
                activeColor: AppColors.appleGreen,
                onChanged: (v) {
                  widget.state.updateSettings(
                    widget.state.settings.copyWith(cpuFreqLock: v),
                  );
                },
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Фиксация частоты CPU',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: AppColors.appleLabel,
                  ),
                ),
                subtitle: const Text(
                  'Предотвращает троттлинг на длинных сессиях',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.appleSecondaryLabel,
                  ),
                ),
              ),
              const Divider(color: AppColors.appleGlassBorder, height: 16),
              SwitchListTile(
                value: widget.state.settings.lowPowerMode,
                activeColor: AppColors.appleGreen,
                onChanged: (v) {
                  widget.state.updateSettings(
                    widget.state.settings.copyWith(lowPowerMode: v),
                  );
                },
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Низкое энергопотребление',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: AppColors.appleLabel,
                  ),
                ),
                subtitle: const Text(
                  'Ограничение до 2 энергоэффективных потоков',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.appleSecondaryLabel,
                  ),
                ),
              ),
              const Divider(color: AppColors.appleGlassBorder, height: 16),
              SwitchListTile(
                value: widget.state.settings.backgroundExecution,
                activeColor: AppColors.appleGreen,
                onChanged: (v) {
                  widget.state.updateSettings(
                    widget.state.settings.copyWith(backgroundExecution: v),
                  );
                },
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Фоновый режим работы',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: AppColors.appleLabel,
                  ),
                ),
                subtitle: const Text(
                  'Держать контекст тернарных весов в памяти',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.appleSecondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoreRow(String title, double factor, String percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: AppTypography.monoFont,
                fontSize: 11,
                color: AppColors.appleLabel,
              ),
            ),
            Text(
              percent,
              style: TextStyle(
                fontFamily: AppTypography.monoFont,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 5,
            width: double.infinity,
            color: AppColors.appleGlassHighlight,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: factor,
              child: Container(
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
