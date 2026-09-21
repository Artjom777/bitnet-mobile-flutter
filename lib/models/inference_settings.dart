class InferenceSettings {
  final int cpuThreads;
  final bool instructionSetEnabled;
  final int contextSize;
  final double temperature;
  final double topP;
  final double repetitionPenalty;
  final String systemPrompt;
  final bool offlineMode;
  final bool wakelock;
  final String modelsDirectory;
  final int maxTokens;
  final String deviceBackend; // 'cpu', 'gpu', 'npu'
  final bool cpuFreqLock;
  final bool lowPowerMode;
  final bool backgroundExecution;
  final bool russianSkillEnabled;
  final bool autoTranslateToRussian;

  const InferenceSettings({
    this.cpuThreads = 4,
    this.instructionSetEnabled = true,
    this.contextSize = 4096,
    this.maxTokens = 1024,
    this.deviceBackend = 'cpu',
    this.temperature = 0.70,
    this.topP = 0.90,
    this.repetitionPenalty = 1.10,
    this.systemPrompt =
        'Ты персональный локальный ассистент на базе модели BitNet b1.58. Отвечай лаконично, точно и структурированно без выхода в интернет.',
    this.offlineMode = true,
    this.wakelock = true,
    this.modelsDirectory = '/storage/emulated/0/BitNetAI/models',
    this.cpuFreqLock = true,
    this.lowPowerMode = false,
    this.backgroundExecution = true,
    this.russianSkillEnabled = true,
    this.autoTranslateToRussian = true,
  });

  InferenceSettings copyWith({
    int? cpuThreads,
    bool? instructionSetEnabled,
    int? contextSize,
    int? maxTokens,
    String? deviceBackend,
    double? temperature,
    double? topP,
    double? repetitionPenalty,
    String? systemPrompt,
    bool? offlineMode,
    bool? wakelock,
    String? modelsDirectory,
    bool? cpuFreqLock,
    bool? lowPowerMode,
    bool? backgroundExecution,
    bool? russianSkillEnabled,
    bool? autoTranslateToRussian,
  }) {
    return InferenceSettings(
      cpuThreads: cpuThreads ?? this.cpuThreads,
      instructionSetEnabled: instructionSetEnabled ?? this.instructionSetEnabled,
      contextSize: contextSize ?? this.contextSize,
      maxTokens: maxTokens ?? this.maxTokens,
      deviceBackend: deviceBackend ?? this.deviceBackend,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      offlineMode: offlineMode ?? this.offlineMode,
      wakelock: wakelock ?? this.wakelock,
      modelsDirectory: modelsDirectory ?? this.modelsDirectory,
      cpuFreqLock: cpuFreqLock ?? this.cpuFreqLock,
      lowPowerMode: lowPowerMode ?? this.lowPowerMode,
      backgroundExecution: backgroundExecution ?? this.backgroundExecution,
      russianSkillEnabled: russianSkillEnabled ?? this.russianSkillEnabled,
      autoTranslateToRussian: autoTranslateToRussian ?? this.autoTranslateToRussian,
    );
  }
}
