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
  final bool cpuFreqLock;
  final bool lowPowerMode;
  final bool backgroundExecution;

  const InferenceSettings({
    this.cpuThreads = 4,
    this.instructionSetEnabled = true,
    this.contextSize = 4096,
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
  });

  InferenceSettings copyWith({
    int? cpuThreads,
    bool? instructionSetEnabled,
    int? contextSize,
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
  }) {
    return InferenceSettings(
      cpuThreads: cpuThreads ?? this.cpuThreads,
      instructionSetEnabled: instructionSetEnabled ?? this.instructionSetEnabled,
      contextSize: contextSize ?? this.contextSize,
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
    );
  }
}
