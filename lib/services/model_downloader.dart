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
    'BitNet-b1.58-2B-4T (Microsoft Research i2_s, 1.15 ГБ) — Основная BitNet':
        'https://huggingface.co/microsoft/bitnet-b1.58-2B-4T-gguf/resolve/main/ggml-model-i2_s.gguf',
    'Qwen2.5-0.5B-Instruct (GGUF Q8_0, 530 МБ) — Диалоговая (RU / EN)':
        'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf',
    'SmolLM2-360M-Instruct (GGUF Q8_0, 385 МБ) — Быстрая мобильная':
        'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf',
    'Llama-3.2-1B-Instruct (GGUF Q4_K_M, 800 МБ) — Диалоговая Meta':
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
  };

  bool _isCanceled = false;

  void cancelCurrentDownload() {
    _isCanceled = true;
  }

  static Future<Directory> resolveModelStorageDir() async {
    final candidates = [
      Directory('/data/data/com.bitnet.ai/files/models'),
      Directory('/sdcard/Download/BitNet'),
      Directory('/sdcard/BitNet/models'),
      Directory('${Directory.systemTemp.path}/bitnet_models'),
    ];

    for (final dir in candidates) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final testFile = File('${dir.path}/.perm_test');
        await testFile.writeAsString('ok');
        await testFile.delete();
        return dir;
      } catch (_) {
        continue;
      }
    }
    return Directory('${Directory.systemTemp.path}/bitnet_models')..createSync(recursive: true);
  }

  Stream<DownloadProgress> downloadModel({
    required String url,
    required String destinationPath,
  }) async* {
    _isCanceled = false;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);

    try {
      Uri currentUri = Uri.parse(url);
      HttpClientResponse? response;
      int redirectHops = 0;

      while (redirectHops < 8) {
        final request = await client.getUrl(currentUri);
        request.followRedirects = true;
        response = await request.close();

        if (response.isRedirect ||
            response.statusCode == HttpStatus.movedPermanently ||
            response.statusCode == HttpStatus.found ||
            response.statusCode == HttpStatus.seeOther ||
            response.statusCode == HttpStatus.temporaryRedirect ||
            response.statusCode == HttpStatus.permanentRedirect) {
          final loc = response.headers.value(HttpHeaders.locationHeader);
          if (loc != null) {
            currentUri = currentUri.resolve(loc);
            redirectHops++;
            continue;
          }
        }
        break;
      }

      if (response == null || response.statusCode != 200) {
        yield DownloadProgress(
          receivedBytes: 0,
          totalBytes: 0,
          progressPercent: 0,
          speedMbPerSec: 0,
          isCompleted: false,
          error: 'Ошибка HTTP: ${response?.statusCode ?? 'Нет ответа'}',
        );
        return;
      }

      final totalBytes = response.contentLength > 0 ? response.contentLength : 83066016;
      int receivedBytes = 0;
      final file = File(destinationPath);
      await file.parent.create(recursive: true);
      final sink = file.openWrite();

      final stopwatch = Stopwatch()..start();
      int lastReportBytes = 0;

      await for (final chunk in response) {
        if (_isCanceled) {
          await sink.flush();
          await sink.close();
          if (await file.exists()) await file.delete();
          yield DownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            progressPercent: 0,
            speedMbPerSec: 0,
            isCompleted: false,
            error: 'Загрузка отменена пользователем',
          );
          return;
        }

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
