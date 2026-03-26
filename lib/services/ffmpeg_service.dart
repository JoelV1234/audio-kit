import 'dart:convert';
import 'dart:io';

/// Supported output audio formats.
enum AudioFormat { opus, mp3, heAac }

/// Returns the file extension for the given [format].
String extensionForFormat(AudioFormat format) {
  switch (format) {
    case AudioFormat.opus:
      return '.opus';
    case AudioFormat.mp3:
      return '.mp3';
    case AudioFormat.heAac:
      return '.m4a';
  }
}

/// Returns a human-readable label for the given [format].
String labelForFormat(AudioFormat format) {
  switch (format) {
    case AudioFormat.opus:
      return 'Opus';
    case AudioFormat.mp3:
      return 'MP3';
    case AudioFormat.heAac:
      return 'HE-AAC';
  }
}

/// Service that wraps ffmpeg commands for audio conversion and merging.
class FfmpegService {
  /// Returns the ffmpeg arguments for encoding to the given [format].
  static List<String> _codecArgs(AudioFormat format) {
    switch (format) {
      case AudioFormat.opus:
        return ['-c:a', 'libopus', '-b:a', '128k'];
      case AudioFormat.mp3:
        return ['-c:a', 'libmp3lame', '-q:a', '2'];
      case AudioFormat.heAac:
        return ['-c:a', 'libfdk_aac', '-profile:a', 'aac_he', '-b:a', '64k'];
    }
  }

