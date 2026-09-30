import '../models/enums.dart';

/// وصف خطأ تم اكتشافه أثناء المحاكاة — يُعرض للمستخدم مع شرح وحل مقترح
/// وتحديد للمكونات/الأسلاك المسؤولة حتى تُظهر الواجهة سهماً/تلويناً عليها.
class DetectedFault {
  final FaultType type;
  final String titleAr;
  final String problemAr;
  final String solutionAr;
  final List<String> componentIds;
  final List<String> wireIds;
  final bool isCritical;

  DetectedFault({
    required this.type,
    required this.titleAr,
    required this.problemAr,
    required this.solutionAr,
    this.componentIds = const [],
    this.wireIds = const [],
    this.isCritical = true,
  });
}
