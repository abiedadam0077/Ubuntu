import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/detected_fault.dart';
import '../engine/simulation_engine.dart';
import '../models/enums.dart';
import '../models/project_model.dart';

/// وحدة التحكم بتشغيل/إيقاف/إيقاف مؤقت/إعادة ضبط المحاكاة، وتشغيل "نبضة"
/// محرك المحاكاة بشكل دوري (كل 100ms) بحيث تتحدث كل القراءات والحركة بسلاسة.
class SimulationController extends ChangeNotifier {
  late SimulationEngine engine;
  Timer? _timer;
  static const Duration tickInterval = Duration(milliseconds: 100);

  List<DetectedFault> lastFaults = [];
  double totalPowerW = 0;
  Map<String, double> wireCurrents = {};

  SimulationController(ProjectModel project) {
    engine = SimulationEngine(project);
  }

  SimulationStatus get status => engine.status;

  void rebind(ProjectModel project) {
    stop();
    engine = SimulationEngine(project);
    lastFaults = [];
    wireCurrents = {};
    notifyListeners();
  }

  void start() {
    if (engine.status == SimulationStatus.running) return;
    engine.status = SimulationStatus.running;
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) => _tick());
    notifyListeners();
  }

  void pause() {
    if (engine.status != SimulationStatus.running) return;
    engine.status = SimulationStatus.paused;
    _timer?.cancel();
    notifyListeners();
  }

  void resume() {
    if (engine.status != SimulationStatus.paused) return;
    start();
  }

  void stop() {
    _timer?.cancel();
    engine.status = SimulationStatus.stopped;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    engine.reset();
    lastFaults = [];
    wireCurrents = {};
    notifyListeners();
  }

  void _tick() {
    final result = engine.tick(tickInterval.inMilliseconds / 1000.0);
    lastFaults = result.faults;
    totalPowerW = result.totalPowerW;
    wireCurrents = result.wireCurrents;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
