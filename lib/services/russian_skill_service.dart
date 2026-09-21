import 'dart:convert';
import 'dart:io';

class RussianSkillService {
  static final RussianSkillService instance = RussianSkillService._();
  RussianSkillService._();

  /// Check if text contains any Cyrillic letters (Russian, etc.)
  bool containsCyrillic(String text) {
    return RegExp(r'[\u0400-\u04FF]').hasMatch(text);
  }

  /// Check if text contains primarily English / Latin characters
  bool isPrimarilyEnglish(String text) {
    if (text.isEmpty) return false;
    final cyrillicMatches = RegExp(r'[\u0400-\u04FF]').allMatches(text).length;
    final latinMatches = RegExp(r'[a-zA-Z]').allMatches(text).length;
    return latinMatches > 10 && (latinMatches > cyrillicMatches * 2);
  }

  /// Format prompt for English-centric models using Few-Shot Priming
  /// to naturally guide the model into responding in Russian.
  String formatRussianSkillPrompt({
    required String userPrompt,
    required String systemPrompt,
    required bool isEnglishOnlyModel,
  }) {
    if (!containsCyrillic(userPrompt)) {
      return userPrompt;
    }

    return 'Human: [System: You are an intelligent AI assistant. Always respond in fluent Russian (на русском языке). Всегда отвечай только на русском языке.]\n'
        'Привет!\n\n'
        'BITNETAssistant: Здравствуйте! Я локальный ИИ BitNet. Чем я могу помочь вам сегодня?\n\n'
        'Human: $userPrompt\n\n'
        'BITNETAssistant: ';
  }

  /// Quality translation to Russian with code block preservation
  /// Returns null if offline or translation fails (preserving clean original text)
  Future<String?> translateToRussian(String text) async {
    if (text.trim().isEmpty || !isPrimarilyEnglish(text)) {
      return null;
    }
    return _translateText(text, sourceLang: 'en', targetLang: 'ru');
  }

  /// Quality translation to English with code block preservation
  Future<String?> translateToEnglish(String text) async {
    if (text.trim().isEmpty || !containsCyrillic(text)) {
      return null;
    }
    return _translateText(text, sourceLang: 'ru', targetLang: 'en');
  }

  /// Core translation routine with chunking and fallback
  Future<String?> _translateText(
    String text, {
    required String sourceLang,
    required String targetLang,
  }) async {
    // 1. Preserve markdown code blocks and inline code
    final codeBlocks = <String>[];
    final textWithoutCode = text.replaceAllMapped(
      RegExp(r'```[\s\S]*?```|`[^`\n]+`'),
      (match) {
        final placeholder = '__CODE_BLOCK_${codeBlocks.length}__';
        codeBlocks.add(match.group(0)!);
        return placeholder;
      },
    );

    // 2. Break down into paragraphs and sentence chunks (<400 chars)
    final paragraphs = textWithoutCode.split('\n');
    final translatedParagraphs = <String>[];

    for (final para in paragraphs) {
      if (para.trim().isEmpty) {
        translatedParagraphs.add('');
        continue;
      }

      final sentences = para.split(RegExp(r'(?<=[.!?])\s+'));
      final chunks = <String>[];
      var currentChunk = '';

      for (final s in sentences) {
        if (currentChunk.isEmpty) {
          currentChunk = s;
        } else if (currentChunk.length + s.length + 1 < 380) {
          currentChunk += ' $s';
        } else {
          chunks.add(currentChunk);
          currentChunk = s;
        }
      }
      if (currentChunk.isNotEmpty) {
        chunks.add(currentChunk);
      }

      final translatedChunks = <String>[];
      for (final chunk in chunks) {
        final translatedChunk = await _translateChunk(
          chunk,
          sourceLang: sourceLang,
          targetLang: targetLang,
        );
        translatedChunks.add(translatedChunk ?? chunk);
      }
      translatedParagraphs.add(translatedChunks.join(' '));
    }

    var result = translatedParagraphs.join('\n');

    // 3. Restore preserved code blocks
    for (int i = 0; i < codeBlocks.length; i++) {
      result = result.replaceAll('__CODE_BLOCK_${i}__', codeBlocks[i]);
    }

    if (result.trim() == text.trim()) {
      return null;
    }

    return result;
  }

  /// Translate a single text chunk (<400 chars) using MyMemory with fallback to Google Translate
  Future<String?> _translateChunk(
    String chunk, {
    required String sourceLang,
    required String targetLang,
  }) async {
    final trimmed = chunk.trim();
    if (trimmed.isEmpty) return chunk;

    // Try MyMemory API first
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(trimmed)}&langpair=$sourceLang|$targetLang',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'BitNetMobile/1.0');
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        if (json is Map && json['responseData'] is Map) {
          final translated = json['responseData']['translatedText'];
          if (translated is String &&
              translated.isNotEmpty &&
              !translated.startsWith('MYMEMORY WARNING:')) {
            client.close();
            return translated;
          }
        }
      }
      client.close();
    } catch (_) {}

    // Fallback: Google Translate public single endpoint
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(trimmed)}',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Linux; Android 14)');
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        if (json is List && json.isNotEmpty && json[0] is List) {
          final sb = StringBuffer();
          for (final item in json[0]) {
            if (item is List && item.isNotEmpty && item[0] is String) {
              sb.write(item[0]);
            }
          }
          final res = sb.toString();
          client.close();
          if (res.isNotEmpty) return res;
        }
      }
      client.close();
    } catch (_) {}

    return null;
  }
}
