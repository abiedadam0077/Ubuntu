import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/component_catalog.dart';
import '../../models/component_definition.dart';
import '../../models/component_instance.dart';
import '../../models/enums.dart';
import '../../models/project_model.dart';
import '../../state/project_controller.dart';
import '../../state/simulation_controller.dart';
import 'component_painter.dart';

/// يحسب الموضع المطلق لطرف مكون داخل مساحة اللوحة (يأخذ الدوران بعين الاعتبار)
Offset terminalAbsolutePosition(ComponentInstance comp, Size size, Offset anchor) {
  final local = Offset((anchor.dx - 0.5) * size.width, (anchor.dy - 0.5) * size.height);
  final cosA = math.cos(comp.rotation);
  final sinA = math.sin(comp.rotation);
  final rotated = Offset(local.dx * cosA - local.dy * sinA, local.dx * sinA + local.dy * cosA);
  return comp.position + rotated;
}

class CircuitCanvas extends StatefulWidget {
  final ProjectController controller;
  final SimulationController simController;
  final bool realistic;
  final ValueChanged<String>? onWarning;
  final TransformationController? transformationController;
  final ValueChanged<ComponentInstance>? onComponentLongPress;
  final ValueChanged<ComponentInstance>? onComponentDoubleTap;

  const CircuitCanvas({
    super.key,
    required this.controller,
    required this.simController,
    required this.realistic,
    this.onWarning,
    this.transformationController,
    this.onComponentLongPress,
    this.onComponentDoubleTap,
  });

  @override
  State<CircuitCanvas> createState() => _CircuitCanvasState();
}

