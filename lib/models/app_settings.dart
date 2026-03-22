class AppSettings {
  final String theme; // 'light' | 'dark' | 'system'
  final bool reminderEnabled;
  final String reminderTime; // HH:mm
  final List<int> reminderDays; // 0=So, 1=Mo...6=Sa
  final bool openReminderEnabled;
  final String openReminderTime;
  final List<int> openReminderDays;

  const AppSettings({
    this.theme = 'system',
    this.reminderEnabled = false,
    this.reminderTime = '18:00',
    this.reminderDays = const [1, 2, 3, 4, 5],
    this.openReminderEnabled = false,
    this.openReminderTime = '18:00',
    this.openReminderDays = const [1, 2, 3, 4, 5],
  });

  AppSettings copyWith({
    String? theme,
    bool? reminderEnabled,
    String? reminderTime,
    List<int>? reminderDays,
    bool? openReminderEnabled,
    String? openReminderTime,
    List<int>? openReminderDays,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderDays: reminderDays ?? this.reminderDays,
      openReminderEnabled: openReminderEnabled ?? this.openReminderEnabled,
      openReminderTime: openReminderTime ?? this.openReminderTime,
      openReminderDays: openReminderDays ?? this.openReminderDays,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme,
    'reminderEnabled': reminderEnabled,
    'reminderTime': reminderTime,
    'reminderDays': reminderDays,
    'openReminderEnabled': openReminderEnabled,
    'openReminderTime': openReminderTime,
    'openReminderDays': openReminderDays,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      theme: json['theme'] as String? ?? 'system',
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderTime: json['reminderTime'] as String? ?? '18:00',
      reminderDays: (json['reminderDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [1, 2, 3, 4, 5],
      openReminderEnabled: json['openReminderEnabled'] as bool? ?? false,
      openReminderTime: json['openReminderTime'] as String? ?? '18:00',
      openReminderDays: (json['openReminderDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [1, 2, 3, 4, 5],
    );
  }
}
