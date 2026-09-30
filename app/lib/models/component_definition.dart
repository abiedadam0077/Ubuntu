import 'dart:ui';
import 'enums.dart';

/// تعريف طرف كهربائي ضمن المكون (نقطة توصيل)
class TerminalDef {
  final String id;
  final String label;
  final TerminalKind kind;

  /// موضع الطرف نسبةً لصندوق المكون (0..1 على العرض والارتفاع)
  final Offset anchor;

  const TerminalDef({
    required this.id,
    required this.label,
    required this.kind,
    required this.anchor,
  });
}

/// تعريف "نوع" مكون كهربائي (Blueprint) — لا يمثّل نسخة موضوعة في اللوحة،
/// بل القالب الذي تُبنى منه النسخ (ComponentInstance).
///
/// إضافة عنصر جديد للمكتبة = إضافة عنصر جديد في القائمة داخل component_catalog.dart
/// دون الحاجة لتعديل أي كود آخر في التطبيق (نظام Modular/Data-Driven).
class ComponentDefinition {
  final String id; // معرف فريد للنوع، مثال: 'breaker_mcb'
  final String nameAr;
  final String nameEn;
  final ComponentCategory category;
  final BehaviorKind behavior;
  final List<TerminalDef> terminals;
  final Size defaultSize;

  /// خصائص افتراضية قابلة للتعديل من المستخدم (جهد، تيار مقنن، مقاومة...)
  final Map<String, double> defaultProperties;

  /// مفتاح رسم مخصص (لو غير موجود سيُستخدم رسم عام Generic)
  final String? realisticPainterKey;
  final String? symbolPainterKey;

  final String description;

  const ComponentDefinition({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    required this.behavior,
    required this.terminals,
    this.defaultSize = const Size(80, 80),
    this.defaultProperties = const {},
    this.realisticPainterKey,
    this.symbolPainterKey,
    this.description = '',
  });
}
