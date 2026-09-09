import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/player_experience/presentation/providers/player_experience_provider.dart';
import 'package:padelclub_desktop/features/player_experience/presentation/screens/player_hub_screen.dart';
import 'package:padelclub_desktop/features/search/domain/entities/discovery_match.dart';
import 'package:padelclub_desktop/features/search/domain/entities/player_ranking.dart';
import 'package:padelclub_desktop/features/search/presentation/providers/discovery_provider.dart';
import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';
import 'package:padelclub_desktop/features/tournament/presentation/providers/tournament_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

enum _SearchSection { all, matches, players, tournaments }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  _SearchSection _section = _SearchSection.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TournamentProvider>().load();
      context.read<DiscoveryProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    if (_section == _SearchSection.all ||
        _section == _SearchSection.tournaments) {
      context.read<TournamentProvider>().load(query: _searchController.text);
    }
    if (_section != _SearchSection.tournaments) {
      context.read<DiscoveryProvider>().load(query: _searchController.text);
    }
    FocusScope.of(context).unfocus();
  }

  void _selectSection(_SearchSection section) {
    if (_section == section) return;
    _searchController.clear();
    setState(() => _section = section);
    if (section == _SearchSection.all ||
        section == _SearchSection.tournaments) {
      context.read<TournamentProvider>().load();
    }
    if (section != _SearchSection.tournaments) {
      context.read<DiscoveryProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TournamentProvider>();
    final discovery = context.watch<DiscoveryProvider>();
    return MasterScreen(
      title: context.tr("Search"),
      section: AppSection.search,
      child: Scrollbar(
        thumbVisibility: true,
        interactive: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(
              context.tr("Discover your next match"),
              style: TextStyle(
                color: PadelColors.text,
                fontSize: 27,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                "Explore club activity, players, and upcoming competitions.",
              ),
              style: TextStyle(color: PadelColors.textMuted),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const PlayerHubScreen()),
                ),
                icon: const Icon(Icons.sports_tennis_rounded),
                label: Text(context.tr("Open player hub")),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: context.tr(_searchHint(_section)),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: _searchHint(_section),
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _SearchSection.values
                    .map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(context.tr(_sectionLabel(section))),
                          selected: _section == section,
                          onSelected: (_) => _selectSection(section),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            if (_section == _SearchSection.all ||
                _section == _SearchSection.matches) ...[
              _SectionTitle(
                icon: Icons.sports_tennis_rounded,
                title: context.tr("Recent matches"),
              ),
              _MatchContent(provider: discovery, onRetry: _search),
            ],
            if (_section == _SearchSection.all ||
                _section == _SearchSection.players) ...[
              _SectionTitle(
                icon: Icons.leaderboard_rounded,
                title: context.tr("Player rankings"),
              ),
              _RankingContent(provider: discovery, onRetry: _search),
            ],
            if (_section == _SearchSection.all ||
                _section == _SearchSection.tournaments) ...[
              _SectionTitle(
                icon: Icons.emoji_events_rounded,
                title: context.tr("Upcoming tournaments"),
              ),
              _TournamentContent(provider: provider, onRetry: _search),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchContent extends StatelessWidget {
  const _MatchContent({required this.provider, required this.onRetry});
  final DiscoveryProvider provider;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.matches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null && provider.matches.isEmpty) {
      return _UnavailableCard(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Matches are unavailable"),
        message: provider.errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: onRetry,
      );
    }
    if (provider.matches.isEmpty) {
      return _UnavailableCard(
        icon: Icons.scoreboard_outlined,
        title: context.tr("No matches found"),
        message: context.tr(
          "Scheduled and completed tournament matches will appear here.",
        ),
      );
    }
    return Column(
      children: provider.matches
          .map((match) => _MatchCard(match: match))
          .toList(growable: false),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});
  final DiscoveryMatch match;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: PadelColors.border),
    ),
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
            Text(
              match.status,
              style: const TextStyle(
                color: PadelColors.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr("{p1}  vs  {p2}", {
            'p1': match.teamOne.join(' / '),
            'p2': match.teamTwo.join(' / '),
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _Meta(icon: Icons.place_outlined, text: match.courtName),
            _Meta(
              icon: Icons.schedule_rounded,
              text: _shortDate(match.scheduledTime),
            ),
            if (match.score?.isNotEmpty == true)
              _Meta(icon: Icons.scoreboard_outlined, text: match.score!),
          ],
        ),
      ],
    ),
  );
}

