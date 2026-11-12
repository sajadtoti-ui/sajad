// حالة التطبيق: كل البيانات والقواعد بمكان واحد.
// حالياً تنحفظ على التلفون (shared_preferences). بالمرحلة الجاية تنتقل لسيرفر Supabase
// بنفس الدوال، فالشاشات ما تحتاج تتغير.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'models.dart';

int now() => DateTime.now().millisecondsSinceEpoch;
const int kDay = 86400000;

/// بصمة بسيطة لكلمة المرور للتجربة فقط. السيرفر الحقيقي يستخدم bcrypt.
String hashPass(String s) {
  int h = 0x811c9dc5;
  for (final c in utf8.encode('muqabala:$s')) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

/// سؤال بعد خلط الخيارات
class ShownQ {
  final String q;
  final String? img;
  final String topic;
  final List<(String, bool)> opts;
  ShownQ(this.q, this.img, this.topic, this.opts);
}

/// جلسة امتحان (مهنة أو لغة) أو أسئلة أسبوعية/كورس
class ExamSession {
  final String kind; // spec | lang | week | course
  final int index;
  final List<ShownQ> qs;
  final bool generic;
  int k = 0;
  final List<(String, bool)> answers = [];
  ExamSession(this.kind, this.index, this.qs, {this.generic = false});
  int get correct => answers.where((a) => a.$2).length;
  bool get done => k >= qs.length;
}

class WorkerDraft {
  String name = '', gender = '', age = '', transport = '';
  String gov = 'بغداد', qadha = '', qadhaOther = '', area = '', areaOther = '';
  Doc? degree, union;
  List<Doc> certs = [];
  List<Lang> langs = [];
  List<Spec> specs = [];
  String? photo, selfie;
  bool hidePhoto = false;
  String about = '';
  bool edit = false;
}

class AppState extends ChangeNotifier {
  static const _key = 'muqabala_v6';
  final _rnd = math.Random();

  List<Account> accounts = [];
  List<Worker> workers = [];
  List<Company> companies = [];
  List<Req> requests = [];
  List<Post> posts = [];
  List<LogEntry> logs = [];
  List<LogEntry> alerts = [];
  List<OtherSpec> others = [];
  List<NewArea> newAreas = [];
  Map<String, List<String>> custom = {};
  Map<String, Map<String, List<String>>> customGeo = {};
  String? session;
  bool ignoreCooldown = true; // للتجربة: إعادة الامتحان بدون انتظار 14 يوم
  int _fails = 0;
  int _lockUntil = 0;

  /// المحافظات والأقضية والمناطق (الثابتة + المضافة من الموارد البشرية)
  late Map<String, Map<String, Map<String, List<double>?>>> geo;

  // ───────────── التحميل والحفظ ─────────────
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _seed();
      }
    } else {
      _seed();
    }
    _buildGeo();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_toJson()));
  }

  void changed() {
    _save();
    notifyListeners();
  }

  Map<String, dynamic> _toJson() => {
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'workers': workers.map((e) => e.toJson()).toList(),
        'companies': companies.map((e) => e.toJson()).toList(),
        'requests': requests.map((e) => e.toJson()).toList(),
        'posts': posts.map((e) => e.toJson()).toList(),
        'logs': logs.map((e) => e.toJson()).toList(),
        'alerts': alerts.map((e) => e.toJson()).toList(),
        'others': others.map((e) => e.toJson()).toList(),
        'newAreas': newAreas.map((e) => e.toJson()).toList(),
        'custom': custom,
        'customGeo': customGeo,
        'session': session,
      };

  void _fromJson(Map<String, dynamic> j) {
    List<T> l<T>(String k, T Function(Map<String, dynamic>) f) =>
        (j[k] as List? ?? []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    accounts = l('accounts', Account.fromJson);
    workers = l('workers', Worker.fromJson);
    companies = l('companies', Company.fromJson);
    requests = l('requests', Req.fromJson);
    posts = l('posts', Post.fromJson);
    logs = l('logs', LogEntry.fromJson);
    alerts = l('alerts', LogEntry.fromJson);
    others = l('others', OtherSpec.fromJson);
    newAreas = l('newAreas', NewArea.fromJson);
    custom = (j['custom'] as Map? ?? {})
        .map((k, v) => MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()));
    customGeo = (j['customGeo'] as Map? ?? {}).map((g, qs) => MapEntry(
        g.toString(),
        (qs as Map).map((q, areas) =>
            MapEntry(q.toString(), (areas as List).map((e) => e.toString()).toList()))));
    session = j['session'];
  }

  void _buildGeo() {
    geo = {
      for (final g in kGeo.entries)
        g.key: {
          for (final q in g.value.entries) q.key: {for (final a in q.value.entries) a.key: a.value}
        }
    };
    customGeo.forEach((g, qs) {
      qs.forEach((q, areas) {
        final m = geo.putIfAbsent(g, () => {}).putIfAbsent(q, () => {});
        for (final a in areas) {
          if (a.isNotEmpty) m.putIfAbsent(a, () => null);
        }
      });
    });
  }

  Future<void> resetAll() async {
    _seed();
    _buildGeo();
    changed();
  }

  void log(String m) {
    logs.insert(0, LogEntry(now(), m));
    if (logs.length > 80) logs = logs.sublist(0, 80);
  }

  // ───────────── البيانات التجريبية ─────────────
  void _seed() {
    Doc d(String t, String s) => Doc(title: t, file: '${t.replaceAll(' ', '_')}.jpg', status: s);
    Spec sp(String spec, int years, String status, int exam, int? fin) => Spec(
        spec: spec, sector: sectorOf(spec), years: years, status: status,
        examScore: exam, finalScore: fin, attempts: [now() - 20 * kDay]);
    Worker mk(String id, String name, String phone, String g, int age, String t, String gov,
        String q, String a,
        {Doc? deg, Doc? un, List<Doc>? certs, List<Lang>? langs, required List<Spec> specs,
        String about = '', int points = 0}) {
      final w = Worker(
          id: id, name: name, phone: phone, gender: g, age: age, transport: t, gov: gov,
          qadha: q, area: a, degree: deg, union: un, certs: certs, langs: langs, specs: specs,
          about: about, keywords: extractKW(about), idVerified: true, points: points,
          lastUpdate: now() - 10 * kDay, createdAt: now() - 30 * kDay);
      for (final s in w.specs) {
        s.aiScore = total(s.examScore ?? 0, s.years, docCount(w));
      }
      return w;
    }

    workers = [
      mk('w1', 'علي حسين', '07701111111', 'ذكر', 34, 'سيارة', 'بغداد', 'الرصافة', 'الكرادة',
          deg: d('دبلوم كهرباء', 'verified'), certs: [d('شهادة سلامة HSE', 'verified')],
          specs: [sp('كهربائي تأسيس منازل', 8, 'reviewed', 80, 82), sp('فني مولدات', 5, 'pending', 60, null)],
          about: 'أشتغل تأسيس كهرباء بيوت وتركيب منظومات طاقة شمسية وصيانة مولدات، دقيق بالشغل وملتزم بالمواعيد',
          points: 120),
      mk('w2', 'مصطفى كريم', '07702222222', 'ذكر', 41, 'دراجة', 'بغداد', 'الكرخ', 'المنصور',
          deg: d('دبلوم ميكانيك', 'verified'), certs: [d('دورة مولدات Perkins', 'pending')],
          specs: [sp('فني مولدات', 10, 'reviewed', 80, 88)],
          about: 'خبرة طويلة بمولدات بيركنز وكاتربلر، صيانة دورية وتبديل محركات ولوحات ATS', points: 60),
      mk('w3', 'زهراء عباس', '07703333333', 'أنثى', 27, 'لا يوجد', 'بغداد', 'الأعظمية', 'الأعظمية',
          deg: d('بكالوريوس محاسبة', 'verified'), un: d('هوية نقابة المحاسبين', 'verified'),
          langs: [Lang(lang: 'الإنكليزية', level: 'متوسط', status: 'reviewed', score: 70)],
          specs: [sp('محاسب عام', 4, 'reviewed', 80, 76)],
          about: 'محاسبة أجيد برنامج الأمين والإكسل، تدقيق فواتير ومخازن وإعداد ميزانيات شهرية', points: 35),
      mk('w4', 'حسن جاسم', '07704444444', 'ذكر', 23, 'دراجة', 'بغداد', 'الصدر', 'مدينة الصدر',
          specs: [sp('كهربائي تأسيس منازل', 3, 'pending', 60, null)]),
      mk('w5', 'نور الهدى سالم', '07705555555', 'أنثى', 30, 'سيارة', 'البصرة', 'مركز البصرة', 'مركز المدينة',
          deg: d('بكالوريوس لغة إنكليزية', 'verified'), un: d('هوية نقابة المعلمين', 'pending'),
          langs: [Lang(lang: 'الإنكليزية', level: 'طليق', status: 'reviewed', score: 95)],
          specs: [sp('مدرس لغة إنكليزية', 6, 'reviewed', 100, 85)],
          about: 'مدرّسة لغة إنكليزية للمرحلة المتوسطة والإعدادية، تحضير امتحانات وزارية ومحادثة', points: 15),
      mk('w6', 'أحمد سامي', '07706666666', 'ذكر', 25, 'لا يوجد', 'بغداد', 'الرصافة', 'زيونة',
          certs: [d('دورة Full-Stack', 'verified')],
          langs: [Lang(lang: 'الإنكليزية', level: 'جيد جداً', status: 'pending', score: 80)],
          specs: [sp('مطور ويب', 2, 'pending', 80, null)],
          about: 'مطور مواقع React وNode، أحب أشتغل على متاجر إلكترونية ولوحات تحكم', points: 5),
    ];
    workers[2].hidePhoto = true;
    workers[3].lastUpdate = now() - 120 * kDay;
    final pass = hashPass('123456');
    accounts = [
      for (final w in workers) Account(phone: w.phone, pass: pass, role: 'worker', ref: w.id),
      Account(phone: '07900000000', pass: pass, role: 'company', ref: 'c1'),
      Account(phone: '07000000000', pass: pass, role: 'hr'),
    ];
    companies = [
      Company(id: 'c1', name: 'شركة النور للمقاولات', sector: 'البناء والتشطيب', gov: 'بغداد',
          contact: 'م. أحمد', verified: true),
    ];
    posts = [
      Post(id: 'p1', wid: 'w2', t: now() - 2 * kDay,
          text: 'نصيحة: قبل الصيف بدّلوا فلتر الهواء والزيت للمولدات، أغلب العطلات بالحر تجي من الإهمال.',
          comments: [Comment('w1', 'كلامك صحيح، وهم شيكوا البطارية', now() - kDay)]),
      Post(id: 'p2', wid: 'w3', t: now() - 5 * 3600000,
          text: 'أحد يعرف كورس مجاني للإكسل المتقدم؟ أريد أطور نفسي بالجداول المحورية.'),
    ];
    requests = [];
    alerts = [];
    others = [];
    newAreas = [];
    custom = {};
    customGeo = {};
    session = null;
    logs = [LogEntry(now(), 'تم إنشاء بيانات تجريبية')];
  }

  // ───────────── أدوات عامة ─────────────
  Map<String, List<String>> get allSectors =>
      {for (final e in kSectors.entries) e.key: [...e.value, ...?custom[e.key]]};

  String sectorOf(String spec) {
    for (final e in allSectors.entries) {
      if (e.value.contains(spec)) return e.key;
    }
    return 'أخرى';
  }

  String suggestSector(String name) {
    for (final (w, s) in kSectorHints) {
      if (name.contains(w)) return s;
    }
    return 'الخدمات والحرف والعمالة';
  }

  int docCount(Worker w) => (w.degree != null ? 1 : 0) + w.certs.length;

  int total(int exam, int years, int certs) =>
      (exam * 0.5 + math.min(years, 10) / 10 * 30 + math.min(certs, 2) * 10).round();

  String level(int s) => s >= 75 ? 'خبير' : s >= 50 ? 'متمرّس' : 'مبتدئ';

  bool stale(Worker w) => now() - w.lastUpdate > 90 * kDay;
  bool active(Worker w) => w.points >= 50;
  int get weekId => now() ~/ (7 * kDay);
  int get monthId {
    final d = DateTime.now();
    return d.year * 12 + d.month - 1;
  }

  String place(Worker w) =>
      [w.gov, w.qadha, w.area].where((e) => e.isNotEmpty).join(' ← ');

  String norm(String x) => x
      .replaceFirst(RegExp(r'^ال'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceFirst(RegExp(r'ة$'), 'ه')
      .replaceFirst(RegExp(r'ى$'), 'ي')
      .replaceAll(RegExp(r'\s+'), '');

  /// يحوّل نص «عرّف بنفسك» لكلمات مفتاحية.
  /// بالنسخة الحقيقية يسويها الذكاء الاصطناعي، وبدون اسم أو رقم الموظف.
  List<String> extractKW(String t) {
    if (t.trim().isEmpty) return [];
    final clean = t
        .replaceAll(RegExp(r'https?:\S+|www\.\S+|\S+@\S+', caseSensitive: false), ' ')
        .replaceAll(RegExp('[0-9٠-٩]+'), ' ')
        .replaceAll(RegExp('[ً-ْ]'), '')
        .replaceAll(RegExp('[،؛؟«»]'), ' ')
        .replaceAll(RegExp('[^؀-ۿa-zA-Z\\s]'), ' ');
    final out = <String>[];
    for (final x in clean.split(RegExp(r'\s+'))) {
      var k = x.trim();
      if (k.isEmpty || kStop.contains(k)) continue;
      k = k.replaceFirst(RegExp('^[وبلف]?ال(?=[؀-ۿ]{3,})'), '');
      if (RegExp('^و[؀-ۿ]{3,}\$').hasMatch(k)) k = k.substring(1);
      if (k.length < 3 || kStop.contains(k)) continue;
      if (!out.contains(k)) out.add(k);
    }
    return out.take(10).toList();
  }

  /// يكشف محاولات تبادل الأرقام والحسابات والروابط
  bool hasContact(String t) {
    var x = t;
    const ar = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      x = x.replaceAll(ar[i], '$i');
    }
    x = x.replaceAll(RegExp(r'[\s\-\.]'), '');
    return RegExp(r'\d{6,}').hasMatch(x) ||
        RegExp(r'(\+?964|07\d)').hasMatch(x) ||
        RegExp(r'@|https?:|www|\.com|\.iq', caseSensitive: false).hasMatch(t) ||
        RegExp(
                r'(واتس|وتساب|whats|تلي|تلگرام|تلكرام|telegram|انستا|instagram|فيس|facebook|سناب|snap|تيك|tiktok|ايميل|إيميل|email|رقمي|رقمك|رقم تلفون|رقم موبايل)',
                caseSensitive: false)
            .hasMatch(t);
  }

  List<double>? coord(Worker w) => _point(w.gov, w.qadha, w.area);
  List<double>? _point(String g, String q, String a) => geo[g]?[q]?[a];

  double dist(List<double>? a, List<double>? b) {
    if (a == null || b == null) return 9999;
    const r = 6371.0;
    double rad(double x) => x * math.pi / 180;
    final dLa = rad(b[0] - a[0]), dLo = rad(b[1] - a[1]);
    final h = math.pow(math.sin(dLa / 2), 2) +
        math.cos(rad(a[0])) * math.cos(rad(b[0])) * math.pow(math.sin(dLo / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  // ───────────── الحساب والجلسة ─────────────
  Account? get acct => session == null ? null : accounts.where((a) => a.phone == session).firstOrNull;
  Worker? get me {
    final a = acct;
    if (a == null || a.role != 'worker' || a.ref == null) return null;
    return workers.where((w) => w.id == a.ref).firstOrNull;
  }

  Company? get comp {
    final a = acct;
    if (a == null || a.role != 'company' || a.ref == null) return null;
    return companies.where((c) => c.id == a.ref).firstOrNull;
  }

  Worker workerById(String id) => workers.firstWhere((w) => w.id == id);
  Company? companyByName(String n) => companies.where((c) => c.name == n).firstOrNull;

  String? login(String phone, String pass) {
    if (now() < _lockUntil) {
      return '🛡️ محاولات كثيرة. انتظر ${((_lockUntil - now()) / 1000).ceil()} ثانية';
    }
    final a = accounts.where((x) => x.phone == phone.trim()).firstOrNull;
    if (a == null || a.pass != hashPass(pass)) {
      _fails++;
      if (_fails >= 5) {
        _lockUntil = now() + 60000;
        _fails = 0;
        log('🛡️ قفل مؤقت بعد 5 محاولات دخول فاشلة');
      }
      changed();
      return 'الرقم أو كلمة المرور غير صحيحة';
    }
    _fails = 0;
    session = a.phone;
    changed();
    return null;
  }

  bool phoneTaken(String phone) => accounts.any((a) => a.phone == phone);

  void signup(String phone, String pass, String role) {
    accounts.add(Account(phone: phone, pass: hashPass(pass), role: role));
    session = phone;
    log('🆕 حساب جديد (${role == 'worker' ? 'باحث عن عمل' : 'شركة'})');
    changed();
  }

  void logout() {
    session = null;
    changed();
  }

  // ───────────── الموظف ─────────────
  WorkerDraft draftFrom(Worker w) {
    final d = WorkerDraft()
      ..edit = true
      ..name = w.name
      ..gender = w.gender
      ..age = '${w.age}'
      ..transport = w.transport
      ..gov = w.gov
      ..degree = w.degree?.copy()
      ..union = w.union?.copy()
      ..certs = w.certs.map((e) => e.copy()).toList()
      ..langs = w.langs.map((e) => e.copy()).toList()
      ..specs = w.specs.map((e) => e.copy()).toList()
      ..photo = w.photo
      ..hidePhoto = w.hidePhoto
      ..about = w.about;
    final qs = geo[w.gov]?.keys.toList() ?? [];
    if (qs.contains(w.qadha)) {
      d.qadha = w.qadha;
      final areas = geo[w.gov]![w.qadha]!.keys.toList();
      if (w.area.isEmpty || areas.contains(w.area)) {
        d.area = w.area;
      } else {
        d.area = '__o';
        d.areaOther = w.area;
      }
    } else {
      d.qadha = '__o';
      d.qadhaOther = w.qadha;
      d.area = '__o';
      d.areaOther = w.area;
    }
    return d;
  }

  /// يتحقق إذا القضاء/المنطقة الجديدة مكررة باسم ثاني، وإذا لا يقترحها للموارد البشرية
  (String, String) resolvePlace(String g, String q, String a) {
    final qs = geo[g]?.keys.toList() ?? [];
    final fq = qs.where((x) => norm(x) == norm(q)).firstOrNull;
    if (fq != null) q = fq;
    final areas = geo[g]?[q]?.keys.toList() ?? [];
    final fa = areas.where((x) => norm(x) == norm(a)).firstOrNull;
    if (fa != null) a = fa;
    final newQ = !(geo[g]?.containsKey(q) ?? false);
    final newA = a.isNotEmpty && (newQ || !areas.contains(a));
    if ((newQ || newA) &&
        !newAreas.any((n) => n.gov == g && n.qadha == q && n.area == (newA ? a : ''))) {
      newAreas.add(NewArea(g, q, newA ? a : ''));
      log('🤖 منطقة جديدة مقترحة: ${[g, q, if (newA) a].join(' ← ')}');
    }
    return (q, a);
  }

  /// يتحقق من النموذج، ويرجع رسالة خطأ أو null
  String? validateDraft(WorkerDraft d) {
    if (d.name.trim().split(RegExp(r'\s+')).length < 2) return 'اكتب الاسم الثنائي على الأقل';
    if (RegExp(r'[0-9@#$%]').hasMatch(d.name)) return 'الاسم فيه رموز غير مسموحة';
    if (d.gender.isEmpty) return 'اختر الجنس';
    if (d.transport.isEmpty) return 'حدد إذا عندك وسيلة نقل';
    final ag = int.tryParse(d.age) ?? 0;
    if (ag == 0) return 'اكتب العمر';
    if (ag < 18) return 'العمر لازم يكون 18 سنة أو أكثر';
    if (ag > 70) return 'العمر غير منطقي';
    if (d.qadha == '__o' && d.qadhaOther.trim().length < 2) return 'اكتب اسم القضاء أو الناحية';
    if (d.area == '__o' && d.areaOther.trim().length < 2) return 'اكتب اسم المنطقة';
    if (!d.edit && d.selfie == null) return 'خذ صورة حية (سيلفي) للتحقق من هويتك';
    if (d.specs.isEmpty) return 'أضف تخصص واحد على الأقل';
    final nd = d.specs.where((s) => kDegreeSectors.contains(s.sector)).firstOrNull;
    if (nd != null && (d.degree?.file == null)) {
      return 'ارفع الشهادة الدراسية، إلزامية لتخصص ${nd.spec}';
    }
    return null;
  }

  void saveDraft(WorkerDraft d) {
    var q = d.qadha == '__o' ? d.qadhaOther.trim() : d.qadha;
    var a = d.area == '__o' ? d.areaOther.trim() : d.area;
    (q, a) = resolvePlace(d.gov, q, a);
    for (final s in d.specs.where((s) => s.other)) {
      if (!others.any((o) => o.name == s.spec)) {
        others.add(OtherSpec(s.spec, suggestSector(s.spec)));
        log('🤖 تخصص جديد مقترح: «${s.spec}» → ${suggestSector(s.spec)}');
      }
    }
    final about = d.about.trim();
    final w = me;
    if (d.edit && w != null) {
      w
        ..name = d.name.trim()
        ..gender = d.gender
        ..age = int.parse(d.age)
        ..transport = d.transport
        ..gov = d.gov
        ..qadha = q
        ..area = a
        ..degree = d.degree
        ..union = d.union
        ..certs = d.certs
        ..langs = d.langs
        ..specs = d.specs
        ..photo = d.photo
        ..hidePhoto = d.hidePhoto
        ..about = about
        ..keywords = extractKW(about)
        ..lastUpdate = now();
      log('✏️ ${w.name} حدّث معلوماته');
    } else {
      final nw = Worker(
        id: 'w${now()}', name: d.name.trim(), phone: session!, gender: d.gender,
        age: int.parse(d.age), transport: d.transport, gov: d.gov, qadha: q, area: a,
        degree: d.degree, union: d.union, certs: d.certs, langs: d.langs, specs: d.specs,
        photo: d.photo, hidePhoto: d.hidePhoto, about: about, keywords: extractKW(about),
        selfie: d.selfie, lastUpdate: now(), createdAt: now(),
      );
      workers.add(nw);
      acct!.ref = nw.id;
      log('👷 تسجيل جديد: ${nw.name} (${nw.specs.map((s) => s.spec).join('، ')})');
    }
    final pend = [d.degree, d.union, ...d.certs].where((x) => x != null && x.status == 'pending');
    if (pend.isNotEmpty) log('📎 مستندات جديدة بانتظار المراجعة: ${d.name.trim()}');
    changed();
  }

  (bool, String) canRetake(Spec s) {
    final recent = s.attempts.where((t) => now() - t < 180 * kDay).length;
    if (recent >= 3) return (false, 'وصلت الحد الأقصى: 3 محاولات خلال 6 أشهر');
    if (s.attempts.isNotEmpty) {
      final next = s.attempts.reduce(math.max) + 14 * kDay;
      if (!ignoreCooldown && now() < next) {
        final d = DateTime.fromMillisecondsSinceEpoch(next);
        return (false, 'تكدر تعيد الامتحان من ${d.day}/${d.month}');
      }
    }
    return (true, '');
  }

  // ───────────── الامتحانات ─────────────
  List<ShownQ> _mk(List<Q> bank, int n) {
    final b = [...bank]..shuffle(_rnd);
    return b.take(n).map((q) {
      final opts = [for (var i = 0; i < q.opts.length; i++) (q.opts[i], i == q.correct)]..shuffle(_rnd);
      return ShownQ(q.q, q.img, q.topic, opts);
    }).toList();
  }

  ExamSession startExam(int specIndex) {
    final s = me!.specs[specIndex];
    final bank = kQB[s.spec];
    return ExamSession('spec', specIndex, _mk(bank ?? kGeneric, 5), generic: bank == null);
  }

  ExamSession startLang(int langIndex) =>
      ExamSession('lang', langIndex, _mk(kLangQ[me!.langs[langIndex].lang]!, 5));

  ExamSession startQuiz(String kind) {
    final w = me!;
    if (kind == 'week') {
      final first = w.specs.isNotEmpty ? w.specs.first.spec : '';
      return ExamSession('week', 0, _mk(kQB[first] ?? kGeneric, 5));
    }
    return ExamSession('course', 0, _mk(kCourses[monthId % kCourses.length].qs, 2));
  }

  /// يرجع عدد النقاط للأسئلة الأسبوعية/الكورس، أو 0 للامتحانات
  int finishExam(ExamSession e) {
    final w = me!;
    final pct = (e.correct / e.qs.length * 100).round();
    switch (e.kind) {
      case 'spec':
        final s = w.specs[e.index];
        s.examScore = pct;
        s.aiScore = total(pct, s.years, docCount(w));
        s.status = 'pending';
        s.attempts = [...s.attempts, now()];
        s.weak = {for (final a in e.answers.where((a) => !a.$2)) a.$1}.toList();
        s.hrNote = '';
        log('🤖 امتحان: ${w.name} – ${s.spec} – تقييم أولي ${s.aiScore}');
        changed();
        return 0;
      case 'lang':
        final l = w.langs[e.index];
        l.score = pct;
        l.status = 'pending';
        log('🌐 اختبار لغة: ${w.name} – ${l.lang} – $pct');
        changed();
        return 0;
      default:
        final gain = e.kind == 'week' ? e.correct * 5 + 10 : 20;
        w.points += gain;
        if (e.kind == 'week') {
          w.weekDone = weekId;
        } else {
          w.courseDone = monthId;
        }
        log('⭐ ${w.name} كسب $gain نقطة (${e.kind == 'week' ? 'أسئلة الأسبوع' : 'كورس الشهر'})');
        changed();
        return gain;
    }
  }

  // ───────────── الشركة والبحث ─────────────
  String? saveCompany(
      {required String name, required String sector, required String gov, required String contact,
      String? idFront, String? idBack, String? selfie}) {
    if (name.trim().length < 3) return 'اكتب اسم الشركة';
    if (contact.trim().length < 3) return 'اكتب اسم الشخص المسؤول';
    if (idFront == null || idBack == null) return 'ارفع وجه وظهر البطاقة الوطنية';
    if (selfie == null) return 'خذ صورة حية للشخص المسؤول';
    final c = Company(
        id: 'c${now()}', name: name.trim(), sector: sector, gov: gov, contact: contact.trim(),
        idFront: idFront, idBack: idBack, selfie: selfie);
    companies.add(c);
    acct!.ref = c.id;
    log('🏢 شركة جديدة بانتظار التوثيق: ${c.name}');
    changed();
    return null;
  }

  List<SearchHit> search(SearchQuery j) {
    final List<double>? here = j.area.isEmpty ? null : _point(j.gov, j.qadha, j.area);
    final minY = kExp.firstWhere((e) => e.$1 == j.exp, orElse: () => kExp.first).$3;
    final kws = j.kw.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    final out = <SearchHit>[];
    for (final w in workers) {
      final s = w.specs.where((x) => x.spec == j.spec && x.status != 'new').firstOrNull;
      if (s == null) continue;
      if (j.gender.isNotEmpty && w.gender != j.gender) continue;
      if (s.years < minY) continue;
      if (j.lang.isNotEmpty && !w.langs.any((l) => l.lang == j.lang)) continue;
      if (j.trans == 'any' && !(w.transport == 'دراجة' || w.transport == 'سيارة')) continue;
      if ((j.trans == 'سيارة' || j.trans == 'دراجة') && w.transport != j.trans) continue;
      if (kws.isNotEmpty) {
        final hay = '${w.keywords.join(' ')} ${w.about} ${w.certs.map((c) => c.title).join(' ')}';
        if (!kws.any(hay.contains)) continue;
      }
      final d = here != null ? dist(here, coord(w)) : 9999.0;
      final ok = j.qadha.isEmpty
          ? w.gov == j.gov
          : j.area.isEmpty
              ? (w.gov == j.gov && w.qadha == j.qadha)
              : j.radius
                  ? d <= j.km
                  : (w.gov == j.gov && w.qadha == j.qadha && w.area == j.area);
      if (ok) out.add(SearchHit(w, s, d));
    }
    // الترتيب: الدرجة المعتمدة أولاً، وبعدها النشاط والتوثيق والتحديث والقرب
    int key(SearchHit r) =>
        (r.s.status == 'reviewed' ? (r.s.finalScore ?? 0) : 0) +
        math.min<int>(r.w.points ~/ 50, 5) +
        (r.w.union?.status == 'verified' ? 3 : 0) -
        (stale(r.w) ? 5 : 0);
    out.sort((a, b) {
      final c = key(b).compareTo(key(a));
      if (c != 0) return c;
      final y = b.s.years.compareTo(a.s.years);
      return y != 0 ? y : a.d.compareTo(b.d);
    });
    return out;
  }

  // ───────────── المقابلات ─────────────
  Req? findReq(String wid, String company, String spec) => requests
      .where((x) => x.wid == wid && x.company == company && x.spec == spec)
      .firstOrNull;

  Req sendReq(Worker w, SearchQuery j) {
    final r = Req(id: 'r${now()}', wid: w.id, company: comp!.name, spec: j.spec, hours: j.hours);
    requests.add(r);
    log('📩 ${r.company} طلبت مقابلة مع ${w.name}');
    changed();
    return r;
  }

  void answerReq(Req r, bool ok) {
    r.stage = ok ? 'schedule' : 'declined';
    log('${ok ? '✅' : '❌'} ${me?.name ?? ''} ${ok ? 'قبل' : 'اعتذر عن'} مقابلة ${r.company}');
    changed();
  }

  void proposeSlots(Req r, List<int> t) {
    r.slots = t;
    log('📅 ${r.company} اقترحت مواعيد مقابلة فيديو');
    changed();
  }

  void pickSlot(Req r, int i) {
    r.videoAt = r.slots[i];
    r.stage = 'video';
    log('🎥 تحديد مقابلة فيديو');
    changed();
  }

  void endCall(Req r) {
    r.videoDone = true;
    log('🎥 انتهت مقابلة فيديو: ${r.company}');
    changed();
  }

  void videoResult(Req r, bool ok) {
    r.stage = ok ? 'inperson' : 'rejected';
    log(ok ? '👍 المرشح نجح بالفيديو ← مقابلة حضورية' : '👎 المرشح غير مناسب بعد الفيديو');
    changed();
  }

  String? setInPerson(Req r, int? at, String place) {
    if (at == null || place.trim().length < 5) return 'حدد الموعد والمكان';
    if (hasContact(place)) return '🚫 ممنوع وضع أرقام أو روابط بالعنوان';
    r.inAt = at;
    r.place = place.trim();
    log('🤝 تحديد مقابلة حضورية');
    changed();
    return null;
  }

  void confirmIn(Req r) {
    r.inOk = true;
    changed();
  }

  void finalResult(Req r, bool ok) {
    r.stage = ok ? 'hired' : 'rejected';
    log(ok ? '🎉 توظيف عبر التطبيق: ${r.company} – ${r.spec}' : 'المرشح غير مناسب بعد الحضورية');
    changed();
  }

  /// يرجع رسالة خطأ إذا انحجبت الرسالة
  String? sendMsg(Req r, String text, bool isCo) {
    final t = text.trim();
    if (t.isEmpty) return null;
    if (hasContact(t)) {
      r.warn++;
      log('🚫 محاولة مشاركة معلومات تواصل (${isCo ? r.company : 'المرشح'}) – تحذير ${r.warn}');
      if (r.warn >= 3) alerts.add(LogEntry(now(), 'تكرار محاولة تبادل معلومات تواصل: ${r.company} / ${r.spec}'));
      changed();
      return '🚫 الرسالة انحجبت: ممنوع تبادل الأرقام أو الحسابات خارج التطبيق';
    }
    r.msgs.add(Msg(isCo ? 'co' : 'w', t, now()));
    changed();
    return null;
  }

  // ───────────── المجتمع ─────────────
  String? addPost(String text) {
    final t = text.trim();
    if (t.length < 5) return 'اكتب شي أطول شوية';
    if (hasContact(t)) {
      log('🚫 منشور انحجب لأنه فيه معلومات تواصل');
      changed();
      return '🚫 ممنوع نشر أرقام أو روابط أو حسابات';
    }
    final w = me!;
    posts.add(Post(id: 'p${now()}', wid: w.id, text: t, t: now()));
    w.points += 2;
    log('💬 ${w.name} نشر بالمجتمع');
    changed();
    return null;
  }

  String? addComment(Post p, String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    if (hasContact(t)) return '🚫 ممنوع نشر أرقام أو روابط أو حسابات';
    p.comments.add(Comment(me!.id, t, now()));
    changed();
    return null;
  }

  void reportPost(Post p) {
    p.reports++;
    if (p.reports >= 2) {
      p.hidden = true;
      log('🚩 منشور انخفى بعد بلاغين وينتظر المراجعة');
    } else {
      log('🚩 بلاغ على منشور');
    }
    changed();
  }

  // ───────────── الموارد البشرية ─────────────
  void approve(Worker w, int i, int score, String note) {
    final s = w.specs[i];
    s.finalScore = score.clamp(0, 100);
    s.status = 'reviewed';
    s.hrNote = note.trim();
    log('🧑‍💼 اعتماد ${w.name} – ${s.spec}: ${s.finalScore}${s.finalScore != s.aiScore ? ' (عُدّل من ${s.aiScore})' : ''}');
    changed();
  }

  void approveLang(Worker w, int i, int score) {
    final l = w.langs[i];
    l.score = score.clamp(0, 100);
    l.status = 'reviewed';
    log('🌐 اعتماد لغة ${l.lang} – ${w.name}: ${l.score}');
    changed();
  }

  void verifyDoc(Worker w, Doc d, bool ok) {
    d.status = ok ? 'verified' : 'rejected';
    log('${ok ? '✅ توثيق ' : '❌ رفض '}${d.title} – ${w.name}');
    changed();
  }

  void verifyId(Worker w, bool ok) {
    w.selfie = null; // الصورة الحية تنحذف بعد التحقق
    w.idVerified = ok;
    log('${ok ? '🤳 تحقق من هوية ' : '❌ رفض صورة حية: '}${w.name} · وانحذفت الصورة الحية');
    changed();
  }

  void verifyCo(Company c, bool ok) {
    c.selfie = null;
    c.idFront = null;
    c.idBack = null;
    c.verified = ok;
    log('${ok ? '✅ توثيق شركة: ' : '❌ رفض توثيق شركة: '}${c.name} · وانحذفت صور المستمسكات');
    changed();
  }

  void approveArea(int k) {
    final n = newAreas.removeAt(k);
    final q = customGeo.putIfAbsent(n.gov, () => {}).putIfAbsent(n.qadha, () => []);
    if (n.area.isNotEmpty && !q.contains(n.area)) q.add(n.area);
    _buildGeo();
    log('✅ إضافة منطقة: ${[n.gov, n.qadha, if (n.area.isNotEmpty) n.area].join(' ← ')}');
    changed();
  }

  void rejectArea(int k) {
    newAreas.removeAt(k);
    log('❌ رفض منطقة مقترحة');
    changed();
  }

  void approveOther(int k, String sector) {
    final o = others.removeAt(k);
    custom.putIfAbsent(sector, () => []).add(o.name);
    for (final w in workers) {
      for (final s in w.specs) {
        if (s.spec == o.name) {
          s.sector = sector;
          s.other = false;
        }
      }
    }
    log('✅ إضافة تخصص «${o.name}» إلى $sector');
    changed();
  }

  void rejectOther(int k) {
    log('❌ رفض تخصص مقترح «${others[k].name}»');
    others.removeAt(k);
    changed();
  }

  void modPost(Post p, bool keep) {
    if (keep) {
      p.hidden = false;
      p.reports = 0;
      log('↩️ إرجاع منشور بعد المراجعة');
    } else {
      posts.remove(p);
      log('🗑️ حذف منشور مخالف');
    }
    changed();
  }
}

/// نسخة وحدة من الحالة لكل التطبيق
final app = AppState();
