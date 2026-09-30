import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../state/app_settings.dart';
import '../../state/project_controller.dart' show defaultWireColors;

const String kAppVersion = '1.0.0 (build 1)';

const _presetColors = [
  Color(0xFFE53935),
  Color(0xFFFF5470),
  Color(0xFFFB8C00),
  Color(0xFFFFC24B),
  Color(0xFF43A047),
  Color(0xFF00E5A8),
  Color(0xFF1E88E5),
  Color(0xFF3D9CFF),
  Color(0xFF8E24AA),
  Color(0xFF212121),
  Color(0xFF9E9E9E),
  Color(0xFFFFFFFF),
];

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _pickColor(TerminalKind kind) async {
    final chosen = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('لون سلك ${kind.label}'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _presetColors
              .map((c) => GestureDetector(
                    onTap: () => Navigator.pop(context, c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
    if (chosen != null) {
      await widget.settings.setWireColor(kind, chosen);
      setState(() {});
    }
  }

  Future<void> _confirmResetProgress() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة ضبط التقدّم'),
        content: const Text('سيتم حذف كل نقاط الخبرة (XP) والشارات والتحديات المُنجزة. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.settings.resetProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('المظهر'),
          const Card(
            color: AppColors.surfaceAlt,
            child: ListTile(
              leading: Icon(Icons.dark_mode, color: AppColors.primary),
              title: Text('الوضع الداكن'),
              subtitle: Text('مفعّل دائماً لأفضل تجربة بصرية احترافية'),
              trailing: Icon(Icons.check_circle, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('ألوان الأسلاك حسب النوع'),
          Card(
            color: AppColors.surfaceAlt,
            child: Column(
              children: TerminalKind.values
                  .map((k) => ListTile(
                        leading: Container(width: 22, height: 22, decoration: BoxDecoration(color: defaultWireColors[k], shape: BoxShape.circle)),
                        title: Text(k.label),
                        trailing: const Icon(Icons.edit, size: 18),
                        onTap: () => _pickColor(k),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('التقدّم التعليمي'),
          AnimatedBuilder(
            animation: widget.settings,
            builder: (context, _) => Card(
              color: AppColors.surfaceAlt,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.military_tech, color: AppColors.primary),
                    title: Text('المستوى ${widget.settings.level} · ${widget.settings.xp} XP'),
                    subtitle: Text('${widget.settings.completedMissions.length} تحدٍّ مكتمل · ${widget.settings.badges.length} شارة'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore, color: AppColors.danger),
                    title: const Text('إعادة ضبط التقدّم', style: TextStyle(color: AppColors.danger)),
                    onTap: _confirmResetProgress,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('السلامة والمسؤولية'),
          const Card(
            color: AppColors.surfaceAlt,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'هذا التطبيق أداة تعليمية للمحاكاة فقط. أي عمل كهربائي حقيقي (خصوصاً 230V/400V) يجب أن يُنفَّذ حصرياً بواسطة فني كهرباء مؤهل ومرخّص مع اتباع معايير السلامة.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('حول التطبيق'),
          Card(
            color: AppColors.surfaceAlt,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('ElectroSim Pro'),
              subtitle: const Text(kAppVersion),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary)),
      );
}
