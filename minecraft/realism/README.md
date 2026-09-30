# 🎬 Cinematic Realism — باك واقعي لـ Minecraft Bedrock (PBR + Vibrant Visuals)

باك موارد **احترافي وواقعي** صايبتو من الصفر فوق Vibrant Visuals: خامات PBR، إضاءة سينمائية،
سماء جوية حقيقية، ماء بموج وانعكاسات، ضباب لكل بايوم، ظلال ناعمة، غيوم/شمس/قمر واقعيين،
وأصوات وجزيئات محسّنة. مصمم باش يخدم على **هاتف متوسط** بحال vivo Y04 (بلا ما يقتل الـ FPS).

**الملفات الجاهزة:**
| النسخة | الحجم | لمن |
|---|---|---|
| `dist/Cinematic-Realism.mcpack` | 1.9 MB | جهاز متوسط/قوي (334 خامة PBR بـ normal maps + tone mapping ACES) |
| `dist/Cinematic-Realism-Lite.mcpack` | 1.6 MB | جهاز ضعيف (بلا normal maps، موج أرخص، tone mapping generic) |

---

## ⚡ التنصيب (vivo Y04 — Android)

1. نزّل `Cinematic-Realism.mcpack` من المجلد `dist/`.
2. دير عليه ضغطة → **Open with Minecraft** (ولا استعمل تطبيق Files واختار Minecraft).
3. حل ماينكرافت → **Settings → Global Resources → My Packs** → فعّل الباك.
4. **Settings → Video → Graphics Mode → Vibrant Visuals** (ضروري! الباك مصمم فوق VV).
5. دخل للعالم وسير لوقت الغروب 🌅 — تما كيبان الفرق الحقيقي.

> على iOS: نزّل الملف بـ Safari → Share → **Minecraft** → Settings → Global Resources.
> عالويندوز: ديبل-كليك على الملف وكيتنصب وحدو.

### الضبط الموصى به لـ vivo Y04 (T7225 + Mali-G52 → VV كتخدم بحدها)
| الإعداد | القيمة | علاش |
|---|---|---|
| Graphics Mode | **Vibrant Visuals → Favor Performance** | كيبقى الشكل الواقعي مع FPS مزيان |
| Render Distance | **6–8 شانكات** | أكبر واحد كيوفر FPS |
| Preset | جرّب **Cinematic-Realism-Lite** أولا | إلا لقيت التقطيع |
| Clouds | Normal | الباك كيبدل الغيوم أوتوماتيكيا |
| Vibration / UI animations | Off | فابور FPS |

---

## 📦 شنو كاين فالباك (كله مولّد برمجيا بـ Python)

| الجزء | التفاصيل |
|---|---|
| **خامات PBR** | **334 خامة** بـ `texture_set.json` + **MERS** (معدنية/إشعاع/خشونة/تشتت تحت سطحي) + **Normal maps** مولّدة من الضوء/الظل ديال كل خامة (Sobel) |
| **الأجواء (atmospherics)** | 17 نسخة: سماء زِنيت/هورايزن بلون كيتبدل على مدار اليوم، Rayleigh + Mie scattering، وهج الشمس عند الشروق/الغروب |
| **الإضاءة (lighting)** | 17 نسخة: شمس بدرجة لون دافية (100k lux نهار، 8 lux غروب)، قمر أزرق، ambient ملوّن، قوة ضو السماء (ظلال أعمق) |
| **تصحيح الألوان** | 17 نسخة: تباين + حرارة + **highlights/shadows** (ضوء دافي / ظلال باردة) + **tone mapping ACES** (سينمائي بحال الأفلام) |
| **الماء** | 5 أنواع: بحيرة صافية، محيط، نهر، مستنقع، ماء دافي — كل واحد بـ cdom/chlorophyll/sediment + **موج** (octaves, pull, shape) + **caustics** (ضو كيرقص تحت الما) |
| **الضباب** | **80 ملف ضباب** (بلوك الهواء) حسب نوع كل منطقة: غابة، صحراء، مستنقع، ثلج، كهوف، نيثر، إند... |
| **البايومات** | **89 ملف client_biome** كيربطو كل حاجة مع كل بايوم (VV كيتنقل بيناتهم بسلاسة) |
| **الظلال** | `soft_shadows` (ظلال ناعمة واقعية بدل الحجرية) |
| **السماء** | غيوم cumulus مبنية بـ FBM noise (حواف ريشية حجم حقيقي)، شمس بهالة دافية، **قمر بـ 8 فازات** مع كراتر، مطر/ثلج واقعيين |
| **الأصوات** | **11 صوت OGG** مولّدين بـ numpy: 4 مطر (هسيس + قطرات)، 3 رعد (طرقة + هدير + تموجات)، لوب تحت الما ستيريو، 3 ماء جاري |
| **الجزيئات** | قطرات/رشاش المطر والبحر، فقاعات زجاجية، لهب ناعم — ومعهوم MERS (الماء لا مع وعاكس، اللهب كيشعل) |

---

## 🔧 كيفاش تبدل الحوايج (كلشي مولّد من سكربتات)

```bash
cd minecraft/realism
./make.sh              # البناء الكامل (خامات + VV + أصوات + تغليف)
./make.sh --lite       # النسخة الخفيفة
./make.sh --no-pbr     # بلا إعادة توليد الخامات (سريع بزاف)
```

### تبديل الألوان والجو
- **سماء النهار/الغروب/الليل**: `tools/gen_vv.py` → `ATMO_VARIANTS` → `zenith` و `horizon`
  (المفاتيح من 0 = الظهر، 0.25 = الغروب، 0.5 = منتصف الليل، 0.75 = الشروق).
