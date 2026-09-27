# السلام عليكم 🌙

تطبيق أندرويد صغير وزوين: كيفتحو تلقى **«السلام عليكم ورحمة الله وبركاته»** مكتوبة بخط عربي
جميل (Amiri) فوق سماء ليلية فيها نجوم كتلمع وشُهُب كتدوز، وكل ضغطة على الشاشة كتردّها
السلامة مع شرارة دهبية وهدّة هاتف خفيفة.

## الحصول على APK
**الطريقة المباشرة:** حمّل `dist/Salam-Alaikum.apk` مباشرة من هاد المستودع:
<https://github.com/abiedadam0077/Ubuntu/raw/arena/01a0e462-ubuntu/dist/Salam-Alaikum.apk>

**ولا من CI:**
1. دخل لتبويب **[Actions](https://github.com/abiedadam0077/Ubuntu/actions/workflows/build-apk.yml)** فالمستودع
2. حل آخر تشغيلة ديال **«بناء تطبيق السلام (APK)»**
3. حمّل **Salam-Alaikum.apk** من قسم **Artifacts**
4. منبعد: كيدخل الـ APK أوتوماتيكيًا فالمستودع تحت `dist/` — وكتقدر تصايب **Release** دائم بزر
   «Run workflow» (workflow_dispatch) فصفحة الـ workflow

## البناء يدويًا
```bash
cd salam-app
./gradlew assembleDebug
# الناتج: app/build/outputs/apk/debug/Salam-Alaikum.apk
```

## التقنيات
- جافا صافية فوق Android framework — **حتى dependency خارجية**
- خطوط [Amiri](https://github.com/aliftype/amiri) و[Cairo](https://github.com/Gue3bara/Cairo) (رخصة OFL، مرفقة ف`assets/fonts/`)
- سماء النجوم مرسومة بـ `Canvas` (نجوم كتلمع، شهب، ريبيل وشرارات عند اللمس)
- الأيقونة مولّدة بـ `tools/make_icons.py` (بضد الدقة العالية)
- minSdk 21 (أندرويد 5.0+) · targetSdk 34
