class MeaningLanguage {
  const MeaningLanguage({required this.id, required this.name});

  final String id;
  final String name;

  bool get matchesHighlight => id == matchId;

  static const matchId = 'match';
  static const englishId = 'en';

  static const matchHighlight = MeaningLanguage(
    id: matchId,
    name: 'Same as highlighted text',
  );

  static const english = MeaningLanguage(id: englishId, name: 'English');

  static const defaultLanguage = english;

  @override
  bool operator ==(Object other) =>
      other is MeaningLanguage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class MeaningLanguageCatalog {
  static const commonIds = <String>[
    'en',
    'ur',
    'ar',
    'hi',
    'es',
    'fr',
    'zh',
    'de',
    'pt',
    'tr',
  ];

  static const _rest = <MeaningLanguage>[
    MeaningLanguage(id: 'bn', name: 'Bengali'),
    MeaningLanguage(id: 'cs', name: 'Czech'),
    MeaningLanguage(id: 'da', name: 'Danish'),
    MeaningLanguage(id: 'nl', name: 'Dutch'),
    MeaningLanguage(id: 'fi', name: 'Finnish'),
    MeaningLanguage(id: 'el', name: 'Greek'),
    MeaningLanguage(id: 'he', name: 'Hebrew'),
    MeaningLanguage(id: 'hu', name: 'Hungarian'),
    MeaningLanguage(id: 'id', name: 'Indonesian'),
    MeaningLanguage(id: 'it', name: 'Italian'),
    MeaningLanguage(id: 'ja', name: 'Japanese'),
    MeaningLanguage(id: 'ko', name: 'Korean'),
    MeaningLanguage(id: 'ms', name: 'Malay'),
    MeaningLanguage(id: 'no', name: 'Norwegian'),
    MeaningLanguage(id: 'fa', name: 'Persian'),
    MeaningLanguage(id: 'pl', name: 'Polish'),
    MeaningLanguage(id: 'pa', name: 'Punjabi'),
    MeaningLanguage(id: 'ro', name: 'Romanian'),
    MeaningLanguage(id: 'ru', name: 'Russian'),
    MeaningLanguage(id: 'sv', name: 'Swedish'),
    MeaningLanguage(id: 'sw', name: 'Swahili'),
    MeaningLanguage(id: 'tl', name: 'Tagalog'),
    MeaningLanguage(id: 'ta', name: 'Tamil'),
    MeaningLanguage(id: 'th', name: 'Thai'),
    MeaningLanguage(id: 'uk', name: 'Ukrainian'),
    MeaningLanguage(id: 'vi', name: 'Vietnamese'),
  ];

  static const _common = <MeaningLanguage>[
    MeaningLanguage(id: 'en', name: 'English'),
    MeaningLanguage(id: 'ur', name: 'Urdu'),
    MeaningLanguage(id: 'ar', name: 'Arabic'),
    MeaningLanguage(id: 'hi', name: 'Hindi'),
    MeaningLanguage(id: 'es', name: 'Spanish'),
    MeaningLanguage(id: 'fr', name: 'French'),
    MeaningLanguage(id: 'zh', name: 'Chinese'),
    MeaningLanguage(id: 'de', name: 'German'),
    MeaningLanguage(id: 'pt', name: 'Portuguese'),
    MeaningLanguage(id: 'tr', name: 'Turkish'),
  ];

  static List<MeaningLanguage> get all {
    return [
      MeaningLanguage.matchHighlight,
      ..._common,
      ..._rest,
    ];
  }

  static MeaningLanguage byId(String? id) {
    for (final language in all) {
      if (language.id == id) return language;
    }
    return MeaningLanguage.defaultLanguage;
  }

  static List<MeaningLanguage> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return all
        .where(
          (language) =>
              language.name.toLowerCase().contains(needle) ||
              language.id.toLowerCase().contains(needle),
        )
        .toList();
  }

  /// Selected language is first. The rest keep catalog order.
  static List<MeaningLanguage> listed({
    required MeaningLanguage selected,
    String query = '',
  }) {
    final results = search(query);
    return [
      ...results.where((language) => language.id == selected.id),
      ...results.where((language) => language.id != selected.id),
    ];
  }
}
