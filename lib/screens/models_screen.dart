import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/model_item.dart';
import '../state/bitnet_state.dart';
import '../services/model_downloader.dart';
import '../widgets/apple_pressable.dart';
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

  void _confirmDeleteModel(ModelItem model) {
    if (model.filename.startsWith('builtin://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Встроенное ядро BitNet невозможно удалить из системы'),
          backgroundColor: AppColors.appleGlassCard,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.appleGlassCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.appleGlassBorder, width: 0.6),
        ),
        title: const Text(
          'Удаление модели',
          style: TextStyle(
            color: AppColors.appleLabel,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить модель ${model.name}?',
          style: const TextStyle(
            color: AppColors.appleSecondaryLabel,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          ApplePressable(
            onTap: () => Navigator.pop(ctx),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'Отмена',
                style: TextStyle(
                  color: AppColors.appleBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          ApplePressable(
            onTap: () {
              Navigator.pop(ctx);
              widget.state.deleteModel(model);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Модель ${model.name} удалена'),
                  backgroundColor: AppColors.appleGlassCard,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.appleRed.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Удалить',
                style: TextStyle(
                  color: AppColors.appleRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLoadModel(ModelItem model) {
    if (!model.isCompatible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Формат ${model.format} не поддерживается архитектурой ARM64'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!model.filename.startsWith('builtin://')) {
      final file = File(model.filename);
      if (!file.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл «${model.filename}» не существует на диске! Сначала скачайте модель.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    final ok = widget.state.loadModel(model);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Модель ${model.name} успешно загружена в ОЗУ'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось загрузить ${model.name} в bitnet.cpp'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          content: SingleChildScrollView(
            child: Column(
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
        ),
        actions: [
            if (isDownloading)
              TextButton(
                onPressed: () {
                  ModelDownloader.instance.cancelCurrentDownload();
                  setDialogState(() {
                    isDownloading = false;
                    statusText = 'Загрузка отменена';
                  });
                },
                child: const Text('Отменить загрузку', style: TextStyle(color: AppColors.error)),
              ),
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
                      final dir = await ModelDownloader.resolveModelStorageDir();
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

                          String modelDisplayName = filename;
                          for (final entry in ModelDownloader.officialModels.entries) {
                            if (entry.value == url) {
                              modelDisplayName = entry.key.split(' (').first;
                              break;
                            }
                          }

                          final newModel = ModelItem(
                            id: 'downloaded_${DateTime.now().millisecondsSinceEpoch}',
                            name: modelDisplayName,
                            architecture: 'BitNet b1.58 Ternary',
                            filename: destPath,
                            format: filename.endsWith('.tl1') ? '.tl1' : '.gguf',
                            size: '${(p.totalBytes / 1024 / 1024).toStringAsFixed(1)} МБ',
                            contextSize: 4096,
                            quantization: '1.58-bit Ternary',
                            ramRequirement: '1.2 ГБ',
                            speed: '~32 t/s',
                            isLoaded: false,
                            status: 'На накопителе',
                            isCompatible: true,
                            archSupport: 'ARM NEON GEMM ADD',
                            dateModified: 'Только что',
                            description: 'Загружено из Hugging Face',
                          );

                          widget.state.importModel(newModel);
                          widget.state.loadModel(newModel);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Модель «$modelDisplayName» загружена и активирована!'),
                                backgroundColor: AppColors.secondary,
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'В ЧАТ',
                                  textColor: Colors.white,
                                  onPressed: () => widget.state.setTab(0),
                                ),
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
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: AppColors.appleLabel,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.appleGlassSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.appleGreen.withOpacity(0.35),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.appleGreen,
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
                          color: AppColors.appleGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Поддержка форматов .tl1, .gguf (1.58-бит троичное квантование) для bitnet.cpp',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                letterSpacing: -0.2,
                color: AppColors.appleSecondaryLabel,
              ),
            ),
            const SizedBox(height: 14),

            // Hardware Kernel Optimization Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.appleGlassCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.appleGlassBorder,
                  width: 0.6,
                ),
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
                          color: AppColors.appleTeal.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          size: 20,
                          color: AppColors.appleTeal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'ARM NEON I8MM / AVX2',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: AppColors.appleLabel,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Аппаратное ускорение троичных ядер',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.appleSecondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.appleTeal.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ВКЛ',
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.appleTeal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Prominent Import Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.appleGlassCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.appleGlassBorder,
                  width: 0.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
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
                              color: AppColors.appleBlue.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 24,
                              color: AppColors.appleBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Добавить BitNet модель',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                  color: AppColors.appleLabel,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Локальный квант или Hugging Face',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.appleSecondaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: AppColors.appleBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Storage path hint
                  ApplePressable(
                    onTap: () => widget.state.setTab(3),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.appleGlassSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.appleGlassHighlight, width: 0.6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 16, color: AppColors.appleTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.state.settings.modelsDirectory,
                              style: const TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 11,
                                color: AppColors.appleSecondaryLabel,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.appleTertiaryLabel),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Action buttons
                  ApplePressable(
                    onTap: _openFilePicker,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.appleBlue,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.file_open_rounded, size: 17, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Выбрать файл из памяти устройства',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ApplePressable(
                    onTap: _showUrlDownloadDialog,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.appleGlassSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.appleGlassHighlight, width: 0.6),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_download_rounded, size: 17, color: AppColors.appleTeal),
                          SizedBox(width: 8),
                          Text(
                            'Hugging Face / Загрузить по URL',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                              color: AppColors.appleLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Models List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'УСТАНОВЛЕННЫЕ ВЕСА (${widget.state.models.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.appleSecondaryLabel,
                    ),
                  ),
                  Text(
                    widget.state.models.isEmpty
                        ? '0 моделей'
                        : 'Моделей: ${widget.state.models.length}',
                    style: const TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 11,
                      color: AppColors.appleTertiaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Model Cards or Empty Message
            if (widget.state.models.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.appleGlassCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.appleGlassBorder, width: 0.6),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.layers_clear_rounded, size: 44, color: AppColors.appleTertiaryLabel),
                    const SizedBox(height: 12),
                    const Text(
                      'Модели не установлены',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: AppColors.appleLabel,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'На накопителе нет загруженных моделей BitNet.\nНажмите кнопку загрузки выше или импортируйте файл .tl1 / .gguf из проводника.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.appleSecondaryLabel,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ApplePressable(
                      onTap: _showUrlDownloadDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.appleBlue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_download_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Скачать модель (Hugging Face)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...widget.state.models.map((model) => _buildModelCard(model)),
          ],
        ),

        // Apple Floating Action Pill Bottom Right
        Positioned(
          right: 20,
          bottom: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: ApplePressable(
                onTap: _openFilePicker,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.appleBlue,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.appleBlue.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Импорт',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
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
        color: AppColors.appleGlassCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLoaded
              ? AppColors.appleTeal.withOpacity(0.45)
              : AppColors.appleGlassBorder,
          width: isLoaded ? 1.0 : 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: AppColors.appleLabel,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Архитектура: ${model.architecture}',
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 11,
                        color: AppColors.appleTeal,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLoaded
                      ? AppColors.appleGreen.withOpacity(0.18)
                      : AppColors.appleGlassSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isLoaded
                        ? AppColors.appleGreen.withOpacity(0.35)
                        : AppColors.appleGlassBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoaded) ...[
                      const Icon(Icons.check_circle_rounded, size: 11, color: AppColors.appleGreen),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      model.status,
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isLoaded ? AppColors.appleGreen : AppColors.appleSecondaryLabel,
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
            runSpacing: 5,
            children: [
              if (widget.state.settings.russianSkillEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.appleTeal.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.translate_rounded, size: 11, color: AppColors.appleTeal),
                      SizedBox(width: 4),
                      Text(
                        'RU Навык',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.appleTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.appleOrange.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  model.quantization,
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.appleOrange,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.appleGlassSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                ),
                child: Text(
                  'Размер: ${model.size}',
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 10,
                    color: AppColors.appleSecondaryLabel,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.appleGlassSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
                ),
                child: Text(
                  'Контекст: ${model.contextSize}',
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFont,
                    fontSize: 10,
                    color: AppColors.appleSecondaryLabel,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active Metrics (if loaded) or RAM requirement info (if dormant)
          if (isLoaded) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.appleGlassSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.appleGlassBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'RAM VRAM',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                color: AppColors.appleSecondaryLabel,
                              ),
                            ),
                            Text(
                              '1.4 / 4.1 ГБ',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.appleTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            height: 4,
                            color: AppColors.appleGlassHighlight,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.34,
                              child: Container(color: AppColors.appleTeal),
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
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Скорость',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                color: AppColors.appleSecondaryLabel,
                              ),
                            ),
                            Text(
                              '~32 t/s',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.appleBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            height: 4,
                            color: AppColors.appleGlassHighlight,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.78,
                              child: Container(color: AppColors.appleBlue),
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
                    ApplePressable(
                      onTap: () => widget.state.setTab(3),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(7.0),
                        child: Icon(Icons.tune_rounded, size: 18, color: AppColors.appleSecondaryLabel),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ApplePressable(
                      onTap: () => widget.state.setTab(2),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(7.0),
                        child: Icon(Icons.analytics_rounded, size: 18, color: AppColors.appleSecondaryLabel),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ApplePressable(
                      onTap: () => _confirmDeleteModel(model),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(7.0),
                        child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.appleRed),
                      ),
                    ),
                  ],
                ),
                ApplePressable(
                  onTap: () => widget.state.unloadModel(model),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.appleRed.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eject_rounded, size: 15, color: AppColors.appleRed),
                        SizedBox(width: 5),
                        Text(
                          'Выгрузить',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: AppColors.appleRed,
                          ),
                        ),
                      ],
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
                    Icon(
                      model.isCompatible ? Icons.memory_rounded : Icons.warning_amber_rounded,
                      size: 15,
                      color: model.isCompatible ? AppColors.appleTertiaryLabel : AppColors.appleOrange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      model.isCompatible
                          ? 'Требуется ~${model.ramRequirement} ОЗУ'
                          : 'Несовместимый формат',
                      style: TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        color: model.isCompatible ? AppColors.appleSecondaryLabel : AppColors.appleOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ApplePressable(
                      onTap: () => _confirmDeleteModel(model),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.appleTertiaryLabel),
                      ),
                    ),
                  ],
                ),
                ApplePressable(
                  onTap: model.isCompatible ? () => _handleLoadModel(model) : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: model.isCompatible ? AppColors.appleBlue : AppColors.appleGlassSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          model.isCompatible ? Icons.play_arrow_rounded : Icons.block_rounded,
                          size: 15,
                          color: model.isCompatible ? Colors.white : AppColors.appleTertiaryLabel,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          model.isCompatible ? 'Загрузить в ОЗУ' : 'Не поддерживается',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: model.isCompatible ? Colors.white : AppColors.appleTertiaryLabel,
                          ),
                        ),
                      ],
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
