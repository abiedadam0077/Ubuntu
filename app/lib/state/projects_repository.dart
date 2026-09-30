import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/project_model.dart';

const _uuid = Uuid();

/// معلومات مختصرة عن مشروع محفوظ (تُستخدم في شاشة قائمة المشاريع بدون تحميل
/// كل تفاصيل المكونات والأسلاك دفعة واحدة)
class ProjectSummary {
  final String id;
  final String name;
  final DateTime updatedAt;
  final int componentCount;

  ProjectSummary({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.componentCount,
  });
}

/// طبقة الوصول للتخزين المحلي لمشاريع ElectroSim Pro (ملفات .esp.json)
class ProjectsRepository {
  /// نقطة حقن لمجلد التخزين لأغراض الاختبار الآلي (widget tests) بحيث لا
  /// تحتاج الاختبارات لتشغيل قنوات منصة Android/iOS الحقيقية لـ path_provider.
  /// في الاستخدام الفعلي للتطبيق تُترك فارغة فيُستخدم المجلد الحقيقي دائماً.
  final Future<Directory> Function()? directoryProvider;

  ProjectsRepository({this.directoryProvider});

  Future<Directory> _projectsDir() async {
    final base = directoryProvider != null ? await directoryProvider!() : await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/electrosim_projects');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileFor(String id) async {
    final dir = await _projectsDir();
    return File('${dir.path}/$id.esp.json');
  }

  Future<List<ProjectSummary>> listProjects() async {
    final dir = await _projectsDir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.esp.json'));
    final summaries = <ProjectSummary>[];
    for (final f in files) {
      try {
        final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        summaries.add(ProjectSummary(
          id: json['id'] as String,
          name: json['name'] as String? ?? 'مشروع بدون اسم',
          updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
          componentCount: (json['components'] as List?)?.length ?? 0,
        ));
      } catch (_) {
        // نتجاهل أي ملف تالف بدل تعطيل الشاشة كاملة
      }
    }
    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  Future<ProjectModel> createNew(String name) async {
    final project = ProjectModel(id: _uuid.v4(), name: name);
    await save(project);
    return project;
  }

  Future<void> save(ProjectModel project) async {
    project.updatedAt = DateTime.now();
    final file = await _fileFor(project.id);
    await file.writeAsString(jsonEncode(project.toJson()));
  }

  Future<ProjectModel?> load(String id) async {
    final file = await _fileFor(id);
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return ProjectModel.fromJson(json);
  }

  Future<void> delete(String id) async {
    final file = await _fileFor(id);
    if (await file.exists()) await file.delete();
  }

  Future<ProjectModel> duplicate(String id, {String? newName}) async {
    final original = await load(id);
    if (original == null) throw Exception('المشروع غير موجود');
    final copy = original.deepCopy(newId: _uuid.v4(), newName: newName ?? '${original.name} (نسخة)');
    await save(copy);
    return copy;
  }

  Future<void> rename(String id, String newName) async {
    final project = await load(id);
    if (project == null) return;
    project.name = newName;
    await save(project);
  }

  /// يُصدّر المشروع كملف مستقل جاهز للمشاركة، ويعيد المسار الكامل للملف
  Future<File> exportToFile(ProjectModel project) async {
    final dir = await getTemporaryDirectory();
    final safeName = project.name.replaceAll(RegExp(r'[^\w\u0600-\u06FF ]'), '_');
    final file = File('${dir.path}/$safeName.esp.json');
    await file.writeAsString(jsonEncode(project.toJson()));
    return file;
  }

  Future<ProjectModel> importFromFile(String path, {bool asNewId = true}) async {
    final file = File(path);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    var project = ProjectModel.fromJson(json);
    if (asNewId) {
      project = project.deepCopy(newId: _uuid.v4());
    }
    await save(project);
    return project;
  }
}
