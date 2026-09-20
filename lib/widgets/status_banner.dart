import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../state/bitnet_state.dart';

class StatusBanner extends StatelessWidget {
  final BitNetState state;

  const StatusBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final ramPercent = (state.ramUsedGb / state.ramTotalGb).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Row 1: Model title, offline badge, threads
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${state.activeModel.name} (Int2/TL1)',
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Офлайн',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.memory, size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${state.settings.cpuThreads} потока',
                    style: const TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Speed, arch, RAM meter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed, size: 14, color: AppColors.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    '${state.liveTokSpeed} tok/s',
                    style: const TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(color: AppColors.outlineVariant)),
                  const SizedBox(width: 6),
                  const Text(
                    'arm64-v8.2a',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'RAM: ',
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: '${state.ramUsedGb} GB',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        TextSpan(text: ' / ${state.ramTotalGb.toInt()} GB'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ramPercent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
