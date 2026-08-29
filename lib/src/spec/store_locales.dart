/// Which listing languages each store accepts.
///
/// Play and the App Store genuinely differ, and the difference is not
/// cosmetic: a metadata directory named for a language Apple does not know is
/// rejected by `deliver`.
library;

/// The Play listing directory for an app locale.
///
/// Play is the permissive one — it accepts far more languages than Apple,
/// including Nepali.
String playListingDirectory(String locale) => switch (locale) {
  'en' => 'en-US',
  'ne' => 'ne-NP',
  _ => locale,
};

/// The App Store Connect language for an app locale, or null when Apple has no
/// such listing language.
///
/// Apple accepts a fixed list — fastlane's `ALL_LANGUAGES`, generated from App
/// Store Connect itself. It carries `bn-BD`, `hi`, `ur-PK` and nine Indian
/// languages, but **no Nepali**. So a bilingual app ships a localised Play
/// listing and an English-only App Store one, and beej has to model that
/// rather than mirror one store onto the other.
String? appStoreLanguage(String locale) => switch (locale) {
  'en' => 'en-US',
  'ne' => null,
  _ => null,
};
