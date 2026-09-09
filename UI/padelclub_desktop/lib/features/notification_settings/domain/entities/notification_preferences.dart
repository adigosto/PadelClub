class NotificationPreferences {
  const NotificationPreferences({
    required this.inAppEnabled,
    required this.emailEnabled,
    required this.pushEnabled,
  });

  const NotificationPreferences.defaults()
    : inAppEnabled = true,
      emailEnabled = true,
      pushEnabled = true;

  final bool inAppEnabled;
  final bool emailEnabled;
  final bool pushEnabled;

  NotificationPreferences copyWith({
    bool? inAppEnabled,
    bool? emailEnabled,
    bool? pushEnabled,
  }) {
    return NotificationPreferences(
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}
