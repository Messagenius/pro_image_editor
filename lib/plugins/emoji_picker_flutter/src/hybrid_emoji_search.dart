import '/plugins/emoji_picker_flutter/emoji_picker_flutter.dart';

/// Unicode script families used for origin-aware result ranking.
enum _Script { latin, arabic, cjk, cyrillic, devanagari, other }

/// Language codes grouped by their dominant Unicode script.
const _scriptLocales = <_Script, List<String>>{
  _Script.latin: ['en', 'de', 'es', 'fr', 'it', 'nl', 'pt', 'id'],
  _Script.arabic: ['ar'],
  _Script.cjk: ['ja', 'zh'],
  _Script.cyrillic: ['ru', 'uk'],
  _Script.devanagari: ['hi'],
};

final _keywordTokenSplit = RegExp(r'[\s:;,_/&().\-]+');

bool _keywordMatchesToken(String keyword, String token) {
  if (keyword.startsWith(token)) return true;

  return keyword
      .split(_keywordTokenSplit)
      .where((part) => part.isNotEmpty)
      .any((part) => part.startsWith(token));
}

bool _keywordsMatchTokens(Set<String> keywords, List<String> tokens) {
  return tokens.every(
    (token) => keywords.any((keyword) => _keywordMatchesToken(keyword, token)),
  );
}

/// Detects the dominant Unicode script of [text].
_Script _detectScript(String text) {
  final counts = <_Script, int>{for (final s in _Script.values) s: 0};
  for (final r in text.runes) {
    if ((r >= 0x0041 && r <= 0x007A) ||
        (r >= 0x0061 && r <= 0x007A) ||
        (r >= 0x00C0 && r <= 0x024F)) {
      counts[_Script.latin] = (counts[_Script.latin] ?? 0) + 1;
    } else if (r >= 0x0600 && r <= 0x06FF) {
      counts[_Script.arabic] = (counts[_Script.arabic] ?? 0) + 1;
    } else if ((r >= 0x4E00 && r <= 0x9FFF) ||
        (r >= 0x3040 && r <= 0x30FF) ||
        (r >= 0x3400 && r <= 0x4DBF)) {
      counts[_Script.cjk] = (counts[_Script.cjk] ?? 0) + 1;
    } else if (r >= 0x0400 && r <= 0x04FF) {
      counts[_Script.cyrillic] = (counts[_Script.cyrillic] ?? 0) + 1;
    } else if (r >= 0x0900 && r <= 0x097F) {
      counts[_Script.devanagari] = (counts[_Script.devanagari] ?? 0) + 1;
    }
  }
  final dominant = counts.entries
      .where((e) => e.key != _Script.other && e.value > 0)
      .fold<MapEntry<_Script, int>?>(
          null, (best, e) => best == null || e.value > best.value ? e : best);
  return dominant?.key ?? _Script.other;
}

/// A cross-language emoji search index that merges keyword data from every
/// provided locale set and ranks results by relevance:
///
/// 1. **Active-locale match** - the query matches keywords in the currently
///    displayed locale (highest priority).
/// 2. **Script match** - the query's detected Unicode script corresponds to
///    the locale that produced the keyword match (e.g., Cyrillic query
///    boosts Russian/Ukrainian results).
/// 3. **Cross-locale match** - the query matches keywords from any other
///    locale (lowest priority but still surfaced).
///
/// Usage:
/// ```dart
/// final index = HybridEmojiSearchIndex();
/// index.build(activeLocaleSet, getAllDefaultLocaleSets());
/// final results = index.search('smile');
/// ```
///
/// Rebuild by calling [build] again with `force: true` when the active
/// locale changes.
class HybridEmojiSearchIndex {
  // emoji char -> merged lowercase keywords from every locale
  final Map<String, Set<String>> _index = {};
  // emoji char -> lowercase keywords from the active locale
  final Map<String, Set<String>> _activeKeywords = {};
  // language-code -> emoji char -> lowercase keywords
  final Map<String, Map<String, Set<String>>> _localeKeywords = {};
  // emoji char -> Emoji object used for display (from active locale, or
  // English as fallback when the active locale doesn't contain the emoji)
  final Map<String, Emoji> _displayEmojis = {};

  bool _built = false;

