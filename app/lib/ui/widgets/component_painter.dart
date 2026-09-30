import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/component_definition.dart';
import '../../models/component_instance.dart';
import '../../models/enums.dart';

Color categoryColor(ComponentCategory c) {
  switch (c) {
    case ComponentCategory.power:
      return const Color(0xFFFFC24B);
    case ComponentCategory.lighting:
      return const Color(0xFFFFE066);
    case ComponentCategory.protection:
      return const Color(0xFFFF5470);
    case ComponentCategory.industrial:
      return const Color(0xFF3D9CFF);
    case ComponentCategory.motors:
      return const Color(0xFF9B6BFF);
    case ComponentCategory.control:
      return const Color(0xFF00E5A8);
    case ComponentCategory.measurement:
      return const Color(0xFF4DD0E1);
    case ComponentCategory.electronics:
      return const Color(0xFFFF8A65);
    case ComponentCategory.wiring:
      return const Color(0xFFB0BEC5);
  }
}

IconData categoryIcon(ComponentCategory c) {
  switch (c) {
    case ComponentCategory.power:
      return Icons.bolt;
    case ComponentCategory.lighting:
      return Icons.lightbulb;
    case ComponentCategory.protection:
      return Icons.shield;
    case ComponentCategory.industrial:
      return Icons.precision_manufacturing;
    case ComponentCategory.motors:
      return Icons.settings;
    case ComponentCategory.control:
      return Icons.tune;
    case ComponentCategory.measurement:
      return Icons.speed;
    case ComponentCategory.electronics:
      return Icons.memory;
    case ComponentCategory.wiring:
      return Icons.dashboard;
  }
}

/// رسام موحّد لكل المكونات: يختار طريقة الرسم حسب مفتاح الرسم المخصص
/// (realistic/symbol) مع سقوط آمن إلى تصميم عام أنيق لأي مكون مستقبلي
/// لا يملك رسماً خاصاً بعد — هذا ما يجعل إضافة مكونات جديدة لا يكسر الواجهة.
class ComponentPainter extends CustomPainter {
  final ComponentDefinition def;
  final ComponentInstance comp;
  final bool realistic;
  final bool selected;
  final double animPhase; // 0..1 يدور باستمرار أثناء التشغيل (لحركة التيار/الدوران)

  ComponentPainter({
    required this.def,
    required this.comp,
    required this.realistic,
    required this.selected,
    required this.animPhase,
  });

  T? _rt<T>(String key) => comp.runtimeState[key] as T?;

