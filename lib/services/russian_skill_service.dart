import 'dart:convert';
import 'dart:io';

class RussianSkillService {
  static final RussianSkillService instance = RussianSkillService._();
  RussianSkillService._();

  /// Check if text contains any Cyrillic letters (Russian, etc.)
  bool containsCyrillic(String text) {
    return RegExp(r'[\u0400-\u04FF]').hasMatch(text);
  }

  /// Check if text contains Latin words
  bool containsLatinWords(String text) {
    return RegExp(r'[a-zA-Z]{2,}').hasMatch(text);
  }

  /// Check if text contains primarily English / Latin characters
  bool isPrimarilyEnglish(String text) {
    if (text.isEmpty) return false;
    final cyrillicMatches = RegExp(r'[\u0400-\u04FF]').allMatches(text).length;
    final latinMatches = RegExp(r'[a-zA-Z]').allMatches(text).length;
    return latinMatches > 5 && (latinMatches > cyrillicMatches * 1.2);
  }

  /// Format prompt for all BitNet models to enforce Russian output
  String formatRussianSkillPrompt({
    required String userPrompt,
    required String systemPrompt,
    required bool isEnglishOnlyModel,
  }) {
    final baseSys = systemPrompt.trim().isNotEmpty
        ? systemPrompt.trim()
        : 'Ты интеллектуальный ИИ-ассистент на базе 1-битной архитектуры BitNet 1.58b.';
    return 'Human: [System: $baseSys Always respond strictly in Russian language (на русском языке). Всегда отвечай пользователю грамотно, структурированно и строго на русском языке.]\n'
        '$userPrompt\n\n'
        'BITNETAssistant: ';
  }

  /// Quality translation to Russian with code block preservation
  Future<String?> translateToRussian(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;
    final cyrillicMatches = RegExp(r'[\u0400-\u04FF]').allMatches(trimmed).length;
    final latinMatches = RegExp(r'[a-zA-Z]').allMatches(trimmed).length;
    // Only skip if text is overwhelmingly Cyrillic (e.g. native Russian output)
    if (cyrillicMatches > 30 && latinMatches < 6) {
      return text;
    }
    return _translateText(trimmed, sourceLang: 'en', targetLang: 'ru');
  }

  /// Quality translation to English with code block preservation
  Future<String?> translateToEnglish(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;
    if (!containsCyrillic(trimmed)) {
      return text;
    }
    return _translateText(trimmed, sourceLang: 'ru', targetLang: 'en');
  }

