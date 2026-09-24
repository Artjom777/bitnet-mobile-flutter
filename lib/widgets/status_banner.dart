import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../state/bitnet_state.dart';
import 'apple_pressable.dart';

class StatusBanner extends StatelessWidget {
  final BitNetState state;

  const StatusBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final ramPercent = (state.ramUsedGb / state.ramTotalGb).clamp(0.0, 1.0);
    final isModelReady = state.hasActiveModel && state.activeModel.isLoaded;

    return ApplePressable(
      onTap: () => state.setTab(2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.appleGlassCard,
          borderRadius: BorderRadius.circular(20),
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
          children: [
            // Row 1: Model title, offline pill, RU skill pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isModelReady ? AppColors.appleGreen : AppColors.appleOrange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isModelReady ? AppColors.appleGreen : AppColors.appleOrange).withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          state.hasActiveModel
                              ? (isModelReady
                                  ? state.activeModel.name
                                  : '${state.activeModel.name} (Не в ОЗУ)')
                              : 'Модель не загружена',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: isModelReady ? AppColors.appleLabel : AppColors.appleSecondaryLabel,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.appleGlassHighlight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Офлайн',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                            color: AppColors.appleSecondaryLabel,
                          ),
                        ),
                      ),
                      if (state.settings.russianSkillEnabled) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.appleTeal.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'RU Навык',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: AppColors.appleTeal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Threads counter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hub_outlined,
                      size: 13,
                      color: AppColors.appleTertiaryLabel,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${state.settings.cpuThreads} ядра',
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 11,
                        color: AppColors.appleSecondaryLabel,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Live Speed, RAM, Temp
            Row(
              children: [
                // Live Token Speed Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.appleBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.speed_rounded,
                        size: 13,
                        color: AppColors.appleBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${state.liveTokSpeed.toStringAsFixed(1)} tok/s',
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.appleBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'arm64 • ${state.hardwareTelemetry.activeThreads}T',
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 10,
                    color: AppColors.appleTertiaryLabel,
                  ),
                ),
                const Spacer(),
                // RAM Metrics
                Text(
                  'RAM: ${state.ramUsedGb.toStringAsFixed(1)} / ${state.ramTotalGb.toStringAsFixed(0)} GB',
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 11,
                    color: AppColors.appleSecondaryLabel,
                  ),
                ),
                const SizedBox(width: 6),
                // Progress Bar
                SizedBox(
                  width: 40,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ramPercent,
                      backgroundColor: AppColors.appleGlassHighlight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ramPercent > 0.85
                            ? AppColors.appleRed
                            : (ramPercent > 0.65
                                ? AppColors.appleOrange
                                : AppColors.appleGreen),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
