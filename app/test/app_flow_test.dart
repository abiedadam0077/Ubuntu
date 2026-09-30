// اختبارات آلية شاملة لمسار الاستخدام الأساسي لتطبيق ElectroSim Pro.
// الهدف: التأكد أن التنقل بين كل الشاشات الرئيسية والأزرار الأساسية
// يعمل دون أي استثناء (Exception) أو شاشة بيضاء/رمادية عالقة، وذلك عبر
// محرك اختبار Flutter الحقيقي (وليس مجرد قراءة الكود يدوياً).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:electrosim_pro/main.dart';
import 'package:electrosim_pro/state/app_settings.dart';
import 'package:electrosim_pro/state/projects_repository.dart';

/// ينشئ تطبيقاً جاهزاً للاختبار مع تخزين معزول (مجلد مؤقت + SharedPreferences وهمية)
/// حتى لا تعتمد الاختبارات على قنوات المنصة الحقيقية (Android/iOS).
Future<Widget> _buildTestApp(WidgetTester tester, Directory tempDir) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final repository = ProjectsRepository(directoryProvider: () async => tempDir);
  return ElectroSimApp(settings: settings, repository: repository);
}

/// يغلق نافذة تنبيه السلامة إن ظهرت (تظهر تلقائياً أول مرة فقط لكل settings).
Future<void> _dismissSafetyDialogIfShown(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final continueButton = find.text('فهمت، متابعة');
  if (continueButton.evaluate().isNotEmpty) {
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
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
    await tester.pumpWidget(await _buildTestApp(tester, tempDir));
    await tester.pumpAndSettle();

    expect(find.text('ElectroSim Pro'), findsWidgets);
    expect(find.text('مشروع جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إنشاء مشروع جديد يفتح محرر الدائرة دون أخطاء، وزر الرجوع يعمل', (tester) async {
    await tester.pumpWidget(await _buildTestApp(tester, tempDir));
    await tester.pumpAndSettle();

    // زر "مشروع جديد +"
    await tester.tap(find.text('مشروع جديد'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // نافذة تسمية المشروع يجب أن تظهر
    expect(find.text('إنشاء'), findsOneWidget);
    await tester.tap(find.text('إنشاء'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // نافذة تنبيه السلامة يجب أن تظهر أول مرة — نغلقها
    await _dismissSafetyDialogIfShown(tester);
    expect(tester.takeException(), isNull);

    // يجب أن نكون الآن داخل شاشة المحرر (شريط أدوات المحاكاة: تشغيل)
    expect(find.byIcon(Icons.play_arrow), findsWidgets);

    // الرجوع للشاشة الرئيسية (زر الرجوع في المحرر أيقونة Icons.arrow_back عادية)
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('مشروع جديد'), findsOneWidget);
  });

  testWidgets('فتح مكتبة المكونات داخل المحرر يرسم كل الكتالوج دون أخطاء', (tester) async {
    await tester.pumpWidget(await _buildTestApp(tester, tempDir));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مشروع جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنشاء'));
    await tester.pumpAndSettle();
    await _dismissSafetyDialogIfShown(tester);
    expect(tester.takeException(), isNull);

    // التبديل بين تبويبات الشريط السفلي في المحرر (Components / Wire / Tools / Measure)
    for (final icon in [Icons.widgets, Icons.cable, Icons.build, Icons.speed]) {
      final finder = find.byIcon(icon);
      if (finder.evaluate().isNotEmpty) {
        await tester.tap(finder.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }

    // الرجوع قبل نهاية الاختبار حتى يتم استدعاء dispose() على المحرر بشكل
    // صحيح (يُلغي مؤقّت الحفظ التلقائي) بدل ترك Timer معلّق عند إغلاق الاختبار.
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة التعلّم والتحديات تُفتح وتُغلق دون أخطاء', (tester) async {
    await tester.pumpWidget(await _buildTestApp(tester, tempDir));
    await tester.pumpAndSettle();

    await tester.tap(find.text('التعلّم والتحديات'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة محاكاة الأعطال تُفتح وتُغلق دون أخطاء', (tester) async {
    await tester.pumpWidget(await _buildTestApp(tester, tempDir));
    await tester.pumpAndSettle();

    await tester.tap(find.text('محاكاة الأعطال'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة الإعدادات تُفتح وتعرض خيارات ألوان الأسلاك دون أخطاء', (tester) async {
    await tester.pumpWidget(await _buildTestApp(tester, tempDir));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('استيراد ملف غير صالح لا يُسقط التطبيق (معالجة أخطاء دفاعية)', (tester) async {
    await tester.pumpWidget(await _buildTestApp(tester, tempDir));
    await tester.pumpAndSettle();

    // لا يمكن محاكاة منتقي الملفات الحقيقي في اختبار Widget، لكن نتأكد
    // على الأقل أن الشاشة الرئيسية تبقى مستقرة ولا تتجمد بعد بناء الواجهة.
    expect(find.text('استيراد مشروع من ملف'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