  @override
  void paint(Canvas canvas, Size size) {
    final key = realistic ? (def.realisticPainterKey ?? 'generic') : (def.symbolPainterKey ?? 'generic_symbol');
    final rect = Offset.zero & size;

    if (selected) {
      final selPaint = Paint()
        ..color = AppColors.primary.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(14)), selPaint);
      final border = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(14)), border);
    }

    if (!realistic) {
      _paintSymbol(canvas, size, key);
    } else {
      _paintRealistic(canvas, size, key);
    }

    _paintTerminals(canvas, size);
  }

  void _paintTerminals(Canvas canvas, Size size) {
    for (final t in def.terminals) {
      final p = Offset(t.anchor.dx * size.width, t.anchor.dy * size.height);
      final dot = Paint()..color = _terminalColor(t.kind);
      canvas.drawCircle(p, 4.5, dot);
      canvas.drawCircle(p, 4.5, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }

  Color _terminalColor(TerminalKind k) {
    switch (k) {
      case TerminalKind.phase:
      case TerminalKind.dcPlus:
        return const Color(0xFFE53935);
      case TerminalKind.neutral:
      case TerminalKind.dcMinus:
        return const Color(0xFF1E88E5);
      case TerminalKind.ground:
        return const Color(0xFF43A047);
      case TerminalKind.control:
        return const Color(0xFFFB8C00);
      case TerminalKind.generic:
        return const Color(0xFF9E9E9E);
    }
  }

  // ===================================================================
  // تصميم عام أنيق (Fallback) لأي مكون بدون رسم مخصص
  // ===================================================================
  void _paintGenericBox(Canvas canvas, Size size, {IconData? icon, String? label}) {
    final accent = categoryColor(def.category);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      const Radius.circular(12),
    );
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.surfaceAlt, AppColors.surface],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, Paint()..color = accent.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 2);

    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode((icon ?? categoryIcon(def.category)).codePoint),
        style: TextStyle(
          fontSize: math.min(size.width, size.height) * 0.32,
          fontFamily: (icon ?? categoryIcon(def.category)).fontFamily,
          package: (icon ?? categoryIcon(def.category)).fontPackage,
          color: accent,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2 - 6));
  }

  void _drawLabel(Canvas canvas, Size size, String text, {double dy = 0}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width);
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height + dy));
  }

  // ===================================================================
  // رسم واقعي (Realistic Mode)
  // ===================================================================
  void _paintRealistic(Canvas canvas, Size size, String key) {
    final w = size.width, h = size.height;
    switch (key) {
      case 'battery':
      case 'psu':
        _drawBox(canvas, size, const Color(0xFF2C3B52));
        _drawText(canvas, size, '${(comp.properties['voltage'] ?? 12).toStringAsFixed(0)}V', color: Colors.white);
        canvas.drawLine(Offset(w * 0.15, h * 0.3), Offset(w * 0.15, h * 0.7), _strokePaint(Colors.white70, 4));
        canvas.drawLine(Offset(w * 0.85, h * 0.35), Offset(w * 0.85, h * 0.65), _strokePaint(Colors.white70, 2));
        break;
      case 'ac_source':
      case 'ac_source_3ph':
        canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, _fillPaint(const Color(0xFF2C3B52)));
        canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, _strokePaint(const Color(0xFFFFC24B), 2));
        final path = Path()..moveTo(w * 0.25, h / 2);
        for (double x = 0; x <= w * 0.5; x += 4) {
          path.lineTo(w * 0.25 + x, h / 2 - 10 * math.sin(x / (w * 0.5) * math.pi * 2));
        }
        canvas.drawPath(path, _strokePaint(Colors.white, 2));
        break;
      case 'lamp':
      case 'lamp_led':
      case 'pilot_lamp':
        {
          final brightness = ((_rt<num>('brightness')) ?? 0).toDouble().clamp(0.0, 1.4);
          final glow = Paint()
            ..color = Colors.yellowAccent.withOpacity((0.15 + brightness * 0.5).clamp(0.0, 0.85).toDouble())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
          canvas.drawCircle(Offset(w / 2, h * 0.42), math.min(w, h) * 0.42, glow);
          final bulbColor = Color.lerp(const Color(0xFF3A3F4B), const Color(0xFFFFF3B0), brightness.clamp(0, 1).toDouble())!;
          canvas.drawCircle(Offset(w / 2, h * 0.42), math.min(w, h) * 0.3, _fillPaint(bulbColor));
          canvas.drawCircle(Offset(w / 2, h * 0.42), math.min(w, h) * 0.3, _strokePaint(Colors.black26, 1.5));
          canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h * 0.8), width: w * 0.3, height: h * 0.22),
              _fillPaint(const Color(0xFFB0BEC5)));
          break;
        }
      case 'bell':
        _drawBox(canvas, size, const Color(0xFFB08D57));
        canvas.drawArc(Rect.fromCenter(center: Offset(w / 2, h * 0.55), width: w * 0.6, height: h * 0.6), math.pi,
            math.pi, false, _fillPaint(const Color(0xFFD8B573)));
        break;
      case 'fan':
        {
          canvas.save();
          canvas.translate(w / 2, h / 2);
          canvas.rotate(animPhase * math.pi * 2);
          for (var i = 0; i < 3; i++) {
            canvas.save();
            canvas.rotate(i * (math.pi * 2 / 3));
            canvas.drawOval(Rect.fromLTWH(-4, -h * 0.4, 8, h * 0.4), _fillPaint(const Color(0xFF90A4AE)));
            canvas.restore();
          }
          canvas.restore();
          canvas.drawCircle(Offset(w / 2, h / 2), 6, _fillPaint(Colors.white70));
          break;
        }
      case 'motor':
      case 'motor_3ph':
      case 'motor_small':
        {
          canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, _fillPaint(const Color(0xFF37474F)));
          canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, _strokePaint(const Color(0xFF9B6BFF), 2.5));
          canvas.save();
          canvas.translate(w / 2, h / 2);
          canvas.rotate(animPhase * math.pi * 2);
          canvas.drawLine(const Offset(0, 0), Offset(math.min(w, h) * 0.3, 0), _strokePaint(Colors.white70, 3));
          canvas.restore();
          _drawText(canvas, size, 'M', color: Colors.white, dyOffset: 0);
          break;
        }
      case 'switch':
        {
          final on = _switchIsOn();
          _drawBox(canvas, size, const Color(0xFFECEFF1), dark: false);
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, h * 0.2, w * 0.5, h * 0.6), const Radius.circular(6)),
            _fillPaint(const Color(0xFFCFD8DC)),
          );
          final leverY = on ? h * 0.32 : h * 0.58;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(w / 2, leverY), width: w * 0.36, height: h * 0.28),
                const Radius.circular(4)),
            _fillPaint(on ? AppColors.primary : const Color(0xFF607D8B)),
          );
          break;
        }
      case 'socket':
        _drawBox(canvas, size, const Color(0xFFECEFF1), dark: false);
        canvas.drawCircle(Offset(w * 0.35, h * 0.5), 4, _fillPaint(Colors.black45));
        canvas.drawCircle(Offset(w * 0.65, h * 0.5), 4, _fillPaint(Colors.black45));
        canvas.drawCircle(Offset(w * 0.5, h * 0.7), 3, _fillPaint(Colors.black45));
        break;
      case 'junction_box':
        _drawBox(canvas, size, const Color(0xFFFFE082), dark: false);
        canvas.drawCircle(Offset(w / 2, h / 2), 5, _fillPaint(Colors.black26));
        break;
      case 'distribution_board':
        {
          _drawBox(canvas, size, const Color(0xFFE0E0E0), dark: false);
          for (var i = 0; i < 4; i++) {
            canvas.drawRect(Rect.fromLTWH(w * 0.15 + i * w * 0.18, h * 0.15, w * 0.12, h * 0.7),
                _fillPaint(const Color(0xFF37474F)));
          }
          break;
        }
      case 'breaker':
      case 'fuse':
        {
          final on = (_rt<bool>('on') ?? true) && !(_rt<bool>('blown') ?? false);
          _drawBox(canvas, size, const Color(0xFFECEFF1), dark: false);
          canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.1, w * 0.4, h * 0.15), _fillPaint(Colors.black87));
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(w / 2, on ? h * 0.4 : h * 0.6), width: w * 0.22, height: h * 0.4),
                const Radius.circular(3)),
            _fillPaint(on ? const Color(0xFFFF5470) : const Color(0xFF37474F)),
          );
          break;
        }
      case 'rcd':
        {
          final tripped = _rt<bool>('tripped') ?? false;
          _drawBox(canvas, size, const Color(0xFFECEFF1), dark: false);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(w / 2, tripped ? h * 0.62 : h * 0.4), width: w * 0.3, height: h * 0.32),
                const Radius.circular(4)),
            _fillPaint(tripped ? const Color(0xFF37474F) : AppColors.primary),
          );
          _drawText(canvas, size, 'RCD', color: Colors.black87, dyOffset: h * 0.28);
          break;
        }
      case 'contactor':
        {
          final energized = _rt<bool>('energized') ?? false;
          _drawBox(canvas, size, const Color(0xFF37474F));
          for (var i = 0; i < 3; i++) {
            canvas.drawRect(
              Rect.fromLTWH(w * (0.2 + i * 0.22), energized ? h * 0.42 : h * 0.35, w * 0.1, h * 0.25),
              _fillPaint(energized ? AppColors.primary : const Color(0xFF78909C)),
            );
          }
          _drawText(canvas, size, energized ? 'ON' : 'OFF', color: Colors.white70, dyOffset: h * 0.78);
          break;
        }
      case 'aux_contact':
        _drawGenericIcon(canvas, size, Icons.call_split);
        break;
      case 'relay':
      case 'thermal_relay':
      case 'timer':
      case 'counter':
        {
          final energized = (_rt<bool>('energized') ?? false) || (_rt<bool>('tripped') ?? false);
          _drawBox(canvas, size, const Color(0xFF2C3B52));
          canvas.drawCircle(Offset(w * 0.5, h * 0.28), 6, _fillPaint(energized ? AppColors.primary : Colors.white24));
          _drawText(canvas, size,
              key == 'timer' ? 'T' : (key == 'counter' ? 'C' : (key == 'thermal_relay' ? 'TH' : 'K')),
              color: Colors.white, dyOffset: h * 0.15);
          break;
        }
      case 'thermostat':
        _drawGenericIcon(canvas, size, Icons.thermostat);
        break;
      case 'plc':
        {
          _drawBox(canvas, size, const Color(0xFF1B2A41));
          for (var i = 0; i < 3; i++) {
            canvas.drawCircle(Offset(w * 0.18, h * (0.25 + i * 0.22)), 3, _fillPaint(AppColors.warning));
            canvas.drawCircle(Offset(w * 0.82, h * (0.25 + i * 0.22)), 3, _fillPaint(AppColors.primary));
          }
          _drawText(canvas, size, 'PLC', color: Colors.white, dyOffset: -6);
          break;
        }
      case 'push_button_green':
      case 'push_button_red':
        {
          final pressed = _rt<bool>('pressed') ?? false;
          final color = key.contains('green') ? const Color(0xFF43A047) : const Color(0xFFE53935);
          canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - (pressed ? 6 : 2),
              _fillPaint(pressed ? color.withOpacity(0.6) : color));
          canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 2, _strokePaint(Colors.black45, 2));
          break;
        }
      case 'emergency_stop':
        {
          final pressed = _rt<bool>('pressed') ?? false;
          canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 2, _fillPaint(const Color(0xFFECEFF1)));
          canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - (pressed ? 8 : 4),
              _fillPaint(const Color(0xFFD32F2F)));
          break;
        }
      case 'selector_switch':
        _drawGenericIcon(canvas, size, Icons.rotate_right);
        break;
      case 'limit_switch':
        _drawGenericIcon(canvas, size, Icons.linear_scale);
        break;
      case 'sensor':
        _drawGenericIcon(canvas, size, Icons.sensors);
        break;
      case 'transformer':
        {
          _drawBox(canvas, size, const Color(0xFF2C3B52));
          canvas.drawCircle(Offset(w * 0.4, h / 2), h * 0.18, _strokePaint(Colors.white70, 2));
          canvas.drawCircle(Offset(w * 0.6, h / 2), h * 0.18, _strokePaint(Colors.white70, 2));
          break;
        }
      case 'starter':
        {
          final running = _rt<bool>('running') ?? false;
          final mode = _rt<String>('mode') ?? 'star';
          _drawBox(canvas, size, const Color(0xFF1B2A41));
          _drawText(canvas, size, running ? (mode == 'star' ? 'STAR ⭐' : 'DELTA △') : 'STOPPED',
              color: running ? AppColors.primary : Colors.white54, dyOffset: -6);
          canvas.drawCircle(Offset(w / 2, h * 0.78), 10, _fillPaint(running ? AppColors.primary : Colors.white24));
          break;
        }
      case 'multimeter':
      case 'meter_round':
      case 'clamp_meter':
      case 'energy_meter':
        {
          _drawBox(canvas, size, const Color(0xFF212121));
          final val = (_rt<num>('reading') ?? 0).toDouble();
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.15, h * 0.15, w * 0.7, h * 0.4), const Radius.circular(4)),
            _fillPaint(Colors.black),
          );
          _drawTinyText(canvas, Offset(w * 0.5, h * 0.35), val.toStringAsFixed(1), AppColors.primary);
          break;
        }
      case 'oscilloscope':
        {
          _drawBox(canvas, size, const Color(0xFF1B2A41));
          canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.8, h * 0.55), _fillPaint(Colors.black));
          final path = Path()..moveTo(w * 0.12, h * 0.42);
          for (double x = 0; x <= w * 0.76; x += 3) {
            path.lineTo(w * 0.12 + x, h * 0.42 - 14 * math.sin(x / 14 + animPhase * math.pi * 2));
          }
          canvas.drawPath(path, _strokePaint(AppColors.primary, 1.5));
          break;
        }
      case 'resistor':
        {
          canvas.drawLine(Offset(0, h / 2), Offset(w * 0.2, h / 2), _strokePaint(Colors.white70, 2));
          canvas.drawLine(Offset(w * 0.8, h / 2), Offset(w, h / 2), _strokePaint(Colors.white70, 2));
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, h * 0.3, w * 0.6, h * 0.4), const Radius.circular(4)),
            _fillPaint(const Color(0xFFDCC48B)),
          );
          for (var i = 0; i < 3; i++) {
            canvas.drawRect(Rect.fromLTWH(w * (0.32 + i * 0.14), h * 0.3, 4, h * 0.4),
                _fillPaint([Colors.brown, Colors.black, Colors.red][i]));
          }
          break;
        }
      case 'capacitor':
        canvas.drawLine(Offset(w * 0.35, 0), Offset(w * 0.35, h), _strokePaint(Colors.blueAccent, 4));
        canvas.drawLine(Offset(w * 0.65, 0), Offset(w * 0.65, h), _strokePaint(Colors.blueAccent, 4));
        canvas.drawLine(Offset(0, h / 2), Offset(w * 0.35, h / 2), _strokePaint(Colors.white70, 2));
        canvas.drawLine(Offset(w * 0.65, h / 2), Offset(w, h / 2), _strokePaint(Colors.white70, 2));
        break;
      case 'diode':
      case 'led':
        {
          final fwd = _rt<bool>('fwd') ?? true;
          canvas.drawLine(Offset(0, h / 2), Offset(w * 0.35, h / 2), _strokePaint(Colors.white70, 2));
          canvas.drawLine(Offset(w * 0.65, h / 2), Offset(w, h / 2), _strokePaint(Colors.white70, 2));
          final path = Path()
            ..moveTo(w * 0.35, h * 0.2)
            ..lineTo(w * 0.35, h * 0.8)
            ..lineTo(w * 0.62, h / 2)
            ..close();
          final brightness = ((_rt<num>('brightness')) ?? 0).toDouble();
          canvas.drawPath(
              path, _fillPaint(key == 'led' ? Color.lerp(Colors.red.shade900, Colors.redAccent, brightness.clamp(0, 1).toDouble())! : (fwd ? Colors.white70 : Colors.white24)));
          canvas.drawLine(Offset(w * 0.62, h * 0.2), Offset(w * 0.62, h * 0.8), _strokePaint(Colors.white70, 3));
          break;
        }
      case 'transistor':
        _drawGenericIcon(canvas, size, Icons.memory);
        break;
      case 'potentiometer':
        {
          canvas.drawLine(Offset(0, h * 0.7), Offset(w, h * 0.7), _strokePaint(Colors.white70, 2));
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.5, w * 0.8, h * 0.25), const Radius.circular(6)),
            _fillPaint(const Color(0xFFDCC48B)),
          );
          final pos = (comp.properties['wiperPosition'] ?? 0.5).clamp(0.0, 1.0);
          canvas.drawLine(Offset(w * (0.1 + 0.8 * pos), h * 0.5), Offset(w * (0.1 + 0.8 * pos), 0),
              _strokePaint(Colors.white70, 2));
          break;
        }
      case 'buzzer':
        _drawGenericIcon(canvas, size, Icons.campaign);
        break;
      case 'ic':
        {
          _drawBox(canvas, size, const Color(0xFF212121));
          _drawText(canvas, size, 'AND', color: Colors.white, dyOffset: 0);
          break;
        }
      default:
        _paintGenericBox(canvas, size);
    }
  }

  // ===================================================================
  // رسم رمزي قياسي (Electrical Symbol Mode) — رموز مبسّطة قريبة من IEC
  // ===================================================================
  void _paintSymbol(Canvas canvas, Size size, String key) {
    final w = size.width, h = size.height;
    final p = _strokePaint(AppColors.textPrimary, 2);
    switch (key) {
      case 'battery':
        canvas.drawLine(Offset(w * 0.3, h * 0.3), Offset(w * 0.3, h * 0.7), _strokePaint(Colors.white, 4));
        canvas.drawLine(Offset(w * 0.5, h * 0.2), Offset(w * 0.5, h * 0.8), _strokePaint(Colors.white, 1.5));
        canvas.drawLine(Offset(0, h / 2), Offset(w * 0.3, h / 2), p);
        canvas.drawLine(Offset(w * 0.5, h / 2), Offset(w, h / 2), p);
        break;
      case 'psu':
      case 'ac_source':
      case 'ac_source_3ph':
        canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, p);
        final path = Path()..moveTo(w * 0.3, h / 2);
        for (double x = 0; x <= w * 0.4; x += 4) {
          path.lineTo(w * 0.3 + x, h / 2 - 8 * math.sin(x / (w * 0.4) * math.pi * 2));
        }
        canvas.drawPath(path, p);
        break;
      case 'lamp':
        canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, p);
        canvas.drawLine(Offset(w * 0.3, h * 0.3), Offset(w * 0.7, h * 0.7), p);
        canvas.drawLine(Offset(w * 0.7, h * 0.3), Offset(w * 0.3, h * 0.7), p);
        break;
      case 'bell':
        canvas.drawArc(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.6, height: h * 0.6), math.pi,
            math.pi, false, p);
        break;
      case 'motor':
        canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, p);
        _drawText(canvas, size, 'M', color: Colors.white, dyOffset: 0);
        break;
      case 'switch':
        canvas.drawLine(Offset(w * 0.15, h / 2), Offset(w * 0.4, h / 2), p);
        canvas.drawLine(Offset(w * 0.4, h / 2), Offset(w * 0.75, h * 0.3), p);
        canvas.drawCircle(Offset(w * 0.4, h / 2), 3, _fillPaint(Colors.white));
        canvas.drawCircle(Offset(w * 0.8, h / 2), 3, _fillPaint(Colors.white));
        canvas.drawLine(Offset(w * 0.8, h / 2), Offset(w, h / 2), p);
        break;
      case 'socket':
        canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, p);
        break;
      case 'junction_box':
        canvas.drawCircle(Offset(w / 2, h / 2), 5, _fillPaint(Colors.white));
        break;
      case 'distribution_board':
        canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.1, w * 0.6, h * 0.8), p);
        break;
      case 'breaker':
      case 'fuse':
        canvas.drawRect(Rect.fromLTWH(w * 0.35, h * 0.15, w * 0.3, h * 0.7), p);
        canvas.drawLine(Offset(0, h / 2), Offset(w * 0.35, h / 2), p);
        canvas.drawLine(Offset(w * 0.65, h / 2), Offset(w, h / 2), p);
        break;
      case 'rcd':
        canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.15, w * 0.6, h * 0.7), p);
        _drawText(canvas, size, 'RCD', color: Colors.white, dyOffset: 0);
        break;
      case 'contactor':
      case 'relay':
        canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h * 0.3), p);
        canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.3, w * 0.4, h * 0.2), p);
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(Offset(w * (0.25 + i * 0.25), h * 0.6), Offset(w * (0.25 + i * 0.25), h * 0.9), p);
        }
        break;
      case 'contact_no':
        canvas.drawLine(Offset(0, h / 2), Offset(w * 0.35, h / 2), p);
        canvas.drawLine(Offset(w * 0.35, h / 2), Offset(w * 0.65, h * 0.25), p);
        canvas.drawLine(Offset(w * 0.65, h / 2), Offset(w, h / 2), p);
        break;
      case 'contact_nc':
        canvas.drawLine(Offset(0, h / 2), Offset(w * 0.35, h / 2), p);
        canvas.drawLine(Offset(w * 0.35, h * 0.25), Offset(w * 0.65, h * 0.6), p);
        canvas.drawLine(Offset(w * 0.65, h / 2), Offset(w, h / 2), p);
        break;
      case 'thermal_relay':
      case 'timer':
      case 'counter':
      case 'thermostat':
        canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.25, w * 0.5, h * 0.5), p);
        break;
      case 'plc':
        canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.1, w * 0.7, h * 0.8), p);
        _drawText(canvas, size, 'PLC', color: Colors.white, dyOffset: 0);
        break;
      case 'transformer':
        canvas.drawCircle(Offset(w * 0.4, h / 2), h * 0.18, p);
        canvas.drawCircle(Offset(w * 0.6, h / 2), h * 0.18, p);
        break;
      case 'starter':
        canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6), p);
        break;
      case 'meter':
        canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, p);
        _drawText(canvas, size,
            ((comp.properties['mode'] ?? 0).toInt() == 1) ? 'A' : (((comp.properties['mode'] ?? 0).toInt() == 0) ? 'V' : '~'),
            color: Colors.white, dyOffset: 0);
        break;
      case 'resistor':
        canvas.drawLine(Offset(0, h / 2), Offset(w * 0.15, h / 2), p);
        canvas.drawLine(Offset(w * 0.85, h / 2), Offset(w, h / 2), p);
        canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.35, w * 0.7, h * 0.3), p);
        break;
      case 'capacitor':
        canvas.drawLine(Offset(w * 0.4, h * 0.15), Offset(w * 0.4, h * 0.85), p);
        canvas.drawLine(Offset(w * 0.6, h * 0.15), Offset(w * 0.6, h * 0.85), p);
        canvas.drawLine(Offset(0, h / 2), Offset(w * 0.4, h / 2), p);
        canvas.drawLine(Offset(w * 0.6, h / 2), Offset(w, h / 2), p);
        break;
      case 'diode':
      case 'led':
        {
          canvas.drawLine(Offset(0, h / 2), Offset(w * 0.35, h / 2), p);
          canvas.drawLine(Offset(w * 0.65, h / 2), Offset(w, h / 2), p);
          final path = Path()
            ..moveTo(w * 0.35, h * 0.25)
            ..lineTo(w * 0.35, h * 0.75)
            ..lineTo(w * 0.65, h / 2)
            ..close();
          canvas.drawPath(path, p);
          canvas.drawLine(Offset(w * 0.65, h * 0.25), Offset(w * 0.65, h * 0.75), p);
          break;
        }
      case 'transistor':
        canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, p);
        break;
      case 'potentiometer':
        canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.4, w * 0.7, h * 0.2), p);
        canvas.drawLine(Offset(w / 2, h * 0.4), Offset(w / 2, h * 0.1), p);
        break;
      case 'buzzer':
        canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) / 2 - 4, p);
        break;
      case 'ic':
        canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6), p);
        break;
      default:
        _paintGenericBox(canvas, size);
    }
  }

  void _drawGenericIcon(Canvas canvas, Size size, IconData icon) {
    _paintGenericBox(canvas, size, icon: icon);
  }

  bool _switchIsOn() {
    final isSpdt = (comp.properties['isSpdt'] ?? 0) >= 1;
    if (isSpdt) return true;
    return (_rt<bool>('on_0') ?? _rt<bool>('on')) ?? false;
  }

  void _drawBox(Canvas canvas, Size size, Color color, {bool dark = true}) {
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), const Radius.circular(10));
    canvas.drawRRect(rect, _fillPaint(color));
    canvas.drawRRect(rect, _strokePaint(dark ? Colors.black45 : Colors.black26, 1.5));
  }

  void _drawText(Canvas canvas, Size size, String text, {required Color color, double dyOffset = 0}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2 + dyOffset));
  }

  void _drawTinyText(Canvas canvas, Offset center, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 11, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  Paint _fillPaint(Color c) => Paint()..color = c..style = PaintingStyle.fill;
  Paint _strokePaint(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;

  @override
  bool shouldRepaint(covariant ComponentPainter oldDelegate) {
    return true;
  }
}
