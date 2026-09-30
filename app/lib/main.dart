import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'state/app_settings.dart';
import 'state/projects_repository.dart';
import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElectroSimApp());
}

class ElectroSimApp extends StatefulWidget {
  const ElectroSimApp({super.key});

  @override
  State<ElectroSimApp> createState() => _ElectroSimAppState();
}

class _ElectroSimAppState extends State<ElectroSimApp> {
  final AppSettings settings = AppSettings();
  final ProjectsRepository repository = ProjectsRepository();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    settings.load().then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElectroSim Pro',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: !_loaded
          ? const _SplashScreen()
          : HomeScreen(settings: settings, repository: repository),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 18),
            const Text('ElectroSim Pro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
