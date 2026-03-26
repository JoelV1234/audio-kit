import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: 'FFMPEG Kit',
      debugShowCheckedModeBanner: false,
      theme: yaruLightTheme,
      darkTheme: yaruDarkTheme,
      themeMode: _themeMode,
      home: AudioKitHome(
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
