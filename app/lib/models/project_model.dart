import 'component_instance.dart';
import 'wire_model.dart';

/// مشروع محاكاة كامل: المكونات + الأسلاك + الإعدادات + بيانات وصفية
class ProjectModel {
  String id;
  String name;
  DateTime createdAt;
  DateTime updatedAt;
  List<ComponentInstance> components;
  List<WireModel> wires;

  /// إعدادات عامة للمشروع (وضع واقعي/رمزي، شبكة، تكبير محفوظ...)
  bool realisticMode;
  double gridSize;
  double zoom;

  ProjectModel({
    required this.id,
    required this.name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ComponentInstance>? components,
    List<WireModel>? wires,
    this.realisticMode = true,
    this.gridSize = 20,
    this.zoom = 1.0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        components = components ?? [],
        wires = wires ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'realisticMode': realisticMode,
        'gridSize': gridSize,
        'zoom': zoom,
        'components': components.map((c) => c.toJson()).toList(),
        'wires': wires.map((w) => w.toJson()).toList(),
        'formatVersion': 1,
        'app': 'ElectroSim Pro',
      };

  factory ProjectModel.fromJson(Map<String, dynamic> json) => ProjectModel(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        realisticMode: json['realisticMode'] as bool? ?? true,
        gridSize: (json['gridSize'] as num?)?.toDouble() ?? 20,
        zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
        components: (json['components'] as List? ?? [])
            .map((e) => ComponentInstance.fromJson(e as Map<String, dynamic>))
            .toList(),
        wires: (json['wires'] as List? ?? [])
            .map((e) => WireModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  ProjectModel deepCopy({String? newId, String? newName}) {
    final p = ProjectModel.fromJson(toJson());
    if (newId != null) p.id = newId;
    if (newName != null) p.name = newName;
    return p;
  }
}
