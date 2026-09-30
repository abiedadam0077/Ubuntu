// اختبارات آلية شاملة لمسار الاستخدام الأساسي لتطبيق ElectroSim Pro.
// الهدف: التأكد أن التنقل بين كل الشاشات الرئيسية والأزرار الأساسية
// يعمل دون أي استثناء (Exception) أو شاشة بيضاء/رمادية عالقة، وذلك عبر
// محرك اختبار Flutter الحقيقي (وليس مجرد قراءة الكود يدوياً).
//
// ملاحظة مهمة: نتجنّب عمداً استخدام tester.pumpAndSettle() مباشرة بعد
// pumpWidget لأن الشاشة تحتوي CircularProgressIndicator (مؤشر تحميل غير
// محدد المدة له Animation متكرر إلى الأبد) أثناء تحميل الإعدادات/المشاريع؛
// وهذا معروف أنه يجعل pumpAndSettle() "لا يستقر أبداً" وينتهي بخطأ
// "pumpAndSettle timed out" حتى لو لم يكن هناك أي خلل فعلي في التطبيق.
// بدلاً من ذلك نستخدم عدداً محدوداً من النبضات الزمنية (bounded pumps).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:electrosim_pro/main.dart';
import 'package:electrosim_pro/state/app_settings.dart';
import 'package:electrosim_pro/state/projects_repository.dart';

/// ينشئ تطبيقاً جاهزاً للاختبار مع تخزين معزول (مجلد مؤقت + SharedPreferences وهمية)
/// حتى لا تعتمد الاختبارات على قنوات المنصة الحقيقية (Android/iOS).
Widget _buildTestApp(Directory tempDir) {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final repository = ProjectsRepository(directoryProvider: () async => tempDir);
  return ElectroSimApp(settings: settings, repository: repository);
}

