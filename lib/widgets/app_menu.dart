import 'package:flutter/material.dart';

/// Hamburger-style popup menu with theme toggle and about dialog.
class AppMenu extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const AppMenu({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      tooltip: 'Menu',
      onSelected: (value) {
        switch (value) {
          case 'theme_system':
            onThemeModeChanged(ThemeMode.system);
            break;
          case 'theme_light':
            onThemeModeChanged(ThemeMode.light);
            break;
          case 'theme_dark':
            onThemeModeChanged(ThemeMode.dark);
            break;
          case 'about':
            _showAboutDialog(context);
            break;
        }
      },
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              enabled: false,
              child: Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            PopupMenuItem(
              value: 'theme_system',
              child: Row(
                children: [
                  Icon(
                    Icons.brightness_auto,
                    color:
                        currentThemeMode == ThemeMode.system
                            ? Theme.of(context).colorScheme.primary
                            : null,
                  ),
                  const SizedBox(width: 12),
                  const Text('System'),
                  if (currentThemeMode == ThemeMode.system) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: 'theme_light',
              child: Row(
                children: [
                  Icon(
                    Icons.light_mode,
                    color:
                        currentThemeMode == ThemeMode.light
                            ? Theme.of(context).colorScheme.primary
                            : null,
                  ),
                  const SizedBox(width: 12),
                  const Text('Light'),
                  if (currentThemeMode == ThemeMode.light) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: 'theme_dark',
              child: Row(
                children: [
                  Icon(
                    Icons.dark_mode,
                    color:
                        currentThemeMode == ThemeMode.dark
                            ? Theme.of(context).colorScheme.primary
                            : null,
                  ),
                  const SizedBox(width: 12),
                  const Text('Dark'),
                  if (currentThemeMode == ThemeMode.dark) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'about',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Text('About AudioKit'),
                ],
              ),
            ),
          ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AudioKit',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.audiotrack, size: 48),
      children: [
        const Text(
          'A desktop audio toolkit for Linux.\n\n'
          '• Convert video files to Opus, MP3, or HE-AAC\n'
          '• Merge multiple audio files into one\n\n'
          'Powered by ffmpeg.',
        ),
      ],
    );
  }
}
