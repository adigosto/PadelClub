import 'package:flutter/material.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';

enum AdminStatusTone { success, info, warning, danger, neutral }

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: PadelSpacing.xxs),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            PadelSpacing.lg,
            PadelSpacing.lg,
            PadelSpacing.lg,
            PadelSpacing.md,
          ),
          child: constraints.maxWidth < 620 && action != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content,
                    const SizedBox(height: PadelSpacing.md),
                    action!,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: content),
                    if (action != null) ...[
                      const SizedBox(width: PadelSpacing.md),
                      action!,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class AdminFilterChip extends StatelessWidget {
  const AdminFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
      side: BorderSide(color: selected ? PadelColors.blue : PadelColors.border),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.onSubmitted,
    this.icon = Icons.search_rounded,
    this.width = 260,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, size: 18, color: PadelColors.textMuted),
        ),
      ),
    );
  }
}

class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({
    super.key,
    required this.label,
    this.tone = AdminStatusTone.neutral,
    this.showDot = false,
  });

  final String label;
  final AdminStatusTone tone;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      AdminStatusTone.success => (PadelColors.greenDark, PadelColors.greenSoft),
      AdminStatusTone.info => (PadelColors.blue, PadelColors.blueSoft),
      AdminStatusTone.warning => (PadelColors.warning, PadelColors.warningSoft),
      AdminStatusTone.danger => (PadelColors.danger, PadelColors.dangerSoft),
      AdminStatusTone.neutral => (PadelColors.textMuted, PadelColors.canvas),
    };

    return Semantics(
      label: 'Status: $label',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: showDot ? PadelSpacing.xs : PadelSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: showDot ? Colors.transparent : colors.$2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDot) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors.$1,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  color: showDot ? PadelColors.textMuted : colors.$1,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminActionButton extends StatelessWidget {
  const AdminActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      color: destructive ? PadelColors.danger : PadelColors.text,
      style: IconButton.styleFrom(
        backgroundColor: PadelColors.canvas,
        minimumSize: const Size(44, 44),
        maximumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PadelRadii.small),
        ),
      ),
    );
  }
}

class AdminTableSurface extends StatelessWidget {
  const AdminTableSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PadelColors.surface,
        border: Border.all(color: PadelColors.border),
        borderRadius: BorderRadius.circular(PadelRadii.large),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PadelRadii.large),
        child: child,
      ),
    );
  }
}