- **ضوء الشمس والقمر**: `SUN_ILLUM` / `SUN_COLOR` / `MOON_ILLUM`.
- **ستايل الصورة (تباين/حرارة/ACES)**: `GRADE_VARIANTS` (كل نوع بايوم عندو نسختو).
- **الماء**: `WATER_VARIANTS` → `cdom` (يصفر)، `chlorophyll` (يخضر)، `suspended_sediment` (يعكّر)،
  `waves.depth/speed/octaves`، `caustics.power`.
- **الضباب**: `FOG_STYLE` (بداية الضباب + اللون لكل نوع منطقة).
- **الخامات**: `TEXTURES` + `MATERIALS` فـ `tools/gen_pbr.py`
  (مثلا `metal=232, rough=62` = حديد لامع).

من بعد أي تبديل: `./make.sh` وكيعاود يطلع ليك `.mcpack` جديد.

---

## 📐 ملاحظات تقنية (مبنية على الوثائق الرسمية)

- الـ PBR ماكيخدمش إلا بـ `"capabilities": ["pbr"]` و `min_engine_version >= [1,21,120]` فالمانيفست.
- من 1.21.90، إعدادات VV العامة (`lighting/global.json`) ماكتغلطش إعدادات الفانيلا لكل بايوم —
  **لهذا ربطنا كل حاجة من داخل ملفات `biomes/*.client_biome.json`** (هادشي لي كيخدم فعلا).
- الضباب كيتبدل بالمعرّف الرسمي (`minecraft:fog_plains`...) من داخل الباك، فكل بايوم كياخد ضبابنا.
- **خامات VV الرسمية موجودة فالفانيلا** (1.21+)، وحنا كنعاودو نصايبو MERS أحسن (لمعان معدني +
  خشونة أقل + subsurface للوراق والثلج) مع normal maps، وكنديرو bind لخاماتنا فوقها.
- السكربتات كتقرا الخامات الأصلية من `Mojang/bedrock-samples` (عبر `MINECRAFT_VANILLA=/path`).

### شنو مستحيل
شادرات بحال Java (BSL / Complementary / SEUS) ماكايناش فبدروك — المحرك (RenderDragon) مسدود.
هاد الباك كيوصل لأقصى درجة مسموح بيها رسميا: PBR + كل إعدادات VV + سماء/ماء/أصوات/جزيئات.

---

## 📁 بنية المجلد

```
realism/
├── make.sh                 ← البناء الكامل بجملة وحدة
├── dist/                   ← .mcpack الجاهزين
├── pack/                   ← الباك نفسه (المصدر)
│   ├── manifest.json       ← capabilities: pbr
│   ├── pack_icon.png
│   ├── atmospherics/  (17)     lighting/ (17)      color_grading/ (17)
│   ├── water/ (5)              fogs/ (80)          biomes/ (89)
│   ├── shadows/                pbr/global.json
│   ├── textures/blocks/  ← 334 خامة × 3 ملفات (لون + MERS + normal)
│   ├── textures/environment/  ← غيوم، شمس، sun_vv، قمر، مطر
│   ├── textures/particle/     ← قطرات، فقاعات، لهب + MERS
│   └── sounds/               ← 11 OGG + sound_definitions.json
├── tools/                  ← سكربتات التوليد
│   ├── common.py           gen_pbr.py     gen_env.py    gen_vv.py
│   ├── gen_sounds.py       gen_particles.py
│   ├── gen_manifest.py     build.py (تحقق + تغليف)
└── data/                   ← نسخة من بيانات الفانيلا (بايومات + ضباب) للأساس
```

## ✅ التحقق
`tools/build.py` كيدير فحص كامل قبل التغليف: كل JSON، المانيفست، كل مرجع (`atmosphere/lighting/grading/water/fog`)،
كل `texture_set` (واش اللون و MERS و normal موجودين)، وكل صوت مذكور فـ `sound_definitions`.
النتيجة الحالية: **0 أخطاء** (334 خامة، 89 بايوم، 80 ضباب، 17+17+17، 5 ماء، 11 صوت).

---
صنع بـ ❤️ فوق [`Mojang/bedrock-samples`](https://github.com/Mojang/bedrock-samples) و
وثائق Microsoft الرسمية لـ [Vibrant Visuals](https://learn.microsoft.com/en-us/minecraft/creator/documents/vibrantvisuals/vvresourcepacks).

---

## ⬇️ التحميل المباشر

### 1) سيرفر محلي (فوري، من الهاتف على نفس الشبكة)
```bash
cd minecraft/realism && python3 serve.py --port 8000
```
من بعد حل `http://<IP ديال الحاسوب>:8000` فالاستعمار — كتلقى أزرار تحميل لكل الباكات.
إلا كنت فـ Arena: حل الـ **Live Preview** وكتحمّل من تما مباشرة.

### 2) روابط GitHub (دايمة، على أي جهاز)
الملفات موجودة فالـ tag `cinematic-realism-v1.0`:

| الملف | رابط التحميل المباشر |
|---|---|
| Cinematic-Realism | `https://raw.githubusercontent.com/abiedadam0077/Ubuntu/cinematic-realism-v1.0/minecraft/realism/dist/Cinematic-Realism.mcpack` |
| Cinematic-Realism-Lite | `https://raw.githubusercontent.com/abiedadam0077/Ubuntu/cinematic-realism-v1.0/minecraft/realism/dist/Cinematic-Realism-Lite.mcpack` |
| LowEnd-Vibes | `https://raw.githubusercontent.com/abiedadam0077/Ubuntu/cinematic-realism-v1.0/minecraft/dist/LowEnd-Vibes.mcpack` |

ولا من واجهة GitHub: `https://github.com/abiedadam0077/Ubuntu/tree/cinematic-realism-v1.0/minecraft/realism/dist` → اختار الملف → زر **Download raw file**.
