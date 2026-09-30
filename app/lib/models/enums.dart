/// تعدادات أساسية يستخدمها كل المشروع (النماذج، المحرك، الواجهة)
/// هذا الملف هو "مصدر الحقيقة" لأنواع الفئات والسلوكيات، بحيث يمكن
/// إضافة نوع جديد بسهولة دون كسر بقية النظام.
library electrosim_enums;

/// فئات مكتبة المكونات — منظمة بنفس التصنيف المطلوب لمكتبة احترافية
/// (بحث + تصنيفات واضحة بدل Grid عشوائي)
enum ComponentCategory {
  power, // مصادر الطاقة
  lighting, // إنارة
  switchesButtons, // مفاتيح وأزرار
  protection, // حماية (قواطع، فيوز، RCD)
  motors, // محركات
  industrial, // تحكم صناعي (محولات، بادئات تشغيل)
  sensors, // حساسات ومفاتيح نهاية شوط
  measurement, // أجهزة قياس
  sockets, // مقابس وعلب توصيل ولوحات
  relaysContactors, // كونتاكتورات وريليهات وتايمر وعداد
  plc, // وحدات تحكم مبرمجة
  electronics, // إلكترونيات أساسية
  other, // أخرى
}

extension ComponentCategoryX on ComponentCategory {
  String get nameAr {
    switch (this) {
      case ComponentCategory.power:
        return 'مصادر الطاقة';
      case ComponentCategory.lighting:
        return 'الإضاءة';
      case ComponentCategory.switchesButtons:
        return 'المفاتيح والأزرار';
      case ComponentCategory.protection:
        return 'الحماية';
      case ComponentCategory.motors:
        return 'المحركات';
      case ComponentCategory.industrial:
        return 'التحكم الصناعي';
      case ComponentCategory.sensors:
        return 'الحساسات';
      case ComponentCategory.measurement:
        return 'القياس';
      case ComponentCategory.sockets:
        return 'المقابس والتوصيل';
      case ComponentCategory.relaysContactors:
        return 'كونتاكتورات وريليهات';
      case ComponentCategory.plc:
        return 'PLC';
      case ComponentCategory.electronics:
        return 'الإلكترونيات';
      case ComponentCategory.other:
        return 'أخرى';
    }
  }

  String get emoji {
    switch (this) {
      case ComponentCategory.power:
        return '⚡';
      case ComponentCategory.lighting:
        return '💡';
      case ComponentCategory.switchesButtons:
        return '🔘';
      case ComponentCategory.protection:
        return '🛡️';
      case ComponentCategory.motors:
        return '⚙️';
      case ComponentCategory.industrial:
        return '🔧';
      case ComponentCategory.sensors:
        return '📡';
      case ComponentCategory.measurement:
        return '📏';
      case ComponentCategory.sockets:
        return '🔌';
      case ComponentCategory.relaysContactors:
        return '🔄';
      case ComponentCategory.plc:
        return '🧠';
      case ComponentCategory.electronics:
        return '🔩';
      case ComponentCategory.other:
        return '🗂️';
    }
  }
}

/// نوع الطرف الكهربائي (يُستخدم لتلوين الأسلاك تلقائياً ومنع توصيلات خاطئة)
enum TerminalKind { phase, neutral, ground, dcPlus, dcMinus, control, generic }

extension TerminalKindX on TerminalKind {
  String get label {
    switch (this) {
      case TerminalKind.phase:
        return 'Phase (L)';
      case TerminalKind.neutral:
        return 'Neutral (N)';
      case TerminalKind.ground:
        return 'Ground (PE)';
      case TerminalKind.dcPlus:
        return 'DC +';
      case TerminalKind.dcMinus:
        return 'DC -';
      case TerminalKind.control:
        return 'Control';
      case TerminalKind.generic:
        return 'Terminal';
    }
  }
}

/// السلوك الكهربائي/الميكانيكي الذي يفهمه محرك المحاكاة لكل مكون
enum BehaviorKind {
  sourceAcSinglePhase,
  sourceAcThreePhase,
  sourceDc,
  wireJunction,
  switchToggle, // مفتاح أحادي/مزدوج/تبادلي/درج
  pushButtonNO,
  pushButtonNC,
  lampLoad,
  buzzerLoad,
  resistiveLoad,
  motorLoad,
  breaker, // MCB / Disjoncteur
  motorBreaker, // Disjoncteur moteur
  fuse,
  rcd, // قاطع تفاضلي
  contactorCoil,
  contactorContactNO,
  contactorContactNC,
  relayCoil,
  relayContactNO,
  relayContactNC,
  thermalRelay,
  timerOnDelay,
  counter,
  thermostat,
  limitSwitch,
  emergencyStop,
  selectorSwitch,
  pilotLamp,
  sensorDigital,
  plcPlaceholder,
  diode,
  led,
  capacitor,
  transistor,
  potentiometer,
  meterProbe,
  distributionBoard,
  junctionBox,
  socketOutlet,
  starDeltaStarter,
  dolStarter,
  generic,
}

/// وضع عرض المكون: واقعي أو رمز كهربائي قياسي (IEC)
enum RenderMode { realistic, symbol }

/// حالة المحاكاة العامة
enum SimulationStatus { idle, running, paused, stopped, fault }

/// أنواع الأعطال التي يمكن أن يكتشفها النظام أو يولّدها وضع Fault Simulation
enum FaultType {
  shortCircuit,
  overload,
  reversedPolarity,
  groundFault,
  openCircuit,
  motorWiringError,
  contactStuckNO,
  contactStuckNC,
  fuseBlown,
  phaseMissing,
  wrongConnection,
}
