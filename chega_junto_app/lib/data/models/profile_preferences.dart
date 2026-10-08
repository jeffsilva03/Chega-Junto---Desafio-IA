enum AppTextSize {
  small('Pequeno', .9),
  medium('Médio', 1),
  large('Grande', 1.2),
  extraLarge('Muito grande', 1.4);

  const AppTextSize(this.label, this.factor);
  final String label;
  final double factor;
}

enum AppAppearance {
  light('Claro'),
  dark('Escuro'),
  system('Do aparelho');

  const AppAppearance(this.label);
  final String label;
}

enum AccessibilityOption {
  contrast,
  speech,
  descriptions,
  simpleLanguage,
  haptics,
  reduceMotion,
}

class AccessibilityPreferences {
  const AccessibilityPreferences({
    this.textSize = AppTextSize.medium,
    this.appearance = AppAppearance.light,
    this.highContrast = false,
    this.speech = false,
    this.descriptions = true,
    this.simpleLanguage = true,
    this.haptics = true,
    this.reduceMotion = false,
  });
  final AppTextSize textSize;
  final AppAppearance appearance;
  final bool highContrast,
      speech,
      descriptions,
      simpleLanguage,
      haptics,
      reduceMotion;

  AccessibilityPreferences copyWith({
    AppTextSize? textSize,
    AppAppearance? appearance,
    bool? highContrast,
    bool? speech,
    bool? descriptions,
    bool? simpleLanguage,
    bool? haptics,
    bool? reduceMotion,
  }) => AccessibilityPreferences(
    textSize: textSize ?? this.textSize,
    appearance: appearance ?? this.appearance,
    highContrast: highContrast ?? this.highContrast,
    speech: speech ?? this.speech,
    descriptions: descriptions ?? this.descriptions,
    simpleLanguage: simpleLanguage ?? this.simpleLanguage,
    haptics: haptics ?? this.haptics,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  AccessibilityPreferences change(AccessibilityOption option, bool value) =>
      switch (option) {
        AccessibilityOption.contrast => copyWith(highContrast: value),
        AccessibilityOption.speech => copyWith(speech: value),
        AccessibilityOption.descriptions => copyWith(descriptions: value),
        AccessibilityOption.simpleLanguage => copyWith(simpleLanguage: value),
        AccessibilityOption.haptics => copyWith(haptics: value),
        AccessibilityOption.reduceMotion => copyWith(reduceMotion: value),
      };
}

enum NotificationOption {
  active,
  appointments,
  exams,
  medications,
  documents,
  confirmations,
  system,
  inApp,
}

class NotificationPreferences {
  NotificationPreferences([Map<NotificationOption, bool>? values])
    : _values = Map.unmodifiable(
        values ??
            {
              for (final option in NotificationOption.values)
                option: option != NotificationOption.system,
            },
      );
  final Map<NotificationOption, bool> _values;
  bool enabled(NotificationOption option) => _values[option] ?? false;
  NotificationPreferences change(NotificationOption option, bool value) =>
      NotificationPreferences({..._values, option: value});
}
