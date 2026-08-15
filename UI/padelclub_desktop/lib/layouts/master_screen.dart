import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';

enum AppSection {
  home,
  search,
  members,
  orders,
  reservations,
  products,
  courts,
  notifications,
  profile,
}

bool usesDesktopManagement(BuildContext context) {
  if (kIsWeb) return MediaQuery.sizeOf(context).width >= 900;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

class MasterScreen extends StatelessWidget {
  const MasterScreen({
    super.key,
    required this.child,
    required this.title,
    this.section = AppSection.home,
    this.showBackButton = false,
  });

  final Widget child;
  final String title;
  final AppSection section;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return usesDesktopManagement(context)
        ? _DesktopManagementShell(title: title, section: section, child: child)
        : _MobilePlayerShell(
            title: title,
            section: section,
            showBackButton: showBackButton,
            child: child,
          );
  }
}

class _MobilePlayerShell extends StatelessWidget {
  const _MobilePlayerShell({
    required this.title,
    required this.section,
    required this.showBackButton,
    required this.child,
  });

  final String title;
  final AppSection section;
  final bool showBackButton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const sections = [
      AppSection.home,
      AppSection.search,
      AppSection.reservations,
      AppSection.products,
      AppSection.profile,
    ];
    final selectedIndex = sections
        .indexOf(section)
        .clamp(0, sections.length - 1);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton,
        title: Text(title),
        backgroundColor: PadelColors.greenDark,
        foregroundColor: Colors.white,
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            _openSection(context, sections[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.manage_search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Reservations',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DesktopManagementShell extends StatelessWidget {
  const _DesktopManagementShell({
    required this.title,
    required this.section,
    required this.child,
  });

  final String title;
  final AppSection section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PadelColors.canvas,
      body: Column(
        children: [
          _DesktopAdminBar(section: section),
          Expanded(
            child: Semantics(label: title, child: child),
          ),
        ],
      ),
    );
  }
}

class _DesktopAdminBar extends StatelessWidget {
  const _DesktopAdminBar({required this.section});

  final AppSection section;

  static const _destinations = [
    (AppSection.members, 'User Management'),
    (AppSection.orders, 'Order Management'),
    (AppSection.reservations, 'Reservation Management'),
    (AppSection.products, 'Product Management'),
    (AppSection.courts, 'Court Management'),
    (AppSection.notifications, 'Notifications'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PadelColors.blue,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Open management overview',
                child: InkWell(
                  onTap: () => _openSection(context, AppSection.home),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _AdminBrandMark(),
                        SizedBox(width: 10),
                        Text(
                          'PadelClub Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  itemCount: _destinations.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    final destination = _destinations[index];
                    return _DesktopNavItem(
                      section: destination.$1,
                      current: section,
                      label: destination.$2,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBrandMark extends StatelessWidget {
  const _AdminBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: PadelColors.green,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: const Icon(
        Icons.sports_tennis_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.section,
    required this.current,
    required this.label,
  });

  final AppSection section;
  final AppSection current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selected = section == current;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => _openSection(context, section),
        borderRadius: BorderRadius.circular(PadelRadii.small),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(PadelRadii.small),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

void _openSection(BuildContext context, AppSection section) {
  final route = switch (section) {
    AppSection.home => '/home',
    AppSection.search => '/search',
    AppSection.members => '/members',
    AppSection.orders => '/orders',
    AppSection.reservations => '/reservations',
    AppSection.products => '/products',
    AppSection.courts => '/courts',
    AppSection.notifications => '/notifications',
    AppSection.profile => '/profile',
  };
  final current = ModalRoute.of(context)?.settings.name;
  if (current == route) return;
  Navigator.of(context).pushNamedAndRemoveUntil(
    route,
    (candidate) => candidate.settings.name == '/home',
  );
}
