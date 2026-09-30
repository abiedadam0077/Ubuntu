import 'enums.dart';

/// مرجع لطرف مكون معين (يُستخدم كنقطة بداية/نهاية للسلك)
class TerminalRef {
  final String componentId;
  final String terminalId;

  const TerminalRef({required this.componentId, required this.terminalId});

  Map<String, dynamic> toJson() => {
        'componentId': componentId,
        'terminalId': terminalId,
      };

  factory TerminalRef.fromJson(Map<String, dynamic> json) => TerminalRef(
        componentId: json['componentId'] as String,
        terminalId: json['terminalId'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is TerminalRef &&
      other.componentId == componentId &&
      other.terminalId == terminalId;

  @override
  int get hashCode => Object.hash(componentId, terminalId);

  @override
  String toString() => '$componentId.$terminalId';
}

/// سلك يصل بين طرفين، مع خصائصه الفيزيائية (نوع، مقطع، لون)
class WireModel {
  final String id;
  final TerminalRef from;
  final TerminalRef to;
  TerminalKind kind;
  double crossSectionMm2; // مقطع السلك بالمليمتر المربع
  int colorValue; // ARGB
  bool selected;

  WireModel({
    required this.id,
    required this.from,
    required this.to,
    this.kind = TerminalKind.generic,
    this.crossSectionMm2 = 1.5,
    required this.colorValue,
    this.selected = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from.toJson(),
        'to': to.toJson(),
        'kind': kind.index,
        'crossSection': crossSectionMm2,
        'color': colorValue,
      };

  factory WireModel.fromJson(Map<String, dynamic> json) => WireModel(
        id: json['id'] as String,
        from: TerminalRef.fromJson(json['from'] as Map<String, dynamic>),
        to: TerminalRef.fromJson(json['to'] as Map<String, dynamic>),
        kind: TerminalKind.values[json['kind'] as int? ?? 0],
        crossSectionMm2: (json['crossSection'] as num?)?.toDouble() ?? 1.5,
        colorValue: json['color'] as int? ?? 0xFFFFFFFF,
      );
}
