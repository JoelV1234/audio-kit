import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yaru/yaru.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

import 'widgets/app_menu.dart';
import 'widgets/audio_merger_tab.dart';
import 'widgets/video_to_audio_tab.dart';
import 'services/ffmpeg_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  runApp(const AudioKitApp());
}

class AudioKitApp extends StatefulWidget {
  const AudioKitApp({super.key});

  @override
  State<AudioKitApp> createState() => _AudioKitAppState();
}

class _AudioKitAppState extends State<AudioKitApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AudioKit',
      debugShowCheckedModeBanner: false,
      theme: yaruLight,
      darkTheme: yaruDark,
      themeMode: _themeMode,
      home: AudioKitHome(
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

class AudioKitHome extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const AudioKitHome({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<AudioKitHome> createState() => _AudioKitHomeState();
}

class _AudioKitHomeState extends State<AudioKitHome> with WindowListener {
  bool _ffmpegAvailable = true;

  final _videoTabKey = GlobalKey<VideoToAudioTabState>();
  final _mergerTabKey = GlobalKey<AudioMergerTabState>();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkFfmpeg();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final shouldClose = await _onWillPop();
    if (shouldClose) {
      await windowManager.destroy();
    }
  }

  Future<void> _checkFfmpeg() async {
    final available = await FfmpegService.isAvailable();
    if (!available && mounted) {
      setState(() => _ffmpegAvailable = false);
    }
  }

  void _onTabStateChanged() {
    setState(() {});
  }

  // --- Tab icon builders ---

  Widget _videoTabIcon() {
    final state = _videoTabKey.currentState;
    if (state == null) return const Icon(Icons.video_file);
    if (state.isConverting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (state.allDone) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    return const Icon(Icons.video_file);
  }

  Widget _mergerTabIcon() {
    final state = _mergerTabKey.currentState;
    if (state == null) return const Icon(Icons.merge_type);
    if (state.isMerging) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (state.allDone) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    return const Icon(Icons.merge_type);
  }

  // --- Close confirmation ---

  Future<bool> _onWillPop() async {
    final videoState = _videoTabKey.currentState;
    final mergerState = _mergerTabKey.currentState;

    final videoHasWork = videoState?.hasUnfinishedWork ?? false;
    final mergerHasWork = mergerState?.hasUnfinishedWork ?? false;
    final videoConverting = videoState?.isConverting ?? false;
    final mergerMerging = mergerState?.isMerging ?? false;

    if (!videoHasWork && !mergerHasWork) return true;

    final isProcessing = videoConverting || mergerMerging;

    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Gradient header ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          isProcessing
                              ? [
                                Colors.orange.shade700,
                                Colors.deepOrange.shade500,
                              ]
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
                        _StatusCard(
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
                              _ProgressRow(
                                label:
                                    '${(videoState!.overallProgress * 100).toStringAsFixed(0)}%',
                                progress: videoState.overallProgress,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    videoState.estimatedTimeRemaining,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${videoState.processingCount} processing · ${videoState.pendingCount} queued',
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
                        _StatusCard(
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
                            '${videoState!.pendingCount} file${videoState.pendingCount != 1 ? 's' : ''} added but not yet converted',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ),

                      if ((videoHasWork || videoConverting) &&
                          (mergerHasWork || mergerMerging))
                        const SizedBox(height: 12),

                      // Merger tab status
                      if (mergerMerging)
                        _StatusCard(
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
                                child: const LinearProgressIndicator(
                                  minHeight: 5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Merge in progress...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (mergerHasWork)
                        _StatusCard(
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
                            '${mergerState!.fileCount} file${mergerState.fileCount != 1 ? 's' : ''} added but not yet merged',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
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
                          onPressed: () => Navigator.pop(ctx, false),
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
                          onPressed: () => Navigator.pop(ctx, true),
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
      },
    );

    return shouldClose ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AudioKit'),
          actions: [
            AppMenu(
              currentThemeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: _videoTabIcon(), text: 'Video to Audio'),
              Tab(icon: _mergerTabIcon(), text: 'Audio Merger'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (!_ffmpegAvailable)
              MaterialBanner(
                content: const Text(
                  'ffmpeg was not found on your system. '
                  'Please install ffmpeg to use AudioKit.\n'
                  'Run: sudo apt install ffmpeg',
                ),
                leading: const Icon(Icons.warning, color: Colors.orange),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _ffmpegAvailable = true),
                    child: const Text('Dismiss'),
                  ),
                  TextButton(
                    onPressed: _checkFfmpeg,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  VideoToAudioTab(
                    key: _videoTabKey,
                    onStateChanged: _onTabStateChanged,
                  ),
                  AudioMergerTab(
                    key: _mergerTabKey,
                    onStateChanged: _onTabStateChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Close-dialog widgets
// ─────────────────────────────────────────────────────────────────────────────

/// A polished status card for the close-confirmation dialog.
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String statusLabel;
  final Color statusColor;
  final bool isDark;
  final Widget child;

  const _StatusCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconGradient.first, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A progress bar with a label on the right.
class _ProgressRow extends StatelessWidget {
  final String label;
  final double progress;
  final Color color;

  const _ProgressRow({
    required this.label,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: color.withOpacity(0.15),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
