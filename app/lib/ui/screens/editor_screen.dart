import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/component_catalog.dart';
import '../../models/component_definition.dart';
import '../../models/component_instance.dart';
import '../../models/enums.dart';
import '../../models/project_model.dart';
import '../../state/app_settings.dart';
import '../../state/project_controller.dart';
import '../../state/projects_repository.dart';
import '../../state/simulation_controller.dart';
import '../widgets/circuit_canvas.dart';
import '../widgets/component_painter.dart';
import '../widgets/editor_chrome.dart';
import '../widgets/library_panel.dart';
import 'onboarding/safety_dialog.dart';

class EditorScreen extends StatefulWidget {
  final ProjectModel project;
  final ProjectsRepository repository;
  final AppSettings settings;

  /// عند فتح المحرر كجزء من تحدٍّ تعليمي (Learning) يُمرَّر معرف التحدي
  /// وتظهر أيقونة "إنهاء التحدي" التي تمنح XP وشارة عند الإنجاز.
  final String? missionId;
  final String? missionTitleAr;
  final String? missionHintAr;
  final int missionXp;
  final String? missionBadge;

  const EditorScreen({
    super.key,
    required this.project,
    required this.repository,
    required this.settings,
    this.missionId,
    this.missionTitleAr,
    this.missionHintAr,
    this.missionXp = 20,
    this.missionBadge,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late ProjectController controller;
  late SimulationController simController;
  final TransformationController _tc = TransformationController();

  final List<String> _recentTypeIds = [];
  final Set<String> _favoriteTypeIds = {};
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    controller = ProjectController(widget.project);
    simController = SimulationController(widget.project);
    controller.addListener(_onProjectChanged);
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 20), (_) => _save(silent: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowSafetyDialog();
      _maybeWarnHighVoltage();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    controller.removeListener(_onProjectChanged);
    controller.dispose();
    simController.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _onProjectChanged() {
    // إعادة ربط محرك المحاكاة إذا تغيّر المشروع كلياً (تراجع/إعادة/تحميل)
    if (!identical(simController.engine.project, controller.project)) {
      simController.rebind(controller.project);
    }
  }

  bool _hasHighVoltage() {
    for (final c in controller.project.components) {
      final v = c.properties['voltage'] ?? 0;
      if (v >= 230) return true;
    }
    return false;
  }

  bool _highVoltageWarned = false;

  void _maybeWarnHighVoltage() {
    if (_highVoltageWarned || !mounted) return;
    if (_hasHighVoltage()) {
      _highVoltageWarned = true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ هذه الدائرة تحتوي جهداً 230V/400V — تذكّر أن هذه محاكاة تعليمية فقط، والعمل الحقيقي يتطلب فنياً مؤهلاً.'),
        duration: Duration(seconds: 5),
      ));
    }
  }

  Future<void> _maybeShowSafetyDialog() async {
    if (widget.settings.safetyDialogShown) return;
    if (!mounted) return;
    await showDialog(context: context, barrierDismissible: false, builder: (_) => const SafetyDialog());
    await widget.settings.markSafetyDialogShown();
  }

