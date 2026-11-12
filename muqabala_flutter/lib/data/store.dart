// حالة التطبيق: كل البيانات والقواعد بمكان واحد.
// حالياً تنحفظ على التلفون (shared_preferences). بالمرحلة الجاية تنتقل لسيرفر Supabase
// بنفس الدوال، فالشاشات ما تحتاج تتغير.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'models.dart';

int now() => DateTime.now().millisecondsSinceEpoch;

String _dt(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day}/${d.month} ${d.hour}:$mm';
}
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
  final List<int> secs = []; // الوقت اللي أخذه كل سؤال
  int timeouts = 0;
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

  /// المسودة تنحفظ على التلفون حتى ما تضيع إذا طلع من التطبيق أو صار خطأ
  Json toJson() => {
        'name': name, 'gender': gender, 'age': age, 'transport': transport, 'gov': gov,
        'qadha': qadha, 'qadhaOther': qadhaOther, 'area': area, 'areaOther': areaOther,
        'degree': degree?.toJson(), 'union': union?.toJson(),
        'certs': certs.map((e) => e.toJson()).toList(),
        'langs': langs.map((e) => e.toJson()).toList(),
        'specs': specs.map((e) => e.toJson()).toList(),
        'photo': photo, 'selfie': selfie, 'hidePhoto': hidePhoto, 'about': about,
      };

  static WorkerDraft fromJson(Json j) {
    List<T> l<T>(String k, T Function(Json) f) =>
        (j[k] as List? ?? []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    Doc? doc(String k) => j[k] == null ? null : Doc.fromJson(Map<String, dynamic>.from(j[k] as Map));
    return WorkerDraft()
      ..name = j['name'] ?? ''
      ..gender = j['gender'] ?? ''
      ..age = j['age'] ?? ''
      ..transport = j['transport'] ?? ''
      ..gov = j['gov'] ?? 'بغداد'
      ..qadha = j['qadha'] ?? ''
      ..qadhaOther = j['qadhaOther'] ?? ''
      ..area = j['area'] ?? ''
      ..areaOther = j['areaOther'] ?? ''
      ..degree = doc('degree')
      ..union = doc('union')
      ..certs = l('certs', Doc.fromJson)
      ..langs = l('langs', Lang.fromJson)
      ..specs = l('specs', Spec.fromJson)
      ..photo = j['photo']
      ..selfie = j['selfie']
      ..hidePhoto = j['hidePhoto'] == true
      ..about = j['about'] ?? '';
  }
}

/// أقسام لوحة الموارد البشرية وصلاحية كل دور
const Map<String, String> kHrRoles = {
  'admin': 'مدير (كل الصلاحيات)',
  'reviewer': 'مراجع (امتحانات ومستندات وتوثيق)',
  'support': 'دعم (رسائل وبلاغات ومحادثات)',
};
const Map<String, List<String>> kHrAccess = {
  'reviewer': ['exams', 'langs', 'companies', 'selfies', 'docs', 'areas', 'specs', 'profiles', 'bank', 'stats'],
  'support': ['support', 'reports', 'chats', 'alerts', 'profiles', 'stats'],
};

class AppState extends ChangeNotifier {
  static const _key = 'muqabala_v7';
  static const _draftKey = 'muqabala_reg_draft';
  final _rnd = math.Random();

