// lib/widgets/settings_row.dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text.dart';

// ── SWITCH ROW ────────────────────────────────────────────────────────────────
class SettingSwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  const SettingSwitchRow({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, color: AppColors.brand, size: 18),
        const SizedBox(width: 10),
      ],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.bodyM(color: AppColors.textPrimary)),
        if (subtitle != null) Text(subtitle!, style: AppText.bodyS()),
      ])),
      Switch(value: value, onChanged: onChanged),
    ]),
  );
}

// ── NAV ROW ───────────────────────────────────────────────────────────────────
class SettingNavRow extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;    // FIXED: icon is now rendered
  final VoidCallback onTap;
  final Color? valueColor;

  const SettingNavRow({
    super.key,
    required this.label,
    this.value,
    this.icon,
    required this.onTap,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.brand, size: 18),
          const SizedBox(width: 10),
        ],
        Expanded(child: Text(label, style: AppText.bodyM(color: AppColors.textPrimary))),
        if (value != null) Text(value!, style: AppText.bodyM(color: valueColor ?? AppColors.textMuted)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      ]),
    ),
  );
}

// ── DROPDOWN ROW ──────────────────────────────────────────────────────────────
class SettingDropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData? icon;

  const SettingDropdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, color: AppColors.brand, size: 18),
        const SizedBox(width: 10),
      ],
      Expanded(child: Text(label, style: AppText.bodyM(color: AppColors.textPrimary))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgHighlight, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderBright),
        ),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: value, isDense: true, dropdownColor: AppColors.bgElevated,
          style: AppText.bodyM(color: AppColors.textPrimary),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 16),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        )),
      ),
    ]),
  );
}

// ── SLIDER ROW (NEW) ──────────────────────────────────────────────────────────
class SettingSliderRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? valueLabel;
  final ValueChanged<double> onChanged;
  final IconData? icon;

  const SettingSliderRow({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.valueLabel,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.brand, size: 18),
          const SizedBox(width: 10),
        ],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.bodyM(color: AppColors.textPrimary)),
          if (subtitle != null) Text(subtitle!, style: AppText.bodyS()),
        ])),
        Text(
          valueLabel != null ? valueLabel!(value) : value.toStringAsFixed(0),
          style: AppText.bodyMBold(color: AppColors.brand),
        ),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: AppColors.brand,
          inactiveTrackColor: AppColors.bgHighlight,
          thumbColor: AppColors.brand,
          overlayColor: AppColors.brand.withOpacity(0.1),
          trackHeight: 3,
        ),
        child: Slider(
          value: value, min: min, max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ]),
  );
}

// ── INFO ROW (NEW — replaces _InfoRow scattered in screens) ──────────────────
class SettingInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final VoidCallback? onCopy;

  const SettingInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, color: AppColors.brand, size: 18),
        const SizedBox(width: 10),
      ],
      Expanded(child: Text(label, style: AppText.bodyM())),
      Text(value, style: AppText.bodyM(color: valueColor ?? AppColors.textSecondary)),
      if (onCopy != null) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onCopy,
          child: const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 14),
        ),
      ],
    ]),
  );
}

// ── TIME PICKER ROW (NEW) ─────────────────────────────────────────────────────
class SettingTimePickerRow extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;
  final IconData? icon;

  const SettingTimePickerRow({
    super.key,
    required this.label,
    this.value,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final display = value != null
        ? '${value!.hourOfPeriod}:${value!.minute.toString().padLeft(2,'0')} ${value!.period == DayPeriod.am ? 'AM' : 'PM'}'
        : 'Set';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.brand, size: 18),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(label, style: AppText.bodyM(color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgHighlight, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderBright),
            ),
            child: Text(display, style: AppText.bodyMBold(color: AppColors.brand)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}

// ── SECTION CONTAINER ─────────────────────────────────────────────────────────
class SettingSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title.toUpperCase(), style: AppText.label(color: AppColors.textMuted)),
    ),
    Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      // FIXED: use Column instead of ListView.separated to avoid nested-scroll shrinkWrap issues
      child: Column(children: [
        for (int i = 0; i < children.length; i++) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: children[i]),
          if (i < children.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ]),
    ),
  ]);
}