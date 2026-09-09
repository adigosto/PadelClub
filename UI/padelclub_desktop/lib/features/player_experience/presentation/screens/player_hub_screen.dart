import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/validation/form_validators.dart';
import 'package:padelclub_desktop/features/player_experience/domain/entities/player_city.dart';
import 'package:padelclub_desktop/features/player_experience/presentation/providers/player_experience_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

/// A player-facing lifecycle screen. Public Search remains intentionally light;
/// this screen owns the authenticated actions behind player profile, partners,
/// tournament participation, and match-result confirmation.
class PlayerHubScreen extends StatefulWidget {
  const PlayerHubScreen({super.key});

  @override
  State<PlayerHubScreen> createState() => _PlayerHubScreenState();
}

class _PlayerHubScreenState extends State<PlayerHubScreen> {
  final _partnerSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PlayerExperienceProvider>().load(),
    );
  }

  @override
  void dispose() {
    _partnerSearchController.dispose();
    super.dispose();
  }

  Future<void> _refreshPartners() async {
    await context.read<PlayerExperienceProvider>().load(
      partnerQuery: _partnerSearchController.text,
    );
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  Future<void> _editProfile(PlayerExperienceProfile? current) async {
    final cities = await context
        .read<PlayerExperienceProvider>()
        .loadCities()
        .catchError((Object error) {
          if (mounted) {
            _snack(context.tr('Cities could not be loaded.'), isError: true);
          }
          return <PlayerCity>[];
        });
    if (!mounted || cities.isEmpty) return;
    final formKey = GlobalKey<FormState>();
    final skillLevel = ValueNotifier<String>(current?.skillLevel ?? 'Beginner');
    final preferredSide = ValueNotifier<String>(
      current?.preferredSide ?? 'Either',
    );
    final city = ValueNotifier<int?>(
      cities.any((item) => item.id == current?.cityId) ? current?.cityId : null,
    );
    final bio = TextEditingController(text: current?.bio ?? '');
    final availability = TextEditingController(
      text: current?.availability ?? '',
    );
    final discoverable = ValueNotifier<bool>(current?.isDiscoverable ?? true);

    final profileDialog = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          current == null
              ? context.tr("Complete player profile")
              : context.tr("Edit player profile"),
        ),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: skillLevel,
                  builder: (_, value, _) => DropdownButtonFormField<String>(
                    initialValue: value,
                    decoration: InputDecoration(
                      labelText: context.tr("Skill level"),
                    ),
                    items:
                        ["Beginner", "Intermediate", "Advanced", "Competitive"]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(context.tr(item)),
                              ),
                            )
                            .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) skillLevel.value = value;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: preferredSide,
                  builder: (_, value, _) => DropdownButtonFormField<String>(
                    initialValue: value,
                    decoration: InputDecoration(
                      labelText: context.tr("Preferred side"),
                    ),
                    items: ["Left", "Right", "Either"]
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(context.tr(item)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) preferredSide.value = value;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<int?>(
                  valueListenable: city,
                  builder: (_, value, _) => DropdownButtonFormField<int>(
                    initialValue: value,
                    decoration: InputDecoration(labelText: context.tr('City')),
                    items: cities
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? context.tr('Select a city') : null,
                    onChanged: (value) => city.value = value,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bio,
                  maxLength: 500,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.tr("Short bio (optional)"),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: availability,
                  maxLength: 300,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.tr("Availability (optional)"),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: discoverable,
                  builder: (_, value, _) => SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr("Show me in partner search")),
                    value: value,
                    onChanged: (next) => discoverable.value = next,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr("Cancel")),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final provider = context.read<PlayerExperienceProvider>();
              final saved = await provider.saveProfile(
                skillLevel: skillLevel.value,
                preferredSide: preferredSide.value,
                cityId: city.value!,
                bio: bio.text.trim(),
                availability: availability.text.trim(),
                isDiscoverable: discoverable.value,
              );
              if (!mounted) return;
              if (saved) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _snack(context.tr("Player profile saved."));
              } else {
                _snack(
                  provider.actionErrorMessage ??
                      context.tr("Profile could not be saved."),
                  isError: true,
                );
              }
            },
            child: Text(context.tr("Save profile")),
          ),
        ],
      ),
    );

    await Navigator.of(context, rootNavigator: true).push(profileDialog);
    await profileDialog.completed;
    skillLevel.dispose();
    preferredSide.dispose();
    city.dispose();
    bio.dispose();
    availability.dispose();
    discoverable.dispose();
  }

  Future<void> _invite(PartnerCandidate partner) async {
    final message = TextEditingController();
    final invite = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Invite {p1}", {'p1': partner.playerName})),
        content: TextField(
          controller: message,
          maxLength: 500,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: context.tr("Message (optional)"),
            hintText: context.tr("Would you like to play together?"),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr("Cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, message.text),
            child: Text(context.tr("Send invite")),
          ),
        ],
      ),
    );
    message.dispose();
    if (invite == null || !mounted) return;
    final provider = context.read<PlayerExperienceProvider>();
    final sent = await provider.invitePartner(partner.userId, invite);
    if (!mounted) return;
    _snack(
      sent
          ? context.tr("Partner invitation sent.")
          : provider.actionErrorMessage ??
                context.tr("The invitation could not be sent."),
      isError: !sent,
    );
  }

  Future<void> _respondToInvitation(
    PartnerInvitation invitation,
    bool accept,
  ) async {
    final provider = context.read<PlayerExperienceProvider>();
    final saved = await provider.respondToPartnerInvitation(
      invitation.id,
      accept,
    );
    if (!mounted) return;
    _snack(
      saved
          ? (accept
                ? context.tr("Partner invitation accepted.")
                : context.tr("Partner invitation declined."))
          : provider.actionErrorMessage ??
                context.tr("The invitation could not be updated."),
      isError: !saved,
    );
  }

  Future<void> _reportResult(PlayerMatch match) async {
    final formKey = GlobalKey<FormState>();
    final score = TextEditingController();
    var winnerTeamId = 1;
    final request = await showDialog<({String score, int winnerTeamId})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.tr("Report match result")),
          content: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("{p1} vs {p2}", {
                    'p1': match.teamOne.join(' / '),
                    'p2': match.teamTwo.join(' / '),
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: score,
                  validator: (value) => FormValidators.text(
                    value,
                    l10n: context.l10n,
                    label: 'the match score',
                    maxLength: 100,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr("Score"),
                    hintText: context.tr("Example: 6-4, 3-6, 10-7"),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: winnerTeamId,
                  decoration: InputDecoration(
                    labelText: context.tr("Winning team"),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 1,
                      child: Text(context.tr("Team one")),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(context.tr("Team two")),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => winnerTeamId = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr("Cancel")),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, (
                  score: score.text,
                  winnerTeamId: winnerTeamId,
                ));
              },
              child: Text(context.tr("Submit for confirmation")),
            ),
          ],
        ),
      ),
    );
    score.dispose();
    if (request == null || !mounted) return;
    final provider = context.read<PlayerExperienceProvider>();
    final saved = await provider.reportMatchResult(
      matchId: match.id,
      score: request.score,
      winnerTeamId: request.winnerTeamId,
    );
    if (!mounted) return;
    _snack(
      saved
          ? context.tr("Result submitted for the other team to confirm.")
          : provider.actionErrorMessage ??
                context.tr("The result could not be submitted."),
      isError: !saved,
    );
  }

  Future<void> _confirmResult(PlayerMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Confirm match result")),
        content: Text(
          context.tr(
            "Confirm {p1} for this match? Ratings update after confirmation.",
            {'p1': match.score ?? 'the reported score'},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr("Not yet")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr("Confirm result")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<PlayerExperienceProvider>();
    final saved = await provider.confirmMatchResult(match.id);
    if (!mounted) return;
    _snack(
      saved
          ? context.tr("Match result confirmed and ratings updated.")
          : provider.actionErrorMessage ??
                context.tr("The result could not be confirmed."),
      isError: !saved,
    );
  }

  Future<void> _respondToTournament(
    TournamentRegistration registration,
    bool accept,
  ) async {
    final provider = context.read<PlayerExperienceProvider>();
    final saved = await provider.respondToTournamentInvitation(
      tournamentId: registration.tournamentId,
      accept: accept,
    );
    if (!mounted) return;
    _snack(
      saved
          ? (accept
                ? context.tr("Tournament place confirmed.")
                : context.tr("Tournament invitation declined."))
          : provider.actionErrorMessage ??
                context.tr("Tournament registration could not be updated."),
      isError: !saved,
    );
  }

  Future<void> _withdrawTournament(TournamentRegistration registration) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Withdraw from tournament")),
        content: Text(
          context.tr(
            "Withdraw your team from {p1}? The club rules may prevent this after the registration deadline.",
            {'p1': registration.tournamentName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr("Keep registration")),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr("Withdraw")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<PlayerExperienceProvider>();
    final saved = await provider.withdrawTournament(registration.tournamentId);
    if (!mounted) return;
    _snack(
      saved
          ? context.tr("Tournament registration withdrawn.")
          : provider.actionErrorMessage ??
                context.tr("Tournament withdrawal could not be completed."),
      isError: !saved,
    );
  }

  Future<void> _showBracket(TournamentRegistration registration) async {
    final provider = context.read<PlayerExperienceProvider>();
    await provider.loadBracket(registration.tournamentId);
    if (!mounted) return;
    if (provider.actionErrorMessage != null) {
      _snack(provider.actionErrorMessage!, isError: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: _BracketDialog(tournamentName: registration.tournamentName),
      ),
    );
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? PadelColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerExperienceProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.userId;
    return MasterScreen(
      title: context.tr("Player hub"),
      section: AppSection.search,
      showBackButton: true,
      child: RefreshIndicator(
        onRefresh: _refreshPartners,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr("Play together"),
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          "Manage your player profile, partnerships, competitions, and results.",
                        ),
                        style: TextStyle(color: PadelColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr("Refresh player activity"),
                  onPressed: provider.isLoading ? null : _refreshPartners,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!auth.isEmailVerified)
              _NoticeCard(
                icon: Icons.mark_email_unread_outlined,
                title: context.tr("Verify your email first"),
                message: context.tr(
                  "Partner, match, and tournament actions unlock after email verification in Profile.",
                ),
              ),
            if (provider.isLoading && provider.profile == null)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (provider.errorMessage != null && provider.profile == null)
              _NoticeCard(
                icon: Icons.cloud_off_rounded,
                title: context.tr("Player activity is unavailable"),
                message: provider.errorMessage!,
                actionLabel: context.tr("Try again"),
                onAction: _refreshPartners,
              ),
            _SectionHeader(
              title: context.tr("Player profile"),
              icon: Icons.person_outline_rounded,
              actionLabel: provider.profile == null
                  ? context.tr("Complete")
                  : context.tr("Edit"),
              onAction: () => _editProfile(provider.profile),
            ),
            _ProfileCard(profile: provider.profile),
            _SectionHeader(
              title: context.tr("Find a partner"),
              icon: Icons.group_add_outlined,
              actionLabel: context.tr("Search"),
              onAction: _refreshPartners,
            ),
            TextField(
              controller: _partnerSearchController,
              onSubmitted: (_) => _refreshPartners(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.tr("Search players by name"),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: context.tr("Search players"),
                  onPressed: provider.isLoading ? null : _refreshPartners,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (provider.partners.isEmpty && !provider.isLoading)
              _NoticeCard(
                icon: Icons.group_off_outlined,
                title: context.tr("No discoverable partners yet"),
                message: context.tr(
                  "Ask club players to complete a discoverable player profile.",
                ),
              )
            else
              ...provider.partners.map(
                (partner) => _PartnerCard(
                  partner: partner,
                  busy: provider.isActionInProgress,
                  onInvite: () => _invite(partner),
                ),
              ),
            _SectionHeader(
              title: context.tr("Partner invitations"),
              icon: Icons.mark_email_unread_outlined,
            ),
            if (provider.invitations.isEmpty && !provider.isLoading)
              _NoticeCard(
                icon: Icons.inbox_outlined,
                title: context.tr("No partner invitations"),
                message: context.tr(
                  "Incoming and sent invitations will appear here.",
                ),
              )
            else
              ...provider.invitations.map(
                (invitation) => _InvitationCard(
                  invitation: invitation,
                  isIncoming: invitation.recipientUserId == currentUserId,
                  busy: provider.isActionInProgress,
                  onAccept: () => _respondToInvitation(invitation, true),
                  onDecline: () => _respondToInvitation(invitation, false),
                ),
              ),
            _SectionHeader(
              title: context.tr("My tournaments"),
              icon: Icons.emoji_events_outlined,
            ),
            if (provider.registrations.isEmpty && !provider.isLoading)
              _NoticeCard(
                icon: Icons.event_available_outlined,
                title: context.tr("No tournament registrations"),
                message: context.tr(
                  "Browse tournaments in Search and register with a discoverable partner.",
                ),
              )
            else
              ...provider.registrations.map(
                (registration) => _TournamentRegistrationCard(
                  registration: registration,
                  busy: provider.isActionInProgress,
                  onAccept: () => _respondToTournament(registration, true),
                  onDecline: () => _respondToTournament(registration, false),
                  onWithdraw: () => _withdrawTournament(registration),
                  onBracket: () => _showBracket(registration),
                ),
              ),
            _SectionHeader(
              title: context.tr("My matches"),
              icon: Icons.scoreboard_outlined,
            ),
            if (provider.matches.isEmpty && !provider.isLoading)
              _NoticeCard(
                icon: Icons.sports_tennis_outlined,
                title: context.tr("No personal matches yet"),
                message: context.tr(
                  "Tournament matches involving you will appear here.",
                ),
              )
            else
              ...provider.matches.map(
                (match) => _PlayerMatchCard(
                  match: match,
                  busy: provider.isActionInProgress,
                  onReport: () => _reportResult(match),
                  onConfirm: () => _confirmResult(match),
                ),
              ),
            if (provider.errorMessage != null && provider.profile != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: PadelColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 20, color: PadelColors.greenDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final PlayerExperienceProfile? profile;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return _NoticeCard(
        icon: Icons.person_add_alt_1_outlined,
        title: context.tr("Complete your player profile"),
        message: context.tr(
          "Set your skill, preferred side, city, and discoverability before inviting partners.",
        ),
      );
    }
    return _SurfaceCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: PadelColors.blueSoft,
            foregroundColor: PadelColors.blue,
            child: Text('${profile!.rating}'),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile!.playerName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${profile!.skillLevel} Â· ${profile!.preferredSide} Â· ${profile!.city}',
                  style: const TextStyle(color: PadelColors.textMuted),
                ),
                if (profile!.availability.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile!.availability,
                    style: const TextStyle(color: PadelColors.textMuted),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  profile!.isDiscoverable
                      ? context.tr("Visible in partner search")
                      : context.tr("Hidden from partner search"),
                  style: TextStyle(
                    color: profile!.isDiscoverable
                        ? PadelColors.greenDark
                        : PadelColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.busy,
    required this.onInvite,
  });

  final PartnerCandidate partner;
  final bool busy;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: PadelColors.greenSoft,
          foregroundColor: PadelColors.greenDark,
          child: Text(
            partner.playerName.isEmpty
                ? '?'
                : partner.playerName[0].toUpperCase(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                partner.playerName,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${partner.skillLevel} Â· ${partner.preferredSide} Â· ${partner.city}',
                style: const TextStyle(
                  color: PadelColors.textMuted,
                  fontSize: 12,
                ),
              ),
              if (partner.bio.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  partner.bio,
                  style: const TextStyle(
                    color: PadelColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              if (partner.availability.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  context.tr("Availability: {p1}", {
                    'p1': partner.availability,
                  }),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: busy ? null : onInvite,
          child: Text(context.tr("Invite")),
        ),
      ],
    ),
  );
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.isIncoming,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final PartnerInvitation invitation;
  final bool isIncoming;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final pendingIncoming = isIncoming && invitation.status == 'Pending';
    final counterpart = isIncoming
        ? invitation.senderName
        : invitation.recipientName;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isIncoming
                      ? context.tr("Invitation from {p1}", {'p1': counterpart})
                      : context.tr("Invitation sent to {p1}", {
                          'p1': counterpart,
                        }),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(invitation.status),
            ],
          ),
          if (invitation.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              invitation.message,
              style: const TextStyle(color: PadelColors.textMuted),
            ),
          ],
          if (pendingIncoming) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : onAccept,
                  child: Text(context.tr("Accept")),
                ),
                OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  child: Text(context.tr("Decline")),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TournamentRegistrationCard extends StatelessWidget {
  const _TournamentRegistrationCard({
    required this.registration,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
    required this.onBracket,
  });

  final TournamentRegistration registration;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onWithdraw;
  final VoidCallback onBracket;

  @override
  Widget build(BuildContext context) {
    final awaitingResponse = registration.registrationStatus == 'Invited';
    final canWithdraw =
        registration.registrationStatus != 'Withdrawn' &&
        registration.tournamentStatus == 'Upcoming';
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  registration.tournamentName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(registration.registrationStatus),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${_date(context, registration.startDate)} Â· ${registration.tournamentStatus}',
            style: const TextStyle(color: PadelColors.textMuted, fontSize: 12),
          ),
          if (registration.partnerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              context.tr("Partner: {p1}", {'p1': registration.partnerName}),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: onBracket,
                icon: const Icon(Icons.account_tree_outlined, size: 17),
                label: Text(context.tr("Bracket")),
              ),
              if (awaitingResponse)
                FilledButton(
                  onPressed: busy ? null : onAccept,
                  child: Text(context.tr("Accept")),
                ),
              if (awaitingResponse)
                OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  child: Text(context.tr("Decline")),
                ),
              if (canWithdraw)
                TextButton(
                  onPressed: busy ? null : onWithdraw,
                  child: Text(context.tr("Withdraw")),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerMatchCard extends StatelessWidget {
  const _PlayerMatchCard({
    required this.match,
    required this.busy,
    required this.onReport,
    required this.onConfirm,
  });

  final PlayerMatch match;
  final bool busy;
  final VoidCallback onReport;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final awaitingConfirmation = match.resultStatus == 'PendingConfirmation';
    final canReport =
        match.status == 'Scheduled' || match.status == 'InProgress';
    final canConfirm = match.canConfirmResult;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  match.tournamentName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(
                match.resultStatus.isEmpty ? match.status : match.resultStatus,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.tr("{p1}  vs  {p2}", {
              'p1': match.teamOne.join(' / '),
              'p2': match.teamTwo.join(' / '),
            }),
          ),
          const SizedBox(height: 5),
          Text(
            '${_date(context, match.scheduledTime)} Â· ${match.courtName}${match.score?.isNotEmpty == true ? ' Â· ${match.score}' : ''}',
            style: const TextStyle(color: PadelColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (canConfirm)
            FilledButton(
              onPressed: busy ? null : onConfirm,
              child: Text(context.tr("Confirm reported result")),
            )
          else if (awaitingConfirmation)
            Text(
              context.tr("Awaiting confirmation from the opposing team."),
              style: TextStyle(color: PadelColors.textMuted, fontSize: 12),
            )
          else if (canReport)
            OutlinedButton(
              onPressed: busy ? null : onReport,
              child: Text(context.tr("Report result")),
            ),
        ],
      ),
    );
  }
}

class _BracketDialog extends StatelessWidget {
  const _BracketDialog({required this.tournamentName});
  final String tournamentName;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerExperienceProvider>();
    return AlertDialog(
      title: Text(context.tr("{p1} bracket", {'p1': tournamentName})),
      content: SizedBox(
        width: 480,
        child: provider.isBracketLoading
            ? const SizedBox(
                height: 110,
                child: Center(child: CircularProgressIndicator()),
              )
            : provider.bracket.isEmpty
            ? Text(context.tr("The bracket has not been generated yet."))
            : ListView.separated(
                shrinkWrap: true,
                itemCount: provider.bracket.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, index) {
                  final match = provider.bracket[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      context.tr("Round {p1} Â· {p2} vs {p3}", {
                        'p1': match.round,
                        'p2': match.teamOne.join(' / '),
                        'p3': match.teamTwo.join(' / '),
                      }),
                    ),
                    subtitle: Text(
                      '${_date(context, match.scheduledTime)}${match.score?.isNotEmpty == true ? ' Â· ${match.score}' : ''}${match.isBye ? ' Â· Bye' : ''}',
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr("Close")),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: PadelColors.border),
    ),
    child: child,
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: PadelColors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: PadelColors.textMuted,
                  fontSize: 12,
                ),
              ),
              if (actionLabel != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: PadelColors.blueSoft,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label.isEmpty ? context.tr("Unknown") : context.tr(label),
      style: const TextStyle(
        color: PadelColors.blue,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

String _date(BuildContext context, DateTime value) {
  final local = value.toLocal();
  return '${local.day}.${local.month}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
