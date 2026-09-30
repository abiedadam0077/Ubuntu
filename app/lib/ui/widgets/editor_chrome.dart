import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/detected_fault.dart';
import '../../models/enums.dart';
import '../../state/project_controller.dart';
import '../../state/simulation_controller.dart';

/// الشريط العلوي: اسم المشروع + شريط أدوات مبسّط بحسب التصميم الاحترافي
/// المطلوب: ← رجوع | 🔌 أسلاك | 🧩 مكونات | 🔧 أدوات | 💾 حفظ | ▶ تشغيل
/// (باقي الأدوات: تراجع/إعادة/تكبير/تدوير/حذف/وضع العرض... داخل قائمة
/// "أدوات" حتى يبقى الشريط بسيطاً ولا يُتعب الشاشة، والـCanvas يأخذ بقية
/// المساحة كاملة).
class EditorTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String projectName;
  final ProjectController controller;
  final SimulationController simController;
  final bool realistic;
  final VoidCallback onRename;
  final VoidCallback onSave;
  final VoidCallback onToggleMode;
  final VoidCallback onBack;
  final VoidCallback onOpenWirePanel;
  final VoidCallback onOpenComponents;
  final VoidCallback onOpenTools;

  const EditorTopBar({
    super.key,
    required this.projectName,
    required this.controller,
    required this.simController,
    required this.realistic,
    required this.onRename,
    required this.onSave,
    required this.onToggleMode,
    required this.onBack,
    required this.onOpenWirePanel,
    required this.onOpenComponents,
    required this.onOpenTools,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack, tooltip: 'رجوع'),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: onRename,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(projectName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 13, color: AppColors.textSecondary),
          ],
        ),
      ),
      actions: [
        IconButton(tooltip: 'الأسلاك', icon: const Icon(Icons.cable), onPressed: onOpenWirePanel),
        IconButton(tooltip: 'المكونات', icon: const Icon(Icons.widgets), onPressed: onOpenComponents),
        IconButton(tooltip: 'أدوات', icon: const Icon(Icons.build), onPressed: onOpenTools),
        IconButton(tooltip: 'حفظ', icon: const Icon(Icons.save), onPressed: onSave),
        AnimatedBuilder(
          animation: simController,
          builder: (context, _) {
            final running = simController.status == SimulationStatus.running;
            return IconButton(
              tooltip: running ? 'إيقاف مؤقت' : 'تشغيل المحاكاة',
              icon: Icon(running ? Icons.pause_circle : Icons.play_circle, color: AppColors.primary, size: 28),
              onPressed: () => running ? simController.pause() : simController.start(),
            );
          },
        ),
      ],
    );
  }
}

/// لوحة الأدوات: تراجع/إعادة، تكبير/تصغير، محاذاة، نسخ/لصق، تكرار، تدوير،
/// حذف، قفل، وضع العرض (واقعي/رمزي) — كل أدوات التحرير المتقدمة مجمّعة هنا
/// بدل تشتيتها في شريط علوي مزدحم.
class ToolsPanelBar extends StatelessWidget {
  final ProjectController controller;
  final TransformationController transformationController;
  final bool realistic;
  final VoidCallback onToggleMode;

  const ToolsPanelBar({
    super.key,
    required this.controller,
    required this.transformationController,
    required this.realistic,
    required this.onToggleMode,
  });

