/// Picks a sensible icon for a tab whose spec entry gave only an id.
///
/// Names are `PiconsRegular` constants, all verified to exist in picons 3.0.1.
/// The material fallback names are `Icons` constants. An unrecognised id gets
/// a neutral shape rather than a guess that reads as wrong.
library;

const _piconsByTabId = <String, String>{
  'home': 'house',
  'dashboard': 'squaresFour',
  'search': 'magnifyingGlass',
  'explore': 'compass',
  'browse': 'compass',
  'notes': 'note',
  'note': 'note',
  'tasks': 'checkSquare',
  'todos': 'listChecks',
  'today': 'sun',
  'inbox': 'tray',
  'calendar': 'calendarBlank',
  'stats': 'chartBar',
  'reports': 'chartBar',
  'profile': 'user',
  'account': 'user',
  'library': 'books',
  'favourites': 'star',
  'favorites': 'star',
  'bookmarks': 'bookmarkSimple',
  'history': 'clockCounterClockwise',
  'timer': 'timer',
  'projects': 'folders',
  'clients': 'addressBook',
  'contacts': 'addressBook',
  'messages': 'chatCircle',
  'chat': 'chatCircle',
  'feed': 'newspaper',
  'map': 'mapTrifold',
  'gallery': 'images',
  'photos': 'images',
  'settings': 'gear',
};

const _materialByTabId = <String, String>{
  'home': 'home_outlined',
  'dashboard': 'grid_view_outlined',
  'search': 'search',
  'explore': 'explore_outlined',
  'browse': 'explore_outlined',
  'notes': 'note_outlined',
  'note': 'note_outlined',
  'tasks': 'check_box_outlined',
  'todos': 'checklist',
  'today': 'wb_sunny_outlined',
  'inbox': 'inbox_outlined',
  'calendar': 'calendar_today_outlined',
  'stats': 'bar_chart_outlined',
  'reports': 'bar_chart_outlined',
  'profile': 'person_outline',
  'account': 'person_outline',
  'library': 'library_books_outlined',
  'favourites': 'star_outline',
  'favorites': 'star_outline',
  'bookmarks': 'bookmark_outline',
  'history': 'history',
  'timer': 'timer_outlined',
  'projects': 'folder_outlined',
  'clients': 'contacts_outlined',
  'contacts': 'contacts_outlined',
  'messages': 'chat_bubble_outline',
  'chat': 'chat_bubble_outline',
  'feed': 'feed_outlined',
  'map': 'map_outlined',
  'gallery': 'photo_library_outlined',
  'photos': 'photo_library_outlined',
  'settings': 'settings_outlined',
};

/// The picons constant name for [tabId], or `circle` when unknown.
String defaultPiconsIcon(String tabId) => _piconsByTabId[tabId] ?? 'circle';

/// The `Icons` constant name for [tabId], or `circle_outlined` when unknown.
String defaultMaterialIcon(String tabId) =>
    _materialByTabId[tabId] ?? 'circle_outlined';

/// Translate a picons constant name to its nearest `Icons` equivalent, so a
/// spec written for picons still renders when `icons: material` is chosen.
String materialEquivalentOf(String piconsName) {
  for (final entry in _piconsByTabId.entries) {
    if (entry.value == piconsName) {
      return _materialByTabId[entry.key] ?? 'circle_outlined';
    }
  }
  return 'circle_outlined';
}

/// `my_stuff` -> `My Stuff`. Used when a tab is given as a bare id.
String titleizeTabId(String tabId) => tabId
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

/// The Dart expression a template should emit for [iconName].
///
/// A spec written against one icon set still generates a working app when the
/// other is chosen: material names are recognised by their underscores, and a
/// name with no equivalent falls back to a neutral shape rather than a wrong
/// guess. Shared by the global template context and the per-tab file context
/// so the two cannot disagree.
String iconExpression({required bool usePicons, required String iconName}) {
  final looksMaterial = iconName.contains('_');
  if (usePicons) {
    return looksMaterial ? 'PiconsRegular.circle' : 'PiconsRegular.$iconName';
  }
  return looksMaterial
      ? 'Icons.$iconName'
      : 'Icons.${materialEquivalentOf(iconName)}';
}
