import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../state/bitnet_state.dart';
import '../widgets/waveform_equalizer.dart';

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
        backgroundColor: AppColors.surfaceContainerHighest,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
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
                      Icon(Icons.bolt, color: AppColors.primary, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'СКОРОСТЬ ГЕНЕРАЦИИ',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.circle, size: 6, color: AppColors.secondary),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSecondaryContainer,
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
                          fontFamily: AppTypography.sansFont,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'ток/сек',
                        style: TextStyle(
                          fontFamily: AppTypography.sansFont,
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
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
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${widget.state.ttftMs} мс',
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Animated Waveform Equalizer
              WaveformEqualizer(heights: widget.state.waveformHeights),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.circle, size: 6, color: AppColors.secondary),
                      SizedBox(width: 4),
                      Text(
                        'Квантование: i1_s (Ternary)',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Слот контекста: 142 / 2048',
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
        const SizedBox(height: 14),

        // 2. RAM Consumption Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.memory, color: AppColors.secondary, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Оперативная память',
                        style: TextStyle(
                          fontFamily: AppTypography.sansFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '-78% экономия',
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSecondaryFixed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                        color: AppColors.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: '/ ${widget.state.ramTotalGb.toInt()}.0 ГБ',
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '17.5% занято',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Segmented Progress Bar
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryContainer.withOpacity(0.5),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Comparison container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.circle, size: 6, color: AppColors.secondary),
                            SizedBox(width: 6),
                            Text(
                              'Модель BitNet b1.58 (3B)',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          '1.42 ГБ',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.circle, size: 6, color: AppColors.outline),
                            SizedBox(width: 6),
                            Text(
                              'Аналог FP16 (Без тернарности)',
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          '6.80 ГБ',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.outline,
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Icon(Icons.device_thermostat, color: AppColors.tertiary, size: 20),
                        Text(
                          'Холодный',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Температура',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '34.2°C',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Без перегрева при вычислениях i2_s',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Icon(Icons.hardware, color: AppColors.primary, size: 20),
                        Text(
                          'ARM Neon',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Инструкции',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'GEMM ADD',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Сложение весов без умножения',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.hub, color: AppColors.primary, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Потоки процессора',
                        style: TextStyle(
                          fontFamily: AppTypography.sansFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '4 / 8 ядер',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCoreRow('Поток 0 (Cortex-X4 Prime)', 0.74, '74%', AppColors.primary),
              const SizedBox(height: 8),
              _buildCoreRow('Поток 1 (Cortex-A720 Perf)', 0.68, '68%', AppColors.primaryFixedDim),
              const SizedBox(height: 8),
              _buildCoreRow('Поток 2 (Cortex-A720 Perf)', 0.62, '62%', AppColors.primaryFixedDim),
              const SizedBox(height: 8),
              _buildCoreRow('Поток 3 (Cortex-A720 Perf)', 0.59, '59%', AppColors.primaryFixedDim),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. bitnet.cpp Terminal Log
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.terminal, color: AppColors.onSurfaceVariant, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Лог bitnet.cpp',
                        style: TextStyle(
                          fontFamily: AppTypography.sansFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _copyLog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _logCopied ? Icons.check : Icons.content_copy,
                            size: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _logCopied ? 'Скопировано' : 'Копия',
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.15),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.state.terminalLogs.map((log) {
                    Color tagColor = AppColors.secondary;
                    if (log['color'] == 'primary') tagColor = AppColors.primary;
                    if (log['color'] == 'tertiary') tagColor = AppColors.tertiary;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '${log['tag']}: ',
                            style: TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 11,
                              color: tagColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              log['text']!,
                              style: const TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 11,
                                color: AppColors.onSurface,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Оптимизация инференса',
                style: TextStyle(
                  fontFamily: AppTypography.sansFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: widget.state.settings.cpuFreqLock,
                onChanged: (v) {
                  widget.state.updateSettings(
                    widget.state.settings.copyWith(cpuFreqLock: v),
                  );
                },
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Фиксация частоты CPU',
                  style: TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                ),
                subtitle: const Text(
                  'Предотвращает троттлинг на длинных сессиях',
                  style: TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              SwitchListTile(
                value: widget.state.settings.lowPowerMode,
                onChanged: (v) {
                  widget.state.updateSettings(
                    widget.state.settings.copyWith(lowPowerMode: v),
                  );
                },
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Низкое энергопотребление',
                  style: TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                ),
                subtitle: const Text(
                  'Ограничение до 2 энергоэффективных потоков',
                  style: TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              SwitchListTile(
                value: widget.state.settings.backgroundExecution,
                onChanged: (v) {
                  widget.state.updateSettings(
                    widget.state.settings.copyWith(backgroundExecution: v),
                  );
                },
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Фоновый режим работы',
                  style: TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                ),
                subtitle: const Text(
                  'Держать контекст тернарных весов в памяти',
                  style: TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
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
                fontSize: 10,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              percent,
              style: TextStyle(
                fontFamily: AppTypography.monoFont,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: factor,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