  /// Whether the index has been built at least once.
  bool get isBuilt => _built;

  /// Builds (or rebuilds) the index.
  ///
  /// [activeSet] is the locale whose [Emoji.name]/[Emoji.keywords] are used
  /// for display and receive the highest ranking tier.
  ///
  /// [allSets] maps language codes to their [CategoryEmoji] lists. It should
  /// include all locales you want to search across (typically the return
  /// value of [getAllDefaultLocaleSets]).
  ///
  /// Set [force] to `true` to rebuild even if already built.
  void build(
    List<CategoryEmoji> activeSet,
    Map<String, List<CategoryEmoji>> allSets, {
    bool force = false,
  }) {
    if (_built && !force) return;

    _index.clear();
    _activeKeywords.clear();
    _localeKeywords.clear();
    _displayEmojis.clear();

    // Index active-locale keywords first so display emojis come from there.
    for (final cat in activeSet) {
      if (cat.category == Category.RECENT) continue;
      for (final emoji in cat.emoji) {
        final kw = emoji.keywords.map((k) => k.toLowerCase()).toSet();
        _displayEmojis[emoji.emoji] = emoji;
        _activeKeywords[emoji.emoji] = kw;
        _index.putIfAbsent(emoji.emoji, () => <String>{}).addAll(kw);
      }
    }

    // Merge keywords from every locale into the global index.
    for (final entry in allSets.entries) {
      final langCode = entry.key;
      final localeMap = <String, Set<String>>{};
      _localeKeywords[langCode] = localeMap;

      for (final cat in entry.value) {
        if (cat.category == Category.RECENT) continue;
        for (final emoji in cat.emoji) {
          final char = emoji.emoji;
          final kw = emoji.keywords.map((k) => k.toLowerCase()).toSet();
          localeMap[char] = kw;
          _index.putIfAbsent(char, () => <String>{}).addAll(kw);
          // Provide a display emoji for any char not present in active set.
          _displayEmojis.putIfAbsent(char, () => emoji);
        }
      }
    }

    _built = true;
  }

  /// Searches for emojis matching [query] across every indexed locale.
  ///
  /// Matching uses the same prefix rule as [EmojiPickerUtils.searchEmoji]:
  /// each whitespace-separated token must be a prefix of at least one emoji
  /// keyword. Additionally, a direct match on the emoji character is accepted.
  ///
  /// Results are sorted: active-locale matches first, then matches whose
  /// script aligns with the query language, then all other cross-locale hits.
  ///
  /// Returns an empty list when the index has not been built yet.
  List<Emoji> search(String query, {int maxResults = 100}) {
    if (!_built || query.isEmpty) return [];

    final trimmed = query.trim();

    // Direct emoji character match.
    final charMatch = _displayEmojis[trimmed];

    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => t.toLowerCase())
        .toList();

    if (tokens.isEmpty) return charMatch != null ? [charMatch] : [];

    final queryScript = _detectScript(trimmed);
    final scriptCodes = _scriptLocales[queryScript] ?? const <String>[];

    final scored = <_ScoredEmoji>[];

    for (final entry in _index.entries) {
      final char = entry.key;
      final allKw = entry.value;

      if (!_keywordsMatchTokens(allKw, tokens)) {
        continue;
      }

      final display = _displayEmojis[char];
      if (display == null) continue;

      final activeKw = _activeKeywords[char] ?? const <String>{};
      final matchesActive = _keywordsMatchTokens(activeKw, tokens);

      var matchesScript = false;
      if (!matchesActive) {
        for (final lc in scriptCodes) {
          final lkw = _localeKeywords[lc]?[char];
          if (lkw != null && _keywordsMatchTokens(lkw, tokens)) {
            matchesScript = true;
            break;
          }
        }
      }

      scored.add(_ScoredEmoji(
        display,
        matchesActive ? 3 : (matchesScript ? 2 : 1),
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    final keywordResults = scored.take(maxResults).map((e) => e.emoji).toList();

    if (charMatch != null && !keywordResults.contains(charMatch)) {
      return [charMatch, ...keywordResults];
    }
    return keywordResults;
  }
}

class _ScoredEmoji {
  const _ScoredEmoji(this.emoji, this.score);
  final Emoji emoji;
  final int score;
}
