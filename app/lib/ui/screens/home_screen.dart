import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../state/app_settings.dart';
import '../../state/projects_repository.dart';
import 'editor_screen.dart';
import 'fault_screen.dart';
import 'learning_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppSettings settings;
  final ProjectsRepository repository;

  const HomeScreen({super.key, required this.settings, required this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProjectSummary> _projects = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await widget.repository.listProjects();
      if (!mounted) return;
      setState(() {
        _projects = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'تعذّر تحميل قائمة المشاريع: $e';
        _loading = false;
      });
    }
  }

  Future<void> _createProject() async {
    final controller = TextEditingController(text: 'مشروع جديد');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مشروع جديد'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المشروع')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('إنشاء')),
        ],
      ),
    );
    debugPrint('DEBUG _createProject: showDialog returned name="$name"');
    if (name == null || name.trim().isEmpty) return;
    try {
      final project = await widget.repository.createNew(name.trim());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditorScreen(project: project, repository: widget.repository, settings: widget.settings)),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر إنشاء المشروع: $e')));
    }
  }

  Future<void> _openProject(String id) async {
    try {
      final project = await widget.repository.load(id);
      if (project == null || !mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditorScreen(project: project, repository: widget.repository, settings: widget.settings)),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر فتح المشروع: $e')));
    }
  }

  Future<void> _importProject() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty || result.single.path == null) return;
      await widget.repository.importFromFile(result.single.path!);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاستيراد: $e')));
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
  }

  void _showProjectMenu(ProjectSummary p) {
    // نلتقط سياق الشاشة الرئيسية الثابت (وليس سياق الـbottom sheet العابر)
    // لاستخدامه لاحقاً في أي showDialog/SnackBar بعد إغلاق القائمة، لتفادي
    // أي استخدام لسياق تمّ تفكيكه (unmounted) بعد إغلاق الورقة السفلية.
    final rootContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('إعادة تسمية'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final controller = TextEditingController(text: p.name);
                  final name = await showDialog<String>(
                    context: rootContext,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('إعادة تسمية المشروع'),
                      content: TextField(controller: controller, autofocus: true),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
                        ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('حفظ')),
                      ],
                    ),
                  );
                  if (name != null && name.trim().isNotEmpty) {
                    await widget.repository.rename(p.id, name.trim());
                    _refresh();
                  }
                } catch (e) {
                  _showError(e);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ المشروع'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await widget.repository.duplicate(p.id);
                  _refresh();
                } catch (e) {
                  _showError(e);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('تصدير / مشاركة'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final project = await widget.repository.load(p.id);
                  if (project == null) return;
                  final file = await widget.repository.exportToFile(project);
                  await Share.shareXFiles([XFile(file.path)], text: 'مشروع ElectroSim Pro: ${project.name}');
                } catch (e) {
                  _showError(e);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.danger),
              title: const Text('حذف', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await widget.repository.delete(p.id);
                  _refresh();
                } catch (e) {
                  _showError(e);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ElectroSim Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: widget.settings))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        icon: const Icon(Icons.add),
        label: const Text('مشروع جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _quickActionsRow(),
            const SizedBox(height: 18),
            const Text('مشاريعي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
                    const SizedBox(height: 10),
                    Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('أعد المحاولة')),
                  ],
                ),
              )
            else if (_projects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: const [
                    Icon(Icons.electrical_services, size: 48, color: AppColors.textSecondary),
                    SizedBox(height: 10),
                    Text('لا توجد مشاريع بعد — أنشئ أول دائرة كهربائية لك!', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            else
              ..._projects.map((p) => Card(
                    color: AppColors.surfaceAlt,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: AppColors.bg, child: Icon(Icons.bolt, color: AppColors.primary)),
                      title: Text(p.name),
                      subtitle: Text('${p.componentCount} مكوّن · ${DateFormat('yyyy/MM/dd HH:mm').format(p.updatedAt)}'),
                      onTap: () => _openProject(p.id),
                      trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showProjectMenu(p)),
                    ),
                  )),
            TextButton.icon(
              onPressed: _importProject,
              icon: const Icon(Icons.file_open),
              label: const Text('استيراد مشروع من ملف'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _quickCard(
            icon: Icons.school,
            title: 'التعلّم والتحديات',
            color: AppColors.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LearningScreen(settings: widget.settings, repository: widget.repository))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickCard(
            icon: Icons.bug_report,
            title: 'محاكاة الأعطال',
            color: AppColors.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FaultSimulationScreen(repository: widget.repository, settings: widget.settings))),
          ),
        ),
      ],
    );
  }

  Widget _quickCard({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