  Future<void> _save({bool silent = false}) async {
    await widget.repository.save(controller.project);
    controller.markSaved();
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    }
  }

  Future<void> _renameProject() async {
    final textController = TextEditingController(text: controller.project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تسمية المشروع'),
        content: TextField(controller: textController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, textController.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      controller.renameProject(name.trim());
    }
  }

  int _addCascade = 0;

  void _addComponentAtCenter(String typeId) {
    // نضع المكون في منتصف الجزء الظاهر تقريباً من اللوحة (تحويل عبر مصفوفة العرض الحالية)
    // مع إزاحة تصاعدية بسيطة لتفادي تكديس عدة مكونات فوق بعضها عند الإضافة السريعة
    final cascadeOffset = Offset((_addCascade % 5) * 26.0, (_addCascade % 5) * 26.0);
    _addCascade++;
    final screenCenter = const Offset(220, 260) + cascadeOffset;
    final inverted = Matrix4.inverted(_tc.value);
    final canvasPoint = MatrixUtils.transformPoint(inverted, screenCenter);
    final comp = controller.addComponent(typeId, canvasPoint);
    _trackRecent(typeId);
    controller.selectOnly(comp.id);
    _maybeWarnHighVoltage();
  }

  void _trackRecent(String typeId) {
    setState(() {
      _recentTypeIds.remove(typeId);
      _recentTypeIds.insert(0, typeId);
      if (_recentTypeIds.length > 10) _recentTypeIds.removeLast();
    });
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.warning.withOpacity(0.9)));
  }

  void _openComponentProperties(ComponentInstance comp) {
    final def = componentCatalogById[comp.typeId];
    if (def == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _ComponentPropertiesSheet(controller: controller, comp: comp, def: def),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: EditorTopBar(
        projectName: controller.project.name,
        controller: controller,
        simController: simController,
        realistic: controller.project.realisticMode,
        onRename: _renameProject,
        onSave: () => _save(),
        onToggleMode: () => controller.toggleRealisticMode(),
        onOpenWirePanel: _openWirePanel,
        onOpenComponents: _openComponentLibrary,
        onOpenTools: _openToolsSheet,
        onBack: () async {
          await _save(silent: true);
          if (mounted) Navigator.pop(context);
        },
      ),
      // الـCanvas يأخذ كامل مساحة الشاشة الآن؛ لا توجد أي قائمة ثابتة أسفل
      // الشاشة — المكونات/الأسلاك/الأدوات تُفتح كنوافذ منزلقة (Bottom Sheet)
      // عند الحاجة فقط، وتختفي بالكامل بعد إغلاقها.
      body: Stack(
        children: [
          Positioned.fill(
            child: CircuitCanvas(
              controller: controller,
              simController: simController,
              realistic: controller.project.realisticMode,
              transformationController: _tc,
              onWarning: _showWarning,
              onComponentLongPress: _openComponentProperties,
              onComponentDoubleTap: _openComponentProperties,
            ),
          ),
          AnimatedBuilder(
            animation: simController,
            builder: (context, _) => FaultBanner(faults: simController.lastFaults),
          ),
        ],
      ),
      floatingActionButton: widget.missionId == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.missionHintAr != null) ...[
                  FloatingActionButton.small(
                    heroTag: 'hint',
                    backgroundColor: AppColors.surfaceAlt,
                    foregroundColor: AppColors.warning,
                    onPressed: _showHint,
                    child: const Icon(Icons.lightbulb),
                  ),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton.extended(
                  heroTag: 'complete',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  onPressed: _completeMission,
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('إنهاء التحدي'),
                ),
              ],
            ),
    );
  }

  void _showHint() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lightbulb, color: AppColors.warning, size: 36),
        title: const Text('تلميح'),
        content: Text(widget.missionHintAr ?? ''),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
      ),
    );
  }

  Future<void> _completeMission() async {
    if (widget.settings.completedMissions.contains(widget.missionId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنجزت هذا التحدي من قبل ✅')));
      return;
    }
    await widget.settings.completeMission(widget.missionId!, xpReward: widget.missionXp, badge: widget.missionBadge);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.celebration, color: AppColors.primary, size: 40),
        title: const Text('أحسنت! 🎉'),
        content: Text('أكملت "${widget.missionTitleAr ?? 'التحدي'}" وحصلت على ${widget.missionXp} نقطة خبرة (XP).'),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('متابعة')),
        ],
      ),
    );
  }

  /// شريط سحب صغير أعلى أي Bottom Sheet — تفصيل بصري احترافي يدل أن
  /// النافذة قابلة للسحب للإغلاق.
  Widget _sheetHandle() => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
      );

  /// يفتح مكتبة المكونات الاحترافية كنافذة منزلقة من الأسفل (Drawer) بدل
  /// شريط ثابت يأكل مساحة الشاشة. الضغط على أي مكون يضيفه للّوحة ويُغلق
  /// النافذة تلقائياً حتى يعود الـCanvas كاملاً على الفور.
  void _openComponentLibrary() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.86,
        child: Column(
          children: [
            _sheetHandle(),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('🧩  مكتبة المكونات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Expanded(
              child: ComponentLibraryPanel(
                controller: controller,
                recentTypeIds: _recentTypeIds,
                favoriteTypeIds: _favoriteTypeIds,
                onToggleFavorite: (id) => setState(() {
                  if (_favoriteTypeIds.contains(id)) {
                    _favoriteTypeIds.remove(id);
                  } else {
                    _favoriteTypeIds.add(id);
                  }
                }),
                onQuickAdd: (typeId) {
                  _addComponentAtCenter(typeId);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// يفتح لائحة الأسلاك الحالية (عرض/تحديد/حذف) كنافذة منزلقة
  void _openWirePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.55,
        child: Column(
          children: [
            _sheetHandle(),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('🔌  الأسلاك في هذا المشروع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('اضغط على طرفين متتاليين في اللوحة لتوصيل سلك بينهما مباشرة.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ),
            Expanded(child: _WirePanel(controller: controller)),
          ],
        ),
      ),
    );
  }

  /// يفتح قائمة "الأدوات" الموحّدة: تحرير (تراجع/تكبير/نسخ/تدوير/حذف...) +
  /// وضع العرض + أجهزة القياس + التحكم بالمحاكاة — كل ما ليس من الأساسيات
  /// الخمسة الظاهرة دائماً في الشريط العلوي.
  void _openToolsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _sheetHandle()),
              _toolsSectionTitle('أدوات التحرير'),
              ToolsPanelBar(
                controller: controller,
                transformationController: _tc,
                realistic: controller.project.realisticMode,
                onToggleMode: () => controller.toggleRealisticMode(),
              ),
              const Divider(height: 20),
              _toolsSectionTitle('أجهزة القياس (اضغط لإضافة)'),
              MeasurePanelBar(
                onAddMeter: (typeId) {
                  _addComponentAtCenter(typeId);
                  Navigator.of(sheetContext).pop();
                },
              ),
              const Divider(height: 20),
              _toolsSectionTitle('التحكم بالمحاكاة'),
              SimulationPanelBar(simController: simController),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolsSectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
      );
}

