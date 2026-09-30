import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/component_catalog.dart';
import '../models/component_instance.dart';
import '../models/enums.dart';
import '../models/project_model.dart';
import '../models/wire_model.dart';

const _uuid = Uuid();

/// لون افتراضي لكل نوع طرف (يمكن تخصيصه من الإعدادات لاحقاً)
Map<TerminalKind, Color> defaultWireColors = {
  TerminalKind.phase: const Color(0xFFE53935), // أحمر
  TerminalKind.neutral: const Color(0xFF1E88E5), // أزرق
  TerminalKind.ground: const Color(0xFF43A047), // أخضر/أصفر
  TerminalKind.dcPlus: const Color(0xFFE53935),
  TerminalKind.dcMinus: const Color(0xFF212121),
  TerminalKind.control: const Color(0xFFFB8C00), // برتقالي
  TerminalKind.generic: const Color(0xFF9E9E9E),
};

/// وحدة التحكم الرئيسية بالمشروع الحالي: إضافة/حذف/تحريك المكونات والأسلاك
/// + التراجع/الإعادة + الحفظ. هذا هو "مصدر الحقيقة" الذي تستمع له الواجهة بأكملها.
class ProjectController extends ChangeNotifier {
  ProjectModel project;
  final Set<String> selectedComponentIds = {};
  String? selectedWireId;
  String? pendingWireFrom; // (componentId.terminalId) عند بدء سحب سلك جديد

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _dirty = false;
  bool get isDirty => _dirty;

  ProjectController(this.project);

  void _pushUndo() {
    _undoStack.add(jsonEncode(project.toJson()));
    if (_undoStack.length > 60) _undoStack.removeAt(0);
    _redoStack.clear();
    _dirty = true;
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(jsonEncode(project.toJson()));
    final snapshot = _undoStack.removeLast();
    project = ProjectModel.fromJson(jsonDecode(snapshot) as Map<String, dynamic>);
    selectedComponentIds.clear();
    selectedWireId = null;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(jsonEncode(project.toJson()));
    final snapshot = _redoStack.removeLast();
    project = ProjectModel.fromJson(jsonDecode(snapshot) as Map<String, dynamic>);
    selectedComponentIds.clear();
    selectedWireId = null;
    notifyListeners();
  }

  void markSaved() {
    _dirty = false;
  }

  // ===================== المكونات =====================
  ComponentInstance addComponent(String typeId, Offset position) {
    _pushUndo();
    final def = componentCatalogById[typeId]!;
    final comp = ComponentInstance(
      id: _uuid.v4(),
      typeId: typeId,
      position: position,
      properties: Map<String, double>.from(def.defaultProperties),
    );
    project.components.add(comp);
    project.updatedAt = DateTime.now();
    notifyListeners();
    return comp;
  }

  void moveComponent(String id, Offset newPosition, {bool recordUndo = true}) {
    final comp = _findComponent(id);
    if (comp == null || comp.locked) return;
    if (recordUndo) _pushUndo();
    comp.position = newPosition;
    notifyListeners();
  }

  void rotateSelected() {
    if (selectedComponentIds.isEmpty) return;
    _pushUndo();
    for (final id in selectedComponentIds) {
      final comp = _findComponent(id);
      if (comp == null || comp.locked) continue;
      comp.rotation = (comp.rotation + math.pi / 2) % (math.pi * 2);
    }
    notifyListeners();
  }

  void deleteSelected() {
    if (selectedComponentIds.isEmpty && selectedWireId == null) return;
    _pushUndo();
    project.wires.removeWhere((w) =>
        selectedComponentIds.contains(w.from.componentId) ||
        selectedComponentIds.contains(w.to.componentId) ||
        w.id == selectedWireId);
    project.components.removeWhere((c) => selectedComponentIds.contains(c.id));
    selectedComponentIds.clear();
    selectedWireId = null;
    notifyListeners();
  }

  void duplicateSelected() {
    if (selectedComponentIds.isEmpty) return;
    _pushUndo();
    final newIds = <String>{};
    for (final id in selectedComponentIds) {
      final comp = _findComponent(id);
      if (comp == null) continue;
      final clone = comp.clone(newId: _uuid.v4());
      clone.position = comp.position + const Offset(30, 30);
      project.components.add(clone);
      newIds.add(clone.id);
    }
    selectedComponentIds
      ..clear()
      ..addAll(newIds);
    notifyListeners();
  }

  final List<ComponentInstance> _clipboard = [];

  void copySelected() {
    _clipboard
      ..clear()
      ..addAll(selectedComponentIds.map((id) => _findComponent(id)).whereType<ComponentInstance>());
  }

  void pasteClipboard() {
    if (_clipboard.isEmpty) return;
    _pushUndo();
    final newIds = <String>{};
    for (final comp in _clipboard) {
      final clone = comp.clone(newId: _uuid.v4());
      clone.position = comp.position + const Offset(40, 40);
      project.components.add(clone);
      newIds.add(clone.id);
    }
    selectedComponentIds
      ..clear()
      ..addAll(newIds);
    notifyListeners();
  }

  void toggleLockSelected() {
    _pushUndo();
    for (final id in selectedComponentIds) {
      final comp = _findComponent(id);
      if (comp != null) comp.locked = !comp.locked;
    }
    notifyListeners();
  }

  void renameComponent(String id, String name) {
    final comp = _findComponent(id);
    if (comp == null) return;
    _pushUndo();
    comp.customName = name;
    notifyListeners();
  }

