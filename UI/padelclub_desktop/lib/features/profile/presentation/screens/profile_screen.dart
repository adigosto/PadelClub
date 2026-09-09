import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/di/injection.dart';
import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/validation/form_validators.dart';
import 'package:padelclub_desktop/features/memberships/presentation/providers/membership_provider.dart';
import 'package:padelclub_desktop/features/memberships/presentation/screens/membership_self_service_screen.dart';
import 'package:padelclub_desktop/features/notification_settings/presentation/screens/notification_settings_screen.dart';
import 'package:padelclub_desktop/features/payment_history/presentation/screens/payment_history_screen.dart';
import 'package:padelclub_desktop/features/privacy/presentation/providers/privacy_controls_provider.dart';
import 'package:padelclub_desktop/features/privacy/presentation/screens/privacy_controls_screen.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';
import 'package:padelclub_desktop/features/reservations/presentation/providers/reservation_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ReservationProvider>().loadReservations(
        management: false,
      ),
    );
  }

  Future<void> _editAccount(AuthProvider auth) async {
    final firstName = TextEditingController(text: auth.firstName);
    final lastName = TextEditingController(text: auth.lastName);
    final username = TextEditingController(text: AuthProvider.username);
    final email = TextEditingController(text: auth.email);
    final phone = TextEditingController(text: auth.phoneNumber);
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Edit account details")),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstName,
                  decoration: InputDecoration(
                    labelText: context.tr("First name"),
                  ),
                  validator: (value) => FormValidators.text(
                    value,
                    l10n: context.l10n,
                    label: 'your first name',
                    maxLength: 100,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lastName,
                  decoration: InputDecoration(
                    labelText: context.tr("Last name"),
                  ),
                  validator: (value) => FormValidators.text(
                    value,
                    l10n: context.l10n,
                    label: 'your last name',
                    maxLength: 100,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: username,
                  decoration: InputDecoration(
                    labelText: context.tr("Username"),
                  ),
                  validator: (value) => FormValidators.text(
                    value,
                    l10n: context.l10n,
                    label: 'a username',
                    maxLength: 100,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: context.tr("Email")),
                  validator: (value) =>
                      FormValidators.email(value, l10n: context.l10n),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  validator: (value) => FormValidators.phone(
                    value,
                    l10n: context.l10n,
                    optional: true,
                  ),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: context.tr("Phone")),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr("Cancel")),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(context.tr("Save changes")),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    final success = await auth.updateProfile(
      newUsername: username.text.trim(),
      newEmail: email.text.trim(),
      newFirstName: firstName.text.trim(),
      newLastName: lastName.text.trim(),
      newPhoneNumber: phone.text.trim().isEmpty ? null : phone.text.trim(),
    );
    if (!mounted) return;
    _showResult(
      success,
      auth.errorMessage,
      context.tr("Account details updated."),
    );
  }

  Future<void> _changePassword(AuthProvider auth) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Change password")),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.tr("New password"),
                ),
                validator: (value) => (value?.length ?? 0) < 10
                    ? context.tr("Use at least 10 characters")
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.tr("Confirm password"),
                ),
                validator: (value) => value != password.text
                    ? context.tr("Passwords do not match")
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr("Cancel")),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(context.tr("Update password")),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    final success = await auth.updateProfile(
      newUsername: AuthProvider.username!,
      newEmail: auth.email ?? '',
      newFirstName: auth.firstName ?? '',
      newLastName: auth.lastName ?? '',
      newPhoneNumber: auth.phoneNumber,
      newPassword: password.text,
    );
    if (!mounted) return;
    _showResult(success, auth.errorMessage, context.tr("Password updated."));
  }

  Future<void> _verifyEmail(AuthProvider auth) async {
    final formKey = GlobalKey<FormState>();
    final sent = await auth.requestEmailVerification();
    if (!mounted) return;
    if (!sent) {
      _showResult(false, auth.errorMessage, '');
      return;
    }
    final token = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Verify your email")),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("We sent a verification code to {p1}.", {
                  'p1': auth.email ?? 'your email address',
                }),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: token,
                validator: (value) => FormValidators.text(
                  value,
                  l10n: context.l10n,
                  label: 'the verification code',
                  minLength: 32,
                  maxLength: 256,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.tr("Verification code"),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr("Later")),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(context.tr("Verify")),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    final verified = await auth.verifyEmail(token.text);
    if (!mounted) return;
    _showResult(
      verified,
      auth.errorMessage,
      context.tr("Email verified. Player features are now unlocked."),
    );
  }

  Future<void> _openNotificationSettings() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: sl.notificationSettingsProvider,
          child: const NotificationSettingsScreen(),
        ),
      ),
    );
  }

  Future<void> _openPrivacyControls() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => PrivacyControlsProvider.live(),
          child: const PrivacyControlsScreen(),
        ),
      ),
    );
  }

  Future<void> _openMemberships() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => MembershipProvider(),
          child: const MembershipSelfServiceScreen(),
        ),
      ),
    );
  }

  Future<void> _openPaymentHistory() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
    );
  }

  void _showResult(bool success, String? error, String successMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? successMessage : error ?? context.tr("Update failed."),
        ),
        backgroundColor: success ? null : PadelColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reservationProvider = context.watch<ReservationProvider>();
    final reservations = reservationProvider.reservations;
    final name = auth.displayName.isEmpty
        ? AuthProvider.username ?? context.tr("Player")
        : auth.displayName;
    final initials = _initials(name);
    final completed = reservations.where(_isCompleted).length;
    final upcoming = reservations.where(_isUpcoming).length;
    final hours = reservations.fold<double>(
      0,
      (total, item) => item.status.toLowerCase() == 'cancelled'
          ? total
          : total + item.endTime.difference(item.startTime).inMinutes / 60,
    );

    return MasterScreen(
      title: context.tr("Profile"),
      section: AppSection.profile,
      child: Scrollbar(
        thumbVisibility: true,
        interactive: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
          children: [
            _ProfileHeader(
              name: name,
              username: AuthProvider.username ?? '',
              initials: initials,
            ),
            const SizedBox(height: 16),
            if (reservationProvider.isLoading && reservations.isEmpty)
              const LinearProgressIndicator(),
            if (reservationProvider.errorMessage != null &&
                reservations.isEmpty)
              _InlineNotice(
                message: context.tr(
                  "Reservation statistics are temporarily unavailable.",
                ),
                onRetry: () =>
                    reservationProvider.loadReservations(management: false),
              ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 350 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.25;
                final cards = [
                  _StatCard(
                    value: '$completed',
                    label: context.tr("Matches"),
                    icon: Icons.sports_tennis_rounded,
                  ),
                  _StatCard(
                    value: '$upcoming',
                    label: context.tr("Upcoming"),
                    icon: Icons.event_available_rounded,
                  ),
                  _StatCard(
                    value: hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1),
                    label: context.tr("Hours"),
                    icon: Icons.schedule_rounded,
                  ),
                ];
                if (compact) {
                  return Column(
                    children: [
                      for (var index = 0; index < cards.length; index++) ...[
                        SizedBox(width: double.infinity, child: cards[index]),
                        if (index < cards.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      Expanded(child: cards[index]),
                      if (index < cards.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              },
            ),
            _SectionTitle(context.tr("Achievements")),
            _AchievementRow(
              icon: Icons.flag_rounded,
              title: context.tr("First booking"),
              description: context.tr("Complete your first court reservation."),
              unlocked: reservations.any(
                (item) => item.status.toLowerCase() != 'cancelled',
              ),
            ),
            const SizedBox(height: 10),
            _AchievementRow(
              icon: Icons.workspace_premium_rounded,
              title: context.tr("Court regular"),
              description: context.tr("Complete five matches at PadelClub."),
              unlocked: completed >= 5,
            ),
            _SectionTitle(context.tr("Settings")),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: context.tr("Account details"),
                  subtitle:
                      AuthProvider.username ?? context.tr("Signed-in player"),
                  onTap: () => _editAccount(auth),
                ),
                _SettingsTile(
                  icon: auth.isEmailVerified
                      ? Icons.verified_rounded
                      : Icons.mark_email_unread_outlined,
                  title: auth.isEmailVerified
                      ? context.tr("Email verified")
                      : context.tr("Verify email"),
                  subtitle: auth.isEmailVerified
                      ? auth.email ?? context.tr("Verified account")
                      : context.tr(
                          "Required for partner, match, and tournament features",
                        ),
                  onTap: auth.isEmailVerified ? null : () => _verifyEmail(auth),
                ),
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: context.tr("Notifications"),
                  subtitle: context.tr("Choose how you receive club updates"),
                  onTap: _openNotificationSettings,
                ),
                _SettingsTile(
                  icon: Icons.card_membership_outlined,
                  title: context.tr("My memberships"),
                  subtitle: context.tr(
                    "Review membership status and renewal settings",
                  ),
                  onTap: _openMemberships,
                ),
                _SettingsTile(
                  icon: Icons.payment_outlined,
                  title: context.tr("Payments"),
                  subtitle: context.tr("Pay for orders, reservations and memberships"),
                  onTap: () => Navigator.of(context).pushNamed('/payments'),
                ),
                _SettingsTile(
                  icon: Icons.receipt_long_outlined,
                  title: context.tr("Payment history"),
                  subtitle: context.tr(
                    "Review historical payment records and statuses",
                  ),
                  onTap: _openPaymentHistory,
                ),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: context.tr("Password and security"),
                  subtitle: context.tr(
                    "Change your password and protect your account",
                  ),
                  onTap: () => _changePassword(auth),
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: context.tr("Privacy controls"),
                  subtitle: context.tr(
                    "View your data and manage account deletion",
                  ),
                  onTap: _openPrivacyControls,
                ),
              ],
            ),
            _SectionTitle(context.tr("Support")),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: context.tr("Help center"),
                  subtitle: context.tr("Booking and club assistance"),
                  onTap: () => _showInformation(
                    context,
                    context.tr("Help center"),
                    context.tr(
                      "Contact the PadelClub front desk for booking and account assistance.",
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: context.tr("About PadelClub"),
                  subtitle: context.tr("Version 1.0.0"),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'PadelClub',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(
                      Icons.sports_tennis_rounded,
                      color: PadelColors.greenDark,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: Text(context.tr("Sign out")),
              style: OutlinedButton.styleFrom(
                foregroundColor: PadelColors.danger,
                side: const BorderSide(color: Color(0xFFF0C9C3)),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.username,
    required this.initials,
  });

  final String name;
  final String username;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PadelColors.greenDark, Color(0xFF285A84)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261F7A63),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 37,
            backgroundColor: Colors.white,
            child: Text(
              initials,
              style: const TextStyle(
                color: PadelColors.greenDark,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@$username',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr("PADELCLUB PLAYER"),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: PadelColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, color: PadelColors.greenDark, size: 21),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: PadelColors.textMuted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: unlocked ? PadelColors.greenSoft : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: unlocked ? const Color(0xFFBFE2D5) : PadelColors.border,
      ),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: unlocked
              ? PadelColors.greenDark
              : PadelColors.canvas,
          foregroundColor: unlocked ? Colors.white : PadelColors.textMuted,
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: PadelColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Icon(
          unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          color: unlocked ? PadelColors.greenDark : PadelColors.textMuted,
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 25, bottom: 11),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: PadelColors.border),
    ),
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1) const Divider(height: 1, indent: 56),
        ],
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: PadelColors.greenDark),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: onTap == null
        ? const Icon(Icons.check_circle_rounded, color: PadelColors.greenDark)
        : const Icon(Icons.chevron_right_rounded),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.cloud_off_rounded, color: PadelColors.blue),
      const SizedBox(width: 10),
      Expanded(child: Text(message)),
      IconButton(
        tooltip: context.tr("Retry"),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );
}

bool _isCompleted(Reservation item) {
  final status = item.status.toLowerCase();
  return status == 'completed' ||
      (item.endTime.isBefore(DateTime.now()) && status != 'cancelled');
}

bool _isUpcoming(Reservation item) {
  return item.startTime.isAfter(DateTime.now()) &&
      item.status.toLowerCase() != 'cancelled';
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

void _showInformation(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr("Close")),
        ),
      ],
    ),
  );
}

Future<void> _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr("Sign out?")),
      content: Text(
        context.tr("You will need to enter your credentials again."),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr("Stay signed in")),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.tr("Sign out")),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  context.read<AuthProvider>().logout();
  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
}
