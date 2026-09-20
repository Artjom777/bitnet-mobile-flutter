import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/app_theme.dart';
import 'constants/app_colors.dart';
import 'screens/main_shell.dart';
import 'state/bitnet_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surfaceContainer,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const BitNetApp());
}

class BitNetApp extends StatefulWidget {
  const BitNetApp({super.key});

  @override
  State<BitNetApp> createState() => _BitNetAppState();
}

class _BitNetAppState extends State<BitNetApp> {
  final BitNetState _bitNetState = BitNetState();

  @override
  void dispose() {
    _bitNetState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitNet AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainShell(state: _bitNetState),
    );
  }
}
