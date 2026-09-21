import 'dart:core';

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
    return latinMatches > 0 && (latinMatches > cyrillicMatches * 2);
  }

  /// Format prompt for English-centric models when user inputs Russian
  String formatRussianSkillPrompt({
    required String userPrompt,
    required String systemPrompt,
    required bool isEnglishOnlyModel,
  }) {
    if (!containsCyrillic(userPrompt)) {
      return userPrompt;
    }

    final enMeaning = translateRussianToEnglish(userPrompt);

    return '[System: You are an intelligent multilingual AI assistant powered by BitNet 1.58b. '
        'The user is speaking Russian. You must understand the question and formulate your response in fluent Russian (на русском языке).]\n\n'
        'Human: Question in Russian: $userPrompt\n'
        '(English context: $enMeaning)\n\n'
        'BITNETAssistant: ';
  }

  /// Fast bidirectional Russian -> English translation for prompt grounding
  String translateRussianToEnglish(String text) {
    String out = text;
    for (final entry in _ruToEnPhrases.entries) {
      out = out.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }
    return out;
  }

  /// Fast offline English -> Russian translator for model responses
  String translateEnglishToRussian(String text) {
    if (!isPrimarilyEnglish(text)) {
      return text;
    }

    // Preserve code blocks
    final codeBlocks = <String>[];
    String textWithoutCode = text.replaceAllMapped(RegExp(r'```[\s\S]*?```|`[^`]+`'), (match) {
      final placeholder = '__CODE_BLOCK_${codeBlocks.length}__';
      codeBlocks.add(match.group(0)!);
      return placeholder;
    });

    // 1. Phrase-level translation
    for (final entry in _enToRuPhrases.entries) {
      textWithoutCode = textWithoutCode.replaceAllMapped(
        RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false),
        (m) {
          final matched = m.group(0)!;
          if (matched.isNotEmpty && matched[0] == matched[0].toUpperCase()) {
            return _capitalize(entry.value);
          }
          return entry.value;
        },
      );
    }

    // 2. Word-level translation with case preservation
    final words = textWithoutCode.split(RegExp(r'(\s+|[.,!?;:()\[\]"«»\n])'));
    final delimiters = RegExp(r'(\s+|[.,!?;:()\[\]"«»\n])').allMatches(textWithoutCode).map((m) => m.group(0)!).toList();

    final buffer = StringBuffer();
    int dIndex = 0;

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isNotEmpty) {
        final lower = w.toLowerCase();
        String translated = _enToRuWords[lower] ?? w;

        if (w == w.toUpperCase() && w.length > 1) {
          translated = translated.toUpperCase();
        } else if (w[0] == w[0].toUpperCase()) {
          translated = _capitalize(translated);
        }

        buffer.write(translated);
      }
      if (dIndex < delimiters.length) {
        buffer.write(delimiters[dIndex++]);
      }
    }

    String result = buffer.toString();

    // Restore code blocks
    for (int i = 0; i < codeBlocks.length; i++) {
      result = result.replaceAll('__CODE_BLOCK_${i}__', codeBlocks[i]);
    }

    return result;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // Common phrase pairs
  static final Map<String, String> _ruToEnPhrases = {
    r'привет': 'hello',
    r'здравствуй(те)?': 'hello',
    r'кто ты\??': 'who are you?',
    r'что ты умеешь\??': 'what can you do?',
    r'как ты работаешь\??': 'how do you work?',
    r'что такое bitnet\??': 'what is bitnet?',
    r'что такое квантование\??': 'what is quantization?',
    r'напиши код': 'write code',
    r'напиши пример': 'write an example',
    r'объясни': 'explain',
    r'расскажи о': 'tell about',
    r'помоги мне': 'help me',
    r'почему': 'why',
    r'зачем': 'why',
    r'как': 'how',
    r'когда': 'when',
    r'где': 'where',
    r'сколько': 'how much',
  };

  static final Map<String, String> _enToRuPhrases = {
    'i am a local ai assistant': 'я — локальный ИИ-ассистент',
    'i am an ai assistant': 'я — ИИ-ассистент',
    'i am an artificial intelligence': 'я — искусственный интеллект',
    'i am bitnet': 'я — BitNet',
    'based on the bitnet architecture': 'на базе архитектуры BitNet',
    'based on bitnet': 'на базе BitNet',
    'how can i help you today': 'чем я могу помочь вам сегодня',
    'how can i help you': 'чем я могу вам помочь',
    'how can i assist you': 'чем я могу вам помочь',
    'here is an example': 'вот пример',
    'here is the code': 'вот код',
    'here is a summary': 'вот краткое резюме',
    'for example': 'например',
    'in other words': 'другими словами',
    'first of all': 'прежде всего',
    'in summary': 'в заключение',
    'as a result': 'в результате',
    'it is important to note': 'важно отметить',
    'neural network': 'нейронная сеть',
    'neural networks': 'нейронные сети',
    'artificial intelligence': 'искусственный интеллект',
    'machine learning': 'машинное обучение',
    'deep learning': 'глубокое обучение',
    'ternary weights': 'троичные веса',
    'ternary quantization': 'троичное квантование',
    '1.58-bit quantization': '1.58-битное квантование',
    '1.58-bit ternary': '1.58-битные троичные веса',
    'without internet access': 'без доступа в интернет',
    'local inference': 'локальный инференс',
    'on-device ai': 'локальный ИИ на устройстве',
    'matrix multiplication': 'матричное умножение',
    'arm neon acceleration': 'ускорение ARM NEON',
    'vector instructions': 'векторные инструкции',
    'low memory footprint': 'низкое потребление памяти',
    'fast response': 'быстрый ответ',
    'high performance': 'высокая производительность',
    'feel free to ask': 'вы можете задать любой вопрос',
    'let me know if': 'дайте знать, если',
    'thank you for': 'спасибо за',
    'you are welcome': 'пожалуйста',
    'of course': 'конечно',
    'no problem': 'без проблем',
  };

  static final Map<String, String> _enToRuWords = {
    // Pronouns
    'i': 'я',
    'me': 'меня',
    'my': 'мой',
    'mine': 'моё',
    'you': 'вы',
    'your': 'ваш',
    'yours': 'ваше',
    'he': 'он',
    'him': 'его',
    'his': 'его',
    'she': 'она',
    'her': 'её',
    'it': 'это',
    'its': 'его',
    'we': 'мы',
    'us': 'нас',
    'our': 'наш',
    'ours': 'наше',
    'they': 'они',
    'them': 'их',
    'their': 'их',
    'theirs': 'их',

    // Auxiliaries & Verbs
    'is': '—',
    'are': '—',
    'am': '—',
    'was': 'был',
    'were': 'были',
    'be': 'быть',
    'been': 'был',
    'being': 'будучи',
    'can': 'может',
    'could': 'мог бы',
    'will': 'будет',
    'would': 'бы',
    'should': 'следует',
    'must': 'должен',
    'have': 'имеет',
    'has': 'имеет',
    'had': 'имел',
    'do': 'делает',
    'does': 'делает',
    'did': 'сделал',
    'use': 'использует',
    'uses': 'использует',
    'used': 'использовал',
    'using': 'используя',
    'make': 'создает',
    'work': 'работает',
    'works': 'работает',
    'working': 'работает',
    'help': 'помогает',
    'helps': 'помогает',
    'run': 'запускает',
    'runs': 'запускает',
    'running': 'работает',
    'execute': 'выполняет',
    'executing': 'выполняя',
    'need': 'требует',
    'needs': 'требует',
    'provide': 'предоставляет',
    'provides': 'предоставляет',
    'support': 'поддерживает',
    'supports': 'поддерживает',
    'generate': 'генерирует',
    'generates': 'генерирует',
    'generating': 'генерация',
    'compute': 'вычисляет',
    'process': 'обрабатывает',
    'know': 'знает',
    'think': 'думает',
    'see': 'видит',
    'look': 'смотрит',
    'learn': 'обучается',
    'show': 'показывает',
    'explain': 'объясняет',

    // Question words & Conjunctions
    'what': 'что',
    'which': 'какой',
    'who': 'кто',
    'whom': 'кого',
    'whose': 'чей',
    'where': 'где',
    'when': 'когда',
    'why': 'почему',
    'how': 'как',
    'and': 'и',
    'or': 'или',
    'but': 'но',
    'because': 'потому что',
    'if': 'если',
    'then': 'тогда',
    'else': 'иначе',
    'so': 'так',
    'as': 'как',
    'than': 'чем',
    'that': 'что',
    'this': 'этот',
    'these': 'эти',
    'those': 'те',

    // Prepositions
    'in': 'в',
    'on': 'на',
    'at': 'в',
    'to': 'к',
    'from': 'из',
    'by': 'с помощью',
    'with': 'с',
    'without': 'без',
    'for': 'для',
    'about': 'о',
    'into': 'в',
    'through': 'через',
    'during': 'во время',
    'between': 'между',
    'under': 'под',
    'over': 'над',

    // Adjectives & Adverbs
    'good': 'хороший',
    'great': 'отличный',
    'fast': 'быстрый',
    'faster': 'быстрее',
    'slow': 'медленный',
    'high': 'высокий',
    'low': 'низкий',
    'small': 'маленький',
    'large': 'большой',
    'simple': 'простой',
    'complex': 'сложный',
    'new': 'новый',
    'old': 'старый',
    'first': 'первый',
    'second': 'второй',
    'third': 'третий',
    'local': 'локальный',
    'efficient': 'эффективный',
    'accurate': 'точный',
    'powerful': 'мощный',
    'best': 'лучший',
    'more': 'больше',
    'less': 'меньше',
    'most': 'наиболее',
    'very': 'очень',
    'also': 'также',
    'only': 'только',
    'always': 'всегда',
    'never': 'никогда',
    'now': 'сейчас',
    'here': 'здесь',
    'there': 'там',
    'all': 'все',
    'any': 'любой',
    'some': 'некоторые',
    'many': 'многие',
    'much': 'много',
    'few': 'мало',
    'each': 'каждый',
    'every': 'каждый',

    // Tech & BitNet domain terms
    'model': 'модель',
    'models': 'модели',
    'weight': 'вес',
    'weights': 'веса',
    'quantization': 'квантование',
    'quantized': 'квантованный',
    'layer': 'слой',
    'layers': 'слои',
    'memory': 'память',
    'ram': 'ОЗУ',
    'cpu': 'процессор',
    'gpu': 'видеочип',
    'npu': 'нейропроцессор',
    'token': 'токен',
    'tokens': 'токенов',
    'speed': 'скорость',
    'thread': 'поток',
    'threads': 'потоков',
    'context': 'контекст',
    'cache': 'кэш',
    'parameter': 'параметр',
    'parameters': 'параметров',
    'architecture': 'архитектура',
    'device': 'устройство',
    'system': 'система',
    'file': 'файл',
    'data': 'данные',
    'code': 'код',
    'result': 'результат',
    'answer': 'ответ',
    'question': 'вопрос',
    'example': 'пример',
    'yes': 'да',
    'no': 'нет',
    'true': 'истина',
    'false': 'ложь',
  };
}
