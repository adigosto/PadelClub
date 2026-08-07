import 'package:flutter/material.dart';

import 'package:padelclub_desktop/features/product/presentation/screens/product_list_screen.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedNavIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: Stack(
        children: [
          const _DashboardBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Color(0xFF25324D),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD8E2F1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.battery_std_rounded,
                              size: 16,
                              color: Color(0xFF2E6BD7),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '100%',
                              style: TextStyle(
                                color: Color(0xFF25324D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (index) {
          if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductListScreen()),
            );
            return;
          }
          setState(() {
            _selectedNavIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Početna',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Pretraga',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Rezervacije',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart_rounded),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

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

class _FilterPill extends StatelessWidget {
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
