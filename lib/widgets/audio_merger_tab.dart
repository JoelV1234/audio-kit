import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/media_file.dart';
import '../services/ffmpeg_service.dart';

/// Tab for merging multiple audio files into one.
class AudioMergerTab extends StatefulWidget {
  final VoidCallback? onStateChanged;

  const AudioMergerTab({super.key, this.onStateChanged});

  @override
  State<AudioMergerTab> createState() => AudioMergerTabState();
}

class AudioMergerTabState extends State<AudioMergerTab>
    with AutomaticKeepAliveClientMixin {
  final List<MediaFile> _files = [];
  AudioFormat _selectedFormat = AudioFormat.mp3;
  bool _isDragging = false;
  bool _isMerging = false;
  double _mergeProgress = 0.0;
  String _mergeEta = '';
  Process? _activeProcess;
  bool _cancelRequested = false;
  String? _outputPath;

  @override
  bool get wantKeepAlive => true;

  static const _audioExtensions = {
    '.mp3',
    '.opus',
    '.ogg',
    '.m4a',
    '.aac',
    '.wav',
    '.flac',
    '.wma',
    '.alac',
    '.aiff',
    '.pcm',
    '.webm',
  };

  /// Whether there are pending files or a merge in progress.
  bool get hasUnfinishedWork => _files.isNotEmpty || _isMerging;
  bool get isMerging => _isMerging;
  int get fileCount => _files.length;

  /// True after a successful merge.
  bool _lastMergeSucceeded = false;
  bool get allDone => _lastMergeSucceeded && !_isMerging;

  void _notifyParent() {
    widget.onStateChanged?.call();
  }

  /// Adds audio files from paths.
  void _addFiles(List<String> paths) {
    setState(() {
      for (final path in paths) {
        final ext = p.extension(path).toLowerCase();
        if (_audioExtensions.contains(ext)) {
          if (!_files.any((f) => f.path == path)) {
            _files.add(MediaFile(path: path, name: p.basename(path)));
          }
        }
      }
      _files.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    });
    _notifyParent();
  }

  /// Recursively collects all files from a directory.
  Future<List<String>> _collectFilesFromDir(String dirPath) async {
    final dir = Directory(dirPath);
    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity.path);
      }
    }
    return files;
  }

  Future<void> _onDropDone(DropDoneDetails details) async {
    final directFiles = <String>[];
    final folderPaths = <String>[];

    for (final xfile in details.files) {
      final path = xfile.path;
      if (await FileSystemEntity.isDirectory(path)) {
        folderPaths.add(path);
      } else {
        directFiles.add(path);
      }
    }

    // Add direct files.
    if (directFiles.isNotEmpty) {
      _addFiles(directFiles);
    }

    // Handle folders — show dialog.
    if (folderPaths.isNotEmpty && mounted) {
      final allFolderFiles = <String>[];
      for (final dir in folderPaths) {
        allFolderFiles.addAll(await _collectFilesFromDir(dir));
      }

      final audioCount =
          allFolderFiles
              .where(
                (f) => _audioExtensions.contains(p.extension(f).toLowerCase()),
              )
              .length;

      if (audioCount == 0) {
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  icon: const Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: Colors.orange,
                  ),
                  title: const Text('No Audio Files Found'),
                  content: const Text(
                    'There are no supported audio files in the dropped folder(s).',
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
        return;
      }

      final action = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              icon: const Icon(Icons.folder_open, size: 40),
              title: const Text('Import Folder'),
              content: Text(
                audioCount == allFolderFiles.length
                    ? 'Import $audioCount audio file${audioCount == 1 ? '' : 's'}'
                    : 'Found ${allFolderFiles.length} item${allFolderFiles.length == 1 ? '' : 's'} '
                        'in ${folderPaths.length == 1 ? 'this folder' : '${folderPaths.length} folders'}.\n\n'
                        'Only $audioCount of them ${audioCount == 1 ? 'is an audio file' : 'are audio files'}.\n\n'
                        'Would you like to import the audio files',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'import'),
                  icon: const Icon(Icons.audiotrack),
                  label: const Text('Import Audio Files'),
                ),
              ],
            ),
      );

      if (action == 'import') {
        _addFiles(allFolderFiles);
      }
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioExtensions.map((e) => e.substring(1)).toList(),
      allowMultiple: true,
    );
    if (result != null) {
      _addFiles(result.paths.whereType<String>().toList());
    }
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
    _notifyParent();
  }

  void _clearFiles() {
    setState(() {
      _files.clear();
      _lastMergeSucceeded = false;
    });
    _notifyParent();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _files.removeAt(oldIndex);
      _files.insert(newIndex, item);
    });
  }

  Future<void> _cancelMerge() async {
    if (!_isMerging) return;

    final pathToDelete = _outputPath;

    setState(() {
      _cancelRequested = true;
      _activeProcess?.kill();
      _isMerging = false;
      _mergeProgress = 0.0;
      _mergeEta = '';
      _activeProcess = null;
    });
    _notifyParent();

    if (pathToDelete != null && mounted) {
      final deleteFile = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              icon: const Icon(
                Icons.delete_outline,
                size: 40,
                color: Colors.orange,
              ),
              title: const Text('Delete Partial File?'),
              content: Text(
                'The merge was cancelled. Would you like to delete '
                'the partially created file?\n\n'
                '${p.basename(pathToDelete)}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );

      if (deleteFile == true) {
        try {
          final file = File(pathToDelete);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Best-effort deletion
        }
      }
    }
  }

  Future<String> _getDefaultOutputDir() async {
    final home = Platform.environment['HOME'] ?? '';
    final downloads = p.join(home, 'Downloads');
    if (await Directory(downloads).exists()) {
      return downloads;
    }
    return home;
  }

  Future<void> _merge() async {
    if (_files.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 audio files to merge')),
      );
      return;
    }

    final ext = extensionForFormat(_selectedFormat);
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save merged audio as',
      fileName: 'merged$ext',
      initialDirectory: await _getDefaultOutputDir(),
    );
    if (outputPath == null) return;

    String finalPath = outputPath;
    if (!finalPath.endsWith(ext)) {
      finalPath = '$finalPath$ext';
    }
    _outputPath = finalPath;

    setState(() {
      _isMerging = true;
      _mergeProgress = 0.0;
      _cancelRequested = false;
      _activeProcess = null;
    });
    _notifyParent();

    final result = await FfmpegService.mergeAudioFiles(
      inputPaths: _files.map((f) => f.path).toList(),
      outputPath: finalPath,
      format: _selectedFormat,
      onProcessStarted: (process) {
        if (!mounted) return;
        setState(() => _activeProcess = process);
      },
      onProgress: (progress, eta) {
        if (!mounted) return;
        setState(() {
          _mergeProgress = progress;
          _mergeEta = eta;
        });
      },
    );

    if (!mounted) return;

    setState(() {
      _isMerging = false;
      _activeProcess = null;
      if (result.exitCode == 0) {
        _mergeProgress = 1.0;
      }
      _lastMergeSucceeded = result.exitCode == 0;
    });
    _notifyParent();

    if (mounted && !_cancelRequested) {
      if (result.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merged successfully: ${p.basename(finalPath)}'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merge failed: ${result.stderr}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return DropTarget(
      onDragDone: (details) {
        if (DefaultTabController.maybeOf(context)?.index != 1) return;
        _onDropDone(details);
      },
      onDragEntered: (_) {
        if (DefaultTabController.maybeOf(context)?.index != 1) return;
        setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        if (DefaultTabController.maybeOf(context)?.index != 1) return;
        setState(() => _isDragging = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border:
              _isDragging
                  ? Border.all(color: theme.colorScheme.primary, width: 3)
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Row(
                children: [
                  Icon(Icons.merge_type, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Audio Merger', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  const Text('Output: '),
                  const SizedBox(width: 8),
                  DropdownButton<AudioFormat>(
                    value: _selectedFormat,
                    onChanged:
                        _isMerging
                            ? null
                            : (v) => setState(() => _selectedFormat = v!),
                    items:
                        AudioFormat.values
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(labelForFormat(f)),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isMerging ? null : _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Files'),
                  ),
                  const SizedBox(width: 12),
                  if (!_isMerging)
                    ElevatedButton.icon(
                      onPressed: _files.length < 2 ? null : _merge,
                      icon: const Icon(Icons.call_merge),
                      label: const Text('Merge'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _cancelMerge,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed:
                        (_isMerging || _files.isEmpty) ? null : _clearFiles,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                  if (_files.isNotEmpty) ...[
                    const Spacer(),
                    Text(
                      '${_files.length} files — drag to reorder',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Merge progress bar.
              if (_isMerging)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _mergeProgress > 0 ? _mergeProgress : null,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _mergeProgress > 0
                              ? 'Merging ${_files.length} files... ${(_mergeProgress * 100).toStringAsFixed(1)}%'
                              : 'Preparing files for merge...',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (_mergeEta.isNotEmpty)
                          Text(
                            _mergeEta,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 8),

              // File list or drop prompt
              Expanded(
                child:
                    _files.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.file_upload_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Drag & drop audio files or folders here\nor use "Add Files" button',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Supports: MP3, Opus, OGG, M4A, AAC, WAV, FLAC, and more',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        )
                        : ReorderableListView.builder(
                          itemCount: _files.length,
                          onReorder: _onReorder,
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            return ListTile(
                              key: ValueKey(file.path),
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                              title: Text(
                                file.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                file.path,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing:
                                  _isMerging
                                      ? null
                                      : IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => _removeFile(index),
                                      ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
