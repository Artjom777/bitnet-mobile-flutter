import 'dart:async';
import 'dart:io';

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progressPercent;
  final double speedMbPerSec;
  final bool isCompleted;
  final String? error;

  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progressPercent,
    required this.speedMbPerSec,
    required this.isCompleted,
    this.error,
  });
}

class ModelDownloader {
  static final ModelDownloader instance = ModelDownloader._();
  ModelDownloader._();

  static const Map<String, String> officialModels = {
    'BitNet-b1.58-3B-Q1_58':
        'https://huggingface.co/1bitLLM/bitnet_b1_58-3B/resolve/main/ggml-model-i2_s.gguf',
    'BitNet-b1.58-Large':
        'https://huggingface.co/1bitLLM/bitnet_b1_58-large/resolve/main/ggml-model-i2_s.gguf',
    'Llama3-8B-1.58b':
        'https://huggingface.co/HF1BitLLM/Llama3-8B-1.58-100B-tokens/resolve/main/ggml-model-i2_s.gguf',
  };

  Stream<DownloadProgress> downloadModel({
    required String url,
    required String destinationPath,
  }) async* {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        yield DownloadProgress(
          receivedBytes: 0,
          totalBytes: 0,
          progressPercent: 0,
          speedMbPerSec: 0,
          isCompleted: false,
          error: 'Ошибка HTTP: ${response.statusCode}',
        );
        return;
      }

      final totalBytes = response.contentLength > 0 ? response.contentLength : 1250000000;
      int receivedBytes = 0;
      final file = File(destinationPath);
      await file.parent.create(recursive: true);
      final sink = file.openWrite();

      final stopwatch = Stopwatch()..start();
      int lastReportBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (receivedBytes - lastReportBytes > 1024 * 512 || receivedBytes == totalBytes) {
          final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
          final speed = elapsedSec > 0 ? (receivedBytes / (1024 * 1024)) / elapsedSec : 0.0;
          lastReportBytes = receivedBytes;

          yield DownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            progressPercent: (receivedBytes / totalBytes).clamp(0.0, 1.0),
            speedMbPerSec: speed,
            isCompleted: false,
          );
        }
      }

      await sink.flush();
      await sink.close();

      yield DownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
        progressPercent: 1.0,
        speedMbPerSec: 0.0,
        isCompleted: true,
      );
    } catch (e) {
      yield DownloadProgress(
        receivedBytes: 0,
        totalBytes: 0,
        progressPercent: 0,
        speedMbPerSec: 0,
        isCompleted: false,
        error: e.toString(),
      );
    } finally {
      client.close();
    }
  }
}
