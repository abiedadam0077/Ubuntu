import 'dart:math' as math;

import '../data/component_catalog.dart';
import '../models/component_definition.dart';
import '../models/component_instance.dart';
import '../models/enums.dart';
import '../models/project_model.dart';
import '../models/wire_model.dart';
import 'circuit_graph.dart';
import 'detected_fault.dart';
import 'mna_solver.dart';

const double kClosedConductance = 2000.0; // مفتاح مغلق تقريباً = 0.0005 أوم
const double kOpenConductance = 1e-9; // مفتاح مفتوح تقريباً = 1 جيجا أوم
const double kSafetyLeakConductance = 1e-9; // تسريب واقٍ لمنع مصفوفة منفردة

/// نتيجة تشغيل خطوة محاكاة واحدة
class SimulationResult {
  final SimulationStatus status;
  final Map<String, double> wireCurrents; // wireId -> تيار موقّع (أمبير)
  final List<DetectedFault> faults;
  final double totalPowerW;

  SimulationResult({
    required this.status,
    required this.wireCurrents,
    required this.faults,
    required this.totalPowerW,
  });
}

class SimulationEngine {
  final ProjectModel project;
  double simTime = 0;
  SimulationStatus status = SimulationStatus.idle;

  SimulationEngine(this.project);

  void reset() {
    simTime = 0;
    status = SimulationStatus.idle;
    for (final c in project.components) {
      final def = componentCatalogById[c.typeId];
      final wasOn = c.runtimeState['on'];
      c.runtimeState.clear();
      // نحافظ على وضعية المفاتيح اليدوية بعد Reset بدل إجبارها كلها على الإغلاق
      if (def != null && _isManualToggle(def.behavior) && wasOn != null) {
        c.runtimeState['on'] = wasOn;
      }
    }
  }

  bool _isManualToggle(BehaviorKind b) =>
      b == BehaviorKind.switchToggle ||
      b == BehaviorKind.selectorSwitch ||
      b == BehaviorKind.breaker ||
      b == BehaviorKind.motorBreaker;

  SimulationResult tick(double dt) {
    if (status != SimulationStatus.running) {
      return SimulationResult(status: status, wireCurrents: const {}, faults: const [], totalPowerW: 0);
    }
    simTime += dt;

    final graph = CircuitGraph.build(project);
    MnaResult? mnaResult;
    var virtualNodeCount = 0;

    for (var iter = 0; iter < 6; iter++) {
      final resistive = <ResistiveEdge>[];
      final sources = <VoltageSourceEdge>[];
      var nextVirtual = graph.nodes.length;
      int newVirtualNode() => nextVirtual++;

      for (final comp in project.components) {
        final def = componentCatalogById[comp.typeId];
        if (def == null) continue;
        _stampComponent(comp, def, graph, resistive, sources, newVirtualNode, dt);
      }

      virtualNodeCount = nextVirtual;
      // تسريب أمان لكل عقدة حقيقية لتفادي مصفوفة منفردة عند وجود عناصر معزولة
      for (var i = 0; i < graph.nodes.length; i++) {
        resistive.add(ResistiveEdge(i, graph.referenceNode, kSafetyLeakConductance, 'leak_$i'));
      }

      mnaResult = MnaSolver.solve(
        nodeCount: virtualNodeCount,
        referenceNode: graph.referenceNode,
        resistiveEdges: resistive,
        voltageSources: sources,
      );

      final changed = _postSolveComponents(graph, mnaResult, dt);
      if (!changed) break;
    }

    final wireCurrents = _computeWireCurrents(graph, mnaResult!);
    final faults = _detectFaults(graph, mnaResult, wireCurrents);
    final totalPower = _totalPower();

    if (faults.any((f) => f.isCritical)) {
      status = SimulationStatus.fault;
    }

    return SimulationResult(
      status: status,
      wireCurrents: wireCurrents,
      faults: faults,
      totalPowerW: totalPower,
    );
  }

