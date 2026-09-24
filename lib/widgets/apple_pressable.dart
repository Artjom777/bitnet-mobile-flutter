import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable Apple-style fluid pressable micro-interaction wrapper.
/// - Fires scale down instantly on pointer down (kills latency)
/// - Uses smooth critically damped spring recovery on release
/// - Haptic feedback for tactile satisfaction
class ApplePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double pressedOpacity;
  final Duration duration;
  final Curve curve;
  final bool enableHaptics;
  final BorderRadius? borderRadius;

  const ApplePressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.pressedOpacity = 0.88,
    this.duration = const Duration(milliseconds: 140),
    this.curve = Curves.easeOutCubic,
    this.enableHaptics = true,
    this.borderRadius,
  });

  @override
  State<ApplePressable> createState() => _ApplePressableState();
}

class _ApplePressableState extends State<ApplePressable> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _isPressed = true);
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? widget.pressedScale : 1.0;
    final opacity = _isPressed ? widget.pressedOpacity : 1.0;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: scale,
        duration: widget.duration,
        curve: widget.curve,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: widget.duration,
          curve: widget.curve,
          child: widget.borderRadius != null
              ? ClipRRect(borderRadius: widget.borderRadius!, child: widget.child)
              : widget.child,
        ),
      ),
    );
  }
}
