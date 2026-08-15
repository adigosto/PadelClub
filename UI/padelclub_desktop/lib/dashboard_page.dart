import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/features/home/presentation/screens/mobile_home_screen.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    if (usesDesktopManagement(context)) {
      return context.watch<AuthProvider>().isAdministrator
          ? const _ManagementOverview()
          : const _DesktopAccessDenied();
    }
    return const MobileHomeScreen();
    /* Legacy mobile search composition retained temporarily for Phase 5 extraction.
    return MasterScreen(
      title: 'PadelClub',
      section: AppSection.home,
      child: Stack(
        children: [
          const _DashboardBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Rezultati i igrači',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.9,
                            color: const Color(0xFF17233A),
                          ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD8E2F1)),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Pretražite mečeve, igrače...',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Color(0xFF2E6BD7),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        _FilterPill(label: 'Sve', selected: true),
                        _FilterPill(label: 'Mečevi'),
                        _FilterPill(label: 'Rang lista'),
                        _FilterPill(label: 'Turniri'),
                        _FilterPill(label: 'Trening'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFF2B705),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Najnoviji mečevi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17233A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _MatchCard(
                    timeLabel: 'Danas, 14:30',
                    status: 'UŽIVO',
                    statusColor: Color(0xFFFFE7E3),
                    statusTextColor: Color(0xFFE84E3A),
                    leftPlayer: 'Marko & Ana',
                    leftSubtitle: 'M. Jovanović • A. Kovačević',
                    rightPlayer: 'Stefan & Milica',
                    rightSubtitle: 'S. Petrović • M. Nikolić',
                    score: '6-4, 3-2',
                    footerLeft: 'Teren 1',
                    footerRight: 'Set 2',
                    accentColor: Color(0xFF1F7A63),
                  ),
                  const SizedBox(height: 14),
                  const _MatchCard(
                    timeLabel: 'Juče, 16:00',
                    status: 'ZAVRŠENO',
                    statusColor: Color(0xFFE6F7EA),
                    statusTextColor: Color(0xFF2BA24C),
                    leftPlayer: 'Luka & Jovana',
                    leftSubtitle: 'L. Stanković • J. Mitrović',
                    rightPlayer: 'Nikola & Sara',
                    rightSubtitle: 'N. Radić • S. Popović',
                    score: '6-2, 6-4',
                    footerLeft: 'Teren 2',
                    footerRight: '1h 25min',
                    accentColor: Color(0xFF2E6BD7),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: const [
                      Icon(
                        Icons.military_tech_rounded,
                        color: Color(0xFFF2B705),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Najbolji igrači',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17233A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _PlayerCard(
                    name: 'Amina Club',
                    title: 'Top form',
                    points: '2,480',
                    rank: '#1',
                    avatarColor: Color(0xFF2E6BD7),
                  ),
                  const SizedBox(height: 10),
                  const _PlayerCard(
                    name: 'Marko Jovanović',
                    title: 'Most improved',
                    points: '2,155',
                    rank: '#2',
                    avatarColor: Color(0xFF1F7A63),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

    */
  }
}

class _DesktopAccessDenied extends StatelessWidget {
  const _DesktopAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: SizedBox(
          width: 420,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 58,
                    color: Color(0xFF2F64E7),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Management access required',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The desktop application is reserved for club staff. This account does not currently have an administrator role.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () {
                      context.read<AuthProvider>().logout();
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (_) => false);
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out and go back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagementOverview extends StatelessWidget {
  const _ManagementOverview();

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: 'Management overview',
      section: AppSection.home,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 26, 30, 40),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OverviewHero(
                  onReservations: () =>
                      Navigator.pushNamed(context, '/reservations'),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: compact ? 2 : 4,
                  childAspectRatio: compact ? 2.5 : 2.15,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  children: const [
                    _ManagementMetric(
                      icon: Icons.calendar_month_rounded,
                      label: "Today's bookings",
                      value: '18',
                      color: Color(0xFF2F64E7),
                      trend: '+3 from yesterday',
                    ),
                    _ManagementMetric(
                      icon: Icons.stadium_rounded,
                      label: 'Court occupancy',
                      value: '76%',
                      color: Color(0xFF1F7A63),
                      trend: 'Peak at 18:00',
                    ),
                    _ManagementMetric(
                      icon: Icons.people_alt_rounded,
                      label: 'Active members',
                      value: '248',
                      color: Color(0xFF7657C8),
                      trend: '+12 this month',
                    ),
                    _ManagementMetric(
                      icon: Icons.payments_rounded,
                      label: "Today's revenue",
                      value: '684 KM',
                      color: Color(0xFFD17A32),
                      trend: '82% collected',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (compact) ...[
                  const _TodaySchedule(),
                  const SizedBox(height: 16),
                  const _CourtStatus(),
                ] else
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _TodaySchedule()),
                      SizedBox(width: 16),
                      Expanded(flex: 2, child: _CourtStatus()),
                    ],
                  ),
                const SizedBox(height: 20),
                _QuickActions(
                  onReservations: () =>
                      Navigator.pushNamed(context, '/reservations'),
                  onCourts: () => Navigator.pushNamed(context, '/courts'),
                  onProducts: () => Navigator.pushNamed(context, '/products'),
                  onMembers: () => Navigator.pushNamed(context, '/members'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ManagementMetric extends StatelessWidget {
  const _ManagementMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.trend,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    trend!,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

class _OverviewHero extends StatelessWidget {
  const _OverviewHero({required this.onReservations});
  final VoidCallback onReservations;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF173B8F), Color(0xFF2563EB), Color(0xFF208A78)],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x242563EB),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Good morning, Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Your club is running smoothly. Court demand is strongest between 18:00 and 21:00 today.',
                style: TextStyle(color: Color(0xFFDCE7FF), fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        FilledButton.icon(
          onPressed: onReservations,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF1D4ED8),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New reservation'),
        ),
      ],
    ),
  );
}

