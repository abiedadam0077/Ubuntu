# شادرات ماينكرافت بدروك للجوال — علاش ماكايناش وشنو تدير

> 🎬 **جديد — باك واقعي كامل (PBR + Vibrant Visuals):** كاين فـ [`realism/`](realism/README.md).
> ملفات جاهزة: `realism/dist/Cinematic-Realism.mcpack` (1.9 MB) و `realism/dist/Cinematic-Realism-Lite.mcpack` (1.6 MB).
> كيبدل: 334 خامة PBR + سماء جوية + موج ماء وانعكاسات + إضاءة سينمائية + ضباب لكل بايوم + غيوم/شمس/قمر واقعيين + أصوات المطر والرعد + جزيئات.

**الجواب فجوج جمل:** ماينكرافت بدروك من 1.16 وهي مبنية على محرك **RenderDragon**، وهاد المحرك مسدود على الشادرات (shaders) لي كيديرو الناس فـ Java. من 1.21.80، Mojang دارت **Vibrant Visuals** = الإضاءة والظلال والانعكاسات الرسمية، ولكن **غير على الأجهزة المدعومة**. إلا كان الهاتف ديالك ماشي فذيك اللائحة، ماكاينش حل رسمي، والحلول غير رسمية كتحتاج برامج وسيطة (MB Loader / Minecraft Patched) وبعضها كيخرق شروط الاستعمال.

فهاد المجلد كاين حل عملي ومسموح: **باك خفيف كنسميه LowEnd Vibes** كيبدل الضباب والجو فالعالم بلا ما يحتاج Vibrant Visuals ولا أي برنامج خارجي.

---

## 1) أولا: واش الهاتف ديالك كيدعم Vibrant Visuals؟

دخل للعبة → **Settings → Video → Graphics Mode**. إلا لقيت الخيار **Vibrant Visuals** مفتوح، فالهاتف كيدعمو. إلا كان مخرّب/رمادي (greyed out)، ماشي مدعوم.

الأجهزة المدعومة رسميا:

| النظام | الشرط |
|---|---|
| Android | GPU من نوع **Adreno 640**, **Mali-G68 / G77 (Valhall)**, **Maleoon**, **PowerVR A-Series**, **Xclipse 530** ولا أحدث. مفعّل أوتوماتيكيا من Adreno 740 / Mali-G615 / G715 / PowerVR C-Series / Xclipse 920 وطلع |
| iOS | **A12 Bionic** ولا أحدث = iPhone XR / XS ولا أحدث، iPhone SE (2020) ولا أحدث |
| ماشي مدعوم | ChromeOS, Fire Tablets (Amazon), Nintendo Switch |

**أمثلة سريعة:** Samsung Galaxy S20+ / A54 / A55 ✅ · Redmi Note 12 Pro وطلع ✅ · Poco F4/F5/X5 Pro ✅ · OnePlus 7 وطلع ✅ · Infinix Hot/Smart/Spark و Tecno ❌ · Snapdragon 680/685 و Helio G85/G99 ❌ (حتى إلا كان الهاتف جديد).

### إلا كان Vibrant Visuals موجود ولكن مخرّب، جرّب هادشي بالترتيب:
1. **فعّلو من القائمة الرئيسية ماشي من داخل العالم**: Settings → Video → دير **Allow In-Game Graphics Mode Switching** = ON، ومن بعد دخل للعالم وبدّل Graphics Mode.
2. **حيّد/عطّل الباكات** (texture packs، Programmer Art، باكات قديمة) — كيعطلو الخيار. شوف تاني **Settings → Global Resources** إلا كنت فـ Realm.
3. **حدّث اللعبة** وسدّها كاملة (ماشي غير تصغير) وعاود حلّها.
4. جرّب **عالم جديد** بلا باكات ولا experiments — بعض العوالم القديمة كتقفل الخيار.
5. فالإعدادات ديال VV نفسها، اختار **Favor Performance** إلا كان الهاتف كيتلخبط.

> ملاحظة: VV ماكتخدمش مع split-screen، وواجهات (UI) الباكات الثقيلة كتنقص الـ FPS.

---

## 2) إلا ماكانش مدعوم: 3 حلول

### الحل أ — باك خفيف بلا Vibrant Visuals (هادا لي صايبت ليك هنا) ✅
صايبت ليك باك **LowEnd Vibes** فـ [dist/LowEnd-Vibes.mcpack](dist/LowEnd-Vibes.mcpack) (103 KB غير!). كيدير:

- **ضباب أفقي ناعم** فكل البايومات (85+ بايوم) — كيعطي عمق للعالم وكيغطي pop-in ديال الشانكات.
- **ما أصفى** تحت الما (fog أضعف = رؤية أحسن تحت الما).
- **ضباب النيثر أقل** (كيولي تقد تشوف فيها) + ضباب الرين/الرعد والحمم (lava) مضبوط.
- **كيخدم على Bedrock 1.21+ و 26.x** (النظام الجديد ديال الأرقام) على **Android / iOS / Windows**.
- **ماكيحتاجش** MB Loader ولا Vibrant Visuals — هو resource pack عادي (biomes_client.json + fogs).

**التنصيب على Android:** حمّل `.mcpack` → دير عليه ضغطة → "Open with Minecraft" → **Settings → Global Resources → My Packs** → فعّلو. (ولا بدّل الامتداد لـ `.zip` وحلّو فـ `Android/data/com.mojang.minecraftpe/files/games/com.mojang/resource_packs/`).

