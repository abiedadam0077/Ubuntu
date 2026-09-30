import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';
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
  /// طبقة تجريد نظام الملفات (package:file). في الاستخدام الفعلي للتطبيق
  /// تكون دائماً LocalFileSystem (القرص الحقيقي). في اختبارات الـWidget
  /// الآلية نحقن MemoryFileSystem بدلاً منها — لأن flutter test يُشغّل كل
  /// شيء تحت ساعة زمنية وهمية (fake async) لا تستطيع إتمام عمليات I/O
  /// حقيقية على القرص أبداً (مشكلة معروفة وموثّقة في Flutter نفسه، وليست
  /// خللاً في منطق حفظ المشاريع).
  final FileSystem fileSystem;

  /// نقطة حقن لمسار مجلد التخزين لأغراض الاختبار الآلي؛ في الاستخدام
  /// الفعلي تُترك فارغة فيُستخدم مجلد المستندات الحقيقي عبر path_provider.
  final Future<String> Function()? directoryPathProvider;

  ProjectsRepository({FileSystem? fileSystem, this.directoryPathProvider}) : fileSystem = fileSystem ?? const LocalFileSystem();

  Future<Directory> _projectsDir() async {
    final basePath = directoryPathProvider != null ? await directoryPathProvider!() : (await getApplicationDocumentsDirectory()).path;
    final dir = fileSystem.directory('$basePath/electrosim_projects');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileFor(String id) async {
    final dir = await _projectsDir();
    return fileSystem.file('${dir.path}/$id.esp.json');
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
    final dirPath = directoryPathProvider != null ? await directoryPathProvider!() : (await getTemporaryDirectory()).path;
    final safeName = project.name.replaceAll(RegExp(r'[^\w\u0600-\u06FF ]'), '_');
    final file = fileSystem.file('$dirPath/$safeName.esp.json');
    await file.writeAsString(jsonEncode(project.toJson()));
    return file;
  }

  Future<ProjectModel> importFromFile(String path, {bool asNewId = true}) async {
    final file = fileSystem.file(path);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    var project = ProjectModel.fromJson(json);
    if (asNewId) {
      project = project.deepCopy(newId: _uuid.v4());
    }
    await save(project);
    return project;
  }
}