  void updateComponentProperty(String id, String key, double value) {
    final comp = _findComponent(id);
    if (comp == null) return;
    _pushUndo();
    comp.properties[key] = value;
    notifyListeners();
  }

  void linkComponent(String id, String linkKey, String targetId) {
    final comp = _findComponent(id);
    if (comp == null) return;
    _pushUndo();
    comp.links[linkKey] = targetId;
    notifyListeners();
  }

  /// تبديل حالة مفتاح/زر يدوي أثناء المحاكاة (بدون تسجيل Undo حتى لا تمتلئ الذاكرة)
  void toggleManualState(String id, String key) {
    final comp = _findComponent(id);
    if (comp == null) return;
    final current = (comp.runtimeState[key] as bool?) ?? false;
    comp.runtimeState[key] = !current;
    notifyListeners();
  }

  void setManualState(String id, String key, dynamic value) {
    final comp = _findComponent(id);
    if (comp == null) return;
    comp.runtimeState[key] = value;
    notifyListeners();
  }

  void setPressed(String id, bool pressed) {
    final comp = _findComponent(id);
    if (comp == null) return;
    comp.runtimeState['pressed'] = pressed;
    notifyListeners();
  }

  ComponentInstance? _findComponent(String id) {
    for (final c in project.components) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ===================== التحديد =====================
  void selectOnly(String id) {
    selectedComponentIds
      ..clear()
      ..add(id);
    selectedWireId = null;
    notifyListeners();
  }

  void toggleSelect(String id) {
    if (selectedComponentIds.contains(id)) {
      selectedComponentIds.remove(id);
    } else {
      selectedComponentIds.add(id);
    }
    notifyListeners();
  }

  void selectWire(String id) {
    selectedWireId = id;
    selectedComponentIds.clear();
    notifyListeners();
  }

  void clearSelection() {
    selectedComponentIds.clear();
    selectedWireId = null;
    notifyListeners();
  }

  // ===================== الأسلاك =====================
  String? startWireFrom(String componentId, String terminalId) {
    pendingWireFrom = '$componentId.$terminalId';
    notifyListeners();
    return pendingWireFrom;
  }

  void cancelWire() {
    pendingWireFrom = null;
    notifyListeners();
  }

  String? finishWireTo(String componentId, String terminalId) {
    if (pendingWireFrom == null) return null;
    final parts = pendingWireFrom!.split('.');
    final fromComp = parts[0];
    final fromTerm = parts.sublist(1).join('.');
    pendingWireFrom = null;

    if (fromComp == componentId && fromTerm == terminalId) {
      notifyListeners();
      return null; // نفس الطرف
    }

    final fromDef = componentCatalogById[_findComponent(fromComp)?.typeId ?? ''];
    final toDef = componentCatalogById[_findComponent(componentId)?.typeId ?? ''];
    TerminalKind kind = TerminalKind.generic;
    if (fromDef != null) {
      final t = fromDef.terminals.where((t) => t.id == fromTerm);
      if (t.isNotEmpty) kind = t.first.kind;
    }
    String? warning;
    if (toDef != null) {
      final t = toDef.terminals.where((t) => t.id == terminalId);
      if (t.isNotEmpty) {
        final toKind = t.first.kind;
        if (_isIncompatible(kind, toKind)) {
          warning =
              'تحذير: أنت تحاول توصيل ${kind.label} مع ${toKind.label} — تأكد أن هذا مقصود (قد يسبب قصر دائرة).';
        }
      }
    }

    _pushUndo();
    final wire = WireModel(
      id: _uuid.v4(),
      from: TerminalRef(componentId: fromComp, terminalId: fromTerm),
      to: TerminalRef(componentId: componentId, terminalId: terminalId),
      kind: kind,
      colorValue: (defaultWireColors[kind] ?? const Color(0xFF9E9E9E)).toARGB32(),
    );
    project.wires.add(wire);
    notifyListeners();
    return warning;
  }

  bool _isIncompatible(TerminalKind a, TerminalKind b) {
    final phaseLike = {TerminalKind.phase, TerminalKind.dcPlus};
    final neutralLike = {TerminalKind.neutral, TerminalKind.dcMinus, TerminalKind.ground};
    return phaseLike.contains(a) && neutralLike.contains(b) || phaseLike.contains(b) && neutralLike.contains(a);
  }

  void deleteWire(String id) {
    _pushUndo();
    project.wires.removeWhere((w) => w.id == id);
    if (selectedWireId == id) selectedWireId = null;
    notifyListeners();
  }

  void setWireColor(String id, int colorValue) {
    final wire = project.wires.where((w) => w.id == id);
    if (wire.isEmpty) return;
    _pushUndo();
    wire.first.colorValue = colorValue;
    notifyListeners();
  }

  void setWireCrossSection(String id, double mm2) {
    final wire = project.wires.where((w) => w.id == id);
    if (wire.isEmpty) return;
    _pushUndo();
    wire.first.crossSectionMm2 = mm2;
    notifyListeners();
  }

  // ===================== عام =====================
  void renameProject(String name) {
    _pushUndo();
    project.name = name;
    notifyListeners();
  }

  void toggleRealisticMode() {
    project.realisticMode = !project.realisticMode;
    notifyListeners();
  }

  void setZoom(double z) {
    project.zoom = z.clamp(0.3, 3.0).toDouble();
    notifyListeners();
  }

  void loadProject(ProjectModel p) {
    project = p;
    selectedComponentIds.clear();
    selectedWireId = null;
    _undoStack.clear();
    _redoStack.clear();
    _dirty = false;
    notifyListeners();
  }

  void notify() => notifyListeners();
}
