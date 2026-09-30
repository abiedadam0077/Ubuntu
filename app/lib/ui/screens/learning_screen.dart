import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../models/component_instance.dart';
import '../../models/project_model.dart';
import '../../state/app_settings.dart';
import '../../state/projects_repository.dart';
import 'editor_screen.dart';
import 'fault_screen.dart';

const _uuid = Uuid();

class _Mission {
  final String id;
  final String titleAr;
  final String descriptionAr;
  final int stars;
  final int xp;
  final ProjectModel Function() build;

  const _Mission({
    required this.id,
    required this.titleAr,
    required this.descriptionAr,
    required this.stars,
    required this.xp,
    required this.build,
  });
}

ComponentInstance _place(String typeId, Offset pos) => ComponentInstance(id: _uuid.v4(), typeId: typeId, position: pos);

List<_Mission> _buildMissions() => [
      _Mission(
        id: 'lesson_lamp_switch',
        titleAr: 'مصباح + مفتاح',
        descriptionAr: 'وصّل مصدر AC بمفتاح ثم بمصباح لإضاءته، وشغّل المحاكاة ثم اضغط على المفتاح.',
        stars: 1,
        xp: 20,
        build: () => ProjectModel(id: _uuid.v4(), name: 'تحدي: مصباح ومفتاح')
          ..components.addAll([
            _place('ac_power_supply_1ph', const Offset(200, 300)),
            _place('switch_single', const Offset(450, 260)),
            _place('lamp_incandescent', const Offset(700, 300)),
          ]),
      ),
      _Mission(
        id: 'lesson_two_lamps',
        titleAr: 'مصباحان بمفتاحين',
        descriptionAr: 'تحكّم بكل مصباح عبر مفتاحه المستقل من نفس مصدر التغذية.',
        stars: 2,
        xp: 30,
        build: () => ProjectModel(id: _uuid.v4(), name: 'تحدي: مصباحان ومفتاحان')
          ..components.addAll([
            _place('ac_power_supply_1ph', const Offset(180, 380)),
            _place('switch_single', const Offset(420, 260)),
            _place('lamp_incandescent', const Offset(660, 260)),
            _place('switch_single', const Offset(420, 500)),
            _place('lamp_incandescent', const Offset(660, 500)),
          ]),
      ),
      _Mission(
        id: 'lesson_motor_start_stop',
        titleAr: 'تشغيل/إيقاف محرك بالكونتاكتور',
        descriptionAr:
            'استخدم زر تشغيل (NO) وزر إيقاف (NC) للتحكم بملف الكونتاكتور، ثم وصّل تلامس مساعد (NO) موازياً لزر التشغيل للإمساك الذاتي (Self-Hold)، ووصّل تلامسات القوة للمحرك.',
        stars: 3,
        xp: 50,
        build: () => ProjectModel(id: _uuid.v4(), name: 'تحدي: تشغيل/إيقاف محرك')
          ..components.addAll([
            _place('ac_power_supply_3ph', const Offset(160, 420)),
            _place('push_button_no', const Offset(420, 220)),
            _place('push_button_nc', const Offset(420, 340)),
            _place('contactor', const Offset(680, 300)),
            _place('contactor_aux_no', const Offset(680, 460)),
            _place('relay_thermal', const Offset(920, 300)),
            _place('motor_3ph', const Offset(1160, 300)),
          ]),
      ),
      _Mission(
        id: 'lesson_star_delta',
        titleAr: 'دائرة Star/Delta',
        descriptionAr: 'ابنِ دائرة بدء نجمة-مثلث لتخفيف تيار الإقلاع لمحرك ثلاثي الطور.',
        stars: 4,
        xp: 70,
        build: () => ProjectModel(id: _uuid.v4(), name: 'تحدي: Star/Delta')
          ..components.addAll([
            _place('ac_power_supply_3ph', const Offset(160, 340)),
            _place('star_delta_starter', const Offset(500, 340)),
            _place('motor_3ph', const Offset(860, 340)),
          ]),
      ),
    ];

class LearningScreen extends StatelessWidget {
  final AppSettings settings;
  final ProjectsRepository repository;

  const LearningScreen({super.key, required this.settings, required this.repository});

  @override
  Widget build(BuildContext context) {
    final missions = _buildMissions();
    return Scaffold(
      appBar: AppBar(title: const Text('التعلّم والتحديات')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _progressCard(),
              const SizedBox(height: 18),
              const Text('دروس تدريجية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              ...missions.map((m) => _missionCard(context, m)),
              const SizedBox(height: 18),
              Card(
                color: AppColors.surfaceAlt,
                child: ListTile(
                  leading: const Icon(Icons.bug_report, color: AppColors.warning),
                  title: const Text('تحدي: اكتشف العطل'),
                  subtitle: const Text('عطل عشوائي في لوحة كهربائية — اكتشفه وأصلحه'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FaultSimulationScreen(repository: repository, settings: settings))),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _progressCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 28, backgroundColor: Colors.black26, child: Icon(Icons.bolt, color: Colors.white, size: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المستوى ${settings.level}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: settings.progressToNextLevel.clamp(0.0, 1.0).toDouble(),
                    backgroundColor: Colors.black26,
                    color: Colors.black87,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text('${settings.xp} XP · ${settings.badges.length} شارة', style: const TextStyle(color: Colors.black87, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _missionCard(BuildContext context, _Mission m) {
    final done = settings.completedMissions.contains(m.id);
    return Card(
      color: AppColors.surfaceAlt,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: done ? AppColors.primary.withOpacity(0.2) : AppColors.bg,
          child: Icon(done ? Icons.check_circle : Icons.play_circle_outline, color: done ? AppColors.primary : AppColors.textSecondary),
        ),
        title: Text(m.titleAr),
        subtitle: Text(m.descriptionAr, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(m.stars, (i) => const Icon(Icons.star, color: AppColors.warning, size: 14)),
            const SizedBox(width: 4),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditorScreen(
              project: m.build(),
              repository: repository,
              settings: settings,
              missionId: m.id,
              missionTitleAr: m.titleAr,
              missionXp: m.xp,
              missionBadge: '${m.id}_badge',
            ),
          ),
        ),
      ),
    );
  }
}
