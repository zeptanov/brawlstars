import 'package:flutter/material.dart';

import 'app/settings.dart';
import 'app/theme.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const MazeRoyaleApp());
}

class MazeRoyaleApp extends StatelessWidget {
  const MazeRoyaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maze Royale',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
