import 'package:flutter/material.dart';
import '../widgets/common/progress_row.dart';
import '../widgets/common/status_card.dart';

class CloseConfirmationDialog extends StatelessWidget {
  final bool videoConverting;
  final bool videoHasWork;
  final double videoOverallProgress;
  final String videoEstimatedTimeRemaining;
  final int videoProcessingCount;
  final int videoPendingCount;

  final bool mergerMerging;
  final bool mergerHasWork;
  final int mergerFileCount;

  const CloseConfirmationDialog({
    super.key,
    required this.videoConverting,
    required this.videoHasWork,
    required this.videoOverallProgress,
    required this.videoEstimatedTimeRemaining,
    required this.videoProcessingCount,
    required this.videoPendingCount,
    required this.mergerMerging,
    required this.mergerHasWork,
    required this.mergerFileCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isProcessing = videoConverting || mergerMerging;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gradient header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isProcessing
                          ? [Colors.orange.shade700, Colors.deepOrange.shade500]
                          : [Colors.blue.shade600, Colors.indigo.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isProcessing
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isProcessing ? 'Work in Progress' : 'Unprocessed Files',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isProcessing
                        ? 'Closing now will cancel active operations'
                        : 'You have files waiting to be processed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // ── Status cards ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                children: [
                  // Video tab status
                  if (videoConverting)
                    StatusCard(
                      icon: Icons.video_file,
                      iconGradient: [
                        Colors.blue.shade400,
                        Colors.blue.shade700,
                      ],
                      title: 'Video to Audio',
                      statusLabel: 'CONVERTING',
                      statusColor: Colors.blue,
                      isDark: isDark,
                      child: Column(
                        children: [
                          ProgressRow(
                            label:
                                '${(videoOverallProgress * 100).toStringAsFixed(0)}%',
                            progress: videoOverallProgress,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                videoEstimatedTimeRemaining,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$videoProcessingCount processing · $videoPendingCount queued',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (videoHasWork)
                    StatusCard(
                      icon: Icons.video_file,
                      iconGradient: [
                        Colors.orange.shade400,
                        Colors.orange.shade700,
                      ],
                      title: 'Video to Audio',
                      statusLabel: 'PENDING',
                      statusColor: Colors.orange,
                      isDark: isDark,
                      child: Text(
                        '$videoPendingCount file${videoPendingCount != 1 ? 's' : ''} added but not yet converted',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),

                  if ((videoHasWork || videoConverting) &&
                      (mergerHasWork || mergerMerging))
                    const SizedBox(height: 12),

                  // Merger tab status
                  if (mergerMerging)
                    StatusCard(
                      icon: Icons.merge_type,
                      iconGradient: [
                        Colors.blue.shade400,
                        Colors.blue.shade700,
                      ],
                      title: 'Audio Merger',
                      statusLabel: 'MERGING',
                      statusColor: Colors.blue,
                      isDark: isDark,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: const LinearProgressIndicator(minHeight: 5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Merge in progress...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (mergerHasWork)
                    StatusCard(
                      icon: Icons.merge_type,
                      iconGradient: [
                        Colors.orange.shade400,
                        Colors.orange.shade700,
                      ],
                      title: 'Audio Merger',
                      statusLabel: 'PENDING',
                      statusColor: Colors.orange,
                      isDark: isDark,
                      child: Text(
                        '$mergerFileCount file${mergerFileCount != 1 ? 's' : ''} added but not yet merged',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Action buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Go Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close App'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> show(
    BuildContext context, {
    required bool videoConverting,
    required bool videoHasWork,
    required double videoOverallProgress,
    required String videoEstimatedTimeRemaining,
    required int videoProcessingCount,
    required int videoPendingCount,
    required bool mergerMerging,
    required bool mergerHasWork,
    required int mergerFileCount,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => CloseConfirmationDialog(
            videoConverting: videoConverting,
            videoHasWork: videoHasWork,
            videoOverallProgress: videoOverallProgress,
            videoEstimatedTimeRemaining: videoEstimatedTimeRemaining,
            videoProcessingCount: videoProcessingCount,
            videoPendingCount: videoPendingCount,
            mergerMerging: mergerMerging,
            mergerHasWork: mergerHasWork,
            mergerFileCount: mergerFileCount,
          ),
    );
    return result ?? false;
  }
}
