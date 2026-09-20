import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../state/bitnet_state.dart';

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
    return Container(
      color: AppColors.surface.withOpacity(0.95),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Android System Status Bar Simulation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '14:30',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.wifi, size: 16, color: AppColors.onSurfaceVariant),
                      SizedBox(width: 4),
                      Text(
                        '5G',
                        style: TextStyle(
                          fontFamily: AppTypography.sansFont,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.battery_full, size: 16, color: AppColors.onSurfaceVariant),
                      SizedBox(width: 2),
                      Text(
                        '98%',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // App Brand Header Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo + Titles
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.memory,
                            size: 22,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BitNet AI',
                            style: TextStyle(
                              fontFamily: AppTypography.sansFont,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            sectionName,
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Active Model Chip + User Avatar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
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
                            Text(
                              state.activeModel.name.contains('3B')
                                  ? 'b1.58-3B'
                                  : state.activeModel.name.split('-').first,
                              style: const TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 18,
                          color: AppColors.onPrimary,
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
    );
  }
}