class _RankingContent extends StatelessWidget {
  const _RankingContent({required this.provider, required this.onRetry});
  final DiscoveryProvider provider;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.rankings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null && provider.rankings.isEmpty) {
      return _UnavailableCard(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Rankings are unavailable"),
        message: provider.errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: onRetry,
      );
    }
    if (provider.rankings.isEmpty) {
      return _UnavailableCard(
        icon: Icons.groups_2_outlined,
        title: context.tr("No ranked players found"),
        message: context.tr(
          "Rankings are calculated from completed club matches.",
        ),
      );
    }
    return Column(
      children: provider.rankings.indexed
          .map((entry) => _RankingRow(position: entry.$1 + 1, player: entry.$2))
          .toList(growable: false),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.position, required this.player});
  final int position;
  final PlayerRanking player;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: PadelColors.border),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '$position',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.playerName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                context.tr("{p1} wins · {p2} played · {p3}% win rate", {
                  'p1': player.wins,
                  'p2': player.matchesPlayed,
                  'p3': context.l10n.number(player.winRate, decimalDigits: 0),
                }),
                style: const TextStyle(
                  color: PadelColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: PadelColors.blue.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            context.tr("{p1} rating", {'p1': player.rating}),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: PadelColors.blue,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TournamentContent extends StatelessWidget {
  const _TournamentContent({required this.provider, required this.onRetry});

  final TournamentProvider provider;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.errorMessage != null) {
      return _UnavailableCard(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Tournaments are unavailable"),
        message: provider.errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: onRetry,
      );
    }
    if (provider.tournaments.isEmpty) {
      return _UnavailableCard(
        icon: Icons.event_busy_rounded,
        title: context.tr("No tournaments found"),
        message: context.tr(
          "There are no published tournaments matching this search.",
        ),
      );
    }
    return Column(
      children: provider.tournaments
          .map((item) => _TournamentCard(tournament: item))
          .toList(growable: false),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament});

  final Tournament tournament;

  Future<void> _register(BuildContext context) async {
    final tournamentId = tournament.id;
    if (tournamentId == null) return;
    final player = context.read<PlayerExperienceProvider>();
    if (player.partners.isEmpty && !player.isLoading) {
      await player.load();
    }
    if (!context.mounted) return;
    if (player.partners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: PadelColors.danger,
          content: Text(
            player.errorMessage ??
                context.tr(
                  "Complete a discoverable player profile and find a partner before registering.",
                ),
          ),
        ),
      );
      return;
    }
    final partner = await showDialog<PartnerCandidate>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.tr("Register for {p1}", {'p1': tournament.name})),
        children: player.partners
            .map(
              (candidate) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, candidate),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(candidate.playerName),
                    Text(
                      '${candidate.skillLevel} · ${candidate.preferredSide} · ${candidate.city}',
                      style: const TextStyle(
                        color: PadelColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (partner == null || !context.mounted) return;
    final registered = await player.registerTournament(
      tournamentId: tournamentId,
      partnerUserId: partner.userId,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: registered ? null : PadelColors.danger,
        content: Text(
          registered
              ? context.tr("{p1} has been invited to join your team.", {
                  'p1': partner.playerName,
                })
              : player.actionErrorMessage ??
                    context.tr(
                      "Tournament registration could not be completed.",
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PadelColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: PadelColors.blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  context.tr(_month(tournament.startDate)),
                  style: const TextStyle(
                    color: PadelColors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${tournament.startDate.toLocal().day}',
                  style: const TextStyle(
                    color: PadelColors.blue,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (tournament.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tournament.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PadelColors.textMuted),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 5,
                  children: [
                    _Meta(
                      icon: Icons.groups_rounded,
                      text: context.tr("{p1} players", {
                        'p1': tournament.maxParticipants,
                      }),
                    ),
                    _Meta(
                      icon: Icons.payments_outlined,
                      text:
                          '${context.l10n.number(tournament.entryFee, decimalDigits: 0)} KM',
                    ),
                    _Meta(icon: Icons.flag_rounded, text: tournament.status),
                  ],
                ),
                if (tournament.id != null &&
                    tournament.status == 'Upcoming' &&
                    tournament.registrationDeadline.isAfter(
                      DateTime.now(),
                    )) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => _register(context),
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(context.tr("Register with partner")),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: PadelColors.greenDark),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 11, color: PadelColors.textMuted),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 11),
    child: Row(
      children: [
        Icon(icon, color: PadelColors.greenDark, size: 21),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: PadelColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: PadelColors.blue, size: 27),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: PadelColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

String _sectionLabel(_SearchSection section) => switch (section) {
  _SearchSection.all => 'All',
  _SearchSection.matches => 'Matches',
  _SearchSection.players => 'Players',
  _SearchSection.tournaments => 'Tournaments',
};

String _searchHint(_SearchSection section) => switch (section) {
  _SearchSection.all => 'Search club activity…',
  _SearchSection.matches => 'Search matches…',
  _SearchSection.players => 'Search players…',
  _SearchSection.tournaments => 'Search tournaments…',
};

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day}.${local.month}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _month(DateTime value) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return months[value.toLocal().month - 1];
}
