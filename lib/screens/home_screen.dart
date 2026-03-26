import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../widgets/app_menu.dart';
import '../widgets/audio_merger_tab.dart';
import '../widgets/video_to_audio_tab.dart';
import '../services/ffmpeg_service.dart';
import '../dialogs/close_confirmation_dialog.dart';

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

    return CloseConfirmationDialog.show(
      context,
      videoConverting: videoConverting,
      videoHasWork: videoHasWork,
      videoOverallProgress: videoState?.overallProgress ?? 0,
      videoEstimatedTimeRemaining: videoState?.estimatedTimeRemaining ?? '',
      videoProcessingCount: videoState?.processingCount ?? 0,
      videoPendingCount: videoState?.pendingCount ?? 0,
      mergerMerging: mergerMerging,
      mergerHasWork: mergerHasWork,
      mergerFileCount: mergerState?.fileCount ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 80,
          title: Column(
            children: [
              const SizedBox(height: 10),
              TabBar(
                tabs: [
                  Tab(icon: _videoTabIcon(), text: 'Video to Audio'),
                  Tab(icon: _mergerTabIcon(), text: 'Audio Merger'),
                ],
              ),
            ],
          ),
          actions: [
            AppMenu(
              currentThemeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged,
            ),
            const SizedBox(width: 15),
          ],
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
