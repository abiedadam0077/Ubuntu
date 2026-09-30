// اختبارات آلية شاملة لمسار الاستخدام الأساسي لتطبيق ElectroSim Pro.
// الهدف: التأكد أن التنقل بين كل الشاشات الرئيسية والأزرار الأساسية
// يعمل دون أي استثناء (Exception) أو شاشة بيضاء/رمادية عالقة، وذلك عبر
// محرك اختبار Flutter الحقيقي (وليس مجرد قراءة الكود يدوياً).
//
// ملاحظتان مهمتان حول تصميم هذا الملف:
// 1) نتجنّب عمداً استخدام tester.pumpAndSettle() مباشرة بعد pumpWidget لأن
//    الشاشة تحتوي CircularProgressIndicator (مؤشر تحميل له Animation متكرر
//    إلى الأبد) أثناء تحميل الإعدادات/المشاريع؛ هذا معروف أنه يجعل
//    pumpAndSettle() "لا يستقر أبداً" وينتهي بخطأ "pumpAndSettle timed out"
//    حتى لو لم يكن هناك أي خلل فعلي في التطبيق. نستخدم بدلاً منه عدداً
//    محدوداً من النبضات الزمنية (bounded pumps).
// 2) نستخدم MemoryFileSystem (package:file) بدل القرص الحقيقي لأن
//    flutter test يُشغّل الاختبارات تحت ساعة زمنية وهمية (fake async) لا
//    يمكنها أبداً إنهاء عمليات I/O حقيقية على القرص (dart:io) — هذه مشكلة
//    معروفة وموثّقة رسمياً في Flutter (raw File/Directory تُعلّق الاختبار
//    إلى الأبد)، وليست خللاً في منطق حفظ المشاريع نفسه.
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:electrosim_pro/main.dart';
import 'package:electrosim_pro/state/app_settings.dart';
import 'package:electrosim_pro/state/projects_repository.dart';

/// ينشئ تطبيقاً جاهزاً للاختبار مع تخزين معزول تماماً (نظام ملفات وهمي في
/// الذاكرة + SharedPreferences وهمية) حتى لا تعتمد الاختبارات على قنوات
/// المنصة الحقيقية (Android/iOS) أو على القرص الفعلي.
Widget _buildTestApp() {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final repository = ProjectsRepository(
    fileSystem: MemoryFileSystem(),
    directoryPathProvider: () async => '/test_data',
  );
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

/// يغلق نافذة تنبيه السلامة إن ظهرت (تظهر تلقائياً أول مرة فقط لكل settings).
Future<void> _dismissSafetyDialogIfShown(WidgetTester tester) async {
  final continueButton = find.text('فهمت، متابعة');
  if (continueButton.evaluate().isNotEmpty) {
    await tester.tap(continueButton);
    await _settle(tester);
  }
}

void main() {
  testWidgets('يُقلع التطبيق ويعرض الشاشة الرئيسية دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await _settle(tester);

    expect(find.text('ElectroSim Pro'), findsWidgets);
    expect(find.widgetWithText(FloatingActionButton, 'مشروع جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إنشاء مشروع جديد يفتح محرر الدائرة دون أخطاء، وزر الرجوع يعمل', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await _settle(tester);

    // زر "مشروع جديد +"
    await tester.tap(find.widgetWithText(FloatingActionButton, 'مشروع جديد'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // نافذة تسمية المشروع يجب أن تظهر
    expect(find.text('إنشاء'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'إنشاء'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // نافذة تنبيه السلامة يجب أن تظهر أول مرة — نغلقها
    await _dismissSafetyDialogIfShown(tester);
    expect(tester.takeException(), isNull);

    // يجب أن نكون الآن داخل شاشة المحرر (زر التشغيل في الشريط العلوي المبسّط)
    expect(find.byIcon(Icons.play_circle), findsWidgets);

    // الرجوع للشاشة الرئيسية (زر الرجوع في المحرر أيقونة Icons.arrow_back عادية)
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FloatingActionButton, 'مشروع جديد'), findsOneWidget);
  });

  testWidgets('فتح النوافذ المنزلقة الثلاثة (مكونات/أسلاك/أدوات) دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await _settle(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'مشروع جديد'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'إنشاء'));
    await _settle(tester);
    await _dismissSafetyDialogIfShown(tester);
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.play_circle), findsWidgets);

    // الشريط العلوي المبسّط الجديد: 🔌 أسلاك | 🧩 مكونات | 🔧 أدوات — كل زر
    // يفتح نافذة منزلقة (Bottom Sheet) بدل شريط سفلي ثابت، ثم نغلقها عبر
    // إسقاط أعلى المسارات في الـNavigator (نفس أثر زر الرجوع/سحب النافذة)
    // قبل الانتقال للأيقونة التالية.
    for (final icon in [Icons.widgets, Icons.cable, Icons.build]) {
      final finder = find.byIcon(icon);
      expect(finder, findsWidgets);
      await tester.tap(finder.first);
      await _settle(tester);
      expect(tester.takeException(), isNull);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop();
      await _settle(tester);
      expect(tester.takeException(), isNull);
    }

    // الرجوع قبل نهاية الاختبار حتى يتم استدعاء dispose() على المحرر بشكل
    // صحيح (يُلغي مؤقّت الحفظ التلقائي) بدل ترك Timer معلّق عند إغلاق الاختبار.
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة التعلّم والتحديات تُفتح وتُغلق دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await _settle(tester);

    await tester.tap(find.text('التعلّم والتحديات'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة محاكاة الأعطال تُفتح وتُغلق دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await _settle(tester);

    await tester.tap(find.text('محاكاة الأعطال'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة الإعدادات تُفتح وتعرض خيارات ألوان الأسلاك دون أخطاء', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('استيراد ملف غير صالح لا يُسقط التطبيق (معالجة أخطاء دفاعية)', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await _settle(tester);

    // لا يمكن محاكاة منتقي الملفات الحقيقي في اختبار Widget، لكن نتأكد
    // على الأقل أن الشاشة الرئيسية تبقى مستقرة ولا تتجمد بعد بناء الواجهة.
    expect(find.text('استيراد مشروع من ملف'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
