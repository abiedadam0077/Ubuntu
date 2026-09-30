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
    case ComponentCategory.switchesButtons:
      return const Color(0xFF7CDB8A);
    case ComponentCategory.protection:
      return const Color(0xFFFF5470);
    case ComponentCategory.motors:
      return const Color(0xFF9B6BFF);
    case ComponentCategory.industrial:
      return const Color(0xFF3D9CFF);
    case ComponentCategory.sensors:
      return const Color(0xFF26C6DA);
    case ComponentCategory.measurement:
      return const Color(0xFF4DD0E1);
    case ComponentCategory.sockets:
      return const Color(0xFFB0BEC5);
    case ComponentCategory.relaysContactors:
      return const Color(0xFF00E5A8);
    case ComponentCategory.plc:
      return const Color(0xFF7986CB);
    case ComponentCategory.electronics:
      return const Color(0xFFFF8A65);
    case ComponentCategory.other:
      return const Color(0xFFB0BEC5);
  }
}

IconData categoryIcon(ComponentCategory c) {
  switch (c) {
    case ComponentCategory.power:
      return Icons.bolt;
    case ComponentCategory.lighting:
      return Icons.lightbulb;
    case ComponentCategory.switchesButtons:
      return Icons.toggle_on;
    case ComponentCategory.protection:
      return Icons.shield;
    case ComponentCategory.motors:
      return Icons.settings;
    case ComponentCategory.industrial:
      return Icons.precision_manufacturing;
    case ComponentCategory.sensors:
      return Icons.sensors;
    case ComponentCategory.measurement:
      return Icons.speed;
    case ComponentCategory.sockets:
      return Icons.power;
    case ComponentCategory.relaysContactors:
      return Icons.tune;
    case ComponentCategory.plc:
      return Icons.memory;
    case ComponentCategory.electronics:
      return Icons.developer_board;
    case ComponentCategory.other:
      return Icons.category;
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

  /// إظهار تسميات الأطراف (L1/N/PE/A1/A2...) بجانب كل نقطة اتصال. تُفعَّل
  /// على اللوحة (Canvas) حيث تحتاج توصيلاً دقيقاً، وتُعطَّل داخل صور
  /// المعاينة المصغّرة في مكتبة المكونات حتى تبقى نظيفة عند الحجم الصغير.
  final bool showTerminalLabels;

  ComponentPainter({
    required this.def,
    required this.comp,
    required this.realistic,
    required this.selected,
    required this.animPhase,
    this.showTerminalLabels = true,
  });

  T? _rt<T>(String key) => comp.runtimeState[key] as T?;

  @override
  void paint(Canvas canvas, Size size) {
    final key = realistic ? (def.realisticPainterKey ?? 'generic') : (def.symbolPainterKey ?? 'generic_symbol');
    final rect = Offset.zero & size;

    // ظل خفيف تحت جسم المكون لإعطاء إحساس عمق (Depth) — فقط في الوضع
    // الواقعي، وليس في وضع الرموز القياسية (Symbol) الذي يبقى مسطّحاً بلا ظل.
    if (realistic) {
      final shadowRRect = RRect.fromRectAndRadius(rect.deflate(3).shift(const Offset(0, 2.5)), const Radius.circular(11));
      canvas.drawRRect(
        shadowRRect,
        Paint()
          ..color = Colors.black.withOpacity(0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

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
      // قاعدة معدنية صغيرة خلف كل طرف (برغي/مشبك توصيل واقعي)
      canvas.drawCircle(p, 6, Paint()..color = const Color(0xFFB0BEC5));
      canvas.drawCircle(p, 6, Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 1);
      final dot = Paint()..color = _terminalColor(t.kind);
      canvas.drawCircle(p, 4.5, dot);
      canvas.drawCircle(p, 4.5, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 1);
      // بريق صغير يعطي إحساساً معدنياً لامعاً
      canvas.drawCircle(p - const Offset(1.2, 1.2), 1.1, Paint()..color = Colors.white.withOpacity(0.55));

      if (showTerminalLabels && t.label.isNotEmpty) {
        _drawTerminalLabel(canvas, size, t, p);
      }
    }
  }

  void _drawTerminalLabel(Canvas canvas, Size size, TerminalDef t, Offset p) {
    final tp = TextPainter(
      text: TextSpan(
        text: t.label,
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // نحدد اتجاه وضع التسمية حسب موقع الطرف من حواف المكون حتى لا تتراكب
    // مع جسم الجهاز نفسه.
    double dx;
    double dy;
    const gap = 7.0;
    if (t.anchor.dx <= 0.06) {
      dx = p.dx - gap - tp.width;
      dy = p.dy - tp.height / 2;
    } else if (t.anchor.dx >= 0.94) {
      dx = p.dx + gap;
      dy = p.dy - tp.height / 2;
    } else if (t.anchor.dy <= 0.06) {
      dx = p.dx - tp.width / 2;
      dy = p.dy - gap - tp.height;
    } else if (t.anchor.dy >= 0.94) {
      dx = p.dx - tp.width / 2;
      dy = p.dy + gap;
    } else {
      dx = p.dx - tp.width / 2;
      dy = p.dy + gap;
    }

    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(dx - 2, dy - 1, tp.width + 4, tp.height + 2),
      const Radius.circular(3),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.black.withOpacity(0.62));
    tp.paint(canvas, Offset(dx, dy));
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
  // أدوات مساعدة لرسم "جسم جهاز" احترافي (بلاستيك/معدن) قابلة لإعادة
  // الاستخدام في كل الأجهزة الصناعية (قواطع، كونتاكتورات، ريليهات...)
  // ===================================================================

  /// جسم بلاستيكي متدرّج اللون مع حواف مستديرة وإطار داكن — القاعدة
  /// المشتركة لمعظم الأجهزة الواقعية (قاطع، RCD، كونتاكتور، ريليه...)
  RRect _plasticBody(Canvas canvas, Size size, Color topColor, Color bottomColor, {double inset = 2, double radius = 8}) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ).createShader(rect.outerRect),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.black.withOpacity(0.45)..style = PaintingStyle.stroke..strokeWidth = 1.4);
    // خط لمعان علوي خفيف يعطي إحساس البلاستيك اللامع
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(inset + 2, inset + 1.5, size.width - inset * 2 - 4, (size.height - inset * 2) * 0.28), Radius.circular(radius * 0.7)),
      Paint()..color = Colors.white.withOpacity(0.08),
    );
    return rect;
  }

  /// مشبك تثبيت على سكة DIN (شكل صغير مسنّن أعلى الجهاز) — يوحي بأن
  /// الجهاز مُركَّب فعلاً على لوحة كهربائية صناعية حقيقية.
  void _dinRailClip(Canvas canvas, Size size) {
    final w = size.width;
    final clip = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.5 - w * 0.14, 0, w * 0.28, 4.5), const Radius.circular(2));
    canvas.drawRRect(clip, Paint()..color = const Color(0xFF6B7684));
  }

  /// رأس برغي واقعي صغير (مع خط الشق) — يُستخدم على جوانب الأجهزة
  /// الصناعية وصناديق التوصيل لإعطاء تفاصيل واضحة تحاكي المعدات الحقيقية.
  void _screw(Canvas canvas, Offset pos, {double r = 3.2}) {
    canvas.drawCircle(pos, r, Paint()..color = const Color(0xFF8E99A8));
    canvas.drawCircle(pos, r, Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 0.8);
    canvas.drawLine(pos + Offset(-r * 0.6, 0), pos + Offset(r * 0.6, 0), Paint()..color = Colors.black45..strokeWidth = 0.9);
  }

  /// شريط نص صغير (اسم/قيمة مطبوعة على جسم الجهاز، مثل شدة التيار أو الجهد)
  void _printedLabel(Canvas canvas, Offset center, String text, {double fontSize = 9, Color color = Colors.black87, FontWeight weight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
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
          final bulbCenter = Offset(w / 2, h * 0.4);
          final bulbR = math.min(w, h) * 0.3;
          final glowColor = key == 'pilot_lamp' ? const Color(0xFFFF5470) : Colors.amberAccent;

          if (brightness > 0.02) {
            canvas.drawCircle(
              bulbCenter,
              bulbR * 2.2,
              Paint()
                ..color = glowColor.withOpacity((0.12 + brightness * 0.4).clamp(0.0, 0.75).toDouble())
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
            );
          }

          // زجاجة اللمبة (تدرّج شفاف يعكس الإضاءة الداخلية)
          final glassColor = Color.lerp(const Color(0xFFE8ECEF), const Color(0xFFFFF3B0), brightness.clamp(0, 1).toDouble())!;
          canvas.drawCircle(bulbCenter, bulbR, Paint()..color = glassColor.withOpacity(0.34 + brightness * 0.5));
          canvas.drawCircle(bulbCenter, bulbR, _strokePaint(const Color(0xFF90A4AE), 1.3));

          // الفتيلة الداخلية (خيط متعرّج) — تتوهج برتقالي/أصفر عند التشغيل
          final filamentColor = brightness > 0.05
              ? Color.lerp(const Color(0xFFFF8A00), const Color(0xFFFFF59D), brightness.clamp(0, 1).toDouble())!
              : const Color(0xFF5C6570);
          final fp = Path()
            ..moveTo(bulbCenter.dx - bulbR * 0.35, bulbCenter.dy + bulbR * 0.25)
            ..lineTo(bulbCenter.dx - bulbR * 0.12, bulbCenter.dy - bulbR * 0.3)
            ..lineTo(bulbCenter.dx + bulbR * 0.12, bulbCenter.dy + bulbR * 0.3)
            ..lineTo(bulbCenter.dx + bulbR * 0.35, bulbCenter.dy - bulbR * 0.25);
          canvas.drawPath(fp, _strokePaint(filamentColor, brightness > 0.05 ? 2.2 : 1.4));

          // بريق زجاجي علوي
          canvas.drawCircle(bulbCenter + Offset(-bulbR * 0.35, -bulbR * 0.35), bulbR * 0.18, Paint()..color = Colors.white.withOpacity(0.45));

          // قاعدة اللمبة المعدنية الملولبة (Edison screw base)
          final baseRect = Rect.fromCenter(center: Offset(w / 2, h * 0.76), width: w * 0.32, height: h * 0.26);
          canvas.drawRect(baseRect, Paint()
            ..shader = const LinearGradient(colors: [Color(0xFFCFD8DC), Color(0xFF78909C), Color(0xFFCFD8DC)]).createShader(baseRect));
          for (var i = 0; i < 4; i++) {
            final ty = baseRect.top + baseRect.height * (0.18 + i * 0.22);
            canvas.drawLine(Offset(baseRect.left, ty), Offset(baseRect.right, ty), Paint()..color = Colors.black38..strokeWidth = 1);
          }
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
          final rpmRatio = (_rt<num>('rpmRatio') ?? 0).toDouble();
          final running = rpmRatio > 0.02;
          final bodyR = math.min(w, h) / 2 - 4;
          final center = Offset(w / 2, h * 0.46);

          // الجسم الأسطواني الرئيسي مع تدرّج معدني
          canvas.drawCircle(center, bodyR, Paint()..shader = RadialGradient(colors: const [Color(0xFF546E7A), Color(0xFF2E3B44)], center: const Alignment(-0.3, -0.3)).createShader(Rect.fromCircle(center: center, radius: bodyR)));
          canvas.drawCircle(center, bodyR, _strokePaint(const Color(0xFF9B6BFF), 2.2));

          // زعانف تبريد (Cooling fins) حول جسم المحرك
          for (var i = 0; i < 10; i++) {
            final ang = i * math.pi / 5;
            final p1 = center + Offset(math.cos(ang), math.sin(ang)) * (bodyR * 0.72);
            final p2 = center + Offset(math.cos(ang), math.sin(ang)) * (bodyR * 0.94);
            canvas.drawLine(p1, p2, Paint()..color = Colors.black26..strokeWidth = 1.4);
          }

          // صندوق التوصيل الكهربائي أعلى المحرك
          final boxRect = Rect.fromCenter(center: Offset(w / 2, h * 0.12), width: w * 0.3, height: h * 0.16);
          canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(3)), _fillPaint(const Color(0xFF37474F)));
          canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(3)), _strokePaint(Colors.black45, 1));

          // العمود الدوّار (Shaft) + مروحة تبريد خلفية تدور فعلياً أثناء التشغيل
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(animPhase * math.pi * 2);
          for (var i = 0; i < 4; i++) {
            canvas.save();
            canvas.rotate(i * math.pi / 2);
            canvas.drawOval(Rect.fromCenter(center: Offset(bodyR * 0.42, 0), width: bodyR * 0.62, height: bodyR * 0.22),
                _fillPaint(running ? const Color(0xFFB0BEC5) : const Color(0xFF78909C)));
            canvas.restore();
          }
          canvas.drawCircle(Offset.zero, bodyR * 0.16, _fillPaint(const Color(0xFFCFD8DC)));
          canvas.restore();

          _printedLabel(canvas, Offset(w / 2, h * 0.82), key == 'motor_3ph' ? 'M 3~' : 'M 1~', fontSize: 11, color: Colors.white);
          break;
        }
      case 'switch':
        {
          final on = _switchIsOn();
          // لوحة تأطير بيضاء (Wall plate) بحواف مصقولة
          _plasticBody(canvas, size, const Color(0xFFFAFBFC), const Color(0xFFE3E7EA), radius: 9);
          for (final s in [
            Offset(w * 0.14, h * 0.14),
            Offset(w * 0.86, h * 0.14),
            Offset(w * 0.14, h * 0.86),
            Offset(w * 0.86, h * 0.86),
          ]) {
            _screw(canvas, s, r: 2.2);
          }
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, h * 0.18, w * 0.5, h * 0.64), const Radius.circular(6)),
            _fillPaint(const Color(0xFFCFD8DC)),
          );
          final leverY = on ? h * 0.32 : h * 0.6;
          final leverRect = Rect.fromCenter(center: Offset(w / 2, leverY), width: w * 0.36, height: h * 0.3);
          final leverColor = on ? AppColors.primary : const Color(0xFF607D8B);
          canvas.drawRRect(RRect.fromRectAndRadius(leverRect, const Radius.circular(4)),
              Paint()..shader = LinearGradient(colors: [leverColor.withOpacity(0.85), leverColor]).createShader(leverRect));
          canvas.drawRRect(RRect.fromRectAndRadius(leverRect, const Radius.circular(4)), _strokePaint(Colors.black38, 1));
          break;
        }
      case 'socket':
        {
          _plasticBody(canvas, size, const Color(0xFFFAFBFC), const Color(0xFFE3E7EA), radius: 40);
          for (final s in [Offset(w * 0.16, h * 0.16), Offset(w * 0.84, h * 0.16), Offset(w * 0.16, h * 0.84), Offset(w * 0.84, h * 0.84)]) {
            _screw(canvas, s, r: 2);
          }
          // فتحتا الطور/التعادل + دبوس التأريض (نمط أوروبي Schuko مبسّط)
          canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.36, h * 0.42), width: w * 0.13, height: h * 0.22), _fillPaint(const Color(0xFF23282C)));
          canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.64, h * 0.42), width: w * 0.13, height: h * 0.22), _fillPaint(const Color(0xFF23282C)));
          canvas.drawCircle(Offset(w * 0.5, h * 0.72), w * 0.055, _fillPaint(const Color(0xFFB0BEC5)));
          canvas.drawCircle(Offset(w * 0.5, h * 0.72), w * 0.055, _strokePaint(Colors.black38, 1));
          break;
        }
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
          final tripped = _rt<bool>('tripped') ?? false;
          final blown = _rt<bool>('blown') ?? false;
          final on = (_rt<bool>('on') ?? true) && !blown;
          final rated = (comp.properties['ratedCurrent'] ?? 10).toStringAsFixed(0);

          _plasticBody(canvas, size, const Color(0xFFF5F7F8), const Color(0xFFD4DBDF));
          _dinRailClip(canvas, size);

          // نافذة سوداء علوية (منطقة القوس الكهربائي كما في القواطع الحقيقية)
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.28, h * 0.1, w * 0.44, h * 0.16), const Radius.circular(2)),
            _fillPaint(const Color(0xFF1B1F24)),
          );
          // شدة التيار المطبوعة
          _printedLabel(canvas, Offset(w / 2, h * 0.18), '${rated}A', fontSize: 7.5, color: Colors.white);

          // جسم الرافعة (Toggle lever) بحواف مصقولة
          final leverRect = Rect.fromCenter(center: Offset(w / 2, on ? h * 0.42 : h * 0.66), width: w * 0.24, height: h * 0.42);
          final leverColor = tripped ? const Color(0xFFFF7043) : (on ? const Color(0xFFEF5350) : const Color(0xFF37474F));
          canvas.drawRRect(
            RRect.fromRectAndRadius(leverRect, const Radius.circular(4)),
            Paint()..shader = LinearGradient(colors: [leverColor.withOpacity(0.85), leverColor]).createShader(leverRect),
          );
          canvas.drawRRect(RRect.fromRectAndRadius(leverRect, const Radius.circular(4)), _strokePaint(Colors.black54, 1));
          // خطوط ON/I و OFF/O صغيرة أعلى وأسفل مسار الرافعة
          _printedLabel(canvas, Offset(w / 2, h * 0.28), 'I', fontSize: 8, color: on ? Colors.white : Colors.black38);
          _printedLabel(canvas, Offset(w / 2, h * 0.86), 'O', fontSize: 8, color: !on ? Colors.black87 : Colors.black26);

          if (tripped) {
            // علم التنبيه الصغير (Trip flag) — يظهر مربع برتقالي بجانب القاطع
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.06, h * 0.3, w * 0.14, h * 0.22), const Radius.circular(2)),
              _fillPaint(const Color(0xFFFF9800)),
            );
          }
          // براغي التثبيت السفلية لأسلاك الدخول والخروج
          _screw(canvas, Offset(w * 0.5, h * 0.94), r: 2.6);
          break;
        }
      case 'rcd':
        {
          final tripped = _rt<bool>('tripped') ?? false;
          final sensitivity = (comp.properties['sensitivityMa'] ?? 30).toStringAsFixed(0);

          _plasticBody(canvas, size, const Color(0xFFF5F7F8), const Color(0xFFD4DBDF));
          _dinRailClip(canvas, size);

          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, h * 0.08, w * 0.6, h * 0.14), const Radius.circular(2)),
            _fillPaint(const Color(0xFF1B1F24)),
          );
          _printedLabel(canvas, Offset(w / 2, h * 0.15), '${sensitivity}mA', fontSize: 7, color: Colors.white);

          final leverRect = Rect.fromCenter(center: Offset(w * 0.36, tripped ? h * 0.66 : h * 0.42), width: w * 0.2, height: h * 0.4);
          final leverColor = tripped ? const Color(0xFF37474F) : AppColors.primary;
          canvas.drawRRect(RRect.fromRectAndRadius(leverRect, const Radius.circular(4)),
              Paint()..shader = LinearGradient(colors: [leverColor.withOpacity(0.85), leverColor]).createShader(leverRect));
          canvas.drawRRect(RRect.fromRectAndRadius(leverRect, const Radius.circular(4)), _strokePaint(Colors.black54, 1));

          // زر الاختبار (T) الأصفر المميّز لأجهزة RCD الحقيقية
          canvas.drawCircle(Offset(w * 0.72, h * 0.4), w * 0.11, _fillPaint(const Color(0xFFFFC107)));
          canvas.drawCircle(Offset(w * 0.72, h * 0.4), w * 0.11, _strokePaint(Colors.black38, 1));
          _printedLabel(canvas, Offset(w * 0.72, h * 0.4), 'T', fontSize: 9, color: Colors.black87);

          if (tripped) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.03, h * 0.32, w * 0.12, h * 0.2), const Radius.circular(2)),
              _fillPaint(const Color(0xFFFF9800)),
            );
          }
          _printedLabel(canvas, Offset(w / 2, h * 0.86), 'RCD', fontSize: 8, color: const Color(0xFF37474F));
          break;
        }
      case 'contactor':
        {
          final energized = _rt<bool>('energized') ?? false;
          final coilV = (comp.properties['coilVoltage'] ?? 230).toStringAsFixed(0);

          _plasticBody(canvas, size, const Color(0xFF3E4A59), const Color(0xFF262E38), radius: 10);
          _dinRailClip(canvas, size);

          // غطاء علوي بلون مختلف (نموذجي في الكونتاكتورات الصناعية)
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.05, w * 0.84, h * 0.18), const Radius.circular(5)),
            _fillPaint(const Color(0xFF546575)),
          );
          _printedLabel(canvas, Offset(w / 2, h * 0.14), 'AC ${coilV}V', fontSize: 7.5, color: Colors.white70);

          // ثلاثة أقطاب قدرة، كل قطب فيه تلامسان متحركان يقتربان عند التغذية
          for (var i = 0; i < 3; i++) {
            final cx = w * (0.22 + i * 0.28);
            canvas.drawRect(Rect.fromLTWH(cx - 1.2, h * 0.26, 2.4, h * 0.14), _fillPaint(const Color(0xFF8D9AA8)));
            canvas.drawRect(Rect.fromLTWH(cx - 1.2, h * 0.6, 2.4, h * 0.14), _fillPaint(const Color(0xFF8D9AA8)));
            final gapY = energized ? h * 0.45 : h * 0.4;
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, gapY), width: w * 0.1, height: h * 0.09), const Radius.circular(2)),
              _fillPaint(energized ? AppColors.primary : const Color(0xFF78909C)),
            );
          }

          // مؤشر LED صغير للحالة (يضيء أخضر عند التغذية)
          canvas.drawCircle(Offset(w * 0.88, h * 0.14), 3.4, _fillPaint(energized ? const Color(0xFF00E676) : const Color(0xFF3A4550)));
          if (energized) {
            canvas.drawCircle(Offset(w * 0.88, h * 0.14), 6, Paint()..color = const Color(0xFF00E676).withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
          }

          _printedLabel(canvas, Offset(w / 2, h * 0.9), energized ? 'ON' : 'OFF', fontSize: 9, color: energized ? AppColors.primary : Colors.white54);
          break;
        }
      case 'aux_contact':
        _drawGenericIcon(canvas, size, Icons.call_split);
        break;
      case 'relay':
      case 'timer':
      case 'counter':
        {
          final energized = (_rt<bool>('energized') ?? false) || (_rt<bool>('tripped') ?? false);
          _plasticBody(canvas, size, const Color(0xFF3B4A5A), const Color(0xFF232E3B), radius: 7);
          _dinRailClip(canvas, size);

          // نافذة شفافة صغيرة (Cover) تُظهر آلية التلامس الداخلية
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, h * 0.18, w * 0.6, h * 0.42), const Radius.circular(4)),
            _fillPaint(Colors.black.withOpacity(0.28)),
          );

          // مؤشر LED للحالة
          canvas.drawCircle(Offset(w * 0.5, h * 0.3), 5, _fillPaint(energized ? const Color(0xFF00E676) : const Color(0xFF546475)));
          if (energized) {
            canvas.drawCircle(Offset(w * 0.5, h * 0.3), 9, Paint()..color = const Color(0xFF00E676).withOpacity(0.32)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
          }
          _printedLabel(canvas, Offset(w * 0.5, h * 0.48), key == 'timer' ? '⏱' : (key == 'counter' ? '#' : 'K'), fontSize: 12, color: Colors.white70);
          _printedLabel(canvas, Offset(w * 0.5, h * 0.86), key == 'timer' ? 'TIMER' : (key == 'counter' ? 'COUNTER' : 'RELAY'), fontSize: 6.5, color: Colors.white38);
          break;
        }
      case 'thermal_relay':
        {
          final tripped = _rt<bool>('tripped') ?? false;
          final rated = (comp.properties['ratedCurrent'] ?? 16).toStringAsFixed(0);
          _plasticBody(canvas, size, const Color(0xFFEDE3D3), const Color(0xFFC9BC9F), radius: 8);
          _dinRailClip(canvas, size);

          // قرص ضبط شدة التيار (Dial) — تفصيل مميّز للريليه الحراري الحقيقي
          final dialCenter = Offset(w * 0.5, h * 0.32);
          canvas.drawCircle(dialCenter, w * 0.14, _fillPaint(const Color(0xFF37474F)));
          canvas.drawCircle(dialCenter, w * 0.14, _strokePaint(Colors.black45, 1));
          canvas.save();
          canvas.translate(dialCenter.dx, dialCenter.dy);
          canvas.rotate(0.6);
          canvas.drawLine(Offset.zero, Offset(0, -w * 0.11), _strokePaint(Colors.white70, 1.6));
          canvas.restore();
          _printedLabel(canvas, Offset(w * 0.5, h * 0.5), '${rated}A', fontSize: 7, color: const Color(0xFF3E2C1C));

          // زر إعادة الضبط (RESET) الأزرق المميز
          canvas.drawCircle(Offset(w * 0.24, h * 0.72), w * 0.09, _fillPaint(tripped ? const Color(0xFFFF7043) : const Color(0xFF1E88E5)));
          _printedLabel(canvas, Offset(w * 0.24, h * 0.72), 'R', fontSize: 7, color: Colors.white);
          // زر الاختبار (TEST)
          canvas.drawCircle(Offset(w * 0.76, h * 0.72), w * 0.09, _fillPaint(const Color(0xFF546475)));
          _printedLabel(canvas, Offset(w * 0.76, h * 0.72), 'T', fontSize: 7, color: Colors.white);

          if (tripped) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.06, w * 0.12, h * 0.18), const Radius.circular(2)),
              _fillPaint(const Color(0xFFFF9800)),
            );
          }
          break;
        }
      case 'thermostat':
        _drawGenericIcon(canvas, size, Icons.thermostat);
        break;
      case 'plc':
        {
          _plasticBody(canvas, size, const Color(0xFF2D3B4E), const Color(0xFF19222E), radius: 6);
          _dinRailClip(canvas, size);

          // لوحة بلاستيكية فاتحة للطرفيات العلوية والسفلية
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.06, h * 0.04, w * 0.88, h * 0.1), const Radius.circular(2)),
              _fillPaint(const Color(0xFFB0BEC5)));
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.06, h * 0.86, w * 0.88, h * 0.1), const Radius.circular(2)),
              _fillPaint(const Color(0xFFB0BEC5)));

          _printedLabel(canvas, Offset(w / 2, h * 0.5), 'PLC', fontSize: 15, color: Colors.white, weight: FontWeight.w800);

          // شبكة من مصابيح LED صغيرة للمداخل/المخارج (I/O) — تفصيل بصري
          // يحاكي لوحة مؤشرات PLC الحقيقية (المداخل: كهرماني، المخارج: أخضر)
          for (var i = 0; i < 3; i++) {
            canvas.drawCircle(Offset(w * 0.16, h * (0.28 + i * 0.14)), 2.6, _fillPaint(AppColors.warning.withOpacity(0.8)));
            canvas.drawCircle(Offset(w * 0.84, h * (0.28 + i * 0.14)), 2.6, _fillPaint(AppColors.primary.withOpacity(0.85)));
          }
          break;
        }
      case 'push_button_green':
      case 'push_button_red':
        {
          final pressed = _rt<bool>('pressed') ?? false;
          final center = Offset(w / 2, h / 2);
          final outerR = math.min(w, h) / 2 - 2;
          final color = key.contains('green') ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
          final capColor = key.contains('green') ? const Color(0xFF43A047) : const Color(0xFFE53935);

          // إطار كروم معدني خارجي (Bezel)
          canvas.drawCircle(center, outerR, Paint()..shader = const RadialGradient(colors: [Color(0xFFEDEFF1), Color(0xFF8B96A1)]).createShader(Rect.fromCircle(center: center, radius: outerR)));
          canvas.drawCircle(center, outerR, _strokePaint(Colors.black38, 1));

          // زر الضغط نفسه (ينخفض قليلاً ويصبح أغمق عند الضغط)
          final capR = outerR * (pressed ? 0.62 : 0.72);
          canvas.drawCircle(center, capR, Paint()..shader = RadialGradient(colors: [capColor.withOpacity(pressed ? 0.75 : 1), color]).createShader(Rect.fromCircle(center: center, radius: capR)));
          canvas.drawCircle(center, capR, _strokePaint(Colors.black45, 1.2));
          // بريق لامع علوي
          canvas.drawCircle(center + Offset(-capR * 0.32, -capR * 0.32), capR * 0.28, Paint()..color = Colors.white.withOpacity(pressed ? 0.18 : 0.38));
          break;
        }
      case 'emergency_stop':
        {
          final pressed = _rt<bool>('pressed') ?? false;
          final center = Offset(w / 2, h / 2);
          final outerR = math.min(w, h) / 2 - 2;

          // القاعدة الصفراء القياسية لزر التوقف الطارئ
          canvas.drawCircle(center, outerR, _fillPaint(const Color(0xFFFDD835)));
          canvas.drawCircle(center, outerR, _strokePaint(Colors.black87, 2));

          // رأس الفطر الأحمر الكبير
          final headR = outerR * (pressed ? 0.62 : 0.74);
          canvas.drawCircle(center, headR, Paint()..shader = RadialGradient(colors: [const Color(0xFFEF5350).withOpacity(pressed ? 0.8 : 1), const Color(0xFFB71C1C)]).createShader(Rect.fromCircle(center: center, radius: headR)));
          canvas.drawCircle(center, headR, _strokePaint(Colors.black54, 1.4));
          canvas.drawCircle(center + Offset(-headR * 0.3, -headR * 0.3), headR * 0.25, Paint()..color = Colors.white.withOpacity(0.3));
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
    final hsl = HSLColor.fromColor(color);
    final lighter = hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0)).toColor();
    final darker = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
    canvas.drawRRect(
      rect,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [lighter, darker]).createShader(rect.outerRect),
    );
    canvas.drawRRect(rect, _strokePaint(dark ? Colors.black45 : Colors.black26, 1.5));
    // خط لمعان علوي بسيط
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(4, 3, size.width - 8, (size.height - 4) * 0.22), const Radius.circular(7)),
      Paint()..color = Colors.white.withOpacity(dark ? 0.06 : 0.35),
    );
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
