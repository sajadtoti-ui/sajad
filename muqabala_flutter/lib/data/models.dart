// نماذج البيانات لتطبيق «مقابلة»
// كل نموذج يتحول إلى JSON حتى ينحفظ محلياً الآن، وعلى السيرفر (Supabase) لاحقاً.

typedef Json = Map<String, dynamic>;

List<T> _list<T>(dynamic v, T Function(Json) f) =>
    (v as List? ?? const []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
List<String> _strs(dynamic v) => (v as List? ?? const []).map((e) => e.toString()).toList();
List<int> _ints(dynamic v) => (v as List? ?? const []).map((e) => (e as num).toInt()).toList();
int? _int(dynamic v) => v == null ? null : (v as num).toInt();

/// مستند مرفوع: شهادة دراسية، هوية نقابة، أو شهادة إضافية
class Doc {
  String title;
  String? file; // اسم الملف الأصلي
  String? path; // مكان النسخة المحفوظة على التلفون (بالسيرفر: رابط مقفول)
  String status; // pending | verified | rejected
  String note; // سبب الرفض من الموارد البشرية
  Doc({required this.title, this.file, this.path, this.status = 'pending', this.note = ''});
  bool get isPdf => (file ?? path ?? '').toLowerCase().endsWith('.pdf');
  Json toJson() => {'title': title, 'file': file, 'path': path, 'status': status, 'note': note};
  factory Doc.fromJson(Json j) => Doc(
      title: j['title'] ?? '', file: j['file'], path: j['path'],
      status: j['status'] ?? 'pending', note: j['note'] ?? '');
  Doc copy() => Doc(title: title, file: file, path: path, status: status, note: note);
}

/// تخصص الموظف ونتيجة امتحانه
class Spec {
  String spec;
  String sector;
  int years;
  String status; // new | pending | reviewed
  int? examScore;
  int? aiScore;
  int? finalScore;
  List<int> attempts;
  List<String> weak;
  String hrNote;
  bool other; // تخصص جديد كتبه الموظف بخانة «أخرى»
  Spec({
    required this.spec,
    required this.sector,
    required this.years,
    this.status = 'new',
    this.examScore,
    this.aiScore,
    this.finalScore,
    List<int>? attempts,
    List<String>? weak,
    this.hrNote = '',
    this.other = false,
  })  : attempts = attempts ?? [],
        weak = weak ?? [];
  Json toJson() => {
        'spec': spec, 'sector': sector, 'years': years, 'status': status,
        'examScore': examScore, 'aiScore': aiScore, 'finalScore': finalScore,
        'attempts': attempts, 'weak': weak, 'hrNote': hrNote, 'other': other,
      };
  factory Spec.fromJson(Json j) => Spec(
        spec: j['spec'], sector: j['sector'] ?? '', years: _int(j['years']) ?? 0,
        status: j['status'] ?? 'new', examScore: _int(j['examScore']),
        aiScore: _int(j['aiScore']), finalScore: _int(j['finalScore']),
        attempts: _ints(j['attempts']), weak: _strs(j['weak']),
        hrNote: j['hrNote'] ?? '', other: j['other'] == true,
      );
  Spec copy() => Spec.fromJson(toJson());
}

/// لغة اختيارية ونتيجة اختبارها
class Lang {
  String lang;
  String level;
  String status; // new | pending | reviewed
  int? score;
  Lang({required this.lang, required this.level, this.status = 'new', this.score});
  Json toJson() => {'lang': lang, 'level': level, 'status': status, 'score': score};
  factory Lang.fromJson(Json j) => Lang(
      lang: j['lang'], level: j['level'] ?? '', status: j['status'] ?? 'new', score: _int(j['score']));
  Lang copy() => Lang.fromJson(toJson());
}

class Worker {
  String id;
  String name;
  String phone;
  String gender;
  int age;
  String transport;
  String gov;
  String qadha;
  String area;
  Doc? degree;
  Doc? union;
  List<Doc> certs;
  List<Lang> langs;
  List<Spec> specs;
  String? photo; // base64
  bool hidePhoto;
  String about;
  List<String> keywords;
  String? selfie; // base64، تنحذف بعد التحقق
  bool idVerified;
  int points;
  int? weekDone;
  int? courseDone;
  int lastUpdate;
  int createdAt;

  Worker({
    required this.id,
    required this.name,
    required this.phone,
    required this.gender,
    required this.age,
    required this.transport,
    required this.gov,
    required this.qadha,
    this.area = '',
    this.degree,
    this.union,
    List<Doc>? certs,
    List<Lang>? langs,
    List<Spec>? specs,
    this.photo,
    this.hidePhoto = false,
    this.about = '',
    List<String>? keywords,
    this.selfie,
    this.idVerified = false,
    this.points = 0,
    this.weekDone,
    this.courseDone,
    required this.lastUpdate,
    required this.createdAt,
  })  : certs = certs ?? [],
        langs = langs ?? [],
        specs = specs ?? [],
        keywords = keywords ?? [];

  String get firstName => name.split(' ').first;
  String get shortName {
    final p = name.split(' ');
    return p.length > 1 && p[1].isNotEmpty ? '${p[0]} ${p[1][0]}.' : p[0];
  }

  Json toJson() => {
        'id': id, 'name': name, 'phone': phone, 'gender': gender, 'age': age,
        'transport': transport, 'gov': gov, 'qadha': qadha, 'area': area,
        'degree': degree?.toJson(), 'union': union?.toJson(),
        'certs': certs.map((e) => e.toJson()).toList(),
        'langs': langs.map((e) => e.toJson()).toList(),
        'specs': specs.map((e) => e.toJson()).toList(),
        'photo': photo, 'hidePhoto': hidePhoto, 'about': about, 'keywords': keywords,
        'selfie': selfie, 'idVerified': idVerified, 'points': points,
        'weekDone': weekDone, 'courseDone': courseDone,
        'lastUpdate': lastUpdate, 'createdAt': createdAt,
      };

  factory Worker.fromJson(Json j) => Worker(
        id: j['id'], name: j['name'], phone: j['phone'], gender: j['gender'] ?? '',
        age: _int(j['age']) ?? 0, transport: j['transport'] ?? '', gov: j['gov'] ?? '',
        qadha: j['qadha'] ?? '', area: j['area'] ?? '',
        degree: j['degree'] == null ? null : Doc.fromJson(Map<String, dynamic>.from(j['degree'])),
        union: j['union'] == null ? null : Doc.fromJson(Map<String, dynamic>.from(j['union'])),
        certs: _list(j['certs'], Doc.fromJson),
        langs: _list(j['langs'], Lang.fromJson),
        specs: _list(j['specs'], Spec.fromJson),
        photo: j['photo'], hidePhoto: j['hidePhoto'] == true, about: j['about'] ?? '',
        keywords: _strs(j['keywords']), selfie: j['selfie'], idVerified: j['idVerified'] == true,
        points: _int(j['points']) ?? 0, weekDone: _int(j['weekDone']),
        courseDone: _int(j['courseDone']),
        lastUpdate: _int(j['lastUpdate']) ?? 0, createdAt: _int(j['createdAt']) ?? 0,
      );
}

class Company {
  String id;
  String name;
  String sector;
  String gov;
  String contact;
  String? idFront;
  String? idBack;
  String? selfie;
  bool verified;
  Company({
    required this.id,
    required this.name,
    required this.sector,
    required this.gov,
    required this.contact,
    this.idFront,
    this.idBack,
    this.selfie,
    this.verified = false,
  });
  Json toJson() => {
        'id': id, 'name': name, 'sector': sector, 'gov': gov, 'contact': contact,
        'idFront': idFront, 'idBack': idBack, 'selfie': selfie, 'verified': verified,
      };
  factory Company.fromJson(Json j) => Company(
        id: j['id'], name: j['name'], sector: j['sector'] ?? '', gov: j['gov'] ?? '',
        contact: j['contact'] ?? '', idFront: j['idFront'], idBack: j['idBack'],
        selfie: j['selfie'], verified: j['verified'] == true,
      );
}

class Msg {
  String from; // co | w
  String text;
  int t;
  Msg(this.from, this.text, this.t);
  Json toJson() => {'from': from, 'text': text, 't': t};
  factory Msg.fromJson(Json j) => Msg(j['from'], j['text'], _int(j['t']) ?? 0);
}

/// طلب مقابلة ومراحله: sent → schedule → video → inperson → hired
class Req {
  String id;
  String wid;
  String company;
  String spec;
  String hours;
  String stage; // sent | schedule | video | inperson | hired | rejected | declined
  List<int> slots;
  List<Msg> msgs;
  int? videoAt;
  bool videoDone;
  int? inAt;
  String? place;
  bool inOk;
  int warn;
  Req({
    required this.id,
    required this.wid,
    required this.company,
    required this.spec,
    required this.hours,
    this.stage = 'sent',
    List<int>? slots,
    List<Msg>? msgs,
    this.videoAt,
    this.videoDone = false,
    this.inAt,
    this.place,
    this.inOk = false,
    this.warn = 0,
  })  : slots = slots ?? [],
        msgs = msgs ?? [];
  Json toJson() => {
        'id': id, 'wid': wid, 'company': company, 'spec': spec, 'hours': hours,
        'stage': stage, 'slots': slots, 'msgs': msgs.map((e) => e.toJson()).toList(),
        'videoAt': videoAt, 'videoDone': videoDone, 'inAt': inAt, 'place': place,
        'inOk': inOk, 'warn': warn,
      };
  factory Req.fromJson(Json j) => Req(
        id: j['id'], wid: j['wid'], company: j['company'], spec: j['spec'],
        hours: j['hours'] ?? '', stage: j['stage'] ?? 'sent', slots: _ints(j['slots']),
        msgs: _list(j['msgs'], Msg.fromJson), videoAt: _int(j['videoAt']),
        videoDone: j['videoDone'] == true, inAt: _int(j['inAt']), place: j['place'],
        inOk: j['inOk'] == true, warn: _int(j['warn']) ?? 0,
      );
}

class Comment {
  String wid;
  String text;
  int t;
  Comment(this.wid, this.text, this.t);
  Json toJson() => {'wid': wid, 'text': text, 't': t};
  factory Comment.fromJson(Json j) => Comment(j['wid'], j['text'], _int(j['t']) ?? 0);
}

class Post {
  String id;
  String wid;
  String text;
  int t;
  List<Comment> comments;
  int reports;
  bool hidden;
  Post({
    required this.id,
    required this.wid,
    required this.text,
    required this.t,
    List<Comment>? comments,
    this.reports = 0,
    this.hidden = false,
  }) : comments = comments ?? [];
  Json toJson() => {
        'id': id, 'wid': wid, 'text': text, 't': t,
        'comments': comments.map((e) => e.toJson()).toList(), 'reports': reports, 'hidden': hidden,
      };
  factory Post.fromJson(Json j) => Post(
        id: j['id'], wid: j['wid'], text: j['text'], t: _int(j['t']) ?? 0,
        comments: _list(j['comments'], Comment.fromJson),
        reports: _int(j['reports']) ?? 0, hidden: j['hidden'] == true,
      );
}

class Account {
  String phone;
  String pass; // بصمة كلمة المرور. بالسيرفر الحقيقي: bcrypt
  String role; // worker | company | hr
  String? ref;
  Account({required this.phone, required this.pass, required this.role, this.ref});
  Json toJson() => {'phone': phone, 'pass': pass, 'role': role, 'ref': ref};
  factory Account.fromJson(Json j) =>
      Account(phone: j['phone'], pass: j['pass'], role: j['role'], ref: j['ref']);
}

class LogEntry {
  int t;
  String m;
  LogEntry(this.t, this.m);
  Json toJson() => {'t': t, 'm': m};
  factory LogEntry.fromJson(Json j) => LogEntry(_int(j['t']) ?? 0, j['m'] ?? '');
}

class NewArea {
  String gov;
  String qadha;
  String area;
  NewArea(this.gov, this.qadha, this.area);
  Json toJson() => {'gov': gov, 'qadha': qadha, 'area': area};
  factory NewArea.fromJson(Json j) => NewArea(j['gov'], j['qadha'], j['area'] ?? '');
}

class OtherSpec {
  String name;
  String sector;
  OtherSpec(this.name, this.sector);
  Json toJson() => {'name': name, 'sector': sector};
  factory OtherSpec.fromJson(Json j) => OtherSpec(j['name'], j['sector']);
}

/// شروط بحث الشركة
class SearchQuery {
  String spec;
  String hours;
  String gender; // '' = ما يفرق
  String exp; // '' | 1-3 | 3-5 | 5+
  String kw;
  String trans; // '' | any | سيارة | دراجة
  String lang;
  String gov;
  String qadha;
  String area;
  bool radius;
  double km;
  SearchQuery({
    required this.spec,
    this.hours = '8 ساعات – صباحي',
    this.gender = '',
    this.exp = '',
    this.kw = '',
    this.trans = '',
    this.lang = '',
    this.gov = 'بغداد',
    this.qadha = '',
    this.area = '',
    this.radius = false,
    this.km = 10,
  });
}

/// نتيجة بحث: الموظف وتخصصه والمسافة
class SearchHit {
  final Worker w;
  final Spec s;
  final double d;
  SearchHit(this.w, this.s, this.d);
}
