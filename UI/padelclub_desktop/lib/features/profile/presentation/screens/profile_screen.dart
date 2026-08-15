import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
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
        title: const Text('Edit account details'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstName,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lastName,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save changes'),
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
    _showResult(success, auth.errorMessage, 'Account details updated.');
  }

  Future<void> _changePassword(AuthProvider auth) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) => (value?.length ?? 0) < 10
                    ? 'Use at least 10 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (value) =>
                    value != password.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Update password'),
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
    _showResult(success, auth.errorMessage, 'Password updated.');
  }

  Future<void> _verifyEmail(AuthProvider auth) async {
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
        title: const Text('Verify your email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We sent a verification code to ${auth.email ?? 'your email address'}.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: token,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Verification code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Verify'),
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
      'Email verified. Player features are now unlocked.',
    );
  }

  void _showResult(bool success, String? error, String successMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMessage : error ?? 'Update failed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reservationProvider = context.watch<ReservationProvider>();
    final reservations = reservationProvider.reservations;
    final name = auth.displayName.isEmpty
        ? AuthProvider.username ?? 'Player'
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
      title: 'Profile',
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
                message: 'Reservation statistics are temporarily unavailable.',
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
                    label: 'Matches',
                    icon: Icons.sports_tennis_rounded,
                  ),
                  _StatCard(
                    value: '$upcoming',
                    label: 'Upcoming',
                    icon: Icons.event_available_rounded,
                  ),
                  _StatCard(
                    value: hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1),
                    label: 'Hours',
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
            const _SectionTitle('Achievements'),
            _AchievementRow(
              icon: Icons.flag_rounded,
              title: 'First booking',
              description: 'Complete your first court reservation.',
              unlocked: reservations.any(
                (item) => item.status.toLowerCase() != 'cancelled',
              ),
            ),
            const SizedBox(height: 10),
            _AchievementRow(
              icon: Icons.workspace_premium_rounded,
              title: 'Court regular',
              description: 'Complete five matches at PadelClub.',
              unlocked: completed >= 5,
            ),
            const _SectionTitle('Settings'),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Account details',
                  subtitle: AuthProvider.username ?? 'Signed-in player',
                  onTap: () => _editAccount(auth),
                ),
                _SettingsTile(
                  icon: auth.isEmailVerified
                      ? Icons.verified_rounded
                      : Icons.mark_email_unread_outlined,
                  title: auth.isEmailVerified
                      ? 'Email verified'
                      : 'Verify email',
                  subtitle: auth.isEmailVerified
                      ? auth.email ?? 'Verified account'
                      : 'Required for partner, match, and tournament features',
                  onTap: auth.isEmailVerified ? null : () => _verifyEmail(auth),
                ),
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Club announcements and booking updates',
                  onTap: () => _showInformation(
                    context,
                    'Notifications',
                    'Notification preferences are not available in the current API.',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Privacy and security',
                  subtitle: 'Password and account security',
                  onTap: () => _changePassword(auth),
                ),
              ],
            ),
            const _SectionTitle('Support'),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help center',
                  subtitle: 'Booking and club assistance',
                  onTap: () => _showInformation(
                    context,
                    'Help center',
                    'Contact the PadelClub front desk for booking and account assistance.',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About PadelClub',
                  subtitle: 'Version 1.0.0',
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
              label: const Text('Sign out'),
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
                  child: const Text(
                    'PADELCLUB PLAYER',
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
        tooltip: 'Retry',
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

String? _required(String? value) {
  return value?.trim().isEmpty == true ? 'This field is required' : null;
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
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You will need to enter your credentials again.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Stay signed in'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  context.read<AuthProvider>().logout();
  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
}
