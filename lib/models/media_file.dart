/// Status of a media file in the processing pipeline.
enum MediaFileStatus { pending, processing, done, error }

/// Represents a media file added by the user for conversion or merging.
class MediaFile {
  final String path;
  final String name;
  MediaFileStatus status;
  double progress;
  String statusMessage;
  String? errorMessage;
  String? eta;

  MediaFile({
    required this.path,
    required this.name,
    this.status = MediaFileStatus.pending,
    this.progress = 0.0,
    this.statusMessage = '',
    this.errorMessage,
    this.eta,
  });

  MediaFile copyWith({
    String? path,
    String? name,
    MediaFileStatus? status,
    double? progress,
    String? statusMessage,
    String? errorMessage,
    String? eta,
  }) {
    return MediaFile(
      path: path ?? this.path,
      name: name ?? this.name,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      eta: eta ?? this.eta,
    );
  }
}
