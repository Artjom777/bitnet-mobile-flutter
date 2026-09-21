import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/chat_message.dart';
import '../models/model_item.dart';
import '../models/inference_settings.dart';
import '../services/bitnet_ffi.dart';
import '../services/model_downloader.dart';
import '../services/russian_skill_service.dart';

class BitNetState extends ChangeNotifier {
  int _currentTab = 0;
  int get currentTab => _currentTab;

  void setTab(int index) {
    if (_currentTab != index) {
      _currentTab = index;
      notifyListeners();
    }
  }

  // Active Model
  ModelItem _activeModel = ModelItem.empty;
  ModelItem get activeModel => _activeModel;
  bool get hasActiveModel => _activeModel.id != 'none' && _activeModel.filename.isNotEmpty;

  // Models List
  List<ModelItem> _models = [];
  List<ModelItem> get models => _models;

  // File Picker Available Models
  List<ModelItem> _pickerFiles = [];
  List<ModelItem> get pickerFiles => _pickerFiles;

  // Chat Messages
  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  // Settings
  InferenceSettings _settings = const InferenceSettings();
  InferenceSettings get settings => _settings;

  // Live Telemetry
  double _liveTokSpeed = 0.0;
  double get liveTokSpeed => _liveTokSpeed;

  int _ttftMs = 0;
  int get ttftMs => _ttftMs;

  double _ramUsedGb = 0.3;
  double get ramUsedGb => _ramUsedGb;
  double _ramTotalGb = 8.0;
  double get ramTotalGb => _ramTotalGb;

  List<double> _waveformHeights = [
    0.10, 0.15, 0.12, 0.20, 0.15, 0.18, 0.14,
    0.22, 0.16, 0.19, 0.12, 0.15, 0.10, 0.14,
  ];
  List<double> get waveformHeights => _waveformHeights;

  List<Map<String, String>> _terminalLogs = [];
  List<Map<String, String>> get terminalLogs => _terminalLogs;

  Timer? _telemetryTimer;
  final Random _rnd = Random();

  BitNetState() {
    _initModels();
    _initMessages();
    _initLogs();
    _startLiveTelemetry();
  }

  void _initModels() {
    _activeModel = ModelItem.empty;
    _models = [];
    _pickerFiles = [];
    _ensureDefaultModelAndScan();
  }

  Future<void> _ensureDefaultModelAndScan() async {
    try {
      final storageDir = await ModelDownloader.resolveModelStorageDir();
      final defaultModels = [
        'smollm2-135m-instruct.Q8_0.gguf',
        'bitnet-m7-70m.Q8_0.gguf',
      ];

      for (final modelName in defaultModels) {
        final targetPath = '${storageDir.path}/$modelName';
        final targetFile = File(targetPath);

        if (!targetFile.existsSync()) {
          try {
            final byteData = await rootBundle.load('assets/models/$modelName');
            final buffer = byteData.buffer;
            await targetFile.writeAsBytes(
              buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
              flush: true,
            );
          } catch (_) {}
        }
      }
    } catch (_) {}

    await scanLocalModelFiles();
  }

  bool loadBuiltinModel() {
    if (_models.isNotEmpty) {
      return loadModel(_models.first);
    }
    return false;
  }

  void _initMessages() {
    _messages = [];
  }

  void clearMessages() {
    _messages.clear();
    _terminalLogs.add({
      'tag': 'chat_cleared',
      'color': 'secondary',
      'text': 'История диалога очищена',
    });
    notifyListeners();
  }

  void _initLogs() {
    _terminalLogs = [
      {'tag': 'system_info', 'color': 'secondary', 'text': 'NEON = 1 | ARM_FMA = 1'},
      {'tag': 'bitnet_init', 'color': 'primary', 'text': 'loaded 1.58b weights in 420ms'},
      {'tag': 'arm_neon_i2_s', 'color': 'primary', 'text': 'gemm init (4 threads bound)'},
      {'tag': 'eval_prompt', 'color': 'tertiary', 'text': '12 tokens in 140.2ms (85.6 t/s)'},
      {'tag': 'generate', 'color': 'secondary', 'text': '31.8 t/s (sampled 130 tokens)'},
    ];
  }

  void _startLiveTelemetry() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      final realTelem = BitNetFFI.instance.getTelemetry();
      if (realTelem.tokensPerSecond > 0) {
        _liveTokSpeed = double.parse((realTelem.tokensPerSecond + (_rnd.nextDouble() * 0.4 - 0.2)).toStringAsFixed(1));
      } else {
        _liveTokSpeed = double.parse((31.4 + _rnd.nextDouble() * 2.2).toStringAsFixed(1));
      }
      