class _WirePanel extends StatelessWidget {
  final ProjectController controller;
  const _WirePanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final wires = controller.project.wires;
        return Container(
          color: AppColors.surface,
          child: wires.isEmpty
              ? const Center(
                  child: Text('اضغط على طرفين لتوصيل سلك بينهما', style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  itemCount: wires.length,
                  itemBuilder: (context, i) {
                    final w = wires[i];
                    final selected = controller.selectedWireId == w.id;
                    return ListTile(
                      dense: true,
                      selected: selected,
                      leading: Container(width: 14, height: 14, decoration: BoxDecoration(color: Color(w.colorValue), shape: BoxShape.circle)),
                      title: Text('${w.from} → ${w.to}', style: const TextStyle(fontSize: 12)),
                      subtitle: Text('${w.kind.label} · ${w.crossSectionMm2} mm²', style: const TextStyle(fontSize: 11)),
                      onTap: () => controller.selectWire(w.id),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                        onPressed: () => controller.deleteWire(w.id),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _ComponentPropertiesSheet extends StatefulWidget {
  final ProjectController controller;
  final ComponentInstance comp;
  final ComponentDefinition def;

  const _ComponentPropertiesSheet({required this.controller, required this.comp, required this.def});

  @override
  State<_ComponentPropertiesSheet> createState() => _ComponentPropertiesSheetState();
}

class _ComponentPropertiesSheetState extends State<_ComponentPropertiesSheet> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.comp.customName ?? widget.def.nameAr);
  }

  @override
  Widget build(BuildContext context) {
    final comp = widget.comp;
    final def = widget.def;
    final needsLink = def.behavior == BehaviorKind.contactorContactNO ||
        def.behavior == BehaviorKind.contactorContactNC ||
        def.behavior == BehaviorKind.relayContactNO ||
        def.behavior == BehaviorKind.relayContactNC;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CustomPaint(
                    painter: ComponentPainter(
                      def: def,
                      comp: comp,
                      realistic: widget.controller.project.realisticMode,
                      selected: false,
                      animPhase: 0,
                      showTerminalLabels: false,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'اسم المكون'),
                    onSubmitted: (v) => widget.controller.renameComponent(comp.id, v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(def.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Divider(height: 28),
            if (def.defaultProperties.isEmpty) const Text('لا توجد خصائص قابلة للتعديل لهذا المكون'),
            ...def.defaultProperties.keys.map((key) => _propertyEditor(key)),
            if (needsLink) ...[
              const SizedBox(height: 8),
              const Text('ربط بملف الكونتاكتور/الريليه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _coilPicker(),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      widget.controller.rotateSelected();
                    },
                    icon: const Icon(Icons.rotate_right),
                    label: const Text('تدوير'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.controller.selectOnly(comp.id);
                      widget.controller.deleteSelected();
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                    icon: const Icon(Icons.delete),
                    label: const Text('حذف'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _propertyEditor(String key) {
    final double value = widget.comp.properties[key] ?? widget.def.defaultProperties[key] ?? 0.0;
    final valueController = TextEditingController(text: _formatNum(value));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(_labelForKey(key))),
          Expanded(
            flex: 3,
            child: TextField(
              controller: valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true),
              onSubmitted: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) {
                  widget.controller.updateComponentProperty(widget.comp.id, key, parsed);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  String _labelForKey(String key) {
    const map = {
      'voltage': 'الجهد (V)',
      'frequency': 'التردد (Hz)',
      'internalResistance': 'المقاومة الداخلية (Ω)',
      'resistance': 'المقاومة (Ω)',
      'ratedCurrent': 'التيار المقنن (A)',
      'ratedPower': 'القدرة المقننة (W)',
      'ratedVoltage': 'الجهد المقنن (V)',
      'poleCount': 'عدد الأقطاب',
      'isSpdt': 'مفتاح تبادلي (0/1)',
      'capacitanceUf': 'السعة (µF)',
      'setPoint': 'نقطة الضبط',
      'currentTemp': 'الحرارة الحالية',
      'delaySeconds': 'زمن التأخير (ثانية)',
      'targetCount': 'العدد المستهدف',
    };
    return map[key] ?? key;
  }

  Widget _coilPicker() {
    final coilCandidates = widget.controller.project.components.where((c) {
      final d = componentCatalogById[c.typeId];
      return d != null && (d.behavior == BehaviorKind.contactorCoil || d.behavior == BehaviorKind.relayCoil);
    }).toList();
    if (coilCandidates.isEmpty) {
      return const Text('لا يوجد ملف كونتاكتور/ريليه في المشروع بعد', style: TextStyle(color: AppColors.textSecondary, fontSize: 12));
    }
    final currentLink = widget.comp.links['coil'];
    return Wrap(
      spacing: 8,
      children: coilCandidates.map((c) {
        final def = componentCatalogById[c.typeId]!;
        final selected = currentLink == c.id;
        return ChoiceChip(
          label: Text(c.customName ?? def.nameAr, style: const TextStyle(fontSize: 12)),
          selected: selected,
          onSelected: (_) => widget.controller.linkComponent(widget.comp.id, 'coil', c.id),
        );
      }).toList(),
    );
  }
}
