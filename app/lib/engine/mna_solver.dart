/// حلّال دارات كهربائية مبسّط باستخدام طريقة العقد المعدّلة (Modified Nodal
/// Analysis) — هذا هو "المحرك الرياضي" الحقيقي وراء المحاكاة، وليس مجرد
/// تحريك رسوم. يقوم بحل مصفوفة التوصيل الكهربائي لإيجاد جهد كل عقدة
/// وتيار كل مصدر جهد في الدارة.
library mna_solver;

/// عنصر مقاومي/موصل بين عقدتين (سلك، مقاومة، مفتاح مغلق/مفتوح...)
class ResistiveEdge {
  final int nodeA;
  final int nodeB;
  final double conductanceSiemens; // 1/Ω
  final String ownerId; // معرف يساعد لاحقاً على استخراج التيار المار بهذا العنصر

  ResistiveEdge(this.nodeA, this.nodeB, this.conductanceSiemens, this.ownerId);
}

/// مصدر جهد مثالي بين عقدتين (بطارية/مصدر AC) — الأطراف A(+) و B(-)
class VoltageSourceEdge {
  final int nodeA;
  final int nodeB;
  final double voltage;
  final String ownerId;

  VoltageSourceEdge(this.nodeA, this.nodeB, this.voltage, this.ownerId);
}

class MnaResult {
  final List<double> nodeVoltages; // بالفهرسة الأصلية لكل العقد
  final Map<String, double> sourceCurrents; // ownerId -> current (A) من B إلى A داخلياً

  MnaResult(this.nodeVoltages, this.sourceCurrents);
}

class MnaSolver {
  static MnaResult solve({
    required int nodeCount,
    required int referenceNode,
    required List<ResistiveEdge> resistiveEdges,
    required List<VoltageSourceEdge> voltageSources,
  }) {
    // ترقيم العقد غير المرجعية 0..n-2
    final mapping = <int, int>{};
    var next = 0;
    for (var i = 0; i < nodeCount; i++) {
      if (i == referenceNode) continue;
      mapping[i] = next++;
    }
    final n = nodeCount - 1; // عدد عقد الجهد المجهولة
    final m = voltageSources.length; // عدد تيارات المصادر المجهولة
    final size = n + m;

    if (size == 0) {
      return MnaResult(List.filled(nodeCount, 0.0), {});
    }

    final a = List.generate(size, (_) => List<double>.filled(size, 0.0));
    final z = List<double>.filled(size, 0.0);

    void stampG(int node, int col, double value) {
      if (node == referenceNode) return;
      final r = mapping[node]!;
      a[r][col] += value;
    }

    for (final e in resistiveEdges) {
      final g = e.conductanceSiemens;
      if (e.nodeA != referenceNode) {
        final ra = mapping[e.nodeA]!;
        stampG(e.nodeA, ra, g);
        if (e.nodeB != referenceNode) stampG(e.nodeA, mapping[e.nodeB]!, -g);
      }
      if (e.nodeB != referenceNode) {
        final rb = mapping[e.nodeB]!;
        stampG(e.nodeB, rb, g);
        if (e.nodeA != referenceNode) stampG(e.nodeB, mapping[e.nodeA]!, -g);
      }
    }

    for (var k = 0; k < voltageSources.length; k++) {
      final vs = voltageSources[k];
      final col = n + k;
      if (vs.nodeA != referenceNode) {
        final ra = mapping[vs.nodeA]!;
        a[ra][col] += 1;
        a[col][ra] += 1;
      }
      if (vs.nodeB != referenceNode) {
        final rb = mapping[vs.nodeB]!;
        a[rb][col] += -1;
        a[col][rb] += -1;
      }
      z[col] = vs.voltage;
    }

    final x = _gaussianSolve(a, z);

    final voltages = List<double>.filled(nodeCount, 0.0);
    for (var i = 0; i < nodeCount; i++) {
      if (i == referenceNode) {
        voltages[i] = 0.0;
      } else {
        voltages[i] = x[mapping[i]!];
      }
    }

    final currents = <String, double>{};
    for (var k = 0; k < voltageSources.length; k++) {
      currents[voltageSources[k].ownerId] = x[n + k];
    }

    return MnaResult(voltages, currents);
  }

  /// حل نظام معادلات خطية Ax=z باستخدام الحذف الغاوسي مع اختيار المحور الجزئي
  static List<double> _gaussianSolve(List<List<double>> a, List<double> z) {
    final size = z.length;
    // نسخ لتفادي التعديل على المدخلات
    final m = List.generate(size, (i) => List<double>.from(a[i]));
    final b = List<double>.from(z);

    for (var col = 0; col < size; col++) {
      var pivotRow = col;
      var maxAbs = m[col][col].abs();
      for (var r = col + 1; r < size; r++) {
        final v = m[r][col].abs();
        if (v > maxAbs) {
          maxAbs = v;
          pivotRow = r;
        }
      }
      if (maxAbs < 1e-12) {
        // مصفوفة شبه منفردة (غالباً عقدة معزولة كهربائياً) — نتجاهلها بأمان
        continue;
      }
      if (pivotRow != col) {
        final tmp = m[col];
        m[col] = m[pivotRow];
        m[pivotRow] = tmp;
        final tb = b[col];
        b[col] = b[pivotRow];
        b[pivotRow] = tb;
      }
      final pivot = m[col][col];
      for (var r = col + 1; r < size; r++) {
        final factor = m[r][col] / pivot;
        if (factor == 0) continue;
        for (var c = col; c < size; c++) {
          m[r][c] -= factor * m[col][c];
        }
        b[r] -= factor * b[col];
      }
    }

    final x = List<double>.filled(size, 0.0);
    for (var i = size - 1; i >= 0; i--) {
      var sum = b[i];
      for (var j = i + 1; j < size; j++) {
        sum -= m[i][j] * x[j];
      }
      if (m[i][i].abs() < 1e-12) {
        x[i] = 0;
      } else {
        x[i] = sum / m[i][i];
      }
    }
    return x;
  }
}
