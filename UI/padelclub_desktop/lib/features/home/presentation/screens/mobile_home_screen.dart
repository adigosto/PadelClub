import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/notifications/domain/entities/club_notification.dart';
import 'package:padelclub_desktop/features/notifications/presentation/providers/notification_provider.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';
import 'package:padelclub_desktop/features/reservations/presentation/providers/reservation_provider.dart';
import 'package:padelclub_desktop/features/reviews/domain/entities/club_review.dart';
import 'package:padelclub_desktop/features/reviews/presentation/providers/club_review_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  bool _requestedData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedData) return;
    _requestedData = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait([
      context.read<NotificationProvider>().loadMine(),
      context.read<ReservationProvider>().loadReservations(management: false),
      context.read<ClubReviewProvider>().loadPublished(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final reservationProvider = context.watch<ReservationProvider>();
    final reviewProvider = context.watch<ClubReviewProvider>();
    final firstName = auth.firstName?.trim();
    final greetingName = firstName?.isNotEmpty == true ? firstName! : 'Player';
    final upcoming = _nextReservation(reservationProvider.reservations);

    return MasterScreen(
      title: 'PadelClub',
      section: AppSection.home,
      child: Scrollbar(
        thumbVisibility: true,
        interactive: true,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _GreetingCard(name: greetingName, upcoming: upcoming),
              ),
            ),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Club updates',
                actionLabel:
                    notificationProvider.notifications.any(
                      (item) => item.isRead == false,
                    )
                    ? 'Mark all read'
                    : null,
                onAction: () => notificationProvider.markAllRead(),
              ),
            ),
            SliverToBoxAdapter(
              child: _NotificationStrip(provider: notificationProvider),
            ),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Club reviews',
                actionLabel:
                    reviewProvider.reviews.any(
                      (review) => review.userId == auth.userId,
                    )
                    ? 'Edit mine'
                    : 'Add review',
                onAction: () =>
                    _showReviewEditor(context, reviewProvider, auth.userId),
              ),
            ),
            SliverToBoxAdapter(child: _ReviewStrip(provider: reviewProvider)),
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'Quick actions'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.12,
                children: [
                  _ShortcutCard(
                    title: 'Book a court',
                    subtitle: 'View available times',
                    icon: Icons.calendar_month_rounded,
                    color: PadelColors.greenDark,
                    onTap: () => Navigator.pushNamed(context, '/reservations'),
                  ),
                  _ShortcutCard(
                    title: 'Find players',
                    subtitle: 'Browse matches and rankings',
                    icon: Icons.groups_2_rounded,
                    color: PadelColors.blue,
                    onTap: () => Navigator.pushNamed(context, '/search'),
                  ),
                  _ShortcutCard(
                    title: 'Club shop',
                    subtitle: 'Browse equipment',
                    icon: Icons.shopping_bag_rounded,
                    color: const Color(0xFF276A57),
                    onTap: () => Navigator.pushNamed(context, '/products'),
                  ),
                  _ShortcutCard(
                    title: 'My profile',
                    subtitle: 'Account and activity',
                    icon: Icons.workspace_premium_rounded,
                    color: const Color(0xFF315CA8),
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showReviewEditor(
  BuildContext context,
  ClubReviewProvider provider,
  int? userId,
) async {
  final existing = provider.reviews
      .where((review) => review.userId == userId)
      .firstOrNull;
  final controller = TextEditingController(text: existing?.comment ?? '');
  var rating = existing?.rating ?? 5;
  var isSaving = false;
  String? validationMessage;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add club review' : 'Edit your review',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Share a short, useful note for other club members.',
                style: TextStyle(color: PadelColors.textMuted),
              ),
              const SizedBox(height: 20),
              Text(
                '$rating out of 5',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(
                  5,
                  (index) => IconButton(
                    tooltip: '${index + 1} stars',
                    onPressed: isSaving
                        ? null
                        : () => setSheetState(() => rating = index + 1),
                    icon: Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFF5B942),
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                enabled: !isSaving,
                minLines: 3,
                maxLines: 6,
                maxLength: 600,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (validationMessage != null) {
                    setSheetState(() => validationMessage = null);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Review',
                  hintText: 'Describe your experience at the club',
                ),
              ),
              if (validationMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  validationMessage!,
                  style: const TextStyle(color: PadelColors.danger),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.pop(sheetContext, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final comment = controller.text.trim();
                              if (comment.length < 10) {
                                setSheetState(
                                  () => validationMessage =
                                      'Enter at least 10 characters.',
                                );
                                return;
                              }
                              setSheetState(() => isSaving = true);
                              final success = await provider.saveMine(
                                rating: rating,
                                comment: comment,
                              );
                              if (!sheetContext.mounted) return;
                              if (success) {
                                Navigator.pop(sheetContext, true);
                              } else {
                                setSheetState(() {
                                  isSaving = false;
                                  validationMessage =
                                      provider.errorMessage ??
                                      'Your review could not be saved.';
                                });
                              }
                            },
                      child: isSaving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save review'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  controller.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Your review was saved.')));
  }
}