  // =====================================================================
  // بناء المعادلات الكهربائية لكل مكون (Stamping)
  // =====================================================================
  void _stampComponent(
    ComponentInstance comp,
    ComponentDefinition def,
    CircuitGraph graph,
    List<ResistiveEdge> resistive,
    List<VoltageSourceEdge> sources,
    int Function() newVirtualNode,
    double dt,
  ) {
    int? node(String t) => graph.nodeOf(comp.id, t);

    if (comp.typeId == 'transformer') {
      final p1 = node('p1');
      final p2 = node('p2');
      final s1 = node('s1');
      final s2 = node('s2');
      final double vp = comp.properties['primaryVoltage'] ?? 230;
      final double vs = comp.properties['secondaryVoltage'] ?? 24;
      final double pr = comp.properties['ratedPower'] ?? 100;
      if (p1 != null && p2 != null) {
        final rp = (vp * vp) / (pr <= 0 ? 1 : pr);
        resistive.add(ResistiveEdge(p1, p2, 1 / (rp <= 0 ? 1 : rp), '${comp.id}_p'));
      }
      if (s1 != null && s2 != null) {
        final measuredP = ((comp.runtimeState['_pv'] as num?)?.toDouble() ?? vp).abs();
        final outV = vs * (measuredP / (vp == 0 ? 1 : vp));
        final vn = newVirtualNode();
        sources.add(VoltageSourceEdge(vn, s2, outV, '${comp.id}_s'));
        resistive.add(ResistiveEdge(vn, s1, 1 / 0.5, '${comp.id}_s_rin'));
      }
      return;
    }

    switch (def.behavior) {
      case BehaviorKind.sourceDc:
        {
          final na = node('a');
          final nb = node('b');
          if (na == null || nb == null) return;
          final double v = comp.properties['voltage'] ?? 12;
          final rin = comp.properties['internalResistance'] ?? 0.05;
          final vn = newVirtualNode();
          sources.add(VoltageSourceEdge(vn, nb, v, comp.id));
          resistive.add(ResistiveEdge(vn, na, 1 / rin, '${comp.id}_rin'));
          break;
        }
      case BehaviorKind.sourceAcSinglePhase:
        {
          final nl = node('l');
          final nn = node('n');
          if (nl == null || nn == null) return;
          final double v = comp.properties['voltage'] ?? 230;
          final rin = comp.properties['internalResistance'] ?? 0.02;
          final vn = newVirtualNode();
          sources.add(VoltageSourceEdge(vn, nn, v, comp.id));
          resistive.add(ResistiveEdge(vn, nl, 1 / rin, '${comp.id}_rin'));
          break;
        }
      case BehaviorKind.sourceAcThreePhase:
        {
          final nn = node('n');
          if (nn == null) return;
          final vLine = comp.properties['voltage'] ?? 400;
          final vPhase = vLine / math.sqrt(3);
          final rin = comp.properties['internalResistance'] ?? 0.01;
          for (final ph in ['l1', 'l2', 'l3']) {
            final np = node(ph);
            if (np == null) continue;
            final vn = newVirtualNode();
            sources.add(VoltageSourceEdge(vn, nn, vPhase, '${comp.id}_$ph'));
            resistive.add(ResistiveEdge(vn, np, 1 / rin, '${comp.id}_${ph}_rin'));
          }
          break;
        }

      case BehaviorKind.switchToggle:
      case BehaviorKind.selectorSwitch:
      case BehaviorKind.limitSwitch:
      case BehaviorKind.sensorDigital:
        {
          final isSpdt = (comp.properties['isSpdt'] ?? 0) >= 1;
          if (isSpdt) {
            final nc = node('com');
            final n0 = node('t0');
            final n1 = node('t1');
            final pos = (comp.runtimeState['position'] as int?) ?? 0;
            if (nc != null && n0 != null) {
              resistive.add(ResistiveEdge(nc, n0, pos == 0 ? kClosedConductance : kOpenConductance, '${comp.id}_p0'));
            }
            if (nc != null && n1 != null) {
              resistive.add(ResistiveEdge(nc, n1, pos == 1 ? kClosedConductance : kOpenConductance, '${comp.id}_p1'));
            }
          } else {
            final poles = (comp.properties['poleCount'] ?? 1).toInt();
            for (var p = 0; p < poles; p++) {
              final na = node('com$p');
              final nb = node('t$p');
              if (na == null || nb == null) continue;
              final on = (comp.runtimeState['on_$p'] as bool?) ?? (comp.runtimeState['on'] as bool?) ?? false;
              resistive.add(ResistiveEdge(na, nb, on ? kClosedConductance : kOpenConductance, '${comp.id}_p$p'));
            }
          }
          break;
        }

      case BehaviorKind.pushButtonNO:
        {
          final na = node('com0');
          final nb = node('t0');
          if (na == null || nb == null) return;
          final pressed = (comp.runtimeState['pressed'] as bool?) ?? false;
          resistive.add(ResistiveEdge(na, nb, pressed ? kClosedConductance : kOpenConductance, comp.id));
          break;
        }
      case BehaviorKind.pushButtonNC:
      case BehaviorKind.emergencyStop:
        {
          final na = node('com0');
          final nb = node('t0');
          if (na == null || nb == null) return;
          final pressed = (comp.runtimeState['pressed'] as bool?) ?? false;
          // NC: مغلق افتراضياً، يفتح عند الضغط
          resistive.add(ResistiveEdge(na, nb, pressed ? kOpenConductance : kClosedConductance, comp.id));
          break;
        }

      case BehaviorKind.thermostat:
        {
          final na = node('com0');
          final nb = node('t0');
          if (na == null || nb == null) return;
          final setPoint = comp.properties['setPoint'] ?? 25;
          final temp = comp.properties['currentTemp'] ?? 20;
          final on = temp < setPoint; // يشغّل التسخين حتى الوصول لدرجة الحرارة المطلوبة
          comp.runtimeState['on'] = on;
          resistive.add(ResistiveEdge(na, nb, on ? kClosedConductance : kOpenConductance, comp.id));
          break;
        }

      case BehaviorKind.lampLoad:
      case BehaviorKind.buzzerLoad:
      case BehaviorKind.pilotLamp:
      case BehaviorKind.resistiveLoad:
        {
          final na = node('a');
          final nb = node('b');
          if (na == null || nb == null) return;
          double r;
          if (def.behavior == BehaviorKind.resistiveLoad && comp.properties.containsKey('resistance')) {
            r = comp.properties['resistance'] ?? 220;
          } else {
            final vr = comp.properties['ratedVoltage'] ?? 230;
            final pr = comp.properties['ratedPower'] ?? 60;
            r = (vr * vr) / (pr <= 0 ? 1 : pr);
          }
          if (r <= 0) r = 1;
          resistive.add(ResistiveEdge(na, nb, 1 / r, comp.id));
          break;
        }

      case BehaviorKind.motorLoad:
        {
          final terms = def.terminals.map((t) => t.id).toList();
          if (terms.length >= 3 && terms.contains('u')) {
            // محرك ثلاثي الطور: 3 مسارات مقاومية من U/V/W إلى الأرضي الداخلي الافتراضي
            final vr = comp.properties['ratedVoltage'] ?? 400;
            final pr = comp.properties['ratedPower'] ?? 4000;
            final rPhase = (vr * vr / 3) / (pr <= 0 ? 1 : pr);
            final star = newVirtualNode();
            for (final id in ['u', 'v', 'w']) {
              final n = node(id);
              if (n == null) continue;
              resistive.add(ResistiveEdge(n, star, 1 / (rPhase <= 0 ? 1 : rPhase), '${comp.id}_$id'));
            }
          } else {
            final na = node('a');
            final nb = node('b');
            if (na == null || nb == null) return;
            final vr = comp.properties['ratedVoltage'] ?? 230;
            final pr = comp.properties['ratedPower'] ?? 60;
            var r = (vr * vr) / (pr <= 0 ? 1 : pr);
            if (r <= 0) r = 1;
            resistive.add(ResistiveEdge(na, nb, 1 / r, comp.id));
          }
          break;
        }

      case BehaviorKind.breaker:
      case BehaviorKind.motorBreaker:
      case BehaviorKind.fuse:
      case BehaviorKind.thermalRelay:
        {
          if (def.behavior == BehaviorKind.thermalRelay) {
            final tripped = (comp.runtimeState['tripped'] as bool?) ?? false;
            for (final ph in ['1', '2', '3']) {
              final na = node('l$ph');
              final nb = node('t$ph');
              if (na == null || nb == null) continue;
              resistive.add(ResistiveEdge(na, nb, tripped ? kOpenConductance : kClosedConductance, '${comp.id}_$ph'));
            }
          } else {
            final na = node('a');
            final nb = node('b');
            if (na == null || nb == null) return;
            final on = (comp.runtimeState['on'] as bool?) ?? true;
            final blown = (comp.runtimeState['blown'] as bool?) ?? false;
            final closed = on && !blown;
            resistive.add(ResistiveEdge(na, nb, closed ? kClosedConductance : kOpenConductance, comp.id));
          }
          break;
        }

      case BehaviorKind.rcd:
        {
          final tripped = (comp.runtimeState['tripped'] as bool?) ?? false;
          final lIn = node('l_in');
          final lOut = node('l_out');
          final nIn = node('n_in');
          final nOut = node('n_out');
          if (lIn != null && lOut != null) {
            resistive.add(ResistiveEdge(lIn, lOut, tripped ? kOpenConductance : kClosedConductance, '${comp.id}_L'));
          }
          if (nIn != null && nOut != null) {
            resistive.add(ResistiveEdge(nIn, nOut, tripped ? kOpenConductance : kClosedConductance, '${comp.id}_N'));
          }
          break;
        }

      case BehaviorKind.contactorCoil:
      case BehaviorKind.relayCoil:
        {
          final a1 = node('a1');
          final a2 = node('a2');
          if (a1 != null && a2 != null) {
            // ملف بمقاومة صغيرة (يستهلك تياراً بسيطاً) لتحديد حالة التغذية
            resistive.add(ResistiveEdge(a1, a2, 1 / 400.0, '${comp.id}_coil'));
          }
          final energized = (comp.runtimeState['energized'] as bool?) ?? false;
          if (def.behavior == BehaviorKind.contactorCoil) {
            for (final ph in ['1', '2', '3']) {
              final na = node('l$ph');
              final nb = node('t$ph');
              if (na == null || nb == null) continue;
              resistive.add(ResistiveEdge(na, nb, energized ? kClosedConductance : kOpenConductance, '${comp.id}_$ph'));
            }
          } else {
            final com = node('com');
            final no = node('no');
            final nc = node('nc');
            if (com != null && no != null) {
              resistive.add(ResistiveEdge(com, no, energized ? kClosedConductance : kOpenConductance, '${comp.id}_no'));
            }
            if (com != null && nc != null) {
              resistive.add(ResistiveEdge(com, nc, energized ? kOpenConductance : kClosedConductance, '${comp.id}_nc'));
            }
          }
          break;
        }

      case BehaviorKind.contactorContactNO:
      case BehaviorKind.contactorContactNC:
        {
          final na = node('com0');
          final nb = node('t0');
          if (na == null || nb == null) return;
          final linkedId = comp.links['linkedCoil'];
          bool energized = false;
          if (linkedId != null) {
            final coil = project.components.where((c) => c.id == linkedId);
            if (coil.isNotEmpty) {
              energized = (coil.first.runtimeState['energized'] as bool?) ?? false;
            }
          }
          final closed = def.behavior == BehaviorKind.contactorContactNO ? energized : !energized;
          resistive.add(ResistiveEdge(na, nb, closed ? kClosedConductance : kOpenConductance, comp.id));
          break;
        }

      case BehaviorKind.timerOnDelay:
        {
          final a1 = node('a1');
          final a2 = node('a2');
          if (a1 != null && a2 != null) {
            resistive.add(ResistiveEdge(a1, a2, 1 / 400.0, '${comp.id}_coil'));
          }
          final done = (comp.runtimeState['timerDone'] as bool?) ?? false;
          final com = node('com');
          final no = node('no');
          final nc = node('nc');
          if (com != null && no != null) {
            resistive.add(ResistiveEdge(com, no, done ? kClosedConductance : kOpenConductance, '${comp.id}_no'));
          }
          if (com != null && nc != null) {
            resistive.add(ResistiveEdge(com, nc, done ? kOpenConductance : kClosedConductance, '${comp.id}_nc'));
          }
          break;
        }

      case BehaviorKind.counter:
        {
          final inN = node('in');
          if (inN != null) {
            resistive.add(ResistiveEdge(inN, graph.referenceNode, 1e-6, '${comp.id}_sense'));
          }
          final done = (comp.runtimeState['done'] as bool?) ?? false;
          final com = node('com');
          final no = node('no');
          if (com != null && no != null) {
            resistive.add(ResistiveEdge(com, no, done ? kClosedConductance : kOpenConductance, comp.id));
          }
          break;
        }

      case BehaviorKind.starDeltaStarter:
      case BehaviorKind.dolStarter:
        {
          final running = (comp.runtimeState['running'] as bool?) ?? false;
          final isStarPhase = (comp.runtimeState['mode'] as String?) == 'star';
          for (final pair in [
            ['l1', 'u'],
            ['l2', 'v'],
            ['l3', 'w']
          ]) {
            final na = node(pair[0]);
            final nb = node(pair[1]);
            if (na == null || nb == null) continue;
            double g;
            if (!running) {
              g = kOpenConductance;
            } else if (def.behavior == BehaviorKind.starDeltaStarter && isStarPhase) {
              g = 1 / 45.0; // مقاومة إضافية تحاكي جهد تشغيل مخفض في وضع النجمة
            } else {
              g = kClosedConductance;
            }
            resistive.add(ResistiveEdge(na, nb, g, '${comp.id}_${pair[1]}'));
          }
          break;
        }

      case BehaviorKind.diode:
      case BehaviorKind.led:
        {
          final na = node('a');
          final nb = node('b');
          if (na == null || nb == null) return;
          final fwd = (comp.runtimeState['fwd'] as bool?) ?? true;
          resistive.add(ResistiveEdge(na, nb, fwd ? 50.0 : kOpenConductance, comp.id));
          break;
        }

      case BehaviorKind.capacitor:
        {
          final na = node('a');
          final nb = node('b');
          if (na == null || nb == null) return;
          // عند التيار المستمر المستقر، المكثف يمنع مرور التيار (دارة مفتوحة تقريباً)
          resistive.add(ResistiveEdge(na, nb, kOpenConductance, comp.id));
          break;
        }

      case BehaviorKind.transistor:
        {
          final base = node('base');
          final c = node('collector');
          final e = node('emitter');
          if (base != null) {
            resistive.add(ResistiveEdge(base, graph.referenceNode, 1e-6, '${comp.id}_base'));
          }
          final on = (comp.runtimeState['on'] as bool?) ?? false;
          if (c != null && e != null) {
            resistive.add(ResistiveEdge(c, e, on ? kClosedConductance : kOpenConductance, comp.id));
          }
          break;
        }

      case BehaviorKind.potentiometer:
        {
          final na = node('a');
          final nb = node('b');
          final nw = node('wiper');
          final total = comp.properties['resistance'] ?? 10000;
          final pos = (comp.properties['wiperPosition'] ?? 0.5).clamp(0.01, 0.99);
          if (na != null && nw != null) {
            resistive.add(ResistiveEdge(na, nw, 1 / (total * pos), '${comp.id}_aw'));
          }
          if (nw != null && nb != null) {
            resistive.add(ResistiveEdge(nw, nb, 1 / (total * (1 - pos)), '${comp.id}_wb'));
          }
          break;
        }

      case BehaviorKind.meterProbe:
        {
          final na = node('a');
          final nb = node('b');
          if (na == null || nb == null) return;
          final mode = (comp.properties['mode'] ?? 0).toInt();
          final seriesModes = {1, 3, 5};
          if (seriesModes.contains(mode)) {
            sources.add(VoltageSourceEdge(na, nb, 0, comp.id));
          } else {
            resistive.add(ResistiveEdge(na, nb, 1e-7, comp.id));
          }
          break;
        }

      case BehaviorKind.generic:
      case BehaviorKind.plcPlaceholder:
        {
          for (var i = 0; i < def.terminals.length - 1; i++) {
            final na = node(def.terminals[i].id);
            final nb = node(def.terminals[i + 1].id);
            if (na == null || nb == null) continue;
            resistive.add(ResistiveEdge(na, nb, kOpenConductance, '${comp.id}_$i'));
          }
          break;
        }

      default:
        break;
    }
  }