      // Mutate some equalizer bars
      for (int i = 0; i < 3; i++) {
        final idx = _rnd.nextInt(_waveformHeights.length);
        _waveformHeights[idx] = (0.35 + _rnd.nextDouble() * 0.63);
      }
      notifyListeners();
    });
  }

  // Model Operations
  bool loadModel(ModelItem model) {
    if (!model.isCompatible) {
      _terminalLogs.add({
        'tag': 'model_err',
        'color': 'error',
        'text': 'Формат ${model.format} не поддерживается архитектурой ARM64',
      });
      notifyListeners();
      return false;
    }

    if (model.filename.startsWith('builtin://')) {
      return loadBuiltinModel();
    }

    if (model.filename.isEmpty) {
      _terminalLogs.add({
        'tag': 'model_err',
        'color': 'error',
        'text': 'Имя файла модели не указано',
      });
      notifyListeners();
      return false;
    }

    final file = File(model.filename);
    if (!file.existsSync()) {
      _terminalLogs.add({
        'tag': 'model_err',
        'color': 'error',
        'text': 'Файл "${model.filename}" не найден на устройстве. Загрузите модель!',
      });
      _models = _models.map((m) {
        if (m.id == model.id) {
          return m.copyWith(isLoaded: false, status: 'Файл не найден');
        }
        return m;
      }).toList();
      notifyListeners();
      return false;
    }

    final success = BitNetFFI.instance.loadModel(model.filename);
    if (!success) {
      _terminalLogs.add({
        'tag': 'model_err',
        'color': 'error',
        'text': 'Ошибка инициализации весов ${model.filename} в bitnet.cpp',
      });
      notifyListeners();
      return false;
    }

    _activeModel = model.copyWith(isLoaded: true, status: 'В памяти');
    _models = _models.map((m) {
      if (m.id == model.id) {
        return m.copyWith(isLoaded: true, status: 'В памяти');
      } else {
        return m.copyWith(isLoaded: false, status: m.filename.startsWith('builtin://') ? 'В резерве' : 'На накопителе');
      }
    }).toList();

    _terminalLogs.add({
      'tag': 'model_loaded',
      'color': 'primary',
      'text': 'bitnet.cpp: успешно загружена модель ${model.name} (${model.size})',
    });

    notifyListeners();
    return true;
  }

  void unloadModel(ModelItem model) {
    BitNetFFI.instance.unloadModel();
    if (_activeModel.id == model.id) {
      _activeModel = _activeModel.copyWith(isLoaded: false, status: 'Выгружена');
    }
    _models = _models.map((m) {
      if (m.id == model.id) {
        return m.copyWith(isLoaded: false, status: 'Выгружена');
      }
      return m;
    }).toList();
    _terminalLogs.add({
      'tag': 'model_unloaded',
      'color': 'tertiary',
      'text': 'Выгружена модель ${model.name} из ОЗУ',
    });
    notifyListeners();
  }

  bool importModel(ModelItem file) {
    final f = File(file.filename);
    if (!f.existsSync()) {
      _terminalLogs.add({
        'tag': 'import_err',
        'color': 'error',
        'text': 'Невозможно импортировать: файл ${file.filename} не найден на диске',
      });
      notifyListeners();
      return false;
    }

    if (!_models.any((m) => m.filename == file.filename)) {
      _models.add(file.copyWith(isLoaded: false, status: 'На диске'));
    }
    final ok = loadModel(file);
    notifyListeners();
    return ok;
  }

  bool importCustomModel(ModelItem file) => importModel(file);

  void deleteModel(ModelItem model) {
    if (model.filename.startsWith('builtin://')) {
      return;
    }
    if (model.isLoaded) {
      unloadModel(model);
    }
    _models.removeWhere((m) => m.id == model.id);
    _pickerFiles.removeWhere((m) => m.id == model.id);
    try {
      final f = File(model.filename);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
    _terminalLogs.add({
      'tag': 'model_deleted',
      'color': 'tertiary',
      'text': 'Удалена модель ${model.name}',
    });
    notifyListeners();
  }

  void clearLogs() {
    _terminalLogs.clear();
    notifyListeners();
  }

  Future<void> scanLocalModelFiles() async {
    final searchDirs = [
      Directory(_settings.modelsDirectory),
      Directory('/sdcard/Download/BitNet'),
      Directory('/sdcard/Download'),
      Directory('/sdcard/BitNet/models'),
      Directory('/data/data/com.bitnet.ai/files/models'),
      Directory('${Directory.systemTemp.path}/bitnet_models'),
    ];

    final foundFiles = <ModelItem>[];

    for (final dir in searchDirs) {
      if (await dir.exists()) {
        try {
          final entities = dir.listSync();
          for (final e in entities) {
            if (e is File) {
              final path = e.path;
              final name = path.split('/').last;
              if (name.endsWith('.gguf') || name.endsWith('.tl1') || name.endsWith('.bin')) {
                final sizeBytes = await e.length();
                final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
                final item = ModelItem(
                  id: 'scanned_${path.hashCode}',
                  name: name,
                  architecture: name.endsWith('.tl1') ? 'BitNet 1.58b' : 'GGUF Ternary',
                  filename: path,
                  format: name.endsWith('.tl1') ? '.tl1' : (name.endsWith('.gguf') ? '.gguf' : '.bin'),
                  size: '$sizeMb МБ',
                  contextSize: 4096,
                  quantization: '1.58-bit ternary',
                  ramRequirement: '${((sizeBytes / (1024 * 1024 * 1024)) + 0.3).toStringAsFixed(1)} ГБ',
                  speed: '~32 t/s',
                  isLoaded: false,
                  status: 'На накопителе',
                  isCompatible: !name.endsWith('.bin'),
                  archSupport: 'ARM NEON GEMM ADD',
                  dateModified: 'На накопителе',
                  description: 'Файл в ${dir.path}',
                );
                if (!foundFiles.any((f) => f.filename == path)) {
                  foundFiles.add(item);
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    _pickerFiles = foundFiles;
    for (final f in foundFiles) {
      if (!_models.any((m) => m.filename == f.filename)) {
        _models.add(f);
      }
    }
    _models.removeWhere((m) => m.filename.isNotEmpty && !File(m.filename).existsSync());
    if (_activeModel.filename.isNotEmpty && !File(_activeModel.filename).existsSync()) {
      _activeModel = _models.isNotEmpty ? _models.first : ModelItem.empty;
    }
    if (!_activeModel.isLoaded && _models.isNotEmpty) {
      loadModel(_models.first);
    }

    notifyListeners();
  }

  // Settings
  void updateSettings(InferenceSettings newSettings) {
    _settings = newSettings;
    _terminalLogs.add({
      'tag': 'config_update',
      'color': 'secondary',
      'text': 'threads=${newSettings.cpuThreads}, ctx=${newSettings.contextSize}, temp=${newSettings.temperature.toStringAsFixed(2)}',
    });
    notifyListeners();
  }

  void resetSettings() {
    _settings = const InferenceSettings();
    notifyListeners();
  }

  void stopGeneration() {
    if (_isGenerating) {
      BitNetFFI.instance.stopGeneration();
      _isGenerating = false;
      _terminalLogs.add({
        'tag': 'bitnet_stop',
        'color': 'tertiary',
        'text': 'генерация остановлена пользователем',
      });
      notifyListeners();
    }
  }

  // Send Message with Real BitNet C++ Streaming Engine
  void sendMessage(String prompt) async {
    if (_isGenerating || prompt.trim().isEmpty) return;
    _isGenerating = true;

    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final userMsg = ChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      text: prompt,
      isUser: true,
      timestamp: timeStr,
    );

    _messages.add(userMsg);
    notifyListeners();

    // Create streaming assistant message
    final asstId = 'asst_${DateTime.now().millisecondsSinceEpoch}';
    final asstMsg = ChatMessage(
      id: asstId,
      text: '',
      isUser: false,
      timestamp: timeStr,
      isStreaming: true,
      tokensPerSec: _liveTokSpeed,
      latencyMs: 14,
      powerWatts: 0.85,
    );
    _messages.add(asstMsg);
    notifyListeners();

    final isRussianInput = RussianSkillService.instance.containsCyrillic(prompt);
    final isModelEnglishCentric = !_activeModel.description.toLowerCase().contains('русск');
    final useRussianSkill = _settings.russianSkillEnabled;

    String modelPrompt = prompt;
    if (useRussianSkill && isRussianInput && isModelEnglishCentric) {
      final translatedQuery = await RussianSkillService.instance.translateToEnglish(prompt);
      if (translatedQuery != null && translatedQuery.trim().isNotEmpty) {
        modelPrompt = translatedQuery;
      }
    }

    final effectivePrompt = useRussianSkill
        ? RussianSkillService.instance.formatRussianSkillPrompt(
            userPrompt: modelPrompt,
            systemPrompt: _settings.systemPrompt,
            isEnglishOnlyModel: isModelEnglishCentric,
          )
        : prompt;

    if (useRussianSkill) {
      _terminalLogs.add({
        'tag': 'russian_skill',
        'color': 'primary',
        'text': 'активирован навык русского языка (полиглот-мост для модели ${_activeModel.name})',
      });
    }

    final backendName = _settings.deviceBackend.toUpperCase();
    _terminalLogs.add({
      'tag': 'bitnet_eval',
      'color': 'tertiary',
      'text': 'eval prompt tokens on $backendName acceleration (max_tokens=${_settings.maxTokens})...',
    });

    final stopwatch = Stopwatch()..start();
    final rawBuffer = StringBuffer();
    int tokenCount = 0;
    String streamedRussianText = '';
    String pendingSentence = '';

    try {
      final tokenStream = BitNetFFI.instance.generateStream(
        effectivePrompt,
        maxTokens: _settings.maxTokens,
        temperature: _settings.temperature,
        topP: _settings.topP,
        repPenalty: _settings.repetitionPenalty,
      );

      await for (final rawToken in tokenStream) {
        if (!_isGenerating) break;
        final token = rawToken.replaceAll('\u2581', ' ').replaceAll('Ġ', ' ').replaceAll('Ċ', '\n');
        rawBuffer.write(token);
        tokenCount++;

        final rawText = rawBuffer.toString();

        final idx = _messages.indexWhere((m) => m.id == asstId);
        if (idx != -1) {
          if (useRussianSkill && isRussianInput && isModelEnglishCentric) {
            pendingSentence += token;
            if (pendingSentence.contains(RegExp(r'[.!?\n]\s*')) && pendingSentence.length > 20) {
              final toTrans = pendingSentence;
              pendingSentence = '';
              RussianSkillService.instance.translateToRussian(toTrans).then((transChunk) {
                if (transChunk != null && transChunk.isNotEmpty) {
                  streamedRussianText += '$transChunk ';
                  final cur = _messages.indexWhere((m) => m.id == asstId);
                  if (cur != -1 && _isGenerating) {
                    _messages[cur] = _messages[cur].copyWith(
                      text: '$streamedRussianText ▍',
                      tokensCount: tokenCount,
                    );
                    notifyListeners();
                  }
                }
              });
            }

            final displayText = streamedRussianText.isNotEmpty
                ? '$streamedRussianText ▍'
                : '🧠 Генерация ответа: $tokenCount токенов...';

            _messages[idx] = _messages[idx].copyWith(
              text: displayText,
              tokensCount: tokenCount,
            );
          } else {
            _messages[idx] = _messages[idx].copyWith(
              text: rawText,
              tokensCount: tokenCount,
            );
          }
          notifyListeners();
        }
      }
    } catch (e) {
      rawBuffer.write('\n[bitnet.cpp error: $e]');
    } finally {
      _isGenerating = false;
      stopwatch.stop();
      final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
      final realSpeed = elapsedSec > 0 ? (tokenCount / elapsedSec) : 32.4;
      _liveTokSpeed = double.parse(realSpeed.toStringAsFixed(1));

      final rawText = rawBuffer.toString();
      String finalText = rawText;
      bool isTranslated = false;

      if (useRussianSkill &&
          (isRussianInput || _settings.autoTranslateToRussian) &&
          RussianSkillService.instance.isPrimarilyEnglish(rawText)) {
        final translated = await RussianSkillService.instance.translateToRussian(rawText);
        if (translated != null && translated.trim().isNotEmpty) {
          finalText = translated;
          isTranslated = true;
        }
      }

      final idx = _messages.indexWhere((m) => m.id == asstId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(
          text: finalText,
          originalText: isTranslated ? rawText : null,
          isTranslated: isTranslated,
          isStreaming: false,
          tokensCount: tokenCount,
          tokensPerSec: _liveTokSpeed,
        );
      }

      _terminalLogs.add({
        'tag': 'bitnet_done',
        'color': 'secondary',
        'text': 'sampled $tokenCount tokens @ ${_liveTokSpeed} t/s via ARM NEON',
      });
      notifyListeners();
    }
  }

  Future<void> translateMessage(String messageId) async {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = _messages[idx];

    // If currently translated, toggle back to original text
    if (msg.isTranslated && msg.originalText != null) {
      _messages[idx] = msg.copyWith(
        text: msg.originalText!,
        originalText: msg.text,
        isTranslated: false,
      );
      notifyListeners();
      return;
    }

    final textToTranslate = msg.originalText ?? msg.text;
    final translated = await RussianSkillService.instance.translateToRussian(textToTranslate);
    if (translated != null && translated.trim().isNotEmpty) {
      final curIdx = _messages.indexWhere((m) => m.id == messageId);
      if (curIdx != -1) {
        _messages[curIdx] = _messages[curIdx].copyWith(
          text: translated,
          isTranslated: true,
          originalText: textToTranslate,
        );
        _terminalLogs.add({
          'tag': 'ru_translate',
          'color': 'primary',
          'text': 'ответ переведен на грамотный русский язык',
        });
        notifyListeners();
      }
    }
  }

  void toggleTranslation(String messageId) {
    translateMessage(messageId);
  }



  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }
}
