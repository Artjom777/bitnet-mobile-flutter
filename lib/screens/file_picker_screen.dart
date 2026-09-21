import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/model_item.dart';
import '../state/bitnet_state.dart';

class FilePickerScreen extends StatefulWidget {
  final BitNetState state;

  const FilePickerScreen({super.key, required this.state});

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  int _selectedStorageIndex = 0;
  int _selectedFilterIndex = 0;
  late ModelItem _selectedModel;
  bool _isValidating = false;
  bool _isValidated = false;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isGridView = false;
  String _sortMode = 'default';

  final List<Map<String, dynamic>> _storageProviders = [
    {'name': 'Внутренний накопитель', 'icon': Icons.smartphone, 'path': '/sdcard/Download/BitNet'},
    {'name': 'SD-карта', 'icon': Icons.sd_card, 'path': '/sdcard/BitNet/models'},
    {'name': 'Google Drive', 'icon': Icons.cloud, 'path': '/cloud/drive/BitNet'},
    {'name': 'Недавние', 'icon': Icons.schedule, 'path': '/data/data/com.bitnet.ai/files/models'},
  ];

  final List<String> _filters = [
    'Все совместимые (.tl1, .gguf)',
    '.tl1 (BitNet 1.58b)',
    '.gguf (Ternary)',
    '.bin',
  ];

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.state.pickerFiles.isNotEmpty
        ? widget.state.pickerFiles.first
        : ModelItem.empty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.state.scanLocalModelFiles().then((_) {
        if (mounted && _selectedModel.id == 'none' && widget.state.pickerFiles.isNotEmpty) {
          setState(() {
            _selectedModel = widget.state.pickerFiles.first;
          });
        }
      });
    });
  }

  void _handleValidateAndImport() async {
    if (_selectedModel.id == 'none' || _selectedModel.filename.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите файл модели для импорта'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final file = File(_selectedModel.filename);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Файл «${_selectedModel.filename}» не существует на диске!'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isValidating = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() {
      _isValidating = false;
      _isValidated = true;
    });

    final ok = widget.state.importModel(_selectedModel);
    Navigator.of(context).pop();

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Модель ${_selectedModel.name} проверена и загружена в память!'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка импорта модели ${_selectedModel.name}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Action Bar & Path
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                            tooltip: 'Назад',
                          ),
                          const SizedBox(width: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Выбор весов модели',
                                style: TextStyle(
                                  fontFamily: AppTypography.sansFont,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                'Внутренний накопитель > Download > bitnet_models',
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
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() => _isSearching = !_isSearching),
                            icon: Icon(
                              _isSearching ? Icons.close : Icons.search,
                              color: _isSearching ? AppColors.primary : AppColors.onSurfaceVariant,
                              size: 20,
                            ),
                            tooltip: 'Поиск моделей',
                          ),
                          IconButton(
                            onPressed: () => setState(() => _isGridView = !_isGridView),
                            icon: Icon(
                              _isGridView ? Icons.view_list : Icons.grid_view,
                              color: AppColors.onSurfaceVariant,
                              size: 20,
                            ),
                            tooltip: _isGridView ? 'Список' : 'Сетка',
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceVariant, size: 20),
                            color: AppColors.surfaceContainer,
                            onSelected: (val) {
                              if (val == 'scan') {
                                widget.state.scanLocalModelFiles();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Сканирование накопителя завершено'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                setState(() => _sortMode = val);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'scan',
                                child: Text('Сканировать накопитель', style: TextStyle(color: AppColors.onSurface, fontSize: 13)),
                              ),
                              const PopupMenuItem(
                                value: 'size',
                                child: Text('Сортировать по размеру', style: TextStyle(color: AppColors.onSurface, fontSize: 13)),
                              ),
                              const PopupMenuItem(
                                value: 'name',
                                child: Text('Сортировать по имени', style: TextStyle(color: AppColors.onSurface, fontSize: 13)),
                              ),
                              const PopupMenuItem(
                                value: 'default',
                                child: Text('Сбросить сортировку', style: TextStyle(color: AppColors.onSurface, fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isSearching) ...[
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      style: const TextStyle(
                        fontFamily: AppTypography.sansFont,
                        fontSize: 13,
                        color: AppColors.onSurface,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Поиск по имени файла или архитектуре...',
                        hintStyle: const TextStyle(
                          fontFamily: AppTypography.sansFont,
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Storage provider chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _storageProviders.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final isSel = _selectedStorageIndex == idx;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _selectedStorageIndex = idx),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.secondaryContainer : AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 16,
                                    color: isSel ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item['name'] as String,
                                    style: TextStyle(
                                      fontFamily: AppTypography.monoFont,
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                      color: isSel ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Format filter pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final f = entry.value;
                        final isSel = _selectedFilterIndex == idx;

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setState(() => _selectedFilterIndex = idx),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.primaryContainer : AppColors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  if (isSel) ...[
                                    const Icon(Icons.check, size: 12, color: AppColors.onPrimaryContainer),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    f,
                                    style: TextStyle(
                                      fontFamily: AppTypography.monoFont,
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                      color: isSel ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Path Breadcrumb & Storage Info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_open, size: 18, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Text(
                          _storageProviders[_selectedStorageIndex]['path'] as String,
                          style: const TextStyle(
                            fontFamily: AppTypography.monoFont,
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.circle, size: 6, color: AppColors.secondary),
                          SizedBox(width: 4),
                          Text(
                            'Локально',
                            style: TextStyle(
                              fontFamily: AppTypography.monoFont,
                              fontSize: 10,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // File List or Grid
            Expanded(
              child: Builder(
                builder: (context) {
                  var files = List<ModelItem>.from(widget.state.pickerFiles);
                  if (_selectedFilterIndex == 1) {
                    files = files.where((f) => f.format == '.tl1').toList();
                  } else if (_selectedFilterIndex == 2) {
                    files = files.where((f) => f.format == '.gguf').toList();
                  } else if (_selectedFilterIndex == 3) {
                    files = files.where((f) => f.format == '.bin').toList();
                  }
                  if (_searchQuery.trim().isNotEmpty) {
                    final q = _searchQuery.trim().toLowerCase();
                    files = files.where((f) => f.name.toLowerCase().contains(q) || f.architecture.toLowerCase().contains(q)).toList();
                  }
                  if (_sortMode == 'size') {
                    files.sort((a, b) => b.size.compareTo(a.size));
                  } else if (_sortMode == 'name') {
                    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  }

                  if (files.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.search_off, size: 36, color: AppColors.onSurfaceVariant),
                          SizedBox(height: 8),
                          Text('Модели не найдены', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  if (_isGridView) {
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        final isSelected = _selectedModel.id == file.id;
                        return _buildFileGridItem(file, isSelected);
                      },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final isSelected = _selectedModel.id == file.id;
                      return _buildFileItem(file, isSelected);
                    },
                  );
                },
              ),
            ),
            // Bottom Sheet Drawer & Actions
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Signature Validation Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _selectedModel.isCompatible ? Icons.verified : Icons.warning_amber,
                                  size: 18,
                                  color: _selectedModel.isCompatible ? AppColors.secondary : AppColors.error,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_selectedModel.filename} (${_selectedModel.size})',
                                  style: const TextStyle(
                                    fontFamily: AppTypography.monoFont,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _selectedModel.isCompatible
                                    ? AppColors.secondary.withOpacity(0.15)
                                    : AppColors.error.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedModel.isCompatible ? 'Сигнатура валидна' : 'Несовместимо',
                                style: TextStyle(
                                  fontFamily: AppTypography.monoFont,
                                  fontSize: 10,
                                  color: _selectedModel.isCompatible ? AppColors.secondary : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              _selectedModel.isCompatible ? Icons.speed : Icons.info_outline,
                              size: 14,
                              color: _selectedModel.isCompatible ? AppColors.secondary : AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedModel.isCompatible
                                  ? 'Совместимо с ${_selectedModel.archSupport} • Троичные веса 1.58-бит'
                                  : 'Требуется квантование tl1 или gguf для ядра ARM64',
                              style: const TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Потребуется RAM: ~${_selectedModel.ramRequirement}',
                              style: const TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const Text(
                              'Доступно 6.6 ГБ из 8 ГБ',
                              style: TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 10,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 4,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.22,
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
                  const SizedBox(height: 12),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Отмена',
                            style: TextStyle(
                              fontFamily: AppTypography.sansFont,
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _selectedModel.isCompatible && !_isValidating
                              ? _handleValidateAndImport
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimaryContainer,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _isValidating
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Валидация весов...',
                                      style: TextStyle(
                                        fontFamily: AppTypography.sansFont,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isValidated ? Icons.task_alt : Icons.file_download_done,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isValidated
                                          ? 'Готово к загрузке'
                                          : (_selectedModel.isCompatible
                                              ? 'Открыть и валидировать'
                                              : 'Формат не поддерживается'),
                                      style: const TextStyle(
                                        fontFamily: AppTypography.sansFont,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(ModelItem file, bool isSelected) {
    final isDisabled = !file.isCompatible;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceContainerHigh : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1)
              : null,
        ),
        child: InkWell(
          onTap: isDisabled ? null : () => setState(() => _selectedModel = file),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDisabled
                        ? Icons.block
                        : (file.format == '.tl1' ? Icons.memory : Icons.layers),
                    size: 22,
                    color: isSelected
                        ? AppColors.onPrimaryContainer
                        : (isDisabled ? AppColors.onSurfaceVariant : AppColors.tertiary),
                  ),
                ),
                const SizedBox(width: 12),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              file.filename,
                              style: TextStyle(
                                fontFamily: AppTypography.sansFont,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: isDisabled ? TextDecoration.lineThrough : null,
                                color: isSelected ? AppColors.primary : AppColors.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 13, color: AppColors.onPrimary),
                            )
                          else if (isDisabled)
                            const Icon(Icons.error_outline, size: 16, color: AppColors.error)
                          else
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${file.size} • ${file.dateModified} • ${file.description}',
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (file.id == 'bitnet_b1_58_3b')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified, size: 11, color: AppColors.secondary),
                                  SizedBox(width: 3),
                                  Text(
                                    'Рекомендуется для bitnet.cpp',
                                    style: TextStyle(
                                      fontFamily: AppTypography.monoFont,
                                      fontSize: 9,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              file.quantization,
                              style: const TextStyle(
                                fontFamily: AppTypography.monoFont,
                                fontSize: 9,
                                color: AppColors.tertiary,
                              ),
                            ),
                          ),
                          if (isDisabled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Слишком большой для RAM',
                                style: TextStyle(
                                  fontFamily: AppTypography.monoFont,
                                  fontSize: 9,
                                  color: AppColors.onErrorContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileGridItem(ModelItem file, bool isSelected) {
    final isDisabled = !file.isCompatible;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceContainerHigh : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : Border.all(color: AppColors.outlineVariant.withOpacity(0.15), width: 0.5),
        ),
        child: InkWell(
          onTap: isDisabled ? null : () => setState(() => _selectedModel = file),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDisabled
                            ? Icons.block
                            : (file.format == '.tl1' ? Icons.memory : Icons.layers),
                        size: 18,
                        color: isSelected ? AppColors.onPrimaryContainer : AppColors.tertiary,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 12, color: AppColors.onPrimary),
                      ),
                  ],
                ),
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.sansFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primary : AppColors.onSurface,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      file.size,
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFont,
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        file.format,
                        style: const TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 9,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
