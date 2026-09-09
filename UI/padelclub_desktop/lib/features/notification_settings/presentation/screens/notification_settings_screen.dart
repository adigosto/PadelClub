import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/notification_settings/presentation/providers/notification_settings_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<NotificationSettingsProvider>().load(),
    );
  }

  Future<void> _save(NotificationSettingsProvider provider) async {
    final saved = await provider.save();
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr("Notification preferences saved."))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: context.tr("Notification preferences"),
      section: AppSection.profile,
      showBackButton: true,
      child: Consumer<NotificationSettingsProvider>(
        builder: (context, provider, _) => Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
              children: [
                Text(
                  context.tr("Stay in control"),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: PadelColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    "Choose how PadelClub can send booking, order, and club updates.",
                  ),
                  style: TextStyle(color: PadelColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                if (provider.errorMessage != null)
                  _SettingsNotice(
                    message: provider.errorMessage!,
                    onRetry: provider.isLoading ? null : provider.load,
                  ),
                if (provider.errorMessage != null) const SizedBox(height: 14),
                _PreferenceGroup(
                  enabled: !provider.isLoading && !provider.isSaving,
                  inAppEnabled: provider.preferences.inAppEnabled,
                  emailEnabled: provider.preferences.emailEnabled,
                  pushEnabled: provider.preferences.pushEnabled,
                  onInAppChanged: (value) =>
                      provider.updateDraft(inAppEnabled: value),
                  onEmailChanged: (value) =>
                      provider.updateDraft(emailEnabled: value),
                  onPushChanged: (value) =>
                      provider.updateDraft(pushEnabled: value),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: PadelColors.blueSoft,
                    borderRadius: BorderRadius.circular(PadelRadii.large),
                    border: Border.all(color: const Color(0xFFD3E1FF)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: PadelColors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr(
                            "Push preference is applied when this account has a registered PadelClub mobile device. Email and in-app updates are available immediately.",
                          ),
                          style: TextStyle(
                            color: Color(0xFF35527C),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      provider.hasChanges &&
                          !provider.isSaving &&
                          !provider.isLoading
                      ? () => _save(provider)
                      : null,
                  icon: provider.isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    provider.isSaving
                        ? context.tr("Saving preferences...")
                        : provider.hasChanges
                        ? context.tr("Save preferences")
                        : context.tr("Preferences saved"),
                  ),
                ),
              ],
            ),
            if (provider.isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceGroup extends StatelessWidget {
  const _PreferenceGroup({
    required this.enabled,
    required this.inAppEnabled,
    required this.emailEnabled,
    required this.pushEnabled,
    required this.onInAppChanged,
    required this.onEmailChanged,
    required this.onPushChanged,
  });

  final bool enabled;
  final bool inAppEnabled;
  final bool emailEnabled;
  final bool pushEnabled;
  final ValueChanged<bool> onInAppChanged;
  final ValueChanged<bool> onEmailChanged;
  final ValueChanged<bool> onPushChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PadelRadii.large),
        border: Border.all(color: PadelColors.border),
      ),
      child: Column(
        children: [
          _PreferenceTile(
            icon: Icons.notifications_outlined,
            title: context.tr("In-app notifications"),
            subtitle: context.tr(
              "See important updates when you open PadelClub.",
            ),
            value: inAppEnabled,
            enabled: enabled,
            onChanged: onInAppChanged,
          ),
          const Divider(height: 1, indent: 64),
          _PreferenceTile(
            icon: Icons.email_outlined,
            title: context.tr("Email updates"),
            subtitle: context.tr(
              "Receive confirmations and account updates by email.",
            ),
            value: emailEnabled,
            enabled: enabled,
            onChanged: onEmailChanged,
          ),
          const Divider(height: 1, indent: 64),
          _PreferenceTile(
            icon: Icons.phone_android_outlined,
            title: context.tr("Push notifications"),
            subtitle: context.tr(
              "Get time-sensitive updates on your mobile device.",
            ),
            value: pushEnabled,
            enabled: enabled,
            onChanged: onPushChanged,
          ),
        ],
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: enabled ? onChanged : null,
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: PadelColors.greenSoft,
          borderRadius: BorderRadius.circular(PadelRadii.medium),
        ),
        child: Icon(icon, color: PadelColors.greenDark),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      activeThumbColor: PadelColors.greenDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
    );
  }
}

class _SettingsNotice extends StatelessWidget {
  const _SettingsNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PadelColors.dangerSoft,
        borderRadius: BorderRadius.circular(PadelRadii.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: PadelColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onRetry != null)
            IconButton(
              tooltip: context.tr("Retry"),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}
