import '../data/component_catalog.dart';
import '../models/component_instance.dart';
import '../models/enums.dart';
import '../models/project_model.dart';
import '../models/wire_model.dart';

/// مفتاح فريد لطرف مكون: componentId + '.' + terminalId
String terminalKey(String componentId, String terminalId) => '$componentId.$terminalId';

/// نظام Union-Find بسيط لدمج الأطراف المتصلة عبر الأسلاك في "عُقد" كهربائية
class _UnionFind {
  final Map<String, String> parent = {};

  void add(String key) => parent.putIfAbsent(key, () => key);

  String find(String key) {
    add(key);
    var root = key;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    // ضغط المسار
    var cur = key;
    while (parent[cur] != root) {
      final next = parent[cur]!;
      parent[cur] = root;
      cur = next;
    }
    return root;
  }

  void union(String a, String b) {
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) parent[ra] = rb;
  }
}

/// عقدة كهربائية: مجموعة أطراف متصلة فيزيائياً معاً (نفس الجهد)
class CircuitNode {
  final int index;
  final Set<String> terminalKeys;
  TerminalKind dominantKind;

  CircuitNode(this.index, this.terminalKeys, this.dominantKind);
}

/// الرسم البياني الكهربائي الكامل المبني من مشروع معيّن
class CircuitGraph {
  final Map<String, int> terminalToNode = {}; // terminalKey -> nodeIndex
  final List<CircuitNode> nodes = [];
  int referenceNode = 0;

  static CircuitGraph build(ProjectModel project) {
    final uf = _UnionFind();

    // كل الأطراف الموجودة فعلياً حسب تعريف كل مكون
    for (final comp in project.components) {
      final def = componentCatalogById[comp.typeId];
      if (def == null) continue;
      for (final t in def.terminals) {
        uf.add(terminalKey(comp.id, t.id));
      }
      // العناصر التي تُعتبر "نقطة توزيع" داخلية تدمج أطرافها فيما بينها
      if (def.behavior == BehaviorKind.junctionBox) {
        final ids = def.terminals.map((t) => terminalKey(comp.id, t.id)).toList();
        for (var i = 1; i < ids.length; i++) {
          uf.union(ids.first, ids[i]);
        }
      } else if (def.behavior == BehaviorKind.distributionBoard) {
        final phaseBus = ['in_l', 'out1', 'out2', 'out3', 'out4']
            .map((t) => terminalKey(comp.id, t))
            .toList();
        for (var i = 1; i < phaseBus.length; i++) {
          uf.union(phaseBus.first, phaseBus[i]);
        }
      }
    }

    // دمج الأطراف المتصلة بأسلاك
    for (final wire in project.wires) {
      uf.add(terminalKey(wire.from.componentId, wire.from.terminalId));
      uf.add(terminalKey(wire.to.componentId, wire.to.terminalId));
      uf.union(
        terminalKey(wire.from.componentId, wire.from.terminalId),
        terminalKey(wire.to.componentId, wire.to.terminalId),
      );
    }

    final graph = CircuitGraph();
    final rootToIndex = <String, int>{};
    final rootKinds = <String, List<TerminalKind>>{};

    void ensureNode(String key, TerminalKind kind) {
      final root = uf.find(key);
      if (!rootToIndex.containsKey(root)) {
        rootToIndex[root] = graph.nodes.length;
        graph.nodes.add(CircuitNode(graph.nodes.length, {}, kind));
      }
      final idx = rootToIndex[root]!;
      graph.nodes[idx].terminalKeys.add(key);
      graph.terminalToNode[key] = idx;
      rootKinds.putIfAbsent(root, () => []).add(kind);
    }

    for (final comp in project.components) {
      final def = componentCatalogById[comp.typeId];
      if (def == null) continue;
      for (final t in def.terminals) {
        ensureNode(terminalKey(comp.id, t.id), t.kind);
      }
    }

    // اختيار عقدة مرجعية: أول عقدة تحوي طرف Neutral أو Ground إن وجدت
    var refIdx = 0;
    for (final n in graph.nodes) {
      if (n.terminalKeys.isNotEmpty) {
        final anyNeutralOrGround = rootKinds[uf.find(n.terminalKeys.first)]
                ?.any((k) => k == TerminalKind.neutral || k == TerminalKind.ground) ??
            false;
        if (anyNeutralOrGround) {
          refIdx = n.index;
          break;
        }
      }
    }
    graph.referenceNode = refIdx;
    return graph;
  }

  int? nodeOf(String componentId, String terminalId) => terminalToNode[terminalKey(componentId, terminalId)];
}
