import 'dart:ui';

/// نسخة فعلية من مكون تم وضعها على لوحة الرسم (Canvas)
class ComponentInstance {
  final String id; // معرف فريد للنسخة (uuid)
  final String typeId; // يشير إلى ComponentDefinition.id
  Offset position; // مركز المكون على اللوحة
  double rotation; // بالراديان (0, pi/2, pi, 3pi/2 غالباً)
  bool locked;
  bool selected;
  String? customName;

  /// خصائص قابلة للتعديل لكل نسخة (مثال: قيمة مقاومة، جهد مصدر، تيار مقنن قاطع...)
  Map<String, double> properties;

  /// روابط مرجعية بمكونات أخرى بالمعرف (مثال: ربط تلامس مساعد بملف كونتاكتور)
  Map<String, String> links;

  /// حالة ديناميكية تُحسب أثناء المحاكاة (لا تُحفظ ضمن ملف المشروع الدائم إجبارياً
  /// لكن يمكن حفظها لاستعادة آخر حالة)
  Map<String, dynamic> runtimeState;

  ComponentInstance({
    required this.id,
    required this.typeId,
    required this.position,
    this.rotation = 0,
    this.locked = false,
    this.selected = false,
    this.customName,
    Map<String, double>? properties,
    Map<String, String>? links,
    Map<String, dynamic>? runtimeState,
  })  : properties = properties ?? {},
        links = links ?? {},
        runtimeState = runtimeState ?? {};

  ComponentInstance copyWith({
    Offset? position,
    double? rotation,
    bool? locked,
    bool? selected,
  }) {
    return ComponentInstance(
      id: id,
      typeId: typeId,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      locked: locked ?? this.locked,
      selected: selected ?? this.selected,
      customName: customName,
      properties: Map<String, double>.from(properties),
      links: Map<String, String>.from(links),
      runtimeState: Map<String, dynamic>.from(runtimeState),
    );
  }

  ComponentInstance clone({String? newId}) {
    return ComponentInstance(
      id: newId ?? id,
      typeId: typeId,
      position: position,
      rotation: rotation,
      locked: false,
      selected: false,
      customName: customName,
      properties: Map<String, double>.from(properties),
      links: Map<String, String>.from(links),
      runtimeState: {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'typeId': typeId,
        'x': position.dx,
        'y': position.dy,
        'rotation': rotation,
        'locked': locked,
        'customName': customName,
        'properties': properties,
        'links': links,
      };

  factory ComponentInstance.fromJson(Map<String, dynamic> json) {
    return ComponentInstance(
      id: json['id'] as String,
      typeId: json['typeId'] as String,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      locked: json['locked'] as bool? ?? false,
      customName: json['customName'] as String?,
      properties: (json['properties'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ) ??
          {},
      links: (json['links'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as String),
          ) ??
          {},
    );
  }
}