  // =====================================================================
  // تحديث الحالات بعد الحل (تغذية الملفات، الحماية، الحرارة...) — قد تتغيّر
  // النتيجة فنعيد الحل عدة مرات حتى تستقر (نقطة ثابتة Fixed Point)
  // =====================================================================
  bool _postSolveComponents(CircuitGraph graph, MnaResult mna, double dt) {
    var changed = false;
    double v(String key) {
      final idx = graph.terminalToNode[key];
      if (idx == null) return 0;
      return mna.nodeVoltages[idx];
    }

    for (final comp in project.components) {
      final def = componentCatalogById[comp.typeId];
      if (def == null) continue;

      if (comp.typeId == 'transformer') {
        final vp = (v(terminalKey(comp.id, 'p1')) - v(terminalKey(comp.id, 'p2'))).abs();
        final prev = (comp.runtimeState['_pv'] as num?)?.toDouble() ?? -1;
        if ((vp - prev).abs() > 1) changed = true;
        comp.runtimeState['_pv'] = vp;
        continue;
      }

      switch (def.behavior) {
        case BehaviorKind.contactorCoil:
        case BehaviorKind.relayCoil:
          {
            final va = v(terminalKey(comp.id, 'a1'));
            final vb = v(terminalKey(comp.id, 'a2'));
            final coilV = comp.properties['coilVoltage'] ?? 230;
            final energized = (va - vb).abs() > coilV * 0.6;
            if (energized != (comp.runtimeState['energized'] as bool? ?? false)) changed = true;
            comp.runtimeState['energized'] = energized;
            break;
          }
        case BehaviorKind.timerOnDelay:
          {
            final va = v(terminalKey(comp.id, 'a1'));
            final vb = v(terminalKey(comp.id, 'a2'));
            final coilV = comp.properties['coilVoltage'] ?? 230;
            final energized = (va - vb).abs() > coilV * 0.6;
            var elapsed = (comp.runtimeState['elapsed'] as num?)?.toDouble() ?? 0.0;
            if (energized) {
              elapsed += dt;
            } else {
              elapsed = 0;
            }
            comp.runtimeState['elapsed'] = elapsed;
            final delay = comp.properties['delaySeconds'] ?? 3;
            final done = energized && elapsed >= delay;
            if (done != (comp.runtimeState['timerDone'] as bool? ?? false)) changed = true;
            comp.runtimeState['timerDone'] = done;
            comp.runtimeState['energized'] = energized;
            break;
          }
        case BehaviorKind.counter:
          {
            final vin = v(terminalKey(comp.id, 'in'));
            final energizedNow = vin.abs() > 20;
            final wasEnergized = (comp.runtimeState['lastEnergized'] as bool?) ?? false;
            var count = (comp.runtimeState['count'] as int?) ?? 0;
            if (energizedNow && !wasEnergized) {
              count++;
            }
            comp.runtimeState['lastEnergized'] = energizedNow;
            comp.runtimeState['count'] = count;
            final target = (comp.properties['targetCount'] ?? 5).toInt();
            comp.runtimeState['done'] = count >= target;
            break;
          }
        case BehaviorKind.transistor:
          {
            final vBase = v(terminalKey(comp.id, 'base'));
            final on = vBase.abs() > 1.0;
            if (on != (comp.runtimeState['on'] as bool? ?? false)) changed = true;
            comp.runtimeState['on'] = on;
            break;
          }
        case BehaviorKind.diode:
        case BehaviorKind.led:
          {
            final va = v(terminalKey(comp.id, 'a'));
            final vb = v(terminalKey(comp.id, 'b'));
            final newFwd = (va - vb) >= -0.05;
            if (newFwd != (comp.runtimeState['fwd'] as bool? ?? true)) changed = true;
            comp.runtimeState['fwd'] = newFwd;
            final current = (va - vb) * (newFwd ? 50.0 : kOpenConductance);
            comp.runtimeState['current'] = current;
            comp.runtimeState['brightness'] = (current.abs() / 0.02).clamp(0, 1.5);
            break;
          }
        case BehaviorKind.starDeltaStarter:
          {
            final running = (comp.runtimeState['running'] as bool?) ?? false;
            if (running) {
              var elapsed = (comp.runtimeState['stateElapsed'] as num?)?.toDouble() ?? 0.0;
              elapsed += dt;
              comp.runtimeState['stateElapsed'] = elapsed;
              final transition = comp.properties['transitionSeconds'] ?? 3;
              comp.runtimeState['mode'] = elapsed < transition ? 'star' : 'delta';
            }
            break;
          }
        default:
          break;
      }
    }

    // تحديث القراءات العامة (جهد/تيار/قدرة) وحالة الحماية لكل المكونات ذات الطرفين
    for (final comp in project.components) {
      final def = componentCatalogById[comp.typeId];
      if (def == null) continue;
      _updateReadingsAndProtection(comp, def, graph, mna, dt);
    }

    return changed;
  }

