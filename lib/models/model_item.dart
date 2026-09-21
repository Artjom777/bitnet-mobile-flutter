class ModelItem {
  final String id;
  final String name;
  final String architecture;
  final String filename;
  final String format;
  final String size;
  final int contextSize;
  final String quantization;
  final String ramRequirement;
  final String speed;
  final bool isLoaded;
  final String status;
  final bool isCompatible;
  final String archSupport;
  final String dateModified;
  final String description;

  const ModelItem({
    required this.id,
    required this.name,
    required this.architecture,
    required this.filename,
    required this.format,
    required this.size,
    required this.contextSize,
    required this.quantization,
    required this.ramRequirement,
    required this.speed,
    this.isLoaded = false,
    required this.status,
    this.isCompatible = true,
    required this.archSupport,
    required this.dateModified,
    required this.description,
  });

  ModelItem copyWith({
    String? id,
    String? name,
    String? architecture,
    String? filename,
    String? format,
    String? size,
    int? contextSize,
    String? quantization,
    String? ramRequirement,
    String? speed,
    bool? isLoaded,
    String? status,
    bool? isCompatible,
    String? archSupport,
    String? dateModified,
    String? description,
  }) {
    return ModelItem(
      id: id ?? this.id,
      name: name ?? this.name,
      architecture: architecture ?? this.architecture,
      filename: filename ?? this.filename,
      format: format ?? this.format,
      size: size ?? this.size,
      contextSize: contextSize ?? this.contextSize,
      quantization: quantization ?? this.quantization,
      ramRequirement: ramRequirement ?? this.ramRequirement,
      speed: speed ?? this.speed,
      isLoaded: isLoaded ?? this.isLoaded,
      status: status ?? this.status,
      isCompatible: isCompatible ?? this.isCompatible,
      archSupport: archSupport ?? this.archSupport,
      dateModified: dateModified ?? this.dateModified,
      description: description ?? this.description,
    );
  }

  static const empty = ModelItem(
    id: 'none',
    name: 'Модель не выбрана',
    architecture: 'BitNet C++',
    filename: '',
    format: '',
    size: '0 МБ',
    contextSize: 0,
    quantization: '',
    ramRequirement: '0 ГБ',
    speed: '0 t/s',
    isLoaded: false,
    status: 'Не загружена',
    isCompatible: false,
    archSupport: 'ARM64-v8a',
    dateModified: '',
    description: 'На накопителе нет загруженных моделей. Скачайте модель для запуска.',
  );
}
