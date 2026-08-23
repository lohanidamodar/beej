/// Nepali labels for common tab ids.
///
/// A generated `app_ne.arb` full of English copies is worse than useless — it
/// looks translated, so nobody revisits it. Every string beej itself writes is
/// genuinely translated; tab labels are the one place the developer chose the
/// wording, so known ids are translated here and anything unrecognised falls
/// back to the English label with a `# TODO` marker the developer will see.
library;

const _nepaliByTabId = <String, String>{
  'home': 'गृह',
  'dashboard': 'ड्यासबोर्ड',
  'search': 'खोज',
  'explore': 'अन्वेषण',
  'browse': 'हेर्नुहोस्',
  'notes': 'टिपोटहरू',
  'note': 'टिपोट',
  'tasks': 'कामहरू',
  'todos': 'गर्नुपर्ने',
  'today': 'आज',
  'inbox': 'इनबक्स',
  'calendar': 'पात्रो',
  'stats': 'तथ्याङ्क',
  'reports': 'प्रतिवेदन',
  'profile': 'प्रोफाइल',
  'account': 'खाता',
  'library': 'पुस्तकालय',
  'favourites': 'मनपर्ने',
  'favorites': 'मनपर्ने',
  'bookmarks': 'बुकमार्क',
  'history': 'इतिहास',
  'timer': 'टाइमर',
  'projects': 'परियोजनाहरू',
  'clients': 'ग्राहकहरू',
  'contacts': 'सम्पर्कहरू',
  'messages': 'सन्देशहरू',
  'chat': 'कुराकानी',
  'feed': 'फिड',
  'map': 'नक्सा',
  'gallery': 'ग्यालरी',
  'photos': 'तस्बिरहरू',
  'settings': 'सेटिङ',
};

/// The Nepali label for [tabId], or null when beej does not know the word.
String? nepaliTabLabel(String tabId) => _nepaliByTabId[tabId];
