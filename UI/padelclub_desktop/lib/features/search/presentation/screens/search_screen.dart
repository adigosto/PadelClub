import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
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
      title: 'Search',
      section: AppSection.search,
      child: Scrollbar(
        thumbVisibility: true,
        interactive: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const Text(
              'Discover your next match',
              style: TextStyle(
                color: PadelColors.text,
                fontSize: 27,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Explore club activity, players, and upcoming competitions.',
              style: TextStyle(color: PadelColors.textMuted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: _searchHint(_section),
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
                          label: Text(_sectionLabel(section)),
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
              const _SectionTitle(
                icon: Icons.sports_tennis_rounded,
                title: 'Recent matches',
              ),
              _MatchContent(provider: discovery, onRetry: _search),
            ],
            if (_section == _SearchSection.all ||
                _section == _SearchSection.players) ...[
              const _SectionTitle(
                icon: Icons.leaderboard_rounded,
                title: 'Player rankings',
              ),
              _RankingContent(provider: discovery, onRetry: _search),
            ],
            if (_section == _SearchSection.all ||
                _section == _SearchSection.tournaments) ...[
              const _SectionTitle(
                icon: Icons.emoji_events_rounded,
                title: 'Upcoming tournaments',
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
        title: 'Matches are unavailable',
        message: provider.errorMessage!,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    }
    if (provider.matches.isEmpty) {
      return const _UnavailableCard(
        icon: Icons.scoreboard_outlined,
        title: 'No matches found',
        message: 'Scheduled and completed tournament matches will appear here.',
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
        Text('${match.teamOne.join(' / ')}  vs  ${match.teamTwo.join(' / ')}'),
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
        title: 'Rankings are unavailable',
        message: provider.errorMessage!,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    }
    if (provider.rankings.isEmpty) {
      return const _UnavailableCard(
        icon: Icons.groups_2_outlined,
        title: 'No ranked players found',
        message: 'Rankings are calculated from completed club matches.',
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
                '${player.wins} wins · ${player.matchesPlayed} played · ${player.winRate.toStringAsFixed(0)}% win rate',
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
            '${player.rating} rating',
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
        title: 'Tournaments are unavailable',
        message: provider.errorMessage!,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    }
    if (provider.tournaments.isEmpty) {
      return const _UnavailableCard(
        icon: Icons.event_busy_rounded,
        title: 'No tournaments found',
        message: 'There are no published tournaments matching this search.',
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
                  _month(tournament.startDate),
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
                      text: '${tournament.maxParticipants} players',
                    ),
                    _Meta(
                      icon: Icons.payments_outlined,
                      text: '${tournament.entryFee.toStringAsFixed(0)} KM',
                    ),
                    _Meta(icon: Icons.flag_rounded, text: tournament.status),
                  ],
                ),
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