  void _updateReadingsAndProtection(
    ComponentInstance comp,
    ComponentDefinition def,
    CircuitGraph graph,
    MnaResult mna,
    double dt,
  ) {
    double v(String key) {
      final idx = graph.terminalToNode[key];
      if (idx == null) return 0;
      return mna.nodeVoltages[idx];
    }

    switch (def.behavior) {
      case BehaviorKind.lampLoad:
      case BehaviorKind.buzzerLoad:
      case BehaviorKind.pilotLamp:
      case BehaviorKind.resistiveLoad:
        {
          final va = v(terminalKey(comp.id, 'a'));
          final vb = v(terminalKey(comp.id, 'b'));
          final volt = (va - vb).abs();
          final double pr = comp.properties['ratedPower'] ?? 60;
          double r;
          if (def.behavior == BehaviorKind.resistiveLoad && comp.properties.containsKey('resistance')) {
            r = comp.properties['resistance'] ?? 220;
          } else {
            final double vr = comp.properties['ratedVoltage'] ?? 230;
            r = (vr * vr) / (pr <= 0 ? 1 : pr);
          }
          if (r <= 0) r = 1;
          final current = volt / r;
          final power = volt * current;
          comp.runtimeState['voltage'] = volt;
          comp.runtimeState['current'] = current;
          comp.runtimeState['power'] = power;
          comp.runtimeState['brightness'] = (pr <= 0 ? 0.0 : (power / pr)).clamp(0.0, 1.4);
          break;
        }
      case BehaviorKind.motorLoad:
        {
          final terms = def.terminals.map((t) => t.id).toList();
          double power = 0;
          if (terms.contains('u')) {
            final vu = v(terminalKey(comp.id, 'u'));
            final vv = v(terminalKey(comp.id, 'v'));
            final vw = v(terminalKey(comp.id, 'w'));
            final avg = (vu.abs() + vv.abs() + vw.abs()) / 3;
            final double vr = comp.properties['ratedVoltage'] ?? 400;
            final double pr = comp.properties['ratedPower'] ?? 4000;
            final ratio = (avg / (vr / math.sqrt(3))).clamp(0, 1.6);
            power = pr * ratio * ratio;
            final present = [vu, vv, vw].where((x) => x.abs() > 10).length;
            comp.runtimeState['phasesPresent'] = present;
          } else {
            final va = v(terminalKey(comp.id, 'a'));
            final vb = v(terminalKey(comp.id, 'b'));
            final volt = (va - vb).abs();
            final double vr = comp.properties['ratedVoltage'] ?? 230;
            final double pr = comp.properties['ratedPower'] ?? 60;
            final ratio = (volt / vr).clamp(0, 1.6);
            power = pr * ratio * ratio;
          }
          final pr = comp.properties['ratedPower'] ?? 750;
          final rpmRatio = (power / pr).clamp(0, 1.3);
          comp.runtimeState['power'] = power;
          comp.runtimeState['rpmRatio'] = math.sqrt(rpmRatio);
          break;
        }
      case BehaviorKind.breaker:
      case BehaviorKind.motorBreaker:
      case BehaviorKind.fuse:
        {
          final va = v(terminalKey(comp.id, 'a'));
          final vb = v(terminalKey(comp.id, 'b'));
          final on = (comp.runtimeState['on'] as bool?) ?? true;
          final blown = (comp.runtimeState['blown'] as bool?) ?? false;
          final closed = on && !blown;
          final current = closed ? (va - vb).abs() * kClosedConductance : 0.0;
          comp.runtimeState['current'] = current;
          comp.runtimeState['voltage'] = (va - vb).abs();
          final rated = comp.properties['ratedCurrent'] ?? 10;
          if (closed && rated > 0) {
            if (current > rated * 6) {
              // مستوى قصر دائرة: فصل شبه فوري
              if (def.behavior == BehaviorKind.fuse) {
                comp.runtimeState['blown'] = true;
              } else {
                comp.runtimeState['on'] = false;
                comp.runtimeState['tripped'] = true;
              }
              comp.runtimeState['tripReason'] = 'short';
            } else if (current > rated) {
              var timer = (comp.runtimeState['overloadTimer'] as num?)?.toDouble() ?? 0.0;
              timer += dt;
              comp.runtimeState['overloadTimer'] = timer;
              final allowed = (3.0 / ((current / rated) - 1).clamp(0.15, 10)).clamp(0.3, 5.0);
              if (timer >= allowed) {
                if (def.behavior == BehaviorKind.fuse) {
                  comp.runtimeState['blown'] = true;
                } else {
                  comp.runtimeState['on'] = false;
                  comp.runtimeState['tripped'] = true;
                }
                comp.runtimeState['tripReason'] = 'overload';
              }
            } else {
              comp.runtimeState['overloadTimer'] = 0.0;
            }
          }
          break;
        }
      case BehaviorKind.thermalRelay:
        {
          final currents = <double>[];
          for (final ph in ['1', '2', '3']) {
            final va = v(terminalKey(comp.id, 'l$ph'));
            final vb = v(terminalKey(comp.id, 't$ph'));
            final tripped = (comp.runtimeState['tripped'] as bool?) ?? false;
            currents.add(tripped ? 0 : (va - vb).abs() * kClosedConductance);
          }
          final maxI = currents.isEmpty ? 0.0 : currents.reduce(math.max);
          comp.runtimeState['current'] = maxI;
          final rated = comp.properties['ratedCurrent'] ?? 16;
          final tripped = (comp.runtimeState['tripped'] as bool?) ?? false;
          if (!tripped && maxI > rated) {
            var timer = (comp.runtimeState['overloadTimer'] as num?)?.toDouble() ?? 0.0;
            timer += dt;
            comp.runtimeState['overloadTimer'] = timer;
            if (timer > 2.0) {
              comp.runtimeState['tripped'] = true;
              comp.runtimeState['tripReason'] = 'overload';
            }
          } else if (!tripped) {
            comp.runtimeState['overloadTimer'] = 0.0;
          }
          break;
        }
      case BehaviorKind.rcd:
        {
          final vlIn = v(terminalKey(comp.id, 'l_in'));
          final vlOut = v(terminalKey(comp.id, 'l_out'));
          final vnIn = v(terminalKey(comp.id, 'n_in'));
          final vnOut = v(terminalKey(comp.id, 'n_out'));
          final tripped = (comp.runtimeState['tripped'] as bool?) ?? false;
          final iL = tripped ? 0.0 : (vlIn - vlOut).abs() * kClosedConductance;
          final iN = tripped ? 0.0 : (vnIn - vnOut).abs() * kClosedConductance;
          comp.runtimeState['current'] = iL;
          final imbalance = (iL - iN).abs();
          final sensitivity = (comp.properties['sensitivityMa'] ?? 30) / 1000.0;
          if (!tripped && imbalance > sensitivity && iL > 0.05) {
            comp.runtimeState['tripped'] = true;
            comp.runtimeState['tripReason'] = 'groundFault';
          }
          break;
        }
      default:
        break;
    }
  }