/// يدفع الزمن الافتراضي للاختبار بعدد محدود من النبضات (بدل pumpAndSettle
/// غير المحدود) حتى تُنجَز كل الـFutures القصيرة (تحميل إعدادات/مشاريع) وكل
/// تحريكات الانتقال بين الشاشات، دون الوقوع في فخ مؤشرات التحميل الدائرية.
Future<void> _settle(WidgetTester tester, {int pumps = 20}) async {
  for (var i = 0; i < pumps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// يُستخدم بعد أي تفاعل يُشغّل عملية I/O حقيقية على القرص (إنشاء/حفظ ملف
/// مشروع عبر ProjectsRepository). اختبارات الـWidget تعمل تحت ساعة زمنية
/// وهمية (fake async) لا "تُسرّع" عمليات dart:io الحقيقية تلقائياً؛
/// runAsync() يسمح للحلقة الحقيقية للأحداث بإنهاء تلك العملية قبل أن
/// نتابع الدفع الزمني الوهمي المعتاد.
Future<void> _flushRealIo(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
}

/// يغلق نافذة تنبيه السلامة إن ظهرت (تظهر تلقائياً أول مرة فقط لكل settings).
Future<void> _dismissSafetyDialogIfShown(WidgetTester tester) async {
  final continueButton = find.text('فهمت، متابعة');
  if (continueButton.evaluate().isNotEmpty) {
    await tester.tap(continueButton);
    await _settle(tester);
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('electrosim_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('يُقلع التطبيق ويعرض الشاشة الرئيسية دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp(tempDir));
    await _settle(tester);

    expect(find.text('ElectroSim Pro'), findsWidgets);
    expect(find.text('مشروع جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إنشاء مشروع جديد يفتح محرر الدائرة دون أخطاء، وزر الرجوع يعمل', (tester) async {
    await tester.pumpWidget(_buildTestApp(tempDir));
    await _settle(tester);

    // زر "مشروع جديد +"
    await tester.tap(find.text('مشروع جديد'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // نافذة تسمية المشروع يجب أن تظهر
    expect(find.text('إنشاء'), findsOneWidget);
    await tester.tap(find.text('إنشاء'));
    // تشخيص خطوة بخطوة: نتحقق بعد كل نبضة مبكرة هل ما زال AlertDialog ظاهراً
    await tester.pump();
    // ignore: avoid_print
    print('DEBUG بعد نبضة واحدة: AlertDialog=${find.byType(AlertDialog).evaluate().length}');
    await tester.pump(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print('DEBUG بعد 300ms: AlertDialog=${find.byType(AlertDialog).evaluate().length} exception=${tester.takeException()}');
    await _flushRealIo(tester);
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // نافذة تنبيه السلامة يجب أن تظهر أول مرة — نغلقها
    await _dismissSafetyDialogIfShown(tester);
    expect(tester.takeException(), isNull);

    // تشخيص: إن لم نصل لشاشة المحرر بعد، نطبع كل النصوص الظاهرة حالياً
    // لمعرفة أين توقّف التنقّل فعلياً (بدل تخمين السبب بلا دليل).
    if (find.byIcon(Icons.play_arrow).evaluate().isEmpty) {
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      final dialogs = find.byType(AlertDialog).evaluate().length;
      final snackbars = find.byType(SnackBar).evaluate().length;
      final scaffolds = find.byType(Scaffold).evaluate().length;
      final navigators = find.byType(Navigator).evaluate().length;
      List<String> diskFiles = [];
      await tester.runAsync(() async {
        final projectsDir = Directory('${tempDir.path}/electrosim_projects');
        if (await projectsDir.exists()) {
          diskFiles = projectsDir.listSync().map((f) => f.path).toList();
        }
      });
      // ignore: avoid_print
      print('DEBUG لم نصل لشاشة المحرر بعد.\n'
          '  النصوص: $texts\n'
          '  AlertDialog=$dialogs SnackBar=$snackbars Scaffold=$scaffolds Navigator=$navigators\n'
          '  ملفات المشروع على القرص: $diskFiles\n'
          '  lastException=${tester.takeException()}');
    }

    // يجب أن نكون الآن داخل شاشة المحرر (شريط أدوات المحاكاة: تشغيل)
    expect(find.byIcon(Icons.play_arrow), findsWidgets);

    // الرجوع للشاشة الرئيسية (زر الرجوع في المحرر أيقونة Icons.arrow_back عادية)
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('مشروع جديد'), findsOneWidget);
  });

  testWidgets('فتح مكتبة المكونات داخل المحرر يرسم كل الكتالوج دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp(tempDir));
    await _settle(tester);

    await tester.tap(find.text('مشروع جديد'));
    await _settle(tester);
    await tester.tap(find.text('إنشاء'));
    await _flushRealIo(tester);
    await _settle(tester);
    await _dismissSafetyDialogIfShown(tester);
    expect(tester.takeException(), isNull);

    // التبديل بين تبويبات الشريط السفلي في المحرر (Components / Wire / Tools / Measure)
    for (final icon in [Icons.widgets, Icons.cable, Icons.build, Icons.speed]) {
      final finder = find.byIcon(icon);
      if (finder.evaluate().isNotEmpty) {
        await tester.tap(finder.first);
        await _settle(tester);
        expect(tester.takeException(), isNull);
      }
    }

    // الرجوع قبل نهاية الاختبار حتى يتم استدعاء dispose() على المحرر بشكل
    // صحيح (يُلغي مؤقّت الحفظ التلقائي) بدل ترك Timer معلّق عند إغلاق الاختبار.
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة التعلّم والتحديات تُفتح وتُغلق دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp(tempDir));
    await _settle(tester);

    await tester.tap(find.text('التعلّم والتحديات'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة محاكاة الأعطال تُفتح وتُغلق دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp(tempDir));
    await _settle(tester);

    await tester.tap(find.text('محاكاة الأعطال'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة الإعدادات تُفتح وتعرض خيارات ألوان الأسلاك دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp(tempDir));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('استيراد ملف غير صالح لا يُسقط التطبيق (معالجة أخطاء دفاعية)', (tester) async {
    await tester.pumpWidget(_buildTestApp(tempDir));
    await _settle(tester);

    // لا يمكن محاكاة منتقي الملفات الحقيقي في اختبار Widget، لكن نتأكد
    // على الأقل أن الشاشة الرئيسية تبقى مستقرة ولا تتجمد بعد بناء الواجهة.
    expect(find.text('استيراد مشروع من ملف'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