Reservation? _nextReservation(List<Reservation> reservations) {
  final candidates =
      reservations
          .where(
            (item) =>
                item.startTime.isAfter(DateTime.now()) &&
                item.status.toLowerCase() != 'cancelled',
          )
          .toList(growable: false)
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
  return candidates.firstOrNull;
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.name, required this.upcoming});

  final String name;
  final Reservation? upcoming;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PadelColors.greenDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x291F7A63),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      upcoming == null
                          ? 'No upcoming court booked.'
                          : 'Next reservation',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.sports_tennis_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: Colors.white),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    upcoming == null
                        ? 'No upcoming reservation'
                        : '${_dateLabel(upcoming!.startTime)} · ${_timeLabel(upcoming!.startTime)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/reservations'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text(upcoming == null ? 'Book' : 'View'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({this.title = '', this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: PadelColors.text,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _NotificationStrip extends StatelessWidget {
  const _NotificationStrip({required this.provider});

  final NotificationProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const SizedBox(
        height: 126,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.errorMessage != null && provider.notifications.isEmpty) {
      return _InlineState(
        icon: Icons.cloud_off_rounded,
        message: 'Club updates are temporarily unavailable.',
        onRetry: provider.loadMine,
      );
    }
    if (provider.notifications.isEmpty) {
      return const _InlineState(
        icon: Icons.notifications_none_rounded,
        message: 'You are all caught up.',
      );
    }
    final items = provider.notifications.take(5).toList(growable: false);
    return SizedBox(
      height: 146,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _NotificationCard(
          notification: items[index],
          onTap: items[index].isRead == false
              ? () => provider.markRead(items[index].id)
              : null,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, this.onTap});

  final ClubNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isRead == false;
    return SizedBox(
      width: 280,
      child: Material(
        color: unread ? PadelColors.greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: unread
                        ? PadelColors.greenDark
                        : PadelColors.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _notificationIcon(notification.type),
                    color: unread ? Colors.white : PadelColors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notification.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PadelColors.textMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _dateLabel(notification.createdAt),
                        style: const TextStyle(
                          color: PadelColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({required this.icon, required this.message, this.onRetry});

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PadelColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: PadelColors.greenDark),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          if (onRetry != null)
            IconButton(
              tooltip: 'Retry',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}

class _ReviewStrip extends StatelessWidget {
  const _ReviewStrip({required this.provider});

  final ClubReviewProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.reviews.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.errorMessage != null && provider.reviews.isEmpty) {
      return _InlineState(
        icon: Icons.cloud_off_rounded,
        message: 'Club reviews are temporarily unavailable.',
        onRetry: provider.loadPublished,
      );
    }
    if (provider.reviews.isEmpty) {
      return const _InlineState(
        icon: Icons.rate_review_outlined,
        message: 'No published club reviews yet.',
      );
    }
    return SizedBox(
      height: 152,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: provider.reviews.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => _ReviewCard(review: provider.reviews[index]),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ClubReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 274,
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
              CircleAvatar(
                radius: 18,
                backgroundColor: PadelColors.greenDark,
                child: Text(
                  _initials(review.memberName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.memberName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFF5B942),
                size: 19,
              ),
              Text(
                ' ${review.rating}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: PadelColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 29),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _notificationIcon(String type) {
  return switch (type.toLowerCase()) {
    'reservation' => Icons.calendar_month_rounded,
    'tournament' => Icons.emoji_events_rounded,
    'promotion' => Icons.local_offer_rounded,
    _ => Icons.notifications_rounded,
  };
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return 'Today';
  }
  return '${local.day}.${local.month}.${local.year}';
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