**التنصيب على iOS:** حمّل الملف بـ Safari ولا Files → Share → **Minecraft** → كيدخل بوحدو → Settings → Global Resources → فعّلو. (إلا ما بانش: بدّل الامتداد لـ `.zip` وسمّيه pack.mcpack ولا دخلو بـ iMazing/Files لـ resource_packs).

**التنصيب على Windows:** ديبل كليك على `.mcpack` → كيتنصب وحدو.

#### كيفاش تبدل الألوان براسك
- [lowendvibes/fogs/overworld.json](lowendvibes/fogs/overworld.json) → `fog_color` (اللون)، `fog_start` (فين كيبدا الضباب، 0.78 = من 78% ديال مسافة الرؤية)، `fog_end`.
- نفس الحاجة فـ [fogs/nether.json](lowendvibes/fogs/nether.json) و [fogs/end.json](lowendvibes/fogs/end.json).
- من بعد عاود صبّط الباك:
  ```bash
  cd minecraft && ./build.sh     # كيعاود يصايب dist/LowEnd-Vibes.mcpack
  ```

### الحل ب — "شادرات" بدلية (Newb, RG, Luminous Dreams...) ⚠️
هادو ماكيديروش شادرات حقيقيين بحال Java، ولكن كيبدلو الفوگ/السماء/الما/الانعكاسات داخل RenderDragon، وكيخدمو بلا Vibrant Visuals:

| الباك | علاش | ملاحظة |
|---|---|---|
| [Newb X Legacy / Newb Aero](https://mcpedl.com/newb-aero-shader-renderdragon-shader/) | خفيف بزاف، إضاءة ناعمة، MIT مفتوح المصدر | قال الكاتب بلي VV ما مطلوبش |
| [RG Shader](https://www.curseforge.com/minecraft-bedrock/texture-packs/rg-shader-v2-1-renderdragon-support-2) | فروگ + godrays + أوراق كتحرك، مصمم للأجهزة الضعيفة | كيتحدث بزاف |
| [Luminous Dreams](https://www.curseforge.com/minecraft-bedrock/texture-packs) | Deferred Rendering باك مشهور | ثقيل شوية |
| [WarmLight / BSLB Dreamy](https://mcpecentral.com/top-3-shaders-for-low-end-devices-minecraft-pebedrock) | خفاف (3 MB) | زيادة على السماء والإضاءة |

⚠️ **تنبيه مهم:** باش يخدمو كامل، غالبا خاصك **MB Loader** ولا **Minecraft Patched** (نسخة معدّلة). هادو كيخلفو شروط استعمال Minecraft، وماشي ضد البان، وممكن يأثرو على worlds/الريلمز ديالك. استعملهم **على مسؤوليتك** وفجهاز ثانوي إيلا قدرت.

### الحل ج — Java Edition على الهاتف (شادرات حقيقيين) 
إلا كنت متوفر على هاتف قوي: **Amethyst Launcher** (بديل PojavLauncher، مجاني ومفتوح المصدر) كيخليك تلعب Java على أندرويد، ومن بعد **Iris / Sodium** ولا OptiFine + **Complementary / BSL / Sildur's** = شادرات حقيقيين بحال PC. الثمن: استعمال البطارية والمعالج عالي، وماكيخدمش مزيان على أجهزة ضعيفة.

---

## 3) نصائح FPS على الهاتف (حتى بلا شادرات)
- **Render Distance**: 6–8 شانكات، هذا أكبر واحد كيوفر FPS.
- **Fancy Graphics = OFF** → خدّم السماء والغيوم بحال قديم = فابور FPS.
- **Smooth Lighting / Clouds**: حيّد الغيوم إيلا ما كنتيش محتاجهم.
- **حجّم/سدّ الباكات**: 128x و 256x كيقتلو الهاتف.
- **إطفاء Vibration/UI animations** ماشي مهم ولكن كيخفف.
- خلّي **الباك ديالي (LowEnd Vibes)** بلا باكات أخرى فوقو — هو مضبوط باش يبقى فابور.

---

## 4) شنو كاين فهاد المجلد

```
minecraft/
├── README.md              ← هاد الملف
├── build.sh               ← كيتحقق من JSON وكيصايب .mcpack
├── dist/LowEnd-Vibes.mcpack  ← الباك واجد للتنزيل والتنصيب
└── lowendvibes/           ← المصدر (كتقدر تبدلو)
    ├── manifest.json      ← UUID + الإصدار
    ├── biomes_client.json ← ربط كل بايوم بالضباب ديالو (172 مفتاح: مع و بلا namespace)
    ├── fogs/              ← overworld.json / nether.json / end.json
    ├── texts/             ← en_US.lang + ar_SA.lang
    └── pack_icon.png
```

---

## 5) المصادر
- [Vibrant Visuals — Minecraft Wiki](https://minecraft.wiki/w/Vibrant_Visuals) (الأجهزة المدعومة و l'historique)
- [Vibrant Visuals greyed out — how to fix](https://windowsreport.com/vibrant-visuals-greyed-out-in-minecraft-bedrock/)
- [Bedrock 26.x version numbering](https://www.minecraft.net/en-us/article/minecraft-26-0-bedrock-changelog)
- [Newb X Legacy (open source)](https://minecraft.how/blog/post/newb-x-legacy-bedrock-shaders)

> ملاحظة: Vibrant Visuals هي "شادر رسمي" ديال Mojang — إيلا خدمت عندك، ضعّفها هي وبقا عليها، الباك ديالي كيزيد معاها بلا مشكل (الفوگ ديالي كيتطبق فوق الإضاءة ديالها).
