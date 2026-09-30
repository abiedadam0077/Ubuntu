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
      _paintTerminalStud(canvas, p, t.kind);

      if (showTerminalLabels && t.label.isNotEmpty) {
        _drawTerminalLabel(canvas, size, t, p);
      }
    }
  }

  /// طرف توصيل واقعي على هيئة "برغي نحاسي" حقيقي (كما في قفص التوصيل
  /// الفعلي للأجهزة الكهربائية): قرص نحاسي/برونزي بتدرّج معدني شعاعي +
  /// فتحة برغي (Slot) مطبوعة + حلقة داخلية صغيرة تحمل لون الدلالة
  /// الكهربائية (طور أحمر/تعادل أزرق/أرضي أخضر...) بدل النقطة المسطحة
  /// القديمة — يجعل نقاط التوصيل أوضح ودقيقة بصرياً وأكثر واقعية.
  void _paintTerminalStud(Canvas canvas, Offset p, TerminalKind kind) {
    final semantic = _terminalColor(kind);
    canvas.drawCircle(p + const Offset(0.4, 0.7), 6.4, Paint()..color = Colors.black.withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
    canvas.drawCircle(
      p,
      6.2,
      Paint()..shader = const RadialGradient(colors: [Color(0xFFF0C987), Color(0xFFB8823A), Color(0xFF7A551F)], stops: [0, 0.65, 1]).createShader(Rect.fromCircle(center: p, radius: 6.2)),
    );
    canvas.drawCircle(p, 6.2, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 0.8);
    canvas.drawCircle(p, 3.3, Paint()..color = semantic);
    canvas.drawCircle(p, 3.3, Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 0.6);
    canvas.drawLine(p - const Offset(4.3, 0), p + const Offset(4.3, 0), Paint()..color = Colors.black.withOpacity(0.55)..strokeWidth = 1.1);
    canvas.drawCircle(p - const Offset(1.6, 1.6), 1.15, Paint()..color = Colors.white.withOpacity(0.65));
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

  /// صفيحة توصيل فضّية (قفص برغي) — الجزء المعدني الذي يُثبَّت فيه السلك
  /// فعلياً في أجهزة سكة DIN الحقيقية (قاطع/فيوز/RCD). تُرسم خلف نقاط
  /// التوصيل (Terminals) لتعطي إحساساً بأن الطرف مُثبَّت في قفص برغي حقيقي
  /// وليس مجرد نقطة ملوّنة عائمة.
  void _terminalCage(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFECEFF1), Color(0xFF90A4AE)]).createShader(rect),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 0.8);
  }

  /// مسنّنات تثبيت سكة DIN السفلية (أسنان صغيرة رمادية) — تُكمِّل
  /// [_dinRailClip] العلوي حتى يبدو الجهاز "مُركَّباً" فعلياً على القضيب.
  void _dinFeet(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final fx in [w * 0.22, w * 0.5, w * 0.78]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(fx, h - 1.5), width: w * 0.12, height: 3), const Radius.circular(1)),
        Paint()..color = const Color(0xFF5C6670),
      );
    }
  }

  /// رافعة تبديل واقعية بلمعان علوي (تُستخدم فعلياً في MCB/RCD/قاطع الحماية)
  void _rockerLever(Canvas canvas, Rect rect, Color color) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rr, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.25)!, color, Color.lerp(color, Colors.black, 0.25)!]).createShader(rect));
    canvas.drawRRect(rr, Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rect.left + 1.5, rect.top + 1.5, rect.width - 3, rect.height * 0.22), const Radius.circular(2)),
      Paint()..color = Colors.white.withOpacity(0.35),
    );
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
      case 'pilot_lamp':
        {
          // لمبة إشارة صناعية (Pilot Lamp): جسم أسطواني أسود + قبّة ملوّنة
          // مضيئة أعلاه + سلكا تغذية خارجان من القاعدة — تصميم مختلف تماماً
          // عن مصباح الإضاءة العادي (زجاجة شفافة) لأنه جهاز مختلف فعلياً.
          final brightness = ((_rt<num>('brightness')) ?? 0).toDouble().clamp(0.0, 1.4);
          const lensColor = Color(0xFFFFA726);
          final domeCenter = Offset(w / 2, h * 0.3);
          final domeR = w * 0.32;

          if (brightness > 0.02) {
            canvas.drawCircle(
              domeCenter,
              domeR * 2.3,
              Paint()
                ..color = lensColor.withOpacity((0.15 + brightness * 0.4).clamp(0.0, 0.7).toDouble())
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
            );
          }

          final bodyRect = Rect.fromLTWH(w * 0.22, h * 0.42, w * 0.56, h * 0.4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)),
            Paint()..shader = const LinearGradient(colors: [Color(0xFF3A3F44), Color(0xFF17191B)]).createShader(bodyRect),
          );
          canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)), _strokePaint(Colors.black87, 1));

          canvas.drawCircle(domeCenter, domeR, Paint()..color = Color.lerp(lensColor.withOpacity(0.35), lensColor, brightness.clamp(0.0, 1.0).toDouble())!);
          canvas.drawCircle(domeCenter, domeR, _strokePaint(Colors.black54, 1));
          canvas.drawCircle(domeCenter + Offset(-domeR * 0.3, -domeR * 0.3), domeR * 0.24, Paint()..color = Colors.white.withOpacity(0.4 + brightness * 0.3));

          canvas.drawLine(Offset(w * 0.32, bodyRect.bottom), Offset(w * 0.32, h * 0.92), Paint()..color = const Color(0xFFB0855A)..strokeWidth = 2);
          canvas.drawLine(Offset(w * 0.68, bodyRect.bottom), Offset(w * 0.68, h * 0.92), Paint()..color = const Color(0xFF5A87B0)..strokeWidth = 2);
          break;
        }
      case 'lamp':
      case 'lamp_led':
        {
          final brightness = ((_rt<num>('brightness')) ?? 0).toDouble().clamp(0.0, 1.4);
          final bulbCenter = Offset(w / 2, h * 0.4);
          final bulbR = math.min(w, h) * 0.3;
          const glowColor = Colors.amberAccent;

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
      case 'motor_3ph':
        {
          // محرك ثلاثي الطور واقعي بترتيب أفقي: صندوق توصيل U/V/W أعلى الجسم
          // (عند نفس إحداثيات الأطراف الفعلية 0.2/0.5/0.8)، مروحة تبريد دوّارة
          // عند الطرف الأيسر، وقاعدة/أرجل تثبيت أسفل الجسم كالمحرك الحقيقي.
          final rpmRatio = (_rt<num>('rpmRatio') ?? 0).toDouble();
          final running = rpmRatio > 0.02;

          // القاعدة المعدنية السفلية (Mounting feet)
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.14, h * 0.86, w * 0.72, h * 0.07), const Radius.circular(2)), _fillPaint(const Color(0xFF78838C)));
          canvas.drawRect(Rect.fromLTWH(w * 0.24, h * 0.8, w * 0.07, h * 0.09), _fillPaint(const Color(0xFF90A4AE)));
          canvas.drawRect(Rect.fromLTWH(w * 0.7, h * 0.8, w * 0.07, h * 0.09), _fillPaint(const Color(0xFF90A4AE)));

          // الجسم الأسطواني الرئيسي (يمتد أفقياً بعرض صندوق التوصيل تقريباً)
          final bodyRect = Rect.fromLTWH(w * 0.14, h * 0.32, w * 0.72, h * 0.46);
          final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyRect.height / 2));
          canvas.drawRRect(
            bodyRRect,
            Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: const [Color(0xFF90A4AE), Color(0xFF546E7A), Color(0xFF2E3B44)], stops: const [0, 0.5, 1]).createShader(bodyRect),
          );
          canvas.drawRRect(bodyRRect, _strokePaint(Colors.black38, 1));
          for (var i = 0; i < 7; i++) {
            final fx = bodyRect.left + bodyRect.width * (0.1 + i * 0.13);
            canvas.drawLine(Offset(fx, bodyRect.top + 2), Offset(fx, bodyRect.bottom - 2), Paint()..color = Colors.black26..strokeWidth = 1.6);
          }

          // صندوق التوصيل الكهربائي أعلى الجسم عند مواضع U/V/W الفعلية
          final boxRect = Rect.fromLTWH(w * 0.14, h * 0.06, w * 0.72, h * 0.2);
          canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(4)), _fillPaint(const Color(0xFF263238)));
          canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(4)), _strokePaint(Colors.black45, 1));
          for (final e in const [MapEntry('U', 0.2), MapEntry('V', 0.5), MapEntry('W', 0.8)]) {
            canvas.drawLine(Offset(w * e.value, 0), Offset(w * e.value, boxRect.top + 3), Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 1.4);
            _printedLabel(canvas, Offset(w * e.value, boxRect.bottom - boxRect.height * 0.28), e.key, fontSize: 6.5, color: Colors.white70);
          }

          // مروحة التبريد الدوّارة عند الطرف الأيسر (Non-drive end)
          final fanCenter = Offset(w * 0.14, bodyRect.center.dy);
          canvas.drawCircle(fanCenter, bodyRect.height * 0.34, _fillPaint(const Color(0xFF37474F)));
          canvas.save();
          canvas.translate(fanCenter.dx, fanCenter.dy);
          canvas.rotate(animPhase * math.pi * 2);
          for (var i = 0; i < 5; i++) {
            canvas.save();
            canvas.rotate(i * (math.pi * 2 / 5));
            final blade = Path()
              ..moveTo(0, -1.5)
              ..lineTo(bodyRect.height * 0.32, -bodyRect.height * 0.1)
              ..lineTo(bodyRect.height * 0.32, bodyRect.height * 0.1)
              ..lineTo(0, 1.5)
              ..close();
            canvas.drawPath(blade, _fillPaint(running ? const Color(0xFFFFA726) : const Color(0xFFBCAAA4)));
            canvas.restore();
          }
          canvas.restore();
          canvas.drawCircle(fanCenter, bodyRect.height * 0.09, _fillPaint(const Color(0xFF90A4AE)));

          _printedLabel(canvas, Offset(w * 0.58, bodyRect.center.dy), '3~ M', fontSize: 9.5, color: Colors.white70);
          break;
        }
      case 'motor':
      case 'motor_small':
        {
          // محرك بسيط (أحادي الطور / DC) — جسم أسطواني أفقي بأسلاك يسار/يمين
          // تطابق موضع الأطراف الفعلية بالضبط، ومروحة تبريد دوّارة داخلية.
          final rpmRatio = (_rt<num>('rpmRatio') ?? 0).toDouble();
          final running = rpmRatio > 0.02;
          final accent = key == 'motor_small' ? const Color(0xFF3D9CFF) : const Color(0xFF9B6BFF);

          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.84, w * 0.56, h * 0.07), const Radius.circular(2)), _fillPaint(const Color(0xFF78838C)));

          final bodyRect = Rect.fromLTWH(w * 0.1, h * 0.22, w * 0.8, h * 0.58);
          final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyRect.height / 2));
          canvas.drawRRect(
            bodyRRect,
            Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF90A4AE), const Color(0xFF546E7A), const Color(0xFF2E3B44)]).createShader(bodyRect),
          );
          canvas.drawRRect(bodyRRect, _strokePaint(accent, 1.8));
          for (var i = 0; i < 6; i++) {
            final fx = bodyRect.left + bodyRect.width * (0.14 + i * 0.15);
            canvas.drawLine(Offset(fx, bodyRect.top + 2), Offset(fx, bodyRect.bottom - 2), Paint()..color = Colors.black26..strokeWidth = 1.4);
          }

          // صندوق توصيل صغير زخرفي أعلى الجسم
          final boxRect = Rect.fromCenter(center: Offset(w / 2, h * 0.14), width: w * 0.26, height: h * 0.14);
          canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(3)), _fillPaint(const Color(0xFF37474F)));

          // أسلاك التوصيل الفعلية من الجسم إلى الحافتين (تطابق الأطراف الحقيقية)
          canvas.drawLine(Offset(0, h * 0.5), Offset(bodyRect.left, h * 0.5), Paint()..color = const Color(0xFFB0855A)..strokeWidth = 2.2);
          canvas.drawLine(Offset(bodyRect.right, h * 0.5), Offset(w, h * 0.5), Paint()..color = const Color(0xFF5A87B0)..strokeWidth = 2.2);

          // مروحة تبريد دوّارة قرب الطرف الأيمن الداخلي
          final fanCenter = Offset(bodyRect.right - bodyRect.height * 0.42, bodyRect.center.dy);
          canvas.drawCircle(fanCenter, bodyRect.height * 0.36, _fillPaint(const Color(0xFF263238)));
          canvas.save();
          canvas.translate(fanCenter.dx, fanCenter.dy);
          canvas.rotate(animPhase * math.pi * 2);
          for (var i = 0; i < 4; i++) {
            canvas.save();
            canvas.rotate(i * math.pi / 2);
            canvas.drawOval(Rect.fromCenter(center: Offset(bodyRect.height * 0.2, 0), width: bodyRect.height * 0.34, height: bodyRect.height * 0.14),
                _fillPaint(running ? const Color(0xFFFFA726) : const Color(0xFF78909C)));
            canvas.restore();
          }
          canvas.restore();
          canvas.drawCircle(fanCenter, bodyRect.height * 0.09, _fillPaint(const Color(0xFFCFD8DC)));

          _printedLabel(canvas, Offset(w / 2, h * 0.92), key == 'motor_small' ? 'DC M' : 'M 1~', fontSize: 8, color: const Color(0xFF37474F));
          break;
        }
      case 'switch':
        {
          // لوحة مفتاح بأسلوب "أشعة-سينية" احترافي: قاعدة نحاسية/وردية دافئة
          // تُظهر مسار التلامس الداخلي فعلياً (مفيد تعليمياً ويطابق الهوية
          // البصرية المرجعية)، مع دعم كامل للمفاتيح المتعددة الأقطاب
          // (Multi-gang) والمفتاح التبادلي (SPDT) حسب موضعه الحقيقي.
          final isSpdt = (comp.properties['isSpdt'] ?? 0) >= 1;
          final poleCount = (comp.properties['poleCount'] ?? 1).toInt().clamp(1, 6);
          const wire = Color(0xFF5B3A22);

          final plate = RRect.fromRectAndRadius(Rect.fromLTWH(1.5, 1.5, w - 3, h - 3), const Radius.circular(10));
          canvas.drawRRect(
            plate,
            Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE7B9A4), Color(0xFFD08D6E)]).createShader(Rect.fromLTWH(0, 0, w, h)),
          );
          canvas.drawRRect(plate, Paint()..color = Colors.black.withOpacity(0.32)..style = PaintingStyle.stroke..strokeWidth = 1.2);
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(3, 2, w - 6, (h - 4) * 0.2), const Radius.circular(7)),
            Paint()..color = Colors.white.withOpacity(0.22),
          );

          if (isSpdt) {
            final position = _rt<int>('position') ?? 0;
            final com = Offset(w * 0.5, h * 0.95);
            final t0 = Offset(w * 0.22, h * 0.05);
            final t1 = Offset(w * 0.78, h * 0.05);
            final active = position == 0 ? t0 : t1;
            final inactive = position == 0 ? t1 : t0;
            canvas.drawLine(com, inactive, Paint()..color = wire.withOpacity(0.28)..strokeWidth = 2.2..strokeCap = StrokeCap.round);
            canvas.drawLine(com, active, Paint()..color = wire..strokeWidth = 3.2..strokeCap = StrokeCap.round);
            canvas.drawCircle(com, 3, _fillPaint(wire));
            canvas.drawCircle(active, 2.4, _fillPaint(AppColors.primary));
          } else {
            for (var p = 0; p < poleCount; p++) {
              final x = (p + 1) / (poleCount + 1) * w;
              final on = (_rt<bool>('on_$p') ?? _rt<bool>('on')) ?? false;
              final top = Offset(x, h * 0.05);
              final bottom = Offset(x, h * 0.95);
              if (on) {
                canvas.drawLine(top, bottom, Paint()..color = wire..strokeWidth = 3..strokeCap = StrokeCap.round);
              } else {
                canvas.drawLine(top, Offset(x, h * 0.42), Paint()..color = wire.withOpacity(0.55)..strokeWidth = 2.6..strokeCap = StrokeCap.round);
                canvas.drawLine(Offset(x, h * 0.58), bottom, Paint()..color = wire.withOpacity(0.55)..strokeWidth = 2.6..strokeCap = StrokeCap.round);
              }
              final knobR = (w / poleCount) * 0.2;
              final knobY = on ? h * 0.28 : h * 0.72;
              canvas.drawCircle(Offset(x, knobY), knobR, _fillPaint(on ? AppColors.primary : const Color(0xFF8C6A55)));
              canvas.drawCircle(Offset(x, knobY), knobR, _strokePaint(Colors.black38, 1));
            }
          }
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
        {
          // قاطع MCB واقعي بترتيب رأسي (دخول من أعلى القضيب، خروج من الأسفل
          // نحو الحمل) مطابق لشكل قواطع سكة DIN الحقيقية: جسم أبيض/رمادي
          // فاتح + رافعة زرقاء بارزة تشغل معظم الارتفاع + قفصا برغي فضيان.
          final tripped = _rt<bool>('tripped') ?? false;
          final blown = _rt<bool>('blown') ?? false;
          final on = (_rt<bool>('on') ?? true) && !blown;
          final rated = (comp.properties['ratedCurrent'] ?? 10).toStringAsFixed(0);

          _plasticBody(canvas, size, const Color(0xFFF9FBFC), const Color(0xFFDCE3E7), inset: 1.4, radius: 4);
          _dinRailClip(canvas, size);
          _dinFeet(canvas, size);

          // قفصا التوصيل الفضيان أعلى وأسفل (خلف نقاط التوصيل النحاسية)
          _terminalCage(canvas, Rect.fromCenter(center: Offset(w / 2, h * 0.065), width: w * 0.56, height: h * 0.1));
          _terminalCage(canvas, Rect.fromCenter(center: Offset(w / 2, h * 0.935), width: w * 0.56, height: h * 0.1));

          // شريط أسود علوي يحمل شدة التيار المقنن (كما تُطبع فعلياً على القواطع)
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, h * 0.2), width: w * 0.7, height: h * 0.08), const Radius.circular(2)),
            _fillPaint(const Color(0xFF20272D)),
          );
          _printedLabel(canvas, Offset(w / 2, h * 0.2), '${rated}A', fontSize: 6.6, color: Colors.white);
          _printedLabel(canvas, Offset(w / 2, h * 0.29), 'MCB', fontSize: 5.6, color: const Color(0xFF607D8B), weight: FontWeight.w600);

          // الرافعة الزرقاء المميزة — تنزلق فعلياً لأعلى (ON) أو لأسفل (OFF)،
          // وتتحول للبرتقالي عند التريب (Trip) كما في الأجهزة الحقيقية
          final leverColor = tripped ? const Color(0xFFFF7A45) : const Color(0xFF1B63D6);
          final leverRect = Rect.fromCenter(center: Offset(w / 2, on ? h * 0.5 : h * 0.66), width: w * 0.4, height: h * 0.42);
          _rockerLever(canvas, leverRect, leverColor);
          _printedLabel(canvas, Offset(w / 2, leverRect.top + leverRect.height * 0.24), 'I', fontSize: 8.5, color: Colors.white);
          _printedLabel(canvas, Offset(w / 2, leverRect.bottom - leverRect.height * 0.2), 'O', fontSize: 8, color: Colors.white70);

          if (tripped) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.38, w * 0.16, h * 0.2), const Radius.circular(2)),
              _fillPaint(const Color(0xFFFF9800)),
            );
          }
          break;
        }
      case 'fuse':
        {
          // فيوز واقعي: جسم بلاستيكي رمادي + أنبوب زجاجي شفاف في المنتصف
          // يظهر بداخله السلك المنصهر — ينكسر بصرياً فعلياً عند الانصهار
          final blown = _rt<bool>('blown') ?? false;
          final rated = (comp.properties['ratedCurrent'] ?? 6).toStringAsFixed(0);

          _plasticBody(canvas, size, const Color(0xFFEDEFF1), const Color(0xFFCBD3D8), inset: 1.4, radius: 4);
          _dinRailClip(canvas, size);
          _dinFeet(canvas, size);
          _terminalCage(canvas, Rect.fromCenter(center: Offset(w / 2, h * 0.08), width: w * 0.6, height: h * 0.1));
          _terminalCage(canvas, Rect.fromCenter(center: Offset(w / 2, h * 0.92), width: w * 0.6, height: h * 0.1));

          // الأنبوب الزجاجي الشفاف لعنصر الفيوز
          final tubeRect = Rect.fromCenter(center: Offset(w / 2, h * 0.5), width: w * 0.34, height: h * 0.56);
          canvas.drawRRect(
            RRect.fromRectAndRadius(tubeRect, const Radius.circular(8)),
            Paint()..color = const Color(0xFFB0C4CE).withOpacity(0.5),
          );
          canvas.drawRRect(RRect.fromRectAndRadius(tubeRect, const Radius.circular(8)), _strokePaint(const Color(0xFF78909C), 1.2));
          // غطاءان معدنيان طرفيان للأنبوب (كما في خرطوشة الفيوز الحقيقية)
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tubeRect.left, tubeRect.top, tubeRect.width, tubeRect.height * 0.14), const Radius.circular(6)), _fillPaint(const Color(0xFFB0BEC5)));
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tubeRect.left, tubeRect.bottom - tubeRect.height * 0.14, tubeRect.width, tubeRect.height * 0.14), const Radius.circular(6)), _fillPaint(const Color(0xFFB0BEC5)));

          if (blown) {
            // سلك منقطع (فيوز محترق) — خط متعرّج منكسر بلون داكن مع أثر احتراق خفيف
            canvas.drawCircle(Offset(w / 2, h * 0.5), 3, Paint()..color = Colors.black45..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
            final p1 = Path()
              ..moveTo(w / 2, tubeRect.top + tubeRect.height * 0.18)
              ..lineTo(w / 2 - 2, h * 0.46);
            final p2 = Path()
              ..moveTo(w / 2 + 2, h * 0.54)
              ..lineTo(w / 2, tubeRect.bottom - tubeRect.height * 0.18);
            canvas.drawPath(p1, _strokePaint(const Color(0xFF37474F), 1.6));
            canvas.drawPath(p2, _strokePaint(const Color(0xFF37474F), 1.6));
          } else {
            // سلك سليم متصل (خط مستقيم رفيع لامع)
            canvas.drawLine(
              Offset(w / 2, tubeRect.top + tubeRect.height * 0.16),
              Offset(w / 2, tubeRect.bottom - tubeRect.height * 0.16),
              _strokePaint(const Color(0xFFC0A020), 1.6),
            );
          }
          _printedLabel(canvas, Offset(w / 2, h * 0.5 + h * 0.32), '${rated}A', fontSize: 6.4, color: const Color(0xFF37474F));
          break;
        }
      case 'rcd':
        {
          // قاطع تفاضلي RCD واقعي ذو قطبين جنباً إلى جنب (L يساراً، N يميناً)
          // — يطابق ترتيب الأطراف الرأسي الجديد: دخول أعلى/خروج أسفل لكل عمود.
          final tripped = _rt<bool>('tripped') ?? false;
          final sensitivity = (comp.properties['sensitivityMa'] ?? 30).toStringAsFixed(0);

          _plasticBody(canvas, size, const Color(0xFFF9FBFC), const Color(0xFFDCE3E7), inset: 1.4, radius: 4);
          _dinRailClip(canvas, size);
          _dinFeet(canvas, size);

          _terminalCage(canvas, Rect.fromCenter(center: Offset(w * 0.32, h * 0.06), width: w * 0.26, height: h * 0.08));
          _terminalCage(canvas, Rect.fromCenter(center: Offset(w * 0.68, h * 0.06), width: w * 0.26, height: h * 0.08));
          _terminalCage(canvas, Rect.fromCenter(center: Offset(w * 0.32, h * 0.94), width: w * 0.26, height: h * 0.08));
          _terminalCage(canvas, Rect.fromCenter(center: Offset(w * 0.68, h * 0.94), width: w * 0.26, height: h * 0.08));

          // نافذة سوداء لحساسية التسريب (مثل الطباعة الحقيقية على RCD)
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, h * 0.17), width: w * 0.7, height: h * 0.08), const Radius.circular(2)),
            _fillPaint(const Color(0xFF20272D)),
          );
          _printedLabel(canvas, Offset(w / 2, h * 0.17), '${sensitivity}mA', fontSize: 6.4, color: Colors.white);

          // رافعة زرقاء عريضة تغطي القطبين معاً (كما في RCD الحقيقي ذي مفتاح موحّد)
          final leverColor = tripped ? const Color(0xFF37474F) : const Color(0xFF1B63D6);
          final leverRect = Rect.fromCenter(center: Offset(w / 2, tripped ? h * 0.7 : h * 0.5), width: w * 0.52, height: h * 0.34);
          _rockerLever(canvas, leverRect, leverColor);

          // زر الاختبار (T) الأصفر المميّز لأجهزة RCD الحقيقية
          canvas.drawCircle(Offset(w / 2, h * 0.78), w * 0.1, _fillPaint(const Color(0xFFFFC107)));
          canvas.drawCircle(Offset(w / 2, h * 0.78), w * 0.1, _strokePaint(Colors.black38, 1));
          _printedLabel(canvas, Offset(w / 2, h * 0.78), 'T', fontSize: 8, color: Colors.black87);

          if (tripped) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.02, h * 0.4, w * 0.14, h * 0.18), const Radius.circular(2)),
              _fillPaint(const Color(0xFFFF9800)),
            );
          }
          break;
        }
      case 'contactor':
        {
          // كونتاكتور صناعي واقعي: جسم أبيض/رمادي فاتح (كما في Schneider/ABB
          // الحقيقية) + كتلة ملف جانبية عند A1/A2 + نافذة زرقاء مركزية لحامل
          // التلامسات + 3 أقطاب قدرة عند نفس إحداثيات الأطراف الفعلية تماماً
          // (0.35 / 0.65 / 0.95) حتى تتطابق نقاط التوصيل مع الرسم بصرياً.
          final energized = _rt<bool>('energized') ?? false;
          final coilV = (comp.properties['coilVoltage'] ?? 230).toStringAsFixed(0);

          _plasticBody(canvas, size, const Color(0xFFF4F6F7), const Color(0xFFD7DEE3), radius: 8, inset: 1.5);
          _dinRailClip(canvas, size);

          // كتلة الملف الجانبية (حيث يقع A1 أعلى وA2 أسفل فعلياً على الحافة اليسرى)
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(2, h * 0.05, w * 0.15, h * 0.9), const Radius.circular(4)),
            Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFC7D0D6), Color(0xFFA6B3BC)]).createShader(Rect.fromLTWH(0, 0, w, h)),
          );
          _printedLabel(canvas, Offset(w * 0.095, h * 0.12), 'A1', fontSize: 5.6, color: const Color(0xFF37474F));
          _printedLabel(canvas, Offset(w * 0.095, h * 0.88), 'A2', fontSize: 5.6, color: const Color(0xFF37474F));

          // نافذة زرقاء مركزية (حجرة حامل التلامسات المتحركة) بعرض الأقطاب الثلاثة
          final coilWindow = Rect.fromLTWH(w * 0.22, h * 0.36, w * 0.74, h * 0.3);
          canvas.drawRRect(
            RRect.fromRectAndRadius(coilWindow, const Radius.circular(4)),
            Paint()..shader = LinearGradient(colors: [const Color(0xFF4A7BDE), const Color(0xFF1E3E82)]).createShader(coilWindow),
          );
          canvas.drawRRect(RRect.fromRectAndRadius(coilWindow, const Radius.circular(4)), _strokePaint(Colors.black38, 1));
          _printedLabel(canvas, Offset(w * 0.6, h * 0.14), 'AC ${coilV}V', fontSize: 6.6, color: const Color(0xFF37474F));

          // ثلاثة أقطاب قدرة عند إحداثيات الأطراف الحقيقية 1L1/3L2/5L3 و 2T1/4T2/6T3
          for (final cx in [w * 0.35, w * 0.65, w * 0.95]) {
            canvas.drawRect(Rect.fromLTWH(cx - 1.3, h * 0.06, 2.6, h * 0.3), _fillPaint(const Color(0xFF8D9AA8)));
            canvas.drawRect(Rect.fromLTWH(cx - 1.3, h * 0.64, 2.6, h * 0.3), _fillPaint(const Color(0xFF8D9AA8)));
            final gapY = energized ? h * 0.47 : h * 0.42;
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, gapY), width: w * 0.08, height: h * 0.09), const Radius.circular(2)),
              _fillPaint(energized ? AppColors.primary : const Color(0xFFCFD8DC)),
            );
          }

          // مؤشر LED صغير للحالة (يضيء أخضر عند التغذية)
          canvas.drawCircle(Offset(w * 0.28, h * 0.14), 3.2, _fillPaint(energized ? const Color(0xFF00E676) : const Color(0xFFB0BEC5)));
          if (energized) {
            canvas.drawCircle(Offset(w * 0.28, h * 0.14), 6, Paint()..color = const Color(0xFF00E676).withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
          }

          _printedLabel(canvas, Offset(w / 2, h * 0.96), energized ? 'ON' : 'OFF', fontSize: 7.5, color: energized ? const Color(0xFF1B8E4E) : const Color(0xFF78909C));
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
          // كتلة زر ضغط صناعي واقعي 22مم: هيكل أسود مربّع + قبّة لامعة ملوّنة
          // بارزة من الأعلى تنخفض فعلياً عند الضغط + منطقة طرفين سفلية
          // (11/12) مطبوع عليها "Momentary" كما في الأجهزة الحقيقية.
          final pressed = _rt<bool>('pressed') ?? false;
          final color = key.contains('green') ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
          final capColor = key.contains('green') ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

          final housing = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.06, w * 0.84, h * 0.9), const Radius.circular(6));
          canvas.drawRRect(housing, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B2F33), Color(0xFF17191B)]).createShader(housing.outerRect));
          canvas.drawRRect(housing, _strokePaint(Colors.black87, 1));

          // بريق معدني خفيف على حافة الهيكل
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.08, w * 0.8, h * 0.06), const Radius.circular(3)), Paint()..color = Colors.white.withOpacity(0.06));

          // القبّة/الزر الملوّن البارز من أعلى الهيكل — ينخفض عند الضغط
          final capCenter = Offset(w / 2, pressed ? h * 0.32 : h * 0.26);
          final capR = w * (pressed ? 0.27 : 0.32);
          canvas.drawCircle(capCenter, capR * 1.12, Paint()..color = Colors.black45);
          canvas.drawCircle(capCenter, capR, Paint()..shader = RadialGradient(colors: [capColor.withOpacity(pressed ? 0.7 : 1), color]).createShader(Rect.fromCircle(center: capCenter, radius: capR)));
          canvas.drawCircle(capCenter, capR, _strokePaint(Colors.black54, 1.1));
          canvas.drawCircle(capCenter + Offset(-capR * 0.3, -capR * 0.3), capR * 0.26, Paint()..color = Colors.white.withOpacity(pressed ? 0.16 : 0.4));

          _printedLabel(canvas, Offset(w / 2, h * 0.57), 'Momentary', fontSize: 5.6, color: Colors.white38);
          // منطقة الطرفين السفلية (11/12)
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.72, w * 0.64, h * 0.2), const Radius.circular(3)), _fillPaint(const Color(0xFF3A3F44)));
          break;
        }
      case 'emergency_stop':
        {
          // زر توقف طارئ صناعي: نفس هيكل زر الضغط الأسود + رأس فطر أحمر كبير
          // على قاعدة صفراء (المعيار العالمي لأزرار الطوارئ) — لا ينخفض
          // بالكامل بل "يُقفل" (Latching) عند الضغط كما في الحقيقة.
          final pressed = _rt<bool>('pressed') ?? false;
          final housing = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.06, h * 0.08, w * 0.88, h * 0.86), const Radius.circular(6));
          canvas.drawRRect(housing, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B2F33), Color(0xFF17191B)]).createShader(housing.outerRect));
          canvas.drawRRect(housing, _strokePaint(Colors.black87, 1));

          final center = Offset(w / 2, h * 0.32);
          final ringR = w * 0.36;
          canvas.drawCircle(center, ringR, _fillPaint(const Color(0xFFFDD835)));
          canvas.drawCircle(center, ringR, _strokePaint(Colors.black87, 1.6));

          final headR = ringR * (pressed ? 0.72 : 0.84);
          canvas.drawCircle(center, headR, Paint()..shader = RadialGradient(colors: [const Color(0xFFEF5350).withOpacity(pressed ? 0.82 : 1), const Color(0xFFB71C1C)]).createShader(Rect.fromCircle(center: center, radius: headR)));
          canvas.drawCircle(center, headR, _strokePaint(Colors.black54, 1.4));
          canvas.drawCircle(center + Offset(-headR * 0.3, -headR * 0.3), headR * 0.25, Paint()..color = Colors.white.withOpacity(0.3));
          if (pressed) {
            _printedLabel(canvas, Offset(w / 2, h * 0.6), '🔒', fontSize: 9, color: Colors.white70);
          }
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.16, h * 0.72, w * 0.68, h * 0.2), const Radius.circular(3)), _fillPaint(const Color(0xFF3A3F44)));
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