class _TodaySchedule extends StatelessWidget {
  const _TodaySchedule();
  @override
  Widget build(BuildContext context) => _DashboardPanel(
    title: "Today's schedule",
    subtitle: 'Upcoming court activity',
    child: Column(
      children: const [
        _ScheduleRow(
          time: '16:00',
          court: 'Court Central',
          player: 'Casey Player',
          status: 'Confirmed',
          color: Color(0xFF2563EB),
        ),
        Divider(height: 1),
        _ScheduleRow(
          time: '17:00',
          court: 'Court North',
          player: 'Amar & team',
          status: 'Paid',
          color: Color(0xFF10B981),
        ),
        Divider(height: 1),
        _ScheduleRow(
          time: '18:00',
          court: 'Court Central',
          player: 'League training',
          status: 'Recurring',
          color: Color(0xFF7657C8),
        ),
        Divider(height: 1),
        _ScheduleRow(
          time: '19:00',
          court: 'Court North',
          player: 'Open match',
          status: '4 players',
          color: Color(0xFFD17A32),
        ),
      ],
    ),
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.time,
    required this.court,
    required this.player,
    required this.status,
    required this.color,
  });
  final String time, court, player, status;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF17233A),
            ),
          ),
        ),
        Container(
          width: 3,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(court, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                player,
                style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CourtStatus extends StatelessWidget {
  const _CourtStatus();
  @override
  Widget build(BuildContext context) => _DashboardPanel(
    title: 'Court status',
    subtitle: 'Live operating overview',
    child: Column(
      children: const [
        _CourtRow(
          name: 'Court Central',
          detail: 'Occupied until 17:00',
          progress: .72,
          color: Color(0xFF2563EB),
        ),
        SizedBox(height: 18),
        _CourtRow(
          name: 'Court North',
          detail: 'Available now',
          progress: .48,
          color: Color(0xFF10B981),
        ),
        SizedBox(height: 22),
        _NoticeRow(
          icon: Icons.build_circle_outlined,
          text: 'No maintenance blocks today',
          color: Color(0xFF1F7A63),
        ),
        SizedBox(height: 10),
        _NoticeRow(
          icon: Icons.schedule_rounded,
          text: '6 open slots remaining',
          color: Color(0xFF2F64E7),
        ),
      ],
    ),
  );
}

class _CourtRow extends StatelessWidget {
  const _CourtRow({
    required this.name,
    required this.detail,
    required this.progress,
    required this.color,
  });
  final String name, detail;
  final double progress;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        detail,
        style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
      ),
      const SizedBox(height: 9),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 7,
          backgroundColor: const Color(0xFFEDF1F7),
          color: color,
        ),
      ),
    ],
  );
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: color),
      const SizedBox(width: 9),
      Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onReservations,
    required this.onCourts,
    required this.onProducts,
    required this.onMembers,
  });
  final VoidCallback onReservations, onCourts, onProducts, onMembers;
  @override
  Widget build(BuildContext context) => _DashboardPanel(
    title: 'Quick actions',
    subtitle: 'Jump straight into daily operations',
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: onReservations,
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Reservations'),
        ),
        OutlinedButton.icon(
          onPressed: onCourts,
          icon: const Icon(Icons.stadium_outlined),
          label: const Text('Courts'),
        ),
        OutlinedButton.icon(
          onPressed: onProducts,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Products'),
        ),
        OutlinedButton.icon(
          onPressed: onMembers,
          icon: const Icon(Icons.people_alt_outlined),
          label: const Text('Members'),
        ),
      ],
    ),
  );
}

// ignore: unused_element
class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFEFF), Color(0xFFF3F7FD), Color(0xFFF7F9FD)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -30,
            child: _Orb(size: 170, color: Color(0x1F2E6BD7)),
          ),
          Positioned(
            top: 90,
            left: -40,
            child: _Orb(size: 120, color: Color(0x1A1F7A63)),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ignore: unused_element
class _FilterPill extends StatelessWidget {
  // ignore: unused_element_parameter
  const _FilterPill({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1F7A63) : const Color(0xFFF0F3F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF667085),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.timeLabel,
    required this.status,
    required this.statusColor,
    required this.statusTextColor,
    required this.leftPlayer,
    required this.leftSubtitle,
    required this.rightPlayer,
    required this.rightSubtitle,
    required this.score,
    required this.footerLeft,
    required this.footerRight,
    required this.accentColor,
  });

  final String timeLabel;
  final String status;
  final Color statusColor;
  final Color statusTextColor;
  final String leftPlayer;
  final String leftSubtitle;
  final String rightPlayer;
  final String rightSubtitle;
  final String score;
  final String footerLeft;
  final String footerRight;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1014253A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeLabel,
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TeamColumn(
                  name: leftPlayer,
                  subtitle: leftSubtitle,
                  alignEnd: false,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Color(0xFF98A2B3),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: _TeamColumn(
                  name: rightPlayer,
                  subtitle: rightSubtitle,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              score,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF17233A),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                footerLeft,
                style: const TextStyle(color: Color(0xFF98A2B3)),
              ),
              Text(
                footerRight,
                style: const TextStyle(color: Color(0xFF98A2B3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.name,
    required this.subtitle,
    required this.alignEnd,
  });

  final String name;
  final String subtitle;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF17233A),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.name,
    required this.title,
    required this.points,
    required this.rank,
    required this.avatarColor,
  });

  final String name;
  final String title;
  final String points;
  final String rank;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E2F1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarColor,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF17233A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                points,
                style: const TextStyle(
                  color: Color(0xFF2E6BD7),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rank,
                style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
