class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final String timestamp;
  final double? tokensPerSec;
  final int? latencyMs;
  final double? powerWatts;
  final int? tokensCount;
  final String? codeSnippet;
  final String? codeFilename;
  final bool isStreaming;
  final bool isTranslated;
  final String? originalText;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.tokensPerSec,
    this.latencyMs,
    this.powerWatts,
    this.tokensCount,
    this.codeSnippet,
    this.codeFilename,
    this.isStreaming = false,
    this.isTranslated = false,
    this.originalText,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    String? timestamp,
    double? tokensPerSec,
    int? latencyMs,
    double? powerWatts,
    int? tokensCount,
    String? codeSnippet,
    String? codeFilename,
    bool? isStreaming,
    bool? isTranslated,
    String? originalText,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      tokensPerSec: tokensPerSec ?? this.tokensPerSec,
      latencyMs: latencyMs ?? this.latencyMs,
      powerWatts: powerWatts ?? this.powerWatts,
      tokensCount: tokensCount ?? this.tokensCount,
      codeSnippet: codeSnippet ?? this.codeSnippet,
      codeFilename: codeFilename ?? this.codeFilename,
      isStreaming: isStreaming ?? this.isStreaming,
      isTranslated: isTranslated ?? this.isTranslated,
      originalText: originalText ?? this.originalText,
    );
  }
}