  List<Account> accounts = [];
  List<Worker> workers = [];
  List<Company> companies = [];
  List<Req> requests = [];
  List<Post> posts = [];
  List<LogEntry> logs = [];
  List<LogEntry> alerts = [];
  List<LogEntry> access = []; // سجل وصول الموارد البشرية للمحادثات والملفات
  List<Notif> notifs = [];
  List<Ticket> tickets = [];
  String? pending2fa; // حساب موارد بشرية ينتظر رمز التحقق بخطوتين
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
    expireOld();
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
        'access': access.map((e) => e.toJson()).toList(),
        'notifs': notifs.map((e) => e.toJson()).toList(),
        'tickets': tickets.map((e) => e.toJson()).toList(),
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
    access = l('access', LogEntry.fromJson);
    notifs = l('notifs', Notif.fromJson);
    tickets = l('tickets', Ticket.fromJson);
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
    if (logs.length > 200) logs = logs.sublist(0, 200);
  }

  /// إشعار لصاحب الرقم
  void notify(String? phone, String text, {String? reqId}) {
    if (phone == null) return;
    notifs.insert(0, Notif(to: phone, text: text, t: now(), reqId: reqId));
    if (notifs.length > 300) notifs = notifs.sublist(0, 300);
  }

  List<Notif> get myNotifs => notifs.where((n) => n.to == session).toList();
  int get unread => notifs.where((n) => n.to == session && !n.read).length;
  void readAll() {
    for (final n in notifs.where((n) => n.to == session)) {
      n.read = true;
    }
    changed();
  }

  String? phoneOfCompany(String name) {
    final c = companyByName(name);
    if (c == null) return null;
    return accounts.where((a) => a.role == 'company' && a.ref == c.id).firstOrNull?.phone;
  }

  String? phoneOfWorker(String wid) => workers.where((w) => w.id == wid).firstOrNull?.phone;

  // ───────────── البيانات التجريبية ─────────────
  void _seed() {
    var ago = 40; // كل عنصر يدخل بوقت مختلف حتى يبين الترتيب من الأقدم للأحدث
    Doc d(String t, String s) =>
        Doc(title: t, file: '${t.replaceAll(' ', '_')}.jpg', status: s, at: now() - (ago--) * 3600000);
    Spec sp(String spec, int years, String status, int exam, int? fin) => Spec(
        spec: spec, sector: sectorOf(spec), years: years, status: status,
        examScore: exam, finalScore: fin, attempts: [now() - 20 * kDay],
        since: now() - (ago--) * 3600000, avgSec: 12,
        reviewedAt: status == 'reviewed' ? now() - 15 * kDay : null);
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
        if (s.status == 'pending') {
          s.aiNote = (s.examScore ?? 0) >= 70
              ? 'أداء جيد بأغلب المحاور، يُنصح بالاعتماد.'
              : 'ضعف بأكثر من محور، يُنصح بسؤال عملي بالمقابلة.';
          s.weak = (s.examScore ?? 0) >= 70 ? [] : ['السلامة'];
          s.strong = ['الأساسيات'];
        }
      }
      for (final l in w.langs) {
        l.since = now() - (ago--) * 3600000;
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
      Account(phone: '07000000000', pass: pass, role: 'hr', hrRole: 'admin', hrName: 'سجاد (مدير)'),
      Account(phone: '07000000001', pass: pass, role: 'hr', hrRole: 'reviewer', hrName: 'مراجع 1'),
      Account(phone: '07000000002', pass: pass, role: 'hr', hrRole: 'support', hrName: 'دعم 1'),
    ];
    companies = [
      Company(id: 'c1', name: 'شركة النور للمقاولات', sector: 'البناء والتشطيب', gov: 'بغداد',
          contact: 'م. أحمد', verified: true, createdAt: now() - 40 * kDay, assistant: 'ghina'),
    ];
    // ثلاث طلبات تجريبية: محادثة جارية، وتوظيف قبل 31 يوم (للتقييم بعد 30 يوم)، وطلب مهمل ينتهي تلقائياً
    final w2 = workers[1], w3 = workers[2], w6 = workers[5];
    w2.ratings = [Rating(company: 'شركة النور للمقاولات', kind: 'interview', stars: 5, note: 'فاهم شغله', t: now() - 33 * kDay)];
    requests = [
      Req(id: 'r1', wid: w2.id, company: 'شركة النور للمقاولات', spec: 'فني مولدات', hours: '8 ساعات – صباحي',
          stage: 'hired', createdAt: now() - 40 * kDay, stageAt: now() - 31 * kDay, hiredAt: now() - 31 * kDay,
          rated: true, videoDone: true, inOk: true,
          msgs: [Msg('co', 'هلا، شوكت يناسبك تبدي؟', now() - 32 * kDay), Msg('w', 'من الأحد إن شاء الله', now() - 32 * kDay)]),
      Req(id: 'r2', wid: w3.id, company: 'شركة النور للمقاولات', spec: 'محاسب عام', hours: '8 ساعات – صباحي',
          stage: 'schedule', createdAt: now() - 2 * kDay, stageAt: now() - kDay,
          msgs: [Msg('co', 'أهلاً زهراء، عندچ خبرة ببرنامج الأمين؟', now() - kDay), Msg('w', 'نعم، 3 سنوات', now() - 20 * 3600000)]),
      Req(id: 'r3', wid: w6.id, company: 'شركة النور للمقاولات', spec: 'مطور ويب', hours: 'دوام جزئي',
          stage: 'sent', createdAt: now() - 8 * kDay, stageAt: now() - 8 * kDay),
    ];
    tickets = [
      Ticket(id: 't1', phone: w6.phone, who: w6.name, t: now() - 26 * 3600000,
          text: 'رفعت شهادة الدورة من يومين وبعدها قيد المراجعة، شوكت تخلص؟'),
    ];
    notifs = [];
    access = [];
    posts = [
      Post(id: 'p1', wid: 'w2', t: now() - 2 * kDay,
          text: 'نصيحة: قبل الصيف بدّلوا فلتر الهواء والزيت للمولدات، أغلب العطلات بالحر تجي من الإهمال.',
          comments: [Comment('w1', 'كلامك صحيح، وهم شيكوا البطارية', now() - kDay)]),
      Post(id: 'p2', wid: 'w3', t: now() - 5 * 3600000,
          text: 'أحد يعرف كورس مجاني للإكسل المتقدم؟ أريد أطور نفسي بالجداول المحورية.'),
    ];
    alerts = [];
    others = [];
    newAreas = [];
    custom = {};
    customGeo = {};
    session = null;
    pending2fa = null;
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
    if (a.role == 'hr') {
      // الموارد البشرية: تحقق بخطوتين (رمز على واتساب الموظف)
      pending2fa = a.phone;
      changed();
      return null;
    }
    session = a.phone;
    _onLogin();
    changed();
    return null;
  }

  /// الخطوة الثانية لدخول الموارد البشرية. للتجربة الرمز 4321
  String? verify2fa(String code) {
    if (pending2fa == null) return 'ارجع سجّل دخول من جديد';
    if (code.trim() != '4321') {
      _fails++;
      if (_fails >= 5) {
        pending2fa = null;
        _fails = 0;
        _lockUntil = now() + 60000;
        log('🛡️ 5 رموز غلط بالتحقق بخطوتين، انقفل الدخول دقيقة');
        changed();
        return '🛡️ رموز غلط كثيرة. انتظر دقيقة وسجّل دخول من جديد';
      }
      return 'الرمز غلط. تأكد من آخر رسالة وصلتك على واتساب';
    }
    _fails = 0;
    session = pending2fa;
    pending2fa = null;
    log('🔐 دخول موارد بشرية: ${acct?.hrName ?? ''} (تحقق بخطوتين)');
    changed();
    return null;
  }

  void cancel2fa() {
    pending2fa = null;
    changed();
  }

  /// تذكيرات تلقائية وقت الدخول: تحديث الملف وأسئلة الأسبوع
  void _onLogin() {
    final w = me;
    if (w == null) return;
    bool sentToday(String key) => notifs.any((n) => n.to == w.phone && n.text.contains(key) && now() - n.t < kDay);
    if (stale(w) && !sentToday('حدّث')) notify(w.phone, '⏰ صار أكثر من 3 أشهر ما حدّثت ملفك. حدّثه حتى تبقى بأعلى البحث');
    if (w.weekDone != weekId && !sentToday('أسئلة الأسبوع')) {
      notify(w.phone, '📝 أسئلة الأسبوع نزلت! جاوب واكسب نقاط ترفع ترتيبك');
    }
  }

  bool phoneTaken(String phone) => accounts.any((a) => a.phone == phone);

  void signup(String phone, String pass, String role) {
    accounts.add(Account(phone: phone, pass: hashPass(pass), role: role));
    session = phone;
    log('🆕 حساب جديد (${role == 'worker' ? 'باحث عن عمل' : 'شركة'}) · وافق على الشروط وسياسة الخصوصية');
    notify(phone, '👋 أهلاً بيك بمقابلة! كمّل ملفك حتى توصلك أفضل الفرص');
    changed();
  }

  void logout() {
    session = null;
    pending2fa = null;
    changed();
  }

  /// حذف الحساب وكل بياناته من التطبيق (شرط Google Play)
  void deleteAccount() {
    final a = acct;
    if (a == null) return;
    if (a.role == 'worker' && a.ref != null) {
      final w = workers.where((x) => x.id == a.ref).firstOrNull;
      if (w != null) {
        for (final d in [w.degree, w.union, ...w.certs].whereType<Doc>()) {
          _deleteFile(d.path);
        }
        workers.remove(w);
        requests.removeWhere((r) => r.wid == w.id);
        posts.removeWhere((p) => p.wid == w.id);
        for (final p in posts) {
          p.comments.removeWhere((c) => c.wid == w.id);
        }
      }
    } else if (a.role == 'company' && a.ref != null) {
      final c = companies.where((x) => x.id == a.ref).firstOrNull;
      if (c != null) {
        _deleteFile(c.idFront);
        _deleteFile(c.idBack);
        companies.remove(c);
        requests.removeWhere((r) => r.company == c.name);
      }
    }
    notifs.removeWhere((n) => n.to == a.phone);
    tickets.removeWhere((t) => t.phone == a.phone);
    accounts.remove(a);
    session = null;
    log('🗑️ مستخدم حذف حسابه وكل بياناته');
    changed();
  }

  void _deleteFile(String? p) {
    if (p == null) return;
    try {
      File(p).deleteSync();
    } catch (_) {}
  }

  // ───────────── مسودة التسجيل ─────────────
  Future<void> saveRegDraft(WorkerDraft d) async {
    if (d.edit) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('$_draftKey:$session', jsonEncode(d.toJson()));
  }

  Future<WorkerDraft?> loadRegDraft() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('$_draftKey:$session');
    if (raw == null) return null;
    try {
      return WorkerDraft.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearRegDraft() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('$_draftKey:$session');
  }

  // ───────────── اكتمال الملف ─────────────
  /// نسبة اكتمال ملف الموظف، وأهم خطوة جاية ترفعها
  (int, String?) completeness(Worker w) {
    final items = <(bool, int, String)>[
      (w.idVerified || w.selfie != null, 15, 'خذ صورة حية للتحقق'),
      (w.specs.any((s) => s.status != 'new'), 20, 'سوّي امتحان تخصصك'),
      (w.degree != null, 15, 'ارفع شهادتك الدراسية'),
      (w.about.trim().length >= 30, 10, 'اكتب سطرين عن نفسك بـ«عرّف بنفسك»'),
      (w.photo != null, 10, 'ارفع صورة شخصية'),
      (w.certs.isNotEmpty, 10, 'ارفع شهادة دورة أو كورس'),
      (w.union != null, 10, 'ارفع هوية النقابة'),
      (w.langs.isNotEmpty, 10, 'أضف لغة وامتحنها'),
    ];
    var pct = 0;
    (bool, int, String)? next;
    for (final it in items) {
      if (it.$1) {
        pct += it.$2;
      } else if (next == null || it.$2 > next.$2) {
        next = it;
      }
    }
    return (pct, next == null ? null : '${next.$3} (+${next.$2}%)');
  }

  // ───────────── المساعد غنى ويمان ─────────────
  /// للموظف: غنى للذكور ويمان للإناث. للشركة: اللي تختاره ('' = لسه ما اختارت)
  String get assistant {
    final a = acct;
    if (a == null) return 'ghina';
    if (a.role == 'company') return comp?.assistant ?? '';
    return me?.gender == 'أنثى' ? 'yaman' : 'ghina';
  }

  void setAssistant(String who) {
    final c = comp;
    if (c == null) return;
    c.assistant = who;
    changed();
  }

  // ───────────── الدعم «كلّم شخص» ─────────────
  String get myName {
    final a = acct;
    if (a == null) return '';
    if (a.role == 'company') return comp?.name ?? 'شركة جديدة';
    if (a.role == 'hr') return a.hrName;
    return me?.name ?? 'مستخدم جديد';
  }

  String? sendTicket(String text) {
    final t = text.trim();
    if (t.length < 5) return 'اكتب مشكلتك بجملة وحدة على الأقل';
    tickets.add(Ticket(id: 't${now()}', phone: session!, who: myName, text: t, t: now()));
    log('🆘 رسالة دعم جديدة من $myName');
    changed();
    return null;
  }

  List<Ticket> get myTickets => tickets.where((t) => t.phone == session).toList()..sort((a, b) => b.t.compareTo(a.t));

  void replyTicket(Ticket t, String reply) {
    t.reply = reply.trim();
    t.replyT = now();
    t.replyBy = acct?.hrName ?? '';
    notify(t.phone, '💬 فريق مقابلة رد على رسالتك: ${t.reply}');
    log('💬 رد على رسالة دعم: ${t.who}');
    changed();
  }

  // ───────────── صلاحيات الموارد البشرية ─────────────
  bool can(String section) {
    final a = acct;
    if (a == null || a.role != 'hr') return false;
    if (a.hrRole == 'admin') return true;
    return kHrAccess[a.hrRole]?.contains(section) ?? false;
  }

  void _access(String what) {
    access.insert(0, LogEntry(now(), '${acct?.hrName ?? 'موارد بشرية'} · $what'));
    if (access.length > 300) access = access.sublist(0, 300);
  }

  /// فتح محادثة من الموارد البشرية: ينسجل بالسجل ويوصل إشعار للطرفين
  void hrOpenChat(Req r) {
    final w = workers.where((x) => x.id == r.wid).firstOrNull;
    _access('فتح محادثة ${r.company} ↔ ${w?.name ?? '—'}');
    const msg = '🛡️ إدارة مقابلة راجعت محادثتك لحمايتك (حسب شروط الاستخدام)';
    notify(w?.phone, msg, reqId: r.id);
    notify(phoneOfCompany(r.company), msg, reqId: r.id);
    changed();
  }

  void hrOpenProfile(String who) {
    _access('فتح ملف $who');
    changed();
  }

  /// تعديل درجة حتى بعد الاعتماد
  void hrEditScore(Worker w, int i, int score, String note) {
    final s = w.specs[i];
    final old = s.finalScore;
    s.finalScore = score.clamp(0, 100);
    s.status = 'reviewed';
    s.reviewedAt = now();
    if (note.trim().isNotEmpty) s.hrNote = note.trim();
    _access('تعديل درجة ${w.name} – ${s.spec}: ${old ?? '—'} ← ${s.finalScore}');
    log('✏️ إعادة تقييم ${w.name} – ${s.spec}: ${old ?? '—'} ← ${s.finalScore}');
    notify(w.phone, '📊 الموارد البشرية حدّثت تقييمك بـ${s.spec}: ${s.finalScore}/100');
    changed();
  }

  String? addHr(String phone, String name, String role) {
    if (!RegExp(r'^07\d{9}$').hasMatch(phone.trim())) return 'اكتب رقم عراقي صحيح يبدأ بـ 07 ومن 11 رقم';
    if (name.trim().length < 2) return 'اكتب اسم الموظف';
    if (phoneTaken(phone.trim())) return 'هذا الرقم عنده حساب';
    accounts.add(Account(phone: phone.trim(), pass: hashPass('123456'), role: 'hr', hrRole: role, hrName: name.trim()));
    log('👤 إضافة موظف موارد بشرية: ${name.trim()} (${kHrRoles[role]})');
    changed();
    return null;
  }

  void setHrRole(Account a, String role) {
    a.hrRole = role;
    log('👤 تغيير صلاحية ${a.hrName} إلى ${kHrRoles[role]}');
    changed();
  }

  // ───────────── انتهاء الطلبات تلقائياً ─────────────
  static const int kExpireDays = 7;

  /// كم يوم باقي قبل ما ينتهي الطلب (null إذا ما ينتهي)
  int? daysLeft(Req r) {
    final waiting = r.stage == 'sent' || (r.stage == 'schedule' && r.slots.isNotEmpty && r.videoAt == null);
    if (!waiting) return null;
    return kExpireDays - ((now() - r.stageAt) ~/ kDay);
  }

  void expireOld() {
    var any = false;
    for (final r in requests) {
      final left = daysLeft(r);
      if (left != null && left <= 0) {
        r.stage = 'expired';
        r.stageAt = now();
        any = true;
        const t = '⌛ طلب المقابلة انتهى تلقائياً لأن ما صار رد خلال 7 أيام';
        notify(phoneOfWorker(r.wid), '$t (${r.company})', reqId: r.id);
        notify(phoneOfCompany(r.company), '$t (${r.spec})', reqId: r.id);
        log('⌛ انتهاء طلب مهمل: ${r.company} – ${r.spec}');
      }
    }
    if (any) _save();
  }

  void _stage(Req r, String stage) {
    r.stage = stage;
    r.stageAt = now();
  }

  // ───────────── تقييم الموظفين ─────────────
  bool can30(Req r) => r.stage == 'hired' && !r.rated30 && r.hiredAt != null &&
      (ignoreCooldown || now() - r.hiredAt! >= 30 * kDay);

  void rateWorker(Req r, String kind, int stars, String note) {
    final w = workerById(r.wid);
    w.ratings.add(Rating(company: r.company, kind: kind, stars: stars.clamp(1, 5), note: note.trim(), t: now()));
    if (kind == 'd30') {
      r.rated30 = true;
    } else {
      r.rated = true;
    }
    log('⭐ ${r.company} قيّمت ${w.name}: $stars/5 (${kind == 'd30' ? 'بعد 30 يوم' : 'بعد المقابلة'})');
    changed();
  }

  /// المرشح يبلّغ إن الشركة ما حضرت المقابلة اللي هي حددتها
  void reportNoShow(Req r) {
    if (r.noShow) return;
    r.noShow = true;
    final c = companyByName(r.company);
    if (c != null) c.noShows++;
    alerts.add(LogEntry(now(), 'شركة ما حضرت مقابلة حددتها: ${r.company} / ${r.spec}'));
    log('🚫 ${r.company} ما حضرت مقابلة، نزل تقييم التزامها');
    notify(phoneOfCompany(r.company), '⚠️ المرشح بلّغ إنكم ما حضرتوا المقابلة. تكرارها ينزّل تقييم شركتكم');
    changed();
  }

  /// التزام الشركة من 5: ينقص نص نجمة لكل مقابلة ما حضرتها
  double coScore(String name) {
    final c = companyByName(name);
    return math.max(1.0, 5.0 - (c?.noShows ?? 0) * 0.5);
  }

  // ───────────── مراجعة بنك الأسئلة ─────────────
  /// فحص آلي لبنوك الأسئلة: جواب صح واحد، خيارات مو مكررة، وما بيه أسئلة مكررة.
  /// بالنسخة الحقيقية الذكاء الاصطناعي يراجع صحة المحتوى نفسه وبعدها الموارد البشرية تعتمد.
  List<(String, int, List<String>)> reviewBanks() {
    final out = <(String, int, List<String>)>[];
    for (final e in kQB.entries) {
      final issues = <String>[];
      final seen = <String>{};
      for (final q in e.value) {
        if (!seen.add(q.q)) issues.add('سؤال مكرر: ${q.q}');
        if (q.correct < 0 || q.correct >= q.opts.length) issues.add('رقم الجواب الصح غلط: ${q.q}');
        if (q.opts.toSet().length != q.opts.length) issues.add('خيارات مكررة: ${q.q}');
        if (q.opts.length < 4) issues.add('أقل من 4 خيارات: ${q.q}');
        if (q.topic.isEmpty) issues.add('بدون محور: ${q.q}');
      }
      if (e.value.length < 8) issues.add('البنك بيه ${e.value.length} أسئلة بس، الأفضل 8 أو أكثر');
      out.add((e.key, e.value.length, issues));
    }
    return out;
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
      newAreas.add(NewArea(g, q, newA ? a : '', now()));
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
        others.add(OtherSpec(s.spec, suggestSector(s.spec), now()));
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
    if (!d.edit) clearRegDraft();
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
    return ExamSession('spec', specIndex, _mk(bank ?? kGeneric, 8), generic: bank == null);
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
        final prev = s.examScore;
        s.examScore = pct;
        s.aiScore = total(pct, s.years, docCount(w));
        s.status = 'pending';
        s.since = now();
        s.attempts = [...s.attempts, now()];
        final rep = evaluate(e, prev: s.attempts.length > 1 ? prev : null);
        s.weak = rep.$1;
        s.strong = rep.$2;
        s.avgSec = rep.$3;
        s.aiNote = rep.$4;
        s.hrNote = '';
        log('🤖 امتحان: ${w.name} – ${s.spec} – تقييم أولي ${s.aiScore}');
        changed();
        return 0;
      case 'lang':
        final l = w.langs[e.index];
        l.score = pct;
        l.status = 'pending';
        l.since = now();
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

  /// التقييم الآلي للامتحان: نقاط الضعف والقوة حسب المحور، ومعدل الوقت، وملاحظات للموارد البشرية.
  /// بالنسخة الحقيقية الذكاء الاصطناعي (Gemini) يكتب التحليل، والموارد البشرية تعتمد.
  (List<String>, List<String>, int, String) evaluate(ExamSession e, {int? prev}) {
    final byTopic = <String, (int, int)>{};
    for (final (topic, ok) in e.answers) {
      final t = topic.isEmpty ? 'عام' : topic;
      final c = byTopic[t] ?? (0, 0);
      byTopic[t] = (c.$1 + (ok ? 1 : 0), c.$2 + 1);
    }
    final weak = [for (final x in byTopic.entries) if (x.value.$1 < x.value.$2) x.key];
    final strong = [for (final x in byTopic.entries) if (x.value.$1 == x.value.$2) x.key];
    final avg = e.secs.isEmpty ? 0 : (e.secs.reduce((a, b) => a + b) / e.secs.length).round();
    final pct = (e.correct / e.qs.length * 100).round();
    final notes = <String>[
      if (pct >= 85) 'أداء ممتاز، يُنصح بالاعتماد.'
      else if (pct >= 60) 'أداء مقبول، يُنصح بالاعتماد ويه ملاحظة تطوير.'
      else 'أداء ضعيف، يُنصح بسؤال عملي بالمقابلة أو إعادة الامتحان.',
      if (weak.isNotEmpty) 'يحتاج تطوير بـ: ${weak.join('، ')}.',
      if (avg > 0 && avg <= 4 && pct >= 80) '⚠️ سرعة إجابة عالية جداً ($avg ث للسؤال)، يستحق التأكد بالمقابلة.',
      if (e.timeouts > 0) 'انتهى الوقت على ${e.timeouts} سؤال.',
      if (prev != null) pct > prev ? 'تحسّن عن المحاولة السابقة ($prev% ← $pct%).' : 'ما تحسّن عن المحاولة السابقة ($prev%).',
    ];
    return (weak, strong, avg, notes.join(' '));
  }

  // ───────────── الشركة والبحث ─────────────
  String? saveCompany(
      {required String name, required String sector, required String gov, required String contact,
      String? idFront, String? idBack, String? selfie}) {
    if (name.trim().length < 3) return 'اكتب اسم الشركة';
    if (contact.trim().length < 3) return 'اكتب اسم الشخص المسؤول';
    if (idFront == null || idBack == null) return 'ارفع وجه وظهر البطاقة الوطنية';
    if (selfie == null) return 'خذ صورة حية للشخص المسؤول';
    if (companies.any((x) => x.name == name.trim())) return 'اسم الشركة مسجّل من قبل، أضف اسم الفرع أو المنطقة';
    final c = Company(
        id: 'c${now()}', name: name.trim(), sector: sector, gov: gov, contact: contact.trim(),
        idFront: idFront, idBack: idBack, selfie: selfie, createdAt: now());
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
        (r.w.union?.status == 'verified' ? 3 : 0) +
        ((r.w.stars ?? 3) - 3).round() * 2 -
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
    final r = Req(id: 'r${now()}', wid: w.id, company: comp!.name, spec: j.spec, hours: j.hours,
        createdAt: now(), stageAt: now());
    requests.add(r);
    log('📩 ${r.company} طلبت مقابلة مع ${w.name}');
    notify(w.phone, '📩 ${r.company} تطلب مقابلة وياك لتخصص ${r.spec}. رد خلال 7 أيام', reqId: r.id);
    changed();
    return r;
  }

  void answerReq(Req r, bool ok) {
    _stage(r, ok ? 'schedule' : 'declined');
    notify(phoneOfCompany(r.company), ok ? '✅ ${me?.shortName ?? 'المرشح'} قبل طلب المقابلة. اقترح مواعيد الفيديو' : '❌ المرشح اعتذر عن مقابلة ${r.spec}', reqId: r.id);
    log('${ok ? '✅' : '❌'} ${me?.name ?? ''} ${ok ? 'قبل' : 'اعتذر عن'} مقابلة ${r.company}');
    changed();
  }

  void proposeSlots(Req r, List<int> t) {
    r.slots = t;
    r.stageAt = now();
    notify(phoneOfWorker(r.wid), '📅 ${r.company} اقترحت مواعيد لمقابلة الفيديو، اختار اللي يناسبك', reqId: r.id);
    log('📅 ${r.company} اقترحت مواعيد مقابلة فيديو');
    changed();
  }

  void pickSlot(Req r, int i) {
    r.videoAt = r.slots[i];
    _stage(r, 'video');
    notify(phoneOfCompany(r.company), '🎥 المرشح ثبّت موعد الفيديو: ${_dt(r.videoAt!)}', reqId: r.id);
    log('🎥 تحديد مقابلة فيديو');
    changed();
  }

  void endCall(Req r) {
    r.videoDone = true;
    log('🎥 انتهت مقابلة فيديو: ${r.company}');
    changed();
  }

  void videoResult(Req r, bool ok) {
    _stage(r, ok ? 'inperson' : 'rejected');
    notify(phoneOfWorker(r.wid), ok ? '👍 نجحت بمقابلة الفيديو! الشركة راح تحدد مقابلة حضورية' : 'شكراً على وقتك. ${r.company} اختارت مرشح ثاني هالمرة', reqId: r.id);
    log(ok ? '👍 المرشح نجح بالفيديو ← مقابلة حضورية' : '👎 المرشح غير مناسب بعد الفيديو');
    changed();
  }

  String? setInPerson(Req r, int? at, String place) {
    if (at == null || place.trim().length < 5) return 'حدد الموعد والمكان';
    if (hasContact(place)) return '🚫 ممنوع وضع أرقام أو روابط بالعنوان';
    r.inAt = at;
    r.place = place.trim();
    notify(phoneOfWorker(r.wid), '🤝 ${r.company} حددت مقابلة حضورية: ${_dt(at)}. أكّد حضورك', reqId: r.id);
    log('🤝 تحديد مقابلة حضورية');
    changed();
    return null;
  }

  void confirmIn(Req r) {
    r.inOk = true;
    notify(phoneOfCompany(r.company), '✓ المرشح أكّد حضور المقابلة الحضورية', reqId: r.id);
    changed();
  }

  void finalResult(Req r, bool ok) {
    _stage(r, ok ? 'hired' : 'rejected');
    if (ok) r.hiredAt = now();
    notify(phoneOfWorker(r.wid), ok ? '🎉 مبروك! ${r.company} قررت توظيفك' : 'شكراً على وقتك. ${r.company} اختارت مرشح ثاني هالمرة', reqId: r.id);
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
    notify(isCo ? phoneOfWorker(r.wid) : phoneOfCompany(r.company), '💬 رسالة جديدة من ${isCo ? r.company : 'المرشح'}', reqId: r.id);
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
      p.reportedAt = now();
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
    s.reviewedAt = now();
    notify(w.phone, '✅ انعتمد تقييمك بـ${s.spec}: ${s.finalScore}/100 (${level(s.finalScore!)})');
    log('🧑‍💼 اعتماد ${w.name} – ${s.spec}: ${s.finalScore}${s.finalScore != s.aiScore ? ' (عُدّل من ${s.aiScore})' : ''}');
    changed();
  }

  void approveLang(Worker w, int i, int score) {
    final l = w.langs[i];
    l.score = score.clamp(0, 100);
    l.status = 'reviewed';
    notify(w.phone, '🌐 انعتمد اختبار ${l.lang}: ${l.score}/100');
    log('🌐 اعتماد لغة ${l.lang} – ${w.name}: ${l.score}');
    changed();
  }

  void verifyDoc(Worker w, Doc d, bool ok, [String note = '']) {
    d.status = ok ? 'verified' : 'rejected';
    d.note = ok ? '' : note.trim();
    notify(w.phone, ok ? '✅ انوثّق مستندك: ${d.title}' : '❌ انرفض مستندك «${d.title}»${d.note.isNotEmpty ? ': ${d.note}' : ''}. ارفعه من جديد');
    log('${ok ? '✅ توثيق ' : '❌ رفض '}${d.title} – ${w.name}${d.note.isNotEmpty ? ' (السبب: ${d.note})' : ''}');
    changed();
  }

  void verifyId(Worker w, bool ok) {
    w.selfie = null; // الصورة الحية تنحذف بعد التحقق
    w.idVerified = ok;
    notify(w.phone, ok ? '🤳 تم التحقق من هويتك' : '❌ الصورة الحية ما انقبلت، خذ صورة جديدة بمكان مضوي');
    log('${ok ? '🤳 تحقق من هوية ' : '❌ رفض صورة حية: '}${w.name} · وانحذفت الصورة الحية');
    changed();
  }

  void verifyCo(Company c, bool ok) {
    c.selfie = null;
    // صور البطاقة تنحذف من التلفون بعد التوثيق
    for (final p in [c.idFront, c.idBack]) {
      if (p != null) {
        try {
          File(p).deleteSync();
        } catch (_) {}
      }
    }
    c.idFront = null;
    c.idBack = null;
    c.verified = ok;
    notify(phoneOfCompany(c.name), ok ? '✅ انوثّقت شركتكم، وصارت تطلع «شركة موثّقة» للمرشحين' : '❌ ما انقبل توثيق الشركة. تواصلوا ويانا من «كلّم شخص»');
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