  /// Converts a video file at [inputPath] to audio, writing to [outputPath].
  ///
  /// The [onProcessStarted] callback provides the underlying `Process` so it can be killed.
  /// The [onProgress] callback provides real-time progress between 0.0 and 1.0.
  /// Returns the [ProcessResult] from ffmpeg.
  static Future<ProcessResult> convertVideoToAudio({
    required String inputPath,
    required String outputPath,
    required AudioFormat format,
    void Function(Process)? onProcessStarted,
    void Function(double, String)? onProgress,
  }) async {
    final args = [
      '-y', // overwrite
      '-i', inputPath,
      '-vn', // strip video
      ..._codecArgs(format),
      outputPath,
    ];

    final process = await Process.start('ffmpeg', args);
    if (onProcessStarted != null) onProcessStarted(process);

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    Duration? totalDuration;

    process.stdout.transform(utf8.decoder).listen((data) {
      stdoutBuffer.write(data);
    });

    final stderrCompleter = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stderrBuffer.writeln(line);

          // Parse Duration: 00:00:00.00
          if (totalDuration == null && line.contains('Duration:')) {
            final match = RegExp(
              r'Duration:\s+(\d+):(\d+):(\d+\.\d+)',
            ).firstMatch(line);
            if (match != null) {
              final hours = int.parse(match.group(1)!);
              final mins = int.parse(match.group(2)!);
              final secs = double.parse(match.group(3)!);
              totalDuration = Duration(
                milliseconds:
                    (hours * 3600000 + mins * 60000 + secs * 1000).toInt(),
              );
            }
          }

          // Parse time=00:00:00.00 and speed=1.5x
          if (totalDuration != null &&
              totalDuration!.inMilliseconds > 0 &&
              onProgress != null) {
            final match = RegExp(
              r'time=(\d+):(\d+):(\d+\.\d+)',
            ).firstMatch(line);
            if (match != null) {
              final hours = int.parse(match.group(1)!);
              final mins = int.parse(match.group(2)!);
              final secs = double.parse(match.group(3)!);
              final currentMs =
                  (hours * 3600000 + mins * 60000 + secs * 1000).toInt();

              double progress = currentMs / totalDuration!.inMilliseconds;
              if (progress > 1.0) progress = 1.0;
              if (progress < 0.0) progress = 0.0;

              String eta = '';
              final speedMatch = RegExp(
                r'speed=\s*([\d\.]+)x',
              ).firstMatch(line);
              if (speedMatch != null && progress > 0.0 && progress < 1.0) {
                final speed = double.tryParse(speedMatch.group(1)!) ?? 0.0;
                if (speed > 0) {
                  final remainingRealMs =
                      (totalDuration!.inMilliseconds - currentMs) / speed;
                  final remainingSecs = (remainingRealMs / 1000).round();
                  if (remainingSecs < 60) {
                    eta = '${remainingSecs}s';
                  } else {
                    final m = remainingSecs ~/ 60;
                    final s = remainingSecs % 60;
                    eta = '${m}m ${s}s';
                  }
                }
              }
              onProgress(progress, eta);
            }
          }
        });

    final exitCode = await process.exitCode;
    await stderrCompleter.asFuture();

    if (onProgress != null && exitCode == 0) {
      onProgress(1.0, '');
    }

    return ProcessResult(
      process.pid,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }

  /// Merges multiple audio files into one output file.
  ///
  /// Creates a temporary concat file, runs ffmpeg concat demuxer, then cleans up.
  static Future<ProcessResult> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat format,
    void Function(Process)? onProcessStarted,
    void Function(double, String)? onProgress,
  }) async {
    // Create a temporary concat list file.
    final tempDir = await Directory.systemTemp.createTemp('audiokit_');
    final concatFile = File('${tempDir.path}/concat.txt');

    // We first convert each input to a common PCM WAV so concat works across
    // different source formats, then concat the wav files, then encode to the
    // target format.
    final wavFiles = <String>[];
    for (var i = 0; i < inputPaths.length; i++) {
      final wavPath = '${tempDir.path}/part_$i.wav';
      final process = await Process.start('ffmpeg', [
        '-y',
        '-i',
        inputPaths[i],
        '-ar',
        '44100',
        '-ac',
        '2',
        '-f',
        'wav',
        wavPath,
      ]);

      if (onProcessStarted != null) onProcessStarted(process);

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        // Clean up temp dir
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
        return ProcessResult(
          process.pid,
          exitCode,
          '',
          'WAV conversion failed or cancelled',
        );
      }
      wavFiles.add(wavPath);
      if (onProgress != null) {
        onProgress(((i + 1) / inputPaths.length) * 0.4, '');
      }
    }

    // Write the concat list.
    final concatContent = wavFiles
        .map((p) => "file '${p.replaceAll("'", "'\\''")}'")
        .join('\n');
    await concatFile.writeAsString(concatContent);

    // Run ffmpeg concat.
    final args = [
      '-y',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      concatFile.path,
      ..._codecArgs(format),
      outputPath,
    ];

    final process = await Process.start('ffmpeg', args);
    if (onProcessStarted != null) onProcessStarted(process);
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    Duration? totalDuration;

    process.stdout
        .transform(utf8.decoder)
        .listen((data) => stdoutBuffer.write(data));

    final stderrCompleter = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stderrBuffer.writeln(line);
          // Parse duration
          if (totalDuration == null && line.contains('Duration:')) {
            final match = RegExp(
              r'Duration:\s+(\d+):(\d+):(\d+\.\d+)',
            ).firstMatch(line);
            if (match != null) {
              final hours = int.parse(match.group(1)!);
              final mins = int.parse(match.group(2)!);
              final secs = double.parse(match.group(3)!);
              totalDuration = Duration(
                milliseconds:
                    (hours * 3600000 + mins * 60000 + secs * 1000).toInt(),
              );
            }
          }

          // Parse time and speed
          if (totalDuration != null &&
              totalDuration!.inMilliseconds > 0 &&
              onProgress != null) {
            final match = RegExp(
              r'time=(\d+):(\d+):(\d+\.\d+)',
            ).firstMatch(line);
            if (match != null) {
              final hours = int.parse(match.group(1)!);
              final mins = int.parse(match.group(2)!);
              final secs = double.parse(match.group(3)!);
              final currentMs =
                  (hours * 3600000 + mins * 60000 + secs * 1000).toInt();

              double progress =
                  0.4 + (currentMs / totalDuration!.inMilliseconds) * 0.6;
              if (progress > 1.0) progress = 1.0;
              if (progress < 0.4) progress = 0.4;

              String eta = '';
              final speedMatch = RegExp(
                r'speed=\s*([\d\.]+)x',
              ).firstMatch(line);
              if (speedMatch != null && progress > 0.4 && progress < 1.0) {
                final speed = double.tryParse(speedMatch.group(1)!) ?? 0.0;
                if (speed > 0) {
                  final remainingRealMs =
                      (totalDuration!.inMilliseconds - currentMs) / speed;
                  final remainingSecs = (remainingRealMs / 1000).round();
                  if (remainingSecs < 60) {
                    eta = '${remainingSecs}s';
                  } else {
                    final m = remainingSecs ~/ 60;
                    final s = remainingSecs % 60;
                    eta = '${m}m ${s}s';
                  }
                }
              }

              onProgress(progress, eta);
            }
          }
        });

    final exitCode = await process.exitCode;
    await stderrCompleter.asFuture();
    // Clean up.
    await tempDir.delete(recursive: true);

    if (onProgress != null && exitCode == 0) {
      onProgress(1.0, '');
    }
    return ProcessResult(
      process.pid,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }

  /// Checks that ffmpeg is available on the system.
  static Future<bool> isAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
