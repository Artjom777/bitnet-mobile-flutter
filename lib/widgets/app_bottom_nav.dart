import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'apple_pressable.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.appleGlassSurface,
            border: Border(
              top: BorderSide(
                color: AppColors.appleGlassHighlight,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    label: 'Чат',
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                  ),
                  _buildNavItem(
                    index: 1,
                    label: 'Модели',
                    icon: Icons.square_foot_outlined,
                    activeIcon: Icons.square_foot_rounded,
                  ),
                  _buildNavItem(
                    index: 2,
                    label: 'Мониторинг',
                    icon: Icons.speed_outlined,
                    activeIcon: Icons.speed_rounded,
                  ),
                  _buildNavItem(
                    index: 3,
                    label: 'Настройки',
                    icon: Icons.tune_outlined,
                    activeIcon: Icons.tune_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = currentIndex == index;

    return ApplePressable(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: isSelected ? 48 : 32,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.appleBlue.withOpacity(0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 21,
                  color: isSelected ? AppColors.appleBlue : AppColors.appleSecondaryLabel,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: -0.1,
                color: isSelected ? AppColors.appleBlue : AppColors.appleSecondaryLabel,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
