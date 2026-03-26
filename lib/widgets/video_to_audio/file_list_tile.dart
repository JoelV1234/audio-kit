import 'package:flutter/material.dart';
import '../../models/media_file.dart';

/// Individual file tile with a progress bar and percentage beneath it.
class FileListTile extends StatelessWidget {
  final MediaFile file;
  final VoidCallback onRemove;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const FileListTile({
    super.key,
    required this.file,
    required this.onRemove,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConverting = file.status == MediaFileStatus.processing;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: _statusIcon(file.status),
            title: Text(
              file.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              file.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (file.status == MediaFileStatus.error)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.orange),
                    tooltip: 'Retry',
                    onPressed: onRetry,
                  ),
                if (isConverting)
                  IconButton(
                    icon: const Icon(
                      Icons.stop_circle_outlined,
                      color: Colors.red,
                    ),
                    tooltip: 'Cancel',
                    onPressed: onCancel,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove',
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
          if (isConverting || file.progress > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progressValue(),
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: _progressColor(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        file.statusMessage.isNotEmpty
                            ? file.statusMessage
                            : (isConverting ? 'Converting...' : 'Done'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                      _percentageLabel(),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _percentageLabel() {
    if (file.status == MediaFileStatus.processing) {
      return Text(
        '${(file.progress * 100).toStringAsFixed(1)}%',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      );
    }
    if (file.status == MediaFileStatus.done) {
      return const Text(
        '100%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  double? _progressValue() {
    if (file.status == MediaFileStatus.processing) {
      return file.progress > 0 ? file.progress : null;
    }
    if (file.status == MediaFileStatus.done) return 1.0;
    return 0.0;
  }

  Color _progressColor() {
    if (file.status == MediaFileStatus.done) return Colors.green;
    if (file.status == MediaFileStatus.error) return Colors.red;
    return Colors.blue;
  }

  Widget _statusIcon(MediaFileStatus status) {
    switch (status) {
      case MediaFileStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.grey);
      case MediaFileStatus.processing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case MediaFileStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green);
      case MediaFileStatus.error:
        return const Icon(Icons.error, color: Colors.red);
    }
  }
}
