import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../models/component_instance.dart';
import '../../models/enums.dart';
import '../../models/project_model.dart';
import '../../models/wire_model.dart';
import '../../state/app_settings.dart';
import '../../state/project_controller.dart' show defaultWireColors;
import '../../state/projects_repository.dart';
import 'editor_screen.dart';

const _uuid = Uuid();
final _rng = Random();

class _FaultKind {
  final String id;
  final String titleAr;
  final String hintAr;
  final void Function(ProjectModel p, Map<String, String> ids) apply;

  const _FaultKind({required this.id, required this.titleAr, required this.hintAr, required this.apply});
}

/// يبني لوحة كهربائية صحيحة ومغذّاة بالكامل:
/// مصدر AC → قاطع رئيسي → RCD → MCB → كونتاكتور → ريليه حراري → محرك
/// (تحقيقاً للمتطلب: إمكانية بناء لوحة كهربائية كاملة واختبارها)
({ProjectModel project, Map<String, String> ids}) _buildCorrectBoard() {
  final ids = <String, String>{
    'src': _uuid.v4(),
    'main': _uuid.v4(),
    'rcd': _uuid.v4(),
    'mcb': _uuid.v4(),
    'contactor': _uuid.v4(),
    'thermal': _uuid.v4(),
    'motor': _uuid.v4(),
  };

  final project = ProjectModel(id: _uuid.v4(), name: 'تحدي: اكتشف العطل')
    ..components.addAll([
      ComponentInstance(id: ids['src']!, typeId: 'ac_power_supply_1ph', position: const Offset(120, 360)),
      ComponentInstance(id: ids['main']!, typeId: 'breaker_main', position: const Offset(340, 260)),
      ComponentInstance(id: ids['rcd']!, typeId: 'rcd', position: const Offset(540, 360)),
      ComponentInstance(id: ids['mcb']!, typeId: 'breaker_mcb', position: const Offset(760, 260)),
      ComponentInstance(id: ids['contactor']!, typeId: 'contactor', position: const Offset(980, 360)),
      ComponentInstance(id: ids['thermal']!, typeId: 'relay_thermal', position: const Offset(1200, 360)),
      ComponentInstance(id: ids['motor']!, typeId: 'motor_1ph', position: const Offset(1420, 360)),
    ]);

  void wire(String fromComp, String fromTerm, String toComp, String toTerm, {TerminalKind kind = TerminalKind.phase}) {
    project.wires.add(WireModel(
      id: _uuid.v4(),
      from: TerminalRef(componentId: fromComp, terminalId: fromTerm),
      to: TerminalRef(componentId: toComp, terminalId: toTerm),
      kind: kind,
      colorValue: (defaultWireColors[kind] ?? const Color(0xFF9E9E9E)).toARGB32(),
    ));
  }

  wire(ids['src']!, 'l', ids['main']!, 'a');
  wire(ids['main']!, 'b', ids['rcd']!, 'l_in');
  wire(ids['src']!, 'n', ids['rcd']!, 'n_in', kind: TerminalKind.neutral);
  wire(ids['rcd']!, 'l_out', ids['mcb']!, 'a');
  wire(ids['mcb']!, 'b', ids['contactor']!, 'l1');
  wire(ids['mcb']!, 'b', ids['contactor']!, 'a1', kind: TerminalKind.control);
  wire(ids['contactor']!, 't1', ids['thermal']!, 'l1');
  wire(ids['thermal']!, 't1', ids['motor']!, 'a');
  wire(ids['rcd']!, 'n_out', ids['motor']!, 'b', kind: TerminalKind.neutral);
  wire(ids['rcd']!, 'n_out', ids['contactor']!, 'a2', kind: TerminalKind.neutral);

  return (project: project, ids: ids);
}

List<_FaultKind> _faultKinds() => [
      _FaultKind(
        id: 'short_circuit',
        titleAr: 'قصر دائرة (Short Circuit)',
        hintAr: 'يوجد سلك زائد يوصل خط الطور مباشرة بخط التعادل بعد قاطع MCB بدون أي حمل بينهما — احذفه.',
        apply: (p, ids) {
          p.wires.add(WireModel(
            id: _uuid.v4(),
            from: TerminalRef(componentId: ids['mcb']!, terminalId: 'b'),
            to: TerminalRef(componentId: ids['rcd']!, terminalId: 'n_out'),
            kind: TerminalKind.generic,
            colorValue: const Color(0xFFFF5470).toARGB32(),
          ));
        },
      ),
      _FaultKind(
        id: 'overload',
        titleAr: 'تحميل زائد (Overload)',
        hintAr: 'قدرة المحرك المضبوطة أعلى بكثير من الطبيعي مما يسحب تياراً يفوق قدرة القاطع MCB — أعد قيمة "القدرة المقننة" إلى حدود 750W من قائمة خصائص المحرك.',
        apply: (p, ids) {
          final motor = p.components.firstWhere((c) => c.id == ids['motor']);
          motor.properties['ratedPower'] = 4200;
        },
      ),
      _FaultKind(
        id: 'wire_cut',
        titleAr: 'قطع في التوصيل (Broken Wire)',
        hintAr: 'سلك عودة التعادل (Neutral) من RCD إلى المحرك مفقود — أعد توصيله من نقطة N-OUT في الـRCD إلى الطرف B في المحرك.',
        apply: (p, ids) {
          p.wires.removeWhere((w) => w.from.componentId == ids['rcd'] && w.from.terminalId == 'n_out' && w.to.componentId == ids['motor']);
        },
      ),
    ];

class FaultSimulationScreen extends StatelessWidget {
  final ProjectsRepository repository;
  final AppSettings settings;

  const FaultSimulationScreen({super.key, required this.repository, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('محاكاة الأعطال')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bug_report, color: AppColors.warning, size: 48),
            const SizedBox(height: 16),
            const Text('لوحة كهربائية كاملة: مصدر → قاطع رئيسي → RCD → MCB → كونتاكتور → ريليه حراري → محرك',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            const Text(
              'سيتم حقن عطل عشوائي واحد في هذه اللوحة (قصر دائرة، تحميل زائد، أو قطع توصيل). مهمتك: شغّل المحاكاة، لاحظ سلوك القاطع/المحرك، اكتشف مكان العطل، أصلحه، ثم أعد التشغيل للتأكد أن كل شيء يعمل بأمان.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startChallenge(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('ابدأ تحدياً جديداً'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startChallenge(BuildContext context) {
    final built = _buildCorrectBoard();
    final kinds = _faultKinds();
    final fault = kinds[_rng.nextInt(kinds.length)];
    fault.apply(built.project, built.ids);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          project: built.project,
          repository: repository,
          settings: settings,
          missionId: 'fault_${fault.id}_${DateTime.now().millisecondsSinceEpoch}',
          missionTitleAr: 'اكتشف العطل: ${fault.titleAr}',
          missionHintAr: fault.hintAr,
          missionXp: 40,
          missionBadge: 'fault_hunter',
        ),
      ),
    );
  }
}
