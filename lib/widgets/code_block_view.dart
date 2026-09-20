import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class CodeBlockView extends StatefulWidget {
  final String filename;
  final String code;

  const CodeBlockView({
    super.key,
    required this.filename,
    required this.code,
  });

  @override
  State<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<CodeBlockView> {
  bool _copied = false;

  void _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Код скопирован в буфер обмена'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: filename + copy button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.filename,
                    style: const TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _handleCopy,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        _copied ? Icons.check : Icons.content_copy,
                        size: 14,
                        color: _copied ? AppColors.secondary : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copied ? 'Скопировано' : 'Копировать',
                        style: TextStyle(
                          fontFamily: AppTypography.monoFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _copied ? AppColors.secondary : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.surfaceContainerHighest),
          const SizedBox(height: 8),
          // Code with colored tokens
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildSyntaxHighlightedText(widget.code),
          ),
        ],
      ),
    );
  }

  Widget _buildSyntaxHighlightedText(String rawCode) {
    // Custom token coloring for Python parser.py
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: AppTypography.monoFont,
          fontSize: 12,
          height: 1.45,
          color: AppColors.onSurface,
        ),
        children: [
          const TextSpan(text: 'import ', style: TextStyle(color: AppColors.tertiary)),
          const TextSpan(text: 'json\n\n'),
          const TextSpan(text: 'def ', style: TextStyle(color: AppColors.tertiary)),
          const TextSpan(text: 'parse_data', style: TextStyle(color: AppColors.secondary)),
          const TextSpan(text: '(raw_text: '),
          const TextSpan(text: 'str', style: TextStyle(color: AppColors.secondaryFixed)),
          const TextSpan(text: ') -> '),
          const TextSpan(text: 'dict', style: TextStyle(color: AppColors.secondaryFixed)),
          const TextSpan(text: ':\n'),
          const TextSpan(text: '    try', style: TextStyle(color: AppColors.tertiary)),
          const TextSpan(text: ':\n'),
          const TextSpan(text: '        payload = json.loads(raw_text)\n'),
          const TextSpan(text: '        return ', style: TextStyle(color: AppColors.tertiary)),
          const TextSpan(text: '{"status": ', style: TextStyle(color: AppColors.secondaryFixed)),
          const TextSpan(text: '"ok"', style: TextStyle(color: AppColors.secondaryFixed)),
          const TextSpan(text: ', "data": payload}\n', style: TextStyle(color: AppColors.secondaryFixed)),
          const TextSpan(text: '    except ', style: TextStyle(color: AppColors.tertiary)),
          const TextSpan(text: 'json.JSONDecodeError '),
          const TextSpan(text: 'as ', style: TextStyle(color: AppColors.tertiary)),
          const TextSpan(text: 'err:\n'),
          const TextSpan(text: '        return ', style: TextStyle(color: AppColors.tertiary)),
          const TextSpan(text: '{"status": ', style: TextStyle(color: AppColors.secondaryFixed)),
          const TextSpan(text: '"error"', style: TextStyle(color: AppColors.secondaryFixed)),
          const TextSpan(text: ', "msg": str(err)}', style: TextStyle(color: AppColors.secondaryFixed)),
        ],
      ),
    );
  }
}
