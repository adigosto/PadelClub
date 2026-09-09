import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'locale_controller.dart';

/// Always-visible language tabs, shared by login, desktop and mobile shells.
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Semantics(
        label: context.tr('Language'),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(
              color: onDark ? Colors.white38 : const Color(0xFFDDE5DC),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageOption(
                value: 'en',
                label: 'EN',
                tooltip: 'English',
                selected: controller.locale.languageCode == 'en',
                onDark: onDark,
                onTap: () => _changeLanguage(context, controller, 'en'),
              ),
              _LanguageOption(
                value: 'bs',
                label: 'BS',
                tooltip: 'Bosanski',
                selected: controller.locale.languageCode == 'bs',
                onDark: onDark,
                onTap: () => _changeLanguage(context, controller, 'bs'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeLanguage(
    BuildContext context,
    LocaleController controller,
    String language,
  ) async {
    final saved = await controller.setLanguage(language);
    if (!saved && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Language changed. Your preference could not be saved on this device.',
            ),
          ),
        ),
      );
    }
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.value,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onDark,
    required this.onTap,
  });

  final String value;
  final String label;
  final String tooltip;
  final bool selected;
  final bool onDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected || onDark
        ? Colors.white
        : const Color(0xFF1F7A63);

    return Semantics(
      button: true,
      selected: selected,
      label: '$tooltip ($value)',
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              width: 44,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF2E6BD7), Color(0xFF1F7A63)],
                      )
                    : null,
                color: selected
                    ? null
                    : (onDark ? Colors.transparent : Colors.white),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
