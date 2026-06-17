import 'package:flutter/material.dart';

import '../emoji_picker_flutter.dart';

/// Returns every built-in locale set keyed by its IETF language code.
///
/// Pass this to [HybridEmojiSearchIndex.build] or
/// [EmojiPickerUtils.searchEmojiHybrid] to enable cross-language search
/// across all supported languages.
Map<String, List<CategoryEmoji>> getAllDefaultLocaleSets() => {
      'ar': emojiSetArabic,
      'de': emojiSetGerman,
      'en': emojiSetEnglish,
      'es': emojiSetSpanish,
      'fr': emojiSetFrance,
      'hi': emojiSetHindi,
      'id': emojiSetIndonesian,
      'it': emojiSetItalian,
      'ja': emojiSetJapanese,
      'nl': emojiSetDutch,
      'pt': emojiSetPortuguese,
      'ru': emojiSetRussian,
      'uk': emojiSetUkrainian,
      'zh': emojiSetChinese,
    };

/// Default method for locale selection
List<CategoryEmoji> getDefaultEmojiLocale(Locale locale) {
  switch (locale.languageCode) {
    case 'ar':
      return emojiSetArabic;
    case 'de':
      return emojiSetGerman;
    case 'en':
      return emojiSetEnglish;
    case 'es':
      return emojiSetSpanish;
    case 'fr':
      return emojiSetFrance;
    case 'hi':
      return emojiSetHindi;
    case 'id':
      return emojiSetIndonesian;
    case 'it':
      return emojiSetItalian;
    case 'ja':
      return emojiSetJapanese;
    case 'nl':
      return emojiSetDutch;
    case 'pt':
      return emojiSetPortuguese;
    case 'ru':
      return emojiSetRussian;
    case 'uk':
      return emojiSetUkrainian;
    case 'zh':
      return emojiSetChinese;
    default:
      return emojiSetEnglish;
  }
}
