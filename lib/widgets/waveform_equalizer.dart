import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class WaveformEqualizer extends StatelessWidget {
  final List<double> heights;

  const WaveformEqualizer({super.key, required this.heights});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          // Background soft gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Waveform bars
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: heights.asMap().entries.map((entry) {
              final idx = entry.key;
              final val = entry.value;
              final isLast = idx == heights.length - 1;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 300),
                    alignment: Alignment.bottomCenter,
                    heightFactor: val.clamp(0.1, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isLast
                            ? AppColors.secondary
                            : AppColors.primary.withOpacity(
                                0.4 + (idx / heights.length) * 0.5,
                              ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
