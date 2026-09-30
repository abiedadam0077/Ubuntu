// ملاحظة: هذا الملف موجود فقط لمنع "flutter create" (الذي يُشغَّل تلقائياً
// في CI لتوليد مجلد android/) من إعادة توليد نسخة افتراضية منه تشير لكلاس
// "MyApp" غير الموجود في هذا المشروع (ما كان يُسبب فشل تجميع كل الاختبارات).
// الاختبارات الحقيقية والشاملة موجودة في app_flow_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:electrosim_pro/main.dart';

void main() {
  testWidgets('smoke test: التطبيق يُبنى دون رمي استثناء عند الإقلاع', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ElectroSimApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