  Map<String, double> _computeWireCurrents(CircuitGraph graph, MnaResult mna) {
    final result = <String, double>{};
    for (final wire in project.wires) {
      final na = graph.nodeOf(wire.from.componentId, wire.from.terminalId);
      final nb = graph.nodeOf(wire.to.componentId, wire.to.terminalId);
      if (na == null || nb == null) continue;
      // كل الأسلاك ضمن نفس العقدة (متصلة كهربائياً)؛ نقدّر التيار المار بالسلك
      // بالفرق الجهدي شبه المعدوم مضروباً بموصلية كبيرة (تقريب عملي لعرض الحركة)
      final dv = mna.nodeVoltages[na] - mna.nodeVoltages[nb];
      result[wire.id] = dv * kClosedConductance;
    }
    return result;
  }

  double _totalPower() {
    var total = 0.0;
    for (final c in project.components) {
      final p = c.runtimeState['power'];
      if (p is num) total += p.toDouble();
    }
    return total;
  }

  // =====================================================================
  // كشف الأخطاء
  // =====================================================================
  List<DetectedFault> _detectFaults(CircuitGraph graph, MnaResult mna, Map<String, double> wireCurrents) {
    final faults = <DetectedFault>[];

    for (final comp in project.components) {
      final def = componentCatalogById[comp.typeId];
      if (def == null) continue;

      if (def.behavior == BehaviorKind.sourceDc ||
          def.behavior == BehaviorKind.sourceAcSinglePhase ||
          def.behavior == BehaviorKind.sourceAcThreePhase) {
        // اكتشاف قصر عبر تيار داخلي مرتفع جداً في مقاومة المصدر الداخلية
      }

      if (def.behavior == BehaviorKind.breaker || def.behavior == BehaviorKind.motorBreaker) {
        final tripped = (comp.runtimeState['tripped'] as bool?) ?? false;
        if (tripped) {
          final reason = comp.runtimeState['tripReason'] as String?;
          final rated = comp.properties['ratedCurrent'] ?? 10;
          final current = (comp.runtimeState['current'] as num?)?.toDouble() ?? 0;
          if (reason == 'short') {
            faults.add(DetectedFault(
              type: FaultType.shortCircuit,
              titleAr: '⚠️ قصر دائرة (Short Circuit)',
              problemAr: 'تيار مرتفع جداً جعل القاطع "${comp.customName ?? def.nameAr}" يفصل فوراً لحمايتك.',
              solutionAr: 'راجع التوصيلات: تأكد من عدم توصيل Phase مباشرة مع Neutral أو مع الأرضي بدون حمل مناسب.',
              componentIds: [comp.id],
            ));
          } else if (reason == 'overload') {
            faults.add(DetectedFault(
              type: FaultType.overload,
              titleAr: '⚠️ تحميل زائد (Overload)',
              problemAr:
                  'التيار الحالي: ${current.toStringAsFixed(1)}A تجاوز قدرة القاطع (${rated.toStringAsFixed(0)}A) لمدة كافية فتم الفصل.',
              solutionAr: 'استخدم قاطعاً بتيار مقنن أعلى أو قلل الحمل المتصل بهذا الخط.',
              componentIds: [comp.id],
            ));
          }
        }
      }

      if (def.behavior == BehaviorKind.fuse) {
        final blown = (comp.runtimeState['blown'] as bool?) ?? false;
        if (blown) {
          faults.add(DetectedFault(
            type: FaultType.fuseBlown,
            titleAr: '⚠️ احتراق الفيوز (Fuse Blown)',
            problemAr: 'انصهر الفيوز "${comp.customName ?? def.nameAr}" بسبب تيار تجاوز قيمته المقننة.',
            solutionAr: 'استبدل الفيوز بآخر بنفس القيمة بعد إصلاح سبب زيادة التيار.',
            componentIds: [comp.id],
          ));
        }
      }

      if (def.behavior == BehaviorKind.rcd) {
        final tripped = (comp.runtimeState['tripped'] as bool?) ?? false;
        if (tripped) {
          faults.add(DetectedFault(
            type: FaultType.groundFault,
            titleAr: '⚠️ تسريب أرضي (Ground Fault)',
            problemAr: 'اكتشف القاطع التفاضلي RCD فرقاً بين تيار Phase وNeutral، ما يدل على تسريب للأرضي.',
            solutionAr: 'تحقق من عزل الأسلاك ومن عدم وجود تلامس مباشر بين Phase والأرضي (PE).',
            componentIds: [comp.id],
          ));
        }
      }

      if (def.behavior == BehaviorKind.thermalRelay) {
        final tripped = (comp.runtimeState['tripped'] as bool?) ?? false;
        if (tripped) {
          faults.add(DetectedFault(
            type: FaultType.overload,
            titleAr: '⚠️ فصل الريليه الحراري (Thermal Overload)',
            problemAr: 'تيار المحرك تجاوز القيمة المضبوطة لفترة طويلة فقام الريليه الحراري بحماية المحرك.',
            solutionAr: 'تحقق من حمل المحرك الميكانيكي أو اضبط قيمة الريليه الحراري بشكل صحيح.',
            componentIds: [comp.id],
          ));
        }
      }

      if (def.behavior == BehaviorKind.diode || def.behavior == BehaviorKind.led) {
        final fwd = (comp.runtimeState['fwd'] as bool?) ?? true;
        final current = (comp.runtimeState['current'] as num?)?.toDouble() ?? 0;
        if (!fwd && current.abs() < 1e-6) {
          // ليس بالضرورة خطأ (قد يكون هذا هو الاتجاه الصحيح المطلوب)، نتركها معلومة فقط
        }
      }

      if (def.behavior == BehaviorKind.motorLoad) {
        final terms = def.terminals.map((t) => t.id).toList();
        if (terms.contains('u')) {
          final present = (comp.runtimeState['phasesPresent'] as int?) ?? 3;
          if (present > 0 && present < 3) {
            faults.add(DetectedFault(
              type: FaultType.motorWiringError,
              titleAr: '⚠️ خطأ في توصيل المحرك (Phase Missing)',
              problemAr: 'أحد أطوار المحرك الثلاثي غير متصل — المحرك سيصدر صوت اهتزاز ولن يدور بشكل صحيح.',
              solutionAr: 'تأكد من توصيل الأطراف الثلاثة U وV وW بمصدر التغذية الثلاثي الطور.',
              componentIds: [comp.id],
            ));
          }
        }
      }
    }

    return faults;
  }
}
