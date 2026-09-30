import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'state/app_settings.dart';
import 'state/projects_repository.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    _installFriendlyErrorWidget();
    // نسجّل أي خطأ غير متوقع بدل تجاهله بصمت (يساعد مستقبلاً في التشخيص عن بعد)
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    runApp(const ElectroSimApp());
  }, (error, stack) {
    debugPrint('Unhandled zone error: $error\n$stack');
  });
}

/// يستبدل شاشة الخطأ الرمادية الافتراضية في وضع Release (التي لا تعرض أي نص
/// ويمكن أن تبدو للمستخدم وكأن التطبيق "عالق") بواجهة داكنة واضحة تخبره أن
/// جزءاً من الواجهة واجه خطأً، بدل شاشة رمادية/بيضاء صامتة بدون تفسير.
void _installFriendlyErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: AppColors.bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
          const SizedBox(height: 12),
          const Text(
            'حدث خطأ غير متوقع في هذا الجزء من الواجهة',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            Text(
              details.exceptionAsString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  };
}

class ElectroSimApp extends StatefulWidget {
  /// قابلان للحقن لأغراض الاختبار الآلي (widget tests)؛ في الاستخدام الفعلي
  /// للتطبيق تُترك فارغة فيُنشئ التطبيق نسخته الحقيقية تلقائياً.
  final AppSettings? settings;
  final ProjectsRepository? repository;

  const ElectroSimApp({super.key, this.settings, this.repository});

  @override
  State<ElectroSimApp> createState() => _ElectroSimAppState();
}

class _ElectroSimAppState extends State<ElectroSimApp> {
  late final AppSettings settings = widget.settings ?? AppSettings();
  late final ProjectsRepository repository = widget.repository ?? ProjectsRepository();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// يحمّل إعدادات المستخدم المحفوظة محلياً. إذا تعطّل التحميل لأي سبب
  /// (مساحة تخزين، صلاحيات، إلخ) أو تأخر كثيراً، ننتقل للشاشة الرئيسية
  /// بالقيم الافتراضية بدل ترك المستخدم عالقاً إلى الأبد على شاشة التحميل.
  Future<void> _bootstrap() async {
    try {
      await settings.load().timeout(const Duration(seconds: 6));
    } catch (e, st) {
      debugPrint('تعذّر تحميل الإعدادات، سيُتابَع بالقيم الافتراضية: $e\n$st');
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
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
      // بدون هذه الأسطر الثلاثة، ضبط locale على 'ar' كان يفشل بصمت في كل
      // مكان يحتاج MaterialLocalizations (أهمها: أي showDialog/
      // showModalBottomSheet يحسب barrierLabel الافتراضي فوراً عبر
      // MaterialLocalizations.of(context) قبل حتى بناء المحتوى) — وهذا هو
      // السبب الجذري الأرجح لعدم استجابة أزرار مثل "مشروع جديد +" ولظهور
      // شاشة/عنصر رمادي بدل الواجهة الحقيقية.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