  /// Core translation routine with chunking and code block isolation
  Future<String?> _translateText(
    String text, {
    required String sourceLang,
    required String targetLang,
  }) async {
    var normalizedText = text;
    final fenceCount = RegExp(r'```').allMatches(normalizedText).length;
    if (fenceCount % 2 != 0) {
      normalizedText = '$normalizedText\n```';
    }

    final codeBlockRegex = RegExp(r'```[\s\S]*?```');
    final matches = codeBlockRegex.allMatches(normalizedText);

    if (matches.isEmpty) {
      return _translateProse(normalizedText, sourceLang: sourceLang, targetLang: targetLang);
    }

    final buffer = StringBuffer();
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        final prose = normalizedText.substring(lastIndex, match.start);
        if (prose.trim().isNotEmpty) {
          final trans = await _translateProse(prose, sourceLang: sourceLang, targetLang: targetLang);
          buffer.write(trans ?? prose);
        } else {
          buffer.write(prose);
        }
      }
      // Write the code block 100% untranslated (preserves def, for, if, python syntax intact)
      buffer.write(match.group(0));
      lastIndex = match.end;
    }

    if (lastIndex < normalizedText.length) {
      final prose = normalizedText.substring(lastIndex);
      if (prose.trim().isNotEmpty) {
        final trans = await _translateProse(prose, sourceLang: sourceLang, targetLang: targetLang);
        buffer.write(trans ?? prose);
      } else {
        buffer.write(prose);
      }
    }

    return buffer.toString();
  }

  /// Translate regular prose without code blocks
  Future<String?> _translateProse(
    String prose, {
    required String sourceLang,
    required String targetLang,
  }) async {
    // Preserve inline code fragments `code`
    final inlineSnippets = <String>[];
    final textWithoutInline = prose.replaceAllMapped(RegExp(r'`[^`\n]+`'), (m) {
      final placeholder = '§§CODE${inlineSnippets.length}§§';
      inlineSnippets.add(m.group(0)!);
      return placeholder;
    });

    final paragraphs = textWithoutInline.split('\n');
    final translatedParagraphs = <String>[];

    for (final para in paragraphs) {
      final trimmedPara = para.trim();
      if (trimmedPara.isEmpty) {
        translatedParagraphs.add('');
        continue;
      }

      if (trimmedPara.length <= 1200) {
        final trans = await _translateChunk(trimmedPara, sourceLang: sourceLang, targetLang: targetLang);
        translatedParagraphs.add(trans ?? trimmedPara);
        continue;
      }

      final sentences = trimmedPara.split(RegExp(r'(?<=[.!?])\s+'));
      final chunks = <String>[];
      var currentChunk = '';

      for (final s in sentences) {
        if (currentChunk.isEmpty) {
          currentChunk = s;
        } else if (currentChunk.length + s.length + 1 < 800) {
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

    for (int i = 0; i < inlineSnippets.length; i++) {
      result = result.replaceAll('§§CODE${i}§§', inlineSnippets[i]);
      result = result.replaceAll('§§ CODE${i} §§', inlineSnippets[i]);
      result = result.replaceAll('§§ code${i} §§', inlineSnippets[i]);
    }

    if (result.trim() == prose.trim() && targetLang == 'ru' && isPrimarilyEnglish(result)) {
      return _offlineFallbackTranslate(prose, toRussian: true);
    }

    return result;
  }

  /// Translate a single text chunk with multi-provider fast parallel fallback
  Future<String?> _translateChunk(
    String chunk, {
    required String sourceLang,
    required String targetLang,
  }) async {
    final trimmed = chunk.trim();
    if (trimmed.isEmpty) return chunk;

    String? extractTextFromJson(dynamic data) {
      if (data is List && data.isNotEmpty) {
        final first = data[0];
        if (first is String) {
          return data.whereType<String>().join('');
        } else if (first is List) {
          final sb = StringBuffer();
          for (final item in data) {
            if (item is List) {
              for (final sub in item) {
                if (sub is List && sub.isNotEmpty && sub[0] is String) {
                  sb.write(sub[0]);
                }
              }
            }
          }
          if (sb.isNotEmpty) return sb.toString();
        }
      } else if (data is String && data.isNotEmpty) {
        return data;
      }
      return null;
    }

    Future<String?> tryPost(String urlStr) async {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 5000);
        final request = await client.postUrl(Uri.parse(urlStr));
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded; charset=utf-8');
        request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');

        final bodyBytes = utf8.encode('q=${Uri.encodeQueryComponent(trimmed)}');
        request.contentLength = bodyBytes.length;
        request.add(bodyBytes);

        final response = await request.close().timeout(const Duration(milliseconds: 5000));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          client.close();
          final res = extractTextFromJson(data);
          if (res != null && res.trim().isNotEmpty) return res;
        }
        client.close();
      } catch (_) {}
      return null;
    }

    // Attempt primary fast endpoints in parallel
    final primaryResults = await Future.wait([
      tryPost('https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=$sourceLang&tl=$targetLang'),
      tryPost('https://translate.google.com/translate_a/t?client=at&sl=$sourceLang&tl=$targetLang'),
    ]);

    for (final res in primaryResults) {
      if (res != null && res.trim().isNotEmpty) {
        return res;
      }
    }

    // Secondary GET fallback with query params
    try {
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 4000);
      final uri = Uri.parse(
        'https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=$sourceLang&tl=$targetLang&q=${Uri.encodeComponent(trimmed)}',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final response = await request.close().timeout(const Duration(milliseconds: 4000));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        client.close();
        final res = extractTextFromJson(data);
        if (res != null && res.trim().isNotEmpty) return res;
      }
      client.close();
    } catch (_) {}

    // Offline fallback translation
    return _offlineFallbackTranslate(chunk, toRussian: targetLang == 'ru');
  }

  /// Offline dictionary & rule-based translation fallback when network is unavailable
  String _offlineFallbackTranslate(String text, {required bool toRussian}) {
    if (!toRussian) {
      // Basic RU -> EN offline phrase mapping for model prompt
      var out = text;
      final ruToEn = {
        'Привет': 'Hello',
        'привет': 'hello',
        'Здравствуйте': 'Hello',
        'здравствуйте': 'hello',
        'Кто ты': 'Who are you',
        'кто ты': 'who are you',
        'Что такое': 'What is',
        'что такое': 'what is',
        'Как дела': 'How are you',
        'как дела': 'how are you',
        'Сколько будет': 'What is',
        'сколько будет': 'what is',
        'расскажи': 'tell me',
        'Расскажи': 'Tell me',
        'объясни': 'explain',
        'Объясни': 'Explain',
        'помоги': 'help me',
        'Помоги': 'Help me',
      };
      ruToEn.forEach((k, v) {
        out = out.replaceAll(k, v);
      });
      return out;
    }

    // EN -> RU offline phrase and sentence dictionary
    var res = text;

    final phrases = <String, String>{
      'I am an AI assistant': 'Я ИИ-ассистент',
      'I am a language model': 'Я языковая модель',
      'I am BitNet': 'Я BitNet',
      'I am a 1-bit LLM': 'Я 1-битная модель LLM',
      'running locally on': 'работающая локально на',
      'without internet access': 'без доступа в интернет',
      'How can I help you today?': 'Чем я могу вам помочь сегодня?',
      'How can I help you?': 'Чем я могу помочь вам?',
      'Hello! How can I assist you today?': 'Здравствуйте! Чем я могу помочь вам сегодня?',
      'Hello!': 'Здравствуйте!',
      'Hello': 'Здравствуйте',
      'Hi!': 'Привет!',
      'Hi': 'Привет',
      'Ternary bit-quantized data is a method of representing numbers': 'Троичные квантованные данные — это метод представления чисел',
      'Ternary bit-quantized data': 'Троичные квантованные данные',
      'Ternary (or base-3)': 'Троичная система счисления (по основанию 3)',
      'is a method of representing numbers': 'это способ представления чисел',
      'in three different bases': 'в трех различных базисах',
      'Quantization is': 'Квантование — это',
      'quantization': 'квантование',
      'is a technique': 'это метод',
      'to reduce memory': 'для экономии памяти',
      'The answer is': 'Ответ:',
      'is equal to': 'равно',
      'BitNet b1.58 is a 1-bit LLM': 'BitNet b1.58 — это 1-битная LLM',
      'ternary weights': 'троичные веса {-1, 0, +1}',
      'ternary': 'троичный',
      'weights': 'веса',
      'matrix multiplication': 'матричное умножение',
      'memory consumption': 'потребление оперативной памяти',
      'energy efficiency': 'энергоэффективность',
      'inference speed': 'скорость инференса',
      'tokens per second': 'токенов в секунду',
      'neural network': 'нейронная сеть',
      'language model': 'языковая модель',
      'artificial intelligence': 'искусственный интеллект',
      'In the context of': 'В контексте',
      'represented as': 'представляются как',
      'sign bit': 'знаковый бит',
      'fractional part': 'дробная часть',
      'integer representation': 'представление целых чисел',
      'integers': 'целые числа',
      'characters': 'символы',
      'bytes': 'байт',
      'bits': 'бит',
      'binary': 'двоичный',
    };

    phrases.forEach((en, ru) {
      res = res.replaceAll(RegExp(RegExp.escape(en), caseSensitive: false), ru);
    });

    return res;
  }
}
