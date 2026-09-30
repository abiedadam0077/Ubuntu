import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// نافذة تنبيه سلامة تظهر مرة واحدة عند أول استخدام للتطبيق: توضح أن
/// المحاكاة تعليمية بحتة وأن أي عمل حقيقي بالكهرباء (خصوصاً 230V/400V)
/// يتطلب فنياً مؤهلاً واتباع معايير السلامة المحلية.
class SafetyDialog extends StatelessWidget {
  const SafetyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), shape: BoxShape.circle),
        child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 32),
      ),
      title: const Text('تنبيه سلامة مهم', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'ElectroSim Pro هو محاكي تعليمي فقط لتعلّم مبادئ الكهرباء والتحكم الصناعي بأمان كامل داخل بيئة افتراضية.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'أي تمديد أو صيانة كهربائية حقيقية — خصوصاً بجهد 230V أو 400V أو في لوحات صناعية — يجب أن يقوم بها فني كهرباء مؤهل ومرخّص فقط، مع اتباع معايير السلامة المحلية (فصل التيار، استخدام العزل المناسب، إلخ).',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'لا يتحمل التطبيق أي مسؤولية عن أي استخدام فعلي خاطئ خارج بيئة المحاكاة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('فهمت، متابعة'),
          ),
        ),
      ],
    );
  }
}
