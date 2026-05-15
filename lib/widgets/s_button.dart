// lib/widgets/s_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text.dart';

enum SButtonVariant { primary, outlined, danger }
enum SButtonSize { small, medium, large }

class SButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final SButtonVariant variant;
  final SButtonSize size;
  final bool loading;
  final IconData? icon;
  final double? width;

  const SButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = SButtonVariant.primary,
    this.size = SButtonSize.large,
    this.loading = false,
    this.icon,
    this.width,
  });

  // convenience constructors
  const SButton.outlined({
    super.key,
    required this.label,
    this.onTap,
    this.size = SButtonSize.large,
    this.loading = false,
    this.icon,
    this.width,
  }) : variant = SButtonVariant.outlined;

  const SButton.danger({
    super.key,
    required this.label,
    this.onTap,
    this.size = SButtonSize.large,
    this.loading = false,
    this.icon,
    this.width,
  }) : variant = SButtonVariant.danger;

  double get _height {
    switch (size) {
      case SButtonSize.small:  return 36;
      case SButtonSize.medium: return 44;
      case SButtonSize.large:  return 52;
    }
  }

  double get _fontSize {
    switch (size) {
      case SButtonSize.small:  return 13;
      case SButtonSize.medium: return 14;
      case SButtonSize.large:  return 15;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case SButtonSize.small:  return const EdgeInsets.symmetric(horizontal: 14);
      case SButtonSize.medium: return const EdgeInsets.symmetric(horizontal: 18);
      case SButtonSize.large:  return EdgeInsets.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutlined = variant == SButtonVariant.outlined;
    final isDanger   = variant == SButtonVariant.danger;

    Gradient? gradient;
    Color? bgColor;
    Border? border;
    List<BoxShadow>? shadows;
    Color contentColor;

    if (isOutlined) {
      bgColor = Colors.transparent;
      border = Border.all(color: AppColors.brand, width: 1.5);
      contentColor = AppColors.brand;
    } else if (isDanger) {
      gradient = AppColors.dangerGradient;
      shadows = [BoxShadow(color: AppColors.accentRed.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))];
      contentColor = Colors.white;
    } else {
      gradient = AppColors.brandGradient;
      shadows = [BoxShadow(color: AppColors.brand.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))];
      contentColor = AppColors.textOnBrand;
    }

    return GestureDetector(
      onTap: loading || onTap == null ? null : () {
        HapticFeedback.lightImpact();
        onTap!();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          width: width ?? double.infinity,
          height: _height,
          padding: _padding,
          decoration: BoxDecoration(
            gradient: gradient,
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: border,
            boxShadow: shadows,
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: contentColor),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, color: contentColor, size: _fontSize + 2),
                      const SizedBox(width: 7),
                    ],
                    Text(label, style: AppText.btn(color: contentColor).copyWith(fontSize: _fontSize)),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ── ICON BUTTON ───────────────────────────────────────────────────────────────
class SIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? bgColor;
  final double size;
  final double padding;
  final bool danger;

  const SIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color,
    this.bgColor,
    this.size = 22,
    this.padding = 10,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? AppColors.accentRed.withOpacity(0.12)
        : (bgColor ?? AppColors.bgElevated);
    final iconColor = danger
        ? AppColors.accentRed
        : (color ?? AppColors.textSecondary);

    return GestureDetector(
      onTap: onTap == null ? null : () {
        HapticFeedback.lightImpact();
        onTap!();
      },
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: danger ? AppColors.accentRed.withOpacity(0.3) : AppColors.border,
          ),
        ),
        child: Icon(icon, color: iconColor, size: size),
      ),
    );
  }
}