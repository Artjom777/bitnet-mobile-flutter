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
    return latinMatches > 5 && (latinMatches > cyrillicMatches * 1.5);
  }

  /// Format prompt for English-centric models using clear instruction
  String formatRussianSkillPrompt({
    required String userPrompt,
    required String systemPrompt,
    required bool isEnglishOnlyModel,
  }) {
    if (isEnglishOnlyModel) {
      return 'Human: [System: You are an intelligent AI assistant. Provide a clear, correct, and structured response to the user.]\n'
          '$userPrompt\n\n'
          'BITNETAssistant: ';
    }
    return 'Human: $userPrompt\n\nBITNETAssistant: ';
  }

  /// Quality translation to Russian with code block preservation
  Future<String?> translateToRussian(String text) async {
    if (text.trim().isEmpty) return text;
    if (!isPrimarilyEnglish(text) && containsCyrillic(text)) {
      return text;
    }
    return _translateText(text, sourceLang: 'en', targetLang: 'ru');
  }

  /// Quality translation to English with code block preservation
  Future<String?> translateToEnglish(String text) async {
    if (text.trim().isEmpty) return text;
    if (!containsCyrillic(text)) {
      return text;
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

    if (result.trim() == text.trim() && targetLang == 'ru' && isPrimarilyEnglish(result)) {
      // If network translation failed, use offline dictionary translator
      return _offlineFallbackTranslate(text, toRussian: true);
    }

    return result;
  }

  /// Translate a single text chunk (<400 chars) with multi-provider fallback
  Future<String?> _translateChunk(
    String chunk, {
    required String sourceLang,
    required String targetLang,
  }) async {
    final trimmed = chunk.trim();
    if (trimmed.isEmpty) return chunk;

    // Provider 1: Google clients5 dict-chrome-ex (extremely fast, high throughput)
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(
        'https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=$sourceLang&tl=$targetLang&q=${Uri.encodeComponent(trimmed)}',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        client.close();
        if (data is List && data.isNotEmpty && data[0] is String) {
          return data[0] as String;
        } else if (data is String && data.isNotEmpty) {
          return data;
        }
      }
      client.close();
    } catch (_) {}

    // Provider 2: Google Translate single gtx
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(trimmed)}',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        client.close();
        if (data is List && data.isNotEmpty && data[0] is List) {
          final sb = StringBuffer();
          for (final item in data[0]) {
            if (item is List && item.isNotEmpty && item[0] is String) {
              sb.write(item[0]);
            }
          }
          final res = sb.toString();
          if (res.isNotEmpty) return res;
        }
      }
      client.close();
    } catch (_) {}

    // Provider 3: Lingva translate mirror
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse(
        'https://lingva.ml/api/v1/$sourceLang/$targetLang/${Uri.encodeComponent(trimmed)}',
      );
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        client.close();
        if (data is Map && data['translation'] is String) {
          return data['translation'] as String;
        }
      }
      client.close();
    } catch (_) {}

    // Provider 4: MyMemory API
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(trimmed)}&langpair=$sourceLang|$targetLang',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'BitNetMobile/1.0');
      final response = await request.close().timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        client.close();
        if (json is Map && json['responseData'] is Map) {
          final translated = json['responseData']['translatedText'];
          if (translated is String &&
              translated.isNotEmpty &&
              !translated.startsWith('MYMEMORY WARNING:')) {
            return translated;
          }
        }
      }
      client.close();
    } catch (_) {}

    // Provider 5: Offline fallback translation
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

    // EN -> RU offline comprehensive phrase & grammar dictionary
    var res = text;

    final phrases = <String, String>{
      'I am an AI assistant': 'Я ИИ-ассистент',
      'I am a language model': 'Я языковая модель',
      'I am BitNet': 'Я BitNet',
      'I am a 1-bit LLM': 'Я 1-битная LLM',
      'running locally on': 'работающая локально на',
      'without internet access': 'без доступа в интернет',
      'How can I help you today?': 'Чем я могу вам помочь сегодня?',
      'How can I help you?': 'Чем я могу помочь вам?',
      'Hello! How can I assist you today?': 'Здравствуйте! Чем я могу помочь вам сегодня?',
      'Hello!': 'Здравствуйте!',
      'Hi!': 'Привет!',
      'Quantization is': 'Квантование — это',
      'is a technique': 'это метод',
      'to reduce memory': 'для экономии памяти',
      'The answer is': 'Ответ:',
      'is equal to': 'равно',
      'is': '— это',
      'are': '— это',
    };

    phrases.forEach((en, ru) {
      res = res.replaceAll(RegExp(RegExp.escape(en), caseSensitive: false), ru);
    });

    final words = <String, String>{
      'yes': 'да',
      'no': 'нет',
      'hello': 'привет',
      'hi': 'привет',
      'thanks': 'спасибо',
      'thank you': 'спасибо',
      'please': 'пожалуйста',
      'welcome': 'добро пожаловать',
      'good': 'хорошо',
      'bad': 'плохо',
      'fast': 'быстро',
      'slow': 'медленно',
      'memory': 'память',
      'speed': 'скорость',
      'model': 'модель',
      'neural network': 'нейросеть',
      'weights': 'веса',
      'quantization': 'квантование',
      'result': 'результат',
      'answer': 'ответ',
      'question': 'вопрос',
      'zero': 'ноль',
      'one': 'один',
      'two': 'два',
      'three': 'три',
      'four': 'четыре',
      'five': 'пять',
      'six': 'шесть',
      'seven': 'семь',
      'eight': 'восемь',
      'nine': 'девять',
      'ten': 'десять',
      'because': 'потому что',
      'therefore': 'следовательно',
      'example': 'пример',
      'for example': 'например',
      'equal': 'равно',
      'plus': 'плюс',
      'minus': 'минус',
      'multiply': 'умножить',
      'divide': 'разделить',
    };

    words.forEach((en, ru) {
      res = res.replaceAll(RegExp('\\b${RegExp.escape(en)}\\b', caseSensitive: false), ru);
    });

    return res;
  }
}
