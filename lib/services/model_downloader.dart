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
    'BitNet-M7-70M (Быстрый старт, 79 МБ)':
        'https://huggingface.co/gate369/Bitnet-M7-70m-Q8_0-GGUF/resolve/main/bitnet-m7-70m.Q8_0.gguf',
    'BitNet-b1.58-2B-4T (Microsoft Research, 1.1 ГБ)':
        'https://huggingface.co/microsoft/bitnet-b1.58-2B-4T-gguf/resolve/main/ggml-model-i2_s.gguf',
    'BitNet-b1.58-3B (GreenSky Ternary, 1.2 ГБ)':
        'https://huggingface.co/Green-Sky/bitnet_b1_58-3B-GGUF/resolve/main/bitnet_b1_58-3B.q2_2.gguf',
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
