import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/model_item.dart';
import '../state/bitnet_state.dart';
import '../services/model_downloader.dart';
import 'file_picker_screen.dart';

class ModelsScreen extends StatefulWidget {
  final BitNetState state;

  const ModelsScreen({super.key, required this.state});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  void _openFilePicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FilePickerScreen(state: widget.state),
      ),
    );
  }

  void _showUrlDownloadDialog() {
    String selectedUrl = ModelDownloader.officialModels.values.first;
    final controller = TextEditingController(text: selectedUrl);
    bool isDownloading = false;
    double progress = 0.0;
    String statusText = 'Готов к загрузке с Hugging Face';
    String speedText = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: Row(
            children: const [
              Icon(Icons.cloud_download, color: AppColors.tertiary),
              SizedBox(width: 8),
              Text(
                'Загрузка весов BitNet',
                style: TextStyle(
                  fontFamily: AppTypography.sansFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выберите проверенную модель 1.58-бит или введите URL:',
                style: TextStyle(
                  fontFamily: AppTypography.sansFont,
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...ModelDownloader.officialModels.entries.map((e) {
                final isSelected = controller.text == e.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ChoiceChip(
                    label: Text(
                      e.key,
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 11,
                        color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primaryContainer,
                    backgroundColor: AppColors.surfaceContainerLowest,
                    onSelected: isDownloading ? null : (sel) {
                      if (sel) {
                        setDialogState(() {
                          controller.text = e.value;
                        });
                      }
                    },
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                enabled: !isDownloading,
                style: const TextStyle(
                  fontFamily: AppTypography.monoFont,
                  fontSize: 11,
                  color: AppColors.onSurface,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              if (isDownloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 11,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      speedText,
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            if (!isDownloading)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Отмена', style: TextStyle(color: AppColors.onSurfaceVariant)),
              ),
            ElevatedButton(
              onPressed: isDownloading
                  ? null
                  : () async {
                      final url = controller.text.trim();
                      if (url.isEmpty) return;

                      setDialogState(() {
                        isDownloading = true;
                        statusText = 'Подключение...';
                      });

                      final filename = url.split('/').last;
                      final dir = Directory('/data/data/com.bitnet.ai/files/models');
                      await dir.create(recursive: true);
                      final destPath = '${dir.path}/$filename';

                      final stream = ModelDownloader.instance.downloadModel(
                        url: url,
                        destinationPath: destPath,
                      );

                      await for (final p in stream) {
                        if (p.error != null) {
                          setDialogState(() {
                            isDownloading = false;
                            statusText = 'Ошибка: ${p.error}';
                          });
                          break;
                        }

                        setDialogState(() {
                          progress = p.progressPercent;
                          statusText = '${(p.progressPercent * 100).toStringAsFixed(1)}% (${(p.receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB)';
                          speedText = '${p.speedMbPerSec.toStringAsFixed(1)} MB/s';
                        });

                        if (p.isCompleted) {
                          Navigator.of(ctx).pop();

                          final newModel = ModelItem(
                            id: 'downloaded_${DateTime.now().millisecondsSinceEpoch}',
                            name: filename,
                            architecture: 'BitNet b1.58 Ternary',
                            filename: destPath,
                            format: filename.endsWith('.tl1') ? '.tl1' : '.gguf',
                            size: '${(p.totalBytes / 1024 / 1024).toStringAsFixed(1)} МБ',
                            contextSize: 4096,
                            quantization: '1.58-bit Ternary',
                            ramRequirement: '1.2 ГБ',
                            speed: '~32 t/s',
                            isLoaded: true,
                            status: 'В памяти',
                            isCompatible: true,
                            archSupport: 'ARM NEON GEMM ADD',
                            dateModified: 'Только что',
                            description: 'Загружено из Hugging Face',
                          );

                          widget.state.importModel(newModel);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Модель $filename успешно загружена и активна в bitnet.cpp!'),
                                backgroundColor: AppColors.primaryContainer,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                          break;
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text(isDownloading ? 'Загрузка...' : 'Загрузить и запустить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            // Top Intro Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Локальные модели',
                  style: TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'NPU активен',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                text: 'Поддержка форматов ',
                style: const TextStyle(
                  fontFamily: AppTypography.sansFont,
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
                children: const [
                  TextSpan(
                    text: '.tl1',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  TextSpan(text: ', '),
                  TextSpan(
                    text: '.gguf',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  TextSpan(text: ' (1.58-bit ternary quant) для bitnet.cpp'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Hardware Kernel Optimization Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt,
                          size: 20,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'AVX2 / ARM NEON I8MM',
                            style: TextStyle(
                              fontFamily: AppTypography.sansFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            'Троичные матричные вычисления ускорены',
                            style: TextStyle(
                              fontFamily: AppTypography.sansFont,
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ВКЛ',
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSecondaryFixed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Prominent Import Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.add_circle_outline,
                              size: 26,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Добавить BitNet модель',
                                style: TextStyle(
                                  fontFamily: AppTypography.sansFont,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                'Локальный квант или онлайн-репозиторий',
                                style: TextStyle(
                                  fontFamily: AppTypography.sansFont,
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Storage path hint
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.folder_open, size: 16, color: AppColors.outline),
                        SizedBox(width: 6),
                        Text(
                          '/Download/bitnet_models/',
                          style: TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 11,
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  ElevatedButton.icon(
                    onPressed: _openFilePicker,
                    icon: const Icon(Icons.file_open, size: 18),
                    label: const Text(
                      'Выбрать файл из памяти устройства',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showUrlDownloadDialog,
                    icon: const Icon(Icons.cloud_download, size: 18, color: AppColors.tertiary),
                    label: const Text(
                      'Hugging Face / Загрузить по URL',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHighest,
                      foregroundColor: AppColors.onSurface,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Models List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Установленные веса (${widget.state.models.length})',
                  style: const TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Text(
                  'Хранилище: 4.8 ГБ',
                  style: TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 11,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Model Cards
            ...widget.state.models.map((model) => _buildModelCard(model)),
          ],
        ),

        // Extended FAB Bottom Right
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _openFilePicker,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 8,
            icon: const Icon(Icons.add),
            label: const Text(
              'Импорт модели',
              style: TextStyle(
                fontFamily: AppTypography.sansFont,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelCard(ModelItem model) {
    final isLoaded = model.isLoaded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: isLoaded
            ? Border.all(color: AppColors.primary.withOpacity(0.35), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: const TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Архитектура: ${model.architecture}',
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isLoaded
                      ? AppColors.secondaryContainer
                      : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoaded) ...[
                      const Icon(Icons.check_circle, size: 12, color: AppColors.onSecondaryContainer),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      model.status,
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isLoaded
                            ? AppColors.onSecondaryContainer
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Pill tags
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  model.quantization,
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.tertiary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Размер: ${model.size}',
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Контекст: ${model.contextSize}',
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active Metrics (if loaded) or RAM requirement info (if dormant)
          if (isLoaded) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'RAM VRAM',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '1.4 / 4.1 ГБ',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.34,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Скорость',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '~32 t/s',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.78,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Actions Row for Active Model
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => widget.state.setTab(3), // Jump to Settings
                      icon: const Icon(Icons.tune, size: 18, color: AppColors.onSurfaceVariant),
                      tooltip: 'Настройки инференса',
                    ),
                    IconButton(
                      onPressed: () => widget.state.setTab(2), // Jump to Monitoring
                      icon: const Icon(Icons.analytics, size: 18, color: AppColors.onSurfaceVariant),
                      tooltip: 'Статистика весов',
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => widget.state.unloadModel(model),
                  icon: const Icon(Icons.eject, size: 16),
                  label: const Text('Выгрузить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorContainer,
                    foregroundColor: AppColors.onErrorContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.memory, size: 15, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text(
                      model.id == 'phi3_mini_bitnet'
                          ? 'Сверхбыстрый запуск'
                          : 'Требуется ~${model.ramRequirement} ОЗУ',
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        color: model.id == 'phi3_mini_bitnet'
                            ? AppColors.secondary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => widget.state.loadModel(model),
                  icon: Icon(
                    model.id == 'phi3_mini_bitnet' ? Icons.download_for_offline : Icons.play_arrow,
                    size: 16,
                  ),
                  label: Text(
                    model.id == 'phi3_mini_bitnet' ? 'Загрузить' : 'Загрузить в движок',
                    style: const TextStyle(
                      fontFamily: AppTypography.sansFont,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: model.id == 'phi3_mini_bitnet'
                        ? AppColors.surfaceContainerHighest
                        : AppColors.primaryContainer,
                    foregroundColor: model.id == 'phi3_mini_bitnet'
                        ? AppColors.onSurface
                        : AppColors.onPrimaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