  void _zoom(double factor) {
    final m = Matrix4.copy(transformationController.value)..scale(factor);
    transformationController.value = m;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            _btn(Icons.undo, 'تراجع', controller.canUndo ? controller.undo : null),
            _btn(Icons.redo, 'إعادة', controller.canRedo ? controller.redo : null),
            _btn(realistic ? Icons.photo_camera_back : Icons.schema, realistic ? 'واقعي' : 'رمزي', onToggleMode),
            _btn(Icons.zoom_in, 'تكبير', () => _zoom(1.2)),
            _btn(Icons.zoom_out, 'تصغير', () => _zoom(0.8)),
            _btn(Icons.center_focus_strong, 'إعادة ضبط العرض', () => transformationController.value = Matrix4.identity()),
            _btn(Icons.content_copy, 'نسخ', controller.copySelected),
            _btn(Icons.content_paste, 'لصق', controller.pasteClipboard),
            _btn(Icons.copy_all, 'تكرار', controller.duplicateSelected),
            _btn(Icons.rotate_90_degrees_ccw, 'تدوير', controller.rotateSelected),
            _btn(Icons.lock, 'قفل/فتح', controller.toggleLockSelected),
            _btn(Icons.delete, 'حذف', controller.deleteSelected, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback? onTap, {bool danger = false}) {
    final disabled = onTap == null;
    return SizedBox(
      width: 78,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: BorderSide(color: disabled ? Colors.white12 : (danger ? AppColors.danger.withOpacity(0.5) : Colors.white24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: disabled ? Colors.white24 : (danger ? AppColors.danger : AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: disabled ? Colors.white24 : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// لوحة القياس: اختيار نوع جهاز القياس لإضافته للوحة
class MeasurePanelBar extends StatelessWidget {
  final ValueChanged<String> onAddMeter;

  const MeasurePanelBar({super.key, required this.onAddMeter});

  static const meters = [
    ['multimeter', 'مالتيميتر'],
    ['voltmeter', 'فولتميتر'],
    ['ammeter', 'أميتر'],
    ['ohmmeter', 'أوميتر'],
    ['clamp_meter', 'كلامب ميتر'],
    ['wattmeter', 'واطميتر'],
    ['frequency_meter', 'تردد'],
    ['energy_meter', 'عداد كهرباء'],
    ['oscilloscope', 'راسم إشارة'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(10),
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: meters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = meters[i];
          return GestureDetector(
            onTap: () => onAddMeter(m[0]),
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.speed, color: AppColors.secondary),
                  const SizedBox(height: 6),
                  Text(m[1], style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// لوحة التحكم بالمحاكاة: تشغيل/إيقاف مؤقت/إيقاف/إعادة ضبط + القدرة الكلية
class SimulationPanelBar extends StatelessWidget {
  final SimulationController simController;

  const SimulationPanelBar({super.key, required this.simController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: simController,
      builder: (context, _) {
        final status = simController.status;
        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _actionBtn(Icons.play_arrow, 'تشغيل', status == SimulationStatus.running ? null : simController.start),
              _actionBtn(Icons.pause, 'إيقاف مؤقت', status == SimulationStatus.running ? simController.pause : null),
              _actionBtn(Icons.stop, 'إيقاف', status == SimulationStatus.idle ? null : simController.stop),
              _actionBtn(Icons.refresh, 'إعادة ضبط', simController.reset),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${simController.totalPowerW.toStringAsFixed(0)} W',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  Text(_statusLabel(status), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(SimulationStatus s) {
    switch (s) {
      case SimulationStatus.idle:
        return 'جاهز';
      case SimulationStatus.running:
        return 'قيد التشغيل';
      case SimulationStatus.paused:
        return 'متوقف مؤقتاً';
      case SimulationStatus.stopped:
        return 'متوقف';
      case SimulationStatus.fault:
        return 'يوجد خطأ ⚠️';
    }
  }

  Widget _actionBtn(IconData icon, String tooltip, VoidCallback? onTap) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon),
      color: onTap == null ? Colors.white24 : AppColors.textPrimary,
    );
  }
}

/// شريط عرض الأخطاء المكتشفة أثناء المحاكاة، مع شرح المشكلة والحل المقترح
class FaultBanner extends StatelessWidget {
  final List<DetectedFault> faults;
  final ValueChanged<DetectedFault>? onTapFault;

  const FaultBanner({super.key, required this.faults, this.onTapFault});

  @override
  Widget build(BuildContext context) {
    if (faults.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Column(
        children: faults
            .take(3)
            .map((f) => Card(
                  color: AppColors.danger.withOpacity(0.16),
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTapFault == null ? null : () => onTapFault!(f),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.titleAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('المشكلة: ${f.problemAr}', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('الحل: ${f.solutionAr}',
                              style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