class _CircuitCanvasState extends State<CircuitCanvas> with SingleTickerProviderStateMixin {
  late final TransformationController _tc = widget.transformationController ?? TransformationController();
  Offset? _dragPreviewPoint;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    if (widget.transformationController == null) _tc.dispose();
    super.dispose();
  }

  Offset _globalToScene(Offset global) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(global);
    final inverted = Matrix4.inverted(_tc.value);
    return MatrixUtils.transformPoint(inverted, local);
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.controller.project;
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        final scenePos = _globalToScene(details.offset);
        widget.controller.addComponent(details.data, scenePos);
      },
      builder: (context, candidateData, rejectedData) {
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _tc,
            minScale: 0.3,
            maxScale: 3.0,
            boundaryMargin: const EdgeInsets.all(2000),
            child: SizedBox(
              width: 3000,
              height: 3000,
              child: AnimatedBuilder(
                animation: Listenable.merge([widget.controller, widget.simController, _animController]),
                builder: (context, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GridAndWiresPainter(
                            project: project,
                            wireCurrents: widget.simController.wireCurrents,
                            running: widget.simController.status == SimulationStatus.running,
                            selectedWireId: widget.controller.selectedWireId,
                            dragFrom: widget.controller.pendingWireFrom,
                            dragPreviewPoint: _dragPreviewPoint,
                            animValue: _animController.value,
                          ),
                        ),
                      ),
                      for (final comp in project.components) _buildComponent(comp),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComponent(ComponentInstance comp) {
    final def = componentCatalogById[comp.typeId];
    if (def == null) return const SizedBox.shrink();
    final size = def.defaultSize;
    final selected = widget.controller.selectedComponentIds.contains(comp.id);

    return Positioned(
      left: comp.position.dx - size.width / 2,
      top: comp.position.dy - size.height / 2,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        onTap: () {
          if (widget.controller.pendingWireFrom != null) {
            widget.controller.cancelWire();
            return;
          }
          final interactiveHandled = _handleInteractiveTap(comp, def);
          if (!interactiveHandled) widget.controller.selectOnly(comp.id);
        },
        onTapDown: (_) => _handleInteractivePress(comp, def, true),
        onTapUp: (_) => _handleInteractivePress(comp, def, false),
        onTapCancel: () => _handleInteractivePress(comp, def, false),
        onLongPress: () {
          widget.controller.selectOnly(comp.id);
          widget.onComponentLongPress?.call(comp);
        },
        onDoubleTap: () {
          widget.controller.selectOnly(comp.id);
          widget.onComponentDoubleTap?.call(comp);
        },
        onPanStart: (_) => widget.controller.selectOnly(comp.id),
        onPanUpdate: (details) {
          widget.controller.moveComponent(
            comp.id,
            comp.position + details.delta / _tc.value.getMaxScaleOnAxis(),
            recordUndo: false,
          );
        },
        child: Transform.rotate(
          angle: comp.rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: size,
                painter: ComponentPainter(
                  def: def,
                  comp: comp,
                  realistic: widget.realistic,
                  selected: selected,
                  animPhase: _animPhaseFor(comp),
                ),
              ),
              for (final t in def.terminals)
                Positioned(
                  left: t.anchor.dx * size.width - 12,
                  top: t.anchor.dy * size.height - 12,
                  width: 24,
                  height: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleTerminalTap(comp.id, t.id),
                    child: const SizedBox.expand(),
                  ),
                ),
              if (selected)
                Positioned(
                  bottom: -22,
                  left: 0,
                  right: 0,
                  child: Text(
                    comp.customName ?? def.nameAr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _animPhaseFor(ComponentInstance comp) {
    final rpmRatio = (comp.runtimeState['rpmRatio'] as num?)?.toDouble() ?? 0;
    if (rpmRatio <= 0.01) return 0;
    return (_animController.value * (1 + rpmRatio * 6)) % 1.0;
  }

  void _handleTerminalTap(String componentId, String terminalId) {
    if (widget.controller.pendingWireFrom == null) {
      widget.controller.startWireFrom(componentId, terminalId);
    } else {
      final warning = widget.controller.finishWireTo(componentId, terminalId);
      if (warning != null && widget.onWarning != null) {
        widget.onWarning!(warning);
      }
    }
  }

  static const _toggleBehaviors = {
    BehaviorKind.switchToggle,
    BehaviorKind.selectorSwitch,
    BehaviorKind.limitSwitch,
    BehaviorKind.sensorDigital,
  };

  static const _momentaryBehaviors = {
    BehaviorKind.pushButtonNO,
    BehaviorKind.pushButtonNC,
    BehaviorKind.emergencyStop,
  };

  /// يعالج النقر التفاعلي أثناء التشغيل (تبديل مفتاح/محدد) — يعيد true إن تم التعامل معه
  bool _handleInteractiveTap(ComponentInstance comp, ComponentDefinition def) {
    if (widget.simController.status != SimulationStatus.running) return false;
    if (!_toggleBehaviors.contains(def.behavior)) return false;
    final isSpdt = (comp.properties['isSpdt'] ?? 0) >= 1;
    if (isSpdt) {
      final pos = (comp.runtimeState['position'] as int?) ?? 0;
      widget.controller.setManualState(comp.id, 'position', pos == 0 ? 1 : 0);
    } else {
      widget.controller.toggleManualState(comp.id, 'on');
    }
    return true;
  }

  /// يعالج الضغط المستمر (زر ضغط / توقف طارئ) أثناء التشغيل فقط
  void _handleInteractivePress(ComponentInstance comp, ComponentDefinition def, bool pressed) {
    if (widget.simController.status != SimulationStatus.running) return;
    if (!_momentaryBehaviors.contains(def.behavior)) return;
    widget.controller.setPressed(comp.id, pressed);
  }
}

class _GridAndWiresPainter extends CustomPainter {
  final ProjectModel project;
  final Map<String, double> wireCurrents;
  final bool running;
  final String? selectedWireId;
  final String? dragFrom;
  final Offset? dragPreviewPoint;
  final double animValue;

  _GridAndWiresPainter({
    required this.project,
    required this.wireCurrents,
    required this.running,
    required this.selectedWireId,
    required this.dragFrom,
    required this.dragPreviewPoint,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawWires(canvas);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawWires(Canvas canvas) {
    for (final wire in project.wires) {
      final fromComp = _findComp(wire.from.componentId);
      final toComp = _findComp(wire.to.componentId);
      if (fromComp == null || toComp == null) continue;
      final fromDef = componentCatalogById[fromComp.typeId];
      final toDef = componentCatalogById[toComp.typeId];
      if (fromDef == null || toDef == null) continue;
      final fromAnchor = fromDef.terminals.where((t) => t.id == wire.from.terminalId);
      final toAnchor = toDef.terminals.where((t) => t.id == wire.to.terminalId);
      if (fromAnchor.isEmpty || toAnchor.isEmpty) continue;

      final p1 = terminalAbsolutePosition(fromComp, fromDef.defaultSize, fromAnchor.first.anchor);
      final p2 = terminalAbsolutePosition(toComp, toDef.defaultSize, toAnchor.first.anchor);

      final isSelected = wire.id == selectedWireId;
      final color = Color(wire.colorValue);
      final paint = Paint()
        ..color = isSelected ? AppColors.primary : color
        ..strokeWidth = isSelected ? 4.5 : (1.5 + wire.crossSectionMm2.clamp(0.5, 10).toDouble())
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2 - 20);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, p2.dx, p2.dy);
      canvas.drawPath(path, paint);

      final double current = wireCurrents[wire.id] ?? 0;
      if (running && current.abs() > 0.02) {
        _drawFlowDots(canvas, path, current);
      }
    }

    if (dragFrom != null && dragPreviewPoint != null) {
      final parts = dragFrom!.split('.');
      final comp = _findComp(parts[0]);
      if (comp != null) {
        final def = componentCatalogById[comp.typeId];
        final term = def?.terminals.where((t) => t.id == parts.sublist(1).join('.'));
        if (def != null && term != null && term.isNotEmpty) {
          final p1 = terminalAbsolutePosition(comp, def.defaultSize, term.first.anchor);
          canvas.drawLine(
            p1,
            dragPreviewPoint!,
            Paint()
              ..color = Colors.white54
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }
  }

  void _drawFlowDots(Canvas canvas, Path path, double current) {
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      final double speed = current.abs().clamp(0.05, 8.0).toDouble();
      final double offsetT = (animValue * speed * 40) % 40;
      for (double d = offsetT; d < m.length; d += 40) {
        final tangent = m.getTangentForOffset(d);
        if (tangent == null) continue;
        canvas.drawCircle(tangent.position, 2.6, Paint()..color = AppColors.primary);
      }
    }
  }

  ComponentInstance? _findComp(String id) {
    for (final c in project.components) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant _GridAndWiresPainter oldDelegate) => true;
}
