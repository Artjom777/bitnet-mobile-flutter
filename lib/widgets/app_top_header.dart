import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../state/bitnet_state.dart';
import 'apple_pressable.dart';

class AppTopHeader extends StatelessWidget {
  final BitNetState state;
  final String sectionName;

  const AppTopHeader({
    super.key,
    required this.state,
    required this.sectionName,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.appleGlassSurface,
            border: const Border(
              bottom: BorderSide(
                color: AppColors.appleGlassBorder,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Brand Header Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo + Section Title with Apple typography
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2E2E38), Color(0xFF1E1E24)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: AppColors.appleGlassHighlight,
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.memory,
                                size: 20,
                                color: AppColors.appleTeal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BitNet AI',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  height: 1.15,
                                  color: AppColors.appleLabel,
                                ),
                              ),
                              Text(
                                sectionName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                  color: AppColors.appleTeal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Dynamic Island-style Status Pill + Info Button
                      Row(
                        children: [
                          ApplePressable(
                            onTap: () => state.setTab(1),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.appleGlassCard,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.appleGlassBorder,
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: (state.hasActiveModel && state.activeModel.isLoaded)
                                          ? AppColors.appleGreen
                                          : AppColors.appleOrange,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: ((state.hasActiveModel && state.activeModel.isLoaded)
                                                  ? AppColors.appleGreen
                                                  : AppColors.appleOrange)
                                              .withOpacity(0.5),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    !state.hasActiveModel
                                        ? 'Нет модели'
                                        : (state.activeModel.isLoaded
                                            ? (state.activeModel.name.toLowerCase().contains('aramis')
                                                ? 'Aramis-2B'
                                                : (state.activeModel.name.toLowerCase().contains('bifrost')
                                                    ? 'Bifrost-2B'
                                                    : 'BitNet-2B'))
                                            : 'Не в ОЗУ'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      color: AppColors.appleSecondaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ApplePressable(
                            onTap: () => _showSystemInfoDialog(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.appleGlassCard,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.appleGlassBorder,
                                  width: 0.6,
                                ),
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                size: 17,
                                color: AppColors.appleLabel,
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
          ),
        ),
      ),
    );
  }

  void _showSystemInfoDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: BoxDecoration(
            color: AppColors.appleGlassModal,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppColors.appleGlassBorder,
              width: 0.8,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.appleQuaternaryLabel,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Icon(Icons.memory_rounded, color: AppColors.appleTeal, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'BitNet On-Device Engine',
                      style: AppTypography.appleTitle3,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.appleGlassCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.appleSubtleBorder,
                      width: 0.6,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Архитектура', 'ARM64-v8a Pure'),
                      _buildInfoRow('Квантование', '1.58-бит троичное {-1, 0, +1}'),
                      _buildInfoRow('Вычислительное ядро', 'ARM NEON + GEMM ADD'),
                      _buildInfoRow('Активная модель', state.activeModel.name),
                      _buildInfoRow('Статус в памяти', state.activeModel.isLoaded ? 'Загружена' : 'Не загружена'),
                      _buildInfoRow('Скорость инференса', '${state.liveTokSpeed} tok/s'),
                      _buildInfoRow('Оперативная память', '${state.ramUsedGb.toStringAsFixed(1)} ГБ / ${state.ramTotalGb.toStringAsFixed(1)} ГБ'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ApplePressable(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.appleBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Готово',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: Colors.white,
                          ),
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.appleSecondaryLabel,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.monoFont,
                color: AppColors.appleLabel,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
