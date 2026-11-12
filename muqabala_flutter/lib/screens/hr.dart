// لوحة الموارد البشرية: صفحة رئيسية بعدد الطلبات المنتظرة بكل قسم،
// وكل قسم بصفحة خاصة، والطلبات مرتبة من الأقدم للأحدث حتى ينراجع اللي انتظر أكثر أول.
import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

/// قسم من أقسام اللوحة
class HrSec {
  final String key;
  final String icon;
  final String title;
  final String hint;
  const HrSec(this.key, this.icon, this.title, this.hint);
}

const List<HrSec> kHrSecs = [
  HrSec('exams', '📝', 'الامتحانات', 'اعتماد درجات الذكاء الاصطناعي'),
  HrSec('langs', '🌐', 'اختبارات اللغة', 'اعتماد درجات اللغة'),
  HrSec('docs', '📎', 'المستندات', 'شهادات وهويات نقابة'),
  HrSec('selfies', '🤳', 'الصور الحية', 'التحقق من هوية الموظفين'),
  HrSec('companies', '🏢', 'توثيق الشركات', 'البطاقة والصورة الحية'),
  HrSec('support', '🆘', 'الدعم', 'رسائل «كلّم شخص»'),
  HrSec('reports', '🚩', 'البلاغات', 'منشورات مخفية'),
  HrSec('areas', '📍', 'مناطق جديدة', 'اقتراحات الذكاء الاصطناعي'),
  HrSec('specs', '🛠️', 'تخصصات جديدة', 'اقتراحات الذكاء الاصطناعي'),
  HrSec('chats', '💬', 'المحادثات', 'كل محادثات المقابلات'),
  HrSec('profiles', '🗂️', 'الملفات', 'كل الموظفين والشركات'),
  HrSec('bank', '🧪', 'بنك الأسئلة', 'فحص الأسئلة آلياً'),
  HrSec('alerts', '🚨', 'تنبيهات أمنية', 'محاولات تبادل أرقام وعدم حضور'),
  HrSec('stats', '📊', 'الإحصائيات والسجل', 'الأرقام وسجل العمليات والوصول'),
  HrSec('team', '👥', 'فريق الموارد البشرية', 'الحسابات والصلاحيات'),
];

// ───────────── القوائم المرتبة من الأقدم للأحدث ─────────────
List<(Worker, int)> hrExams() => [
      for (final w in app.workers)
        for (var i = 0; i < w.specs.length; i++)
          if (w.specs[i].status == 'pending') (w, i),
    ]..sort((a, b) => a.$1.specs[a.$2].since.compareTo(b.$1.specs[b.$2].since));

List<(Worker, int)> hrLangs() => [
      for (final w in app.workers)
        for (var i = 0; i < w.langs.length; i++)
          if (w.langs[i].status == 'pending') (w, i),
    ]..sort((a, b) => a.$1.langs[a.$2].since.compareTo(b.$1.langs[b.$2].since));

List<(Worker, String, Doc)> hrDocs() => [
      for (final w in app.workers) ...[
        if (w.degree?.status == 'pending') (w, '🎓 شهادة دراسية', w.degree!),
        if (w.union?.status == 'pending') (w, '🪪 هوية نقابة', w.union!),
        for (final c in w.certs)
          if (c.status == 'pending') (w, '📜 شهادة إضافية', c),
      ],
    ]..sort((a, b) => a.$3.at.compareTo(b.$3.at));

List<Worker> hrSelfies() =>
    app.workers.where((w) => w.selfie != null && !w.idVerified).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

List<Company> hrCompanies() =>
    app.companies.where((c) => !c.verified && c.selfie != null).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

List<Ticket> hrTickets() => [...app.tickets]..sort((a, b) {
    if (a.open != b.open) return a.open ? -1 : 1; // اللي ما انرد عليها أول
    return a.open ? a.t.compareTo(b.t) : b.t.compareTo(a.t);
  });

List<Post> hrReports() => app.posts.where((p) => p.hidden).toList()..sort((a, b) => a.reportedAt.compareTo(b.reportedAt));

int hrCount(String key) => switch (key) {
      'exams' => hrExams().length,
      'langs' => hrLangs().length,
      'docs' => hrDocs().length,
      'selfies' => hrSelfies().length,
      'companies' => hrCompanies().length,
      'support' => app.tickets.where((t) => t.open).length,
      'reports' => hrReports().length,
      'areas' => app.newAreas.length,
      'specs' => app.others.length,
      'alerts' => app.alerts.length,
      'bank' => app.reviewBanks().where((b) => b.$3.isNotEmpty).length,
      _ => 0,
    };

String waited(int t) {
  final h = (now() - t) ~/ 3600000;
  if (h < 1) return 'من شوية';
  if (h < 24) return 'ينتظر من $h ساعة';
  return 'ينتظر من ${h ~/ 24} يوم';
}

// ───────────── الصفحة الرئيسية للوحة ─────────────
class HrScreen extends StatelessWidget {
  const HrScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final secs = kHrSecs.where((s) => s.key == 'team' ? app.acct?.hrRole == 'admin' : app.can(s.key)).toList();
          final total = secs.fold<int>(0, (n, s) => n + (s.key == 'alerts' ? 0 : hrCount(s.key)));
          final overdue = app.tickets.where((t) => t.open && now() - t.t > kDay).length;
          return ListView(padding: const EdgeInsets.all(14), children: [
            Box(children: [
              Text('أهلاً ${app.acct?.hrName ?? ''} 👋', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Mut(total == 0 ? 'ماكو شي ينتظر، كلشي مراجَع 👌' : 'عندك $total طلب ينتظر المراجعة. كل قسم مرتب من الأقدم للأحدث.'),
              if (overdue > 0)
                Note('⏰ $overdue رسالة دعم تجاوزت 24 ساعة بدون رد', kind: NoteKind.warn),
            ]),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 520 ? 3 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: [for (var i = 0; i < secs.length; i++) FadeIn(ms: 250 + i * 35, child: _tile(context, secs[i]))],
              );
            }),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('🧪 وضع التجربة: إعادة الامتحان وتقييم 30 يوم بدون انتظار'),
              value: app.ignoreCooldown,
              onChanged: (v) {
                app.ignoreCooldown = v;
                app.changed();
              },
            ),
            const SizedBox(height: 20),
          ]);
        },
      );

  Widget _tile(BuildContext context, HrSec s) {
    final n = hrCount(s.key);
    final hot = n > 0 && !['bank', 'alerts'].contains(s.key);
    return Press(
      onTap: () => openPage(context, HrSection(sec: s)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hot ? C.soft : Colors.white,
          border: Border.all(color: hot ? C.pri : C.line, width: hot ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(s.icon, style: const TextStyle(fontSize: 24)),
            const Spacer(),
            if (n > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(color: hot ? C.pri : C.amber, borderRadius: BorderRadius.circular(99)),
                child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
          ]),
          const Spacer(),
          Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Text(s.hint, style: const TextStyle(fontSize: 12, color: C.mut), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ───────────── صفحة القسم ─────────────
class HrSection extends StatefulWidget {
  final HrSec sec;
  const HrSection({super.key, required this.sec});
  @override
  State<HrSection> createState() => _HrSectionState();
}

class _HrSectionState extends State<HrSection> {
  final Map<String, TextEditingController> _ctl = {};
  final Map<int, String> _otherSector = {};
  String _q = '';
  String _newRole = 'reviewer';

  TextEditingController _c(String key, [String init = '']) =>
      _ctl.putIfAbsent(key, () => TextEditingController(text: init));

  void _drop(String key) {
    final c = _ctl.remove(key);
    if (c != null) WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final n = hrCount(widget.sec.key);
          return Scaffold(
            appBar: AppBar(title: Text('${widget.sec.icon} ${widget.sec.title}${n > 0 && widget.sec.key != 'bank' ? ' ($n)' : ''}')),
            body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(14), children: _body()),
            ),
          );
        },
      );

  Widget _empty(String t) => Box(children: [Center(child: Mut(t))]);

  Widget _row2(String a, VoidCallback onA, String b, VoidCallback onB) => Row(children: [
        Expanded(child: WideButton(a, onTap: onA)),
        const SizedBox(width: 8),
        Expanded(child: WideButton(b, danger: true, onTap: onB)),
      ]);

  Widget _img(String? b64, String label) => Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 84, height: 84, child: Ava(photo: b64, size: 84))),
        Mut(label),
      ]);

  Widget _since(int t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('🕒 ${waited(t)}', style: TextStyle(fontSize: 12, color: now() - t > kDay ? C.warn : C.mut)),
      );

  List<Widget> _body() {
    switch (widget.sec.key) {
      case 'exams':
        final l = hrExams();
        return [
          const Note('🤖 الذكاء الاصطناعي حلل الإجابات حسب كل محور. راجع التحليل واعتمد الدرجة أو عدّلها.'),
          if (l.isEmpty) _empty('ماكو امتحانات تنتظر 👌'),
          for (final (w, i) in l) Box(children: [_examItem(w, i)]),
        ];
      case 'langs':
        final l = hrLangs();
        return [
          if (l.isEmpty) _empty('ماكو اختبارات لغة تنتظر 👌'),
          for (final (w, i) in l) Box(children: [_langItem(w, i)]),
        ];
      case 'docs':
        final l = hrDocs();
        return [
          const Note('افتح المستند وتأكد إن الاسم مطابق، والجهة والتخصص صحيحين، وما بيه تعديل أو قص.'),
          if (l.isEmpty) _empty('ماكو مستندات تنتظر 👌'),
          for (final (w, k, d) in l)
            DocTile(label: '${w.name} · $k', doc: d, actions: [
              _since(d.at),
              _row2('✅ توثيق', () => app.verifyDoc(w, d, true), 'رفض', () => _reject(w, d)),
            ]),
        ];
      case 'selfies':
        final l = hrSelfies();
        return [
          if (l.isEmpty) _empty('ماكو صور حية تنتظر 👌'),
          for (final w in l)
            Box(children: [
              Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              _since(w.createdAt),
              Row(children: [
                _img(w.selfie, 'الصورة الحية'),
                const SizedBox(width: 10),
                if (w.photo != null) _img(w.photo, 'صورة الملف'),
              ]),
              _row2('✅ شخص حقيقي، احذف الصورة', () => app.verifyId(w, true), 'رفض', () => app.verifyId(w, false)),
            ]),
          const Mut('🗑️ الصورة الحية تنحذف مباشرة بعد التحقق.'),
        ];
      case 'companies':
        final l = hrCompanies();
        return [
          if (l.isEmpty) _empty('ماكو شركات تنتظر 👌'),
          for (final c in l)
            Box(children: [
              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Mut('${c.sector} · ${c.gov} · المسؤول: ${c.contact}'),
              _since(c.createdAt),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                _img(c.selfie, 'الصورة الحية'),
                if (c.idFront != null) Column(children: [DocThumb(doc: Doc(title: 'البطاقة: الوجه', path: c.idFront), size: 84), const Mut('وجه البطاقة')]),
                if (c.idBack != null) Column(children: [DocThumb(doc: Doc(title: 'البطاقة: الظهر', path: c.idBack), size: 84), const Mut('ظهر البطاقة')]),
              ]),
              const Mut('اضغط على أي صورة حتى تكبّرها، وقارن الوجه بصورة البطاقة والاسم بالمسؤول.'),
              _row2('✅ توثيق الشركة', () => app.verifyCo(c, true), 'رفض', () => app.verifyCo(c, false)),
            ]),
          const Mut('🗑️ صور البطاقة والصورة الحية تنحذف بعد التوثيق.'),
        ];
      case 'support':
        final l = hrTickets();
        return [
          const Note('⏰ وعدنا المستخدمين بالرد خلال 24 ساعة. الرسائل اللي ما انرد عليها تطلع أول، من الأقدم للأحدث.'),
          if (l.isEmpty) _empty('ماكو رسائل دعم 👌'),
          for (final t in l) _ticket(t),
        ];
      case 'reports':
        final l = hrReports();
        return [
          if (l.isEmpty) _empty('ماكو بلاغات 👌'),
          for (final p in l)
            Box(children: [
              _since(p.reportedAt),
              Text(p.text),
              Mut('الكاتب: ${app.workers.where((w) => w.id == p.wid).firstOrNull?.name ?? '—'} · ${p.reports} بلاغ'),
              _row2('إرجاع المنشور', () => app.modPost(p, true), 'حذف', () => app.modPost(p, false)),
            ]),
        ];
      case 'areas':
        final idx = [for (var k = 0; k < app.newAreas.length; k++) k]..sort((a, b) => app.newAreas[a].t.compareTo(app.newAreas[b].t));
        return [
          if (idx.isEmpty) _empty('ماكو مناطق جديدة 👌'),
          for (final k in idx)
            Box(children: [
              Text([app.newAreas[k].gov, app.newAreas[k].qadha, if (app.newAreas[k].area.isNotEmpty) app.newAreas[k].area].join(' ← '),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              _since(app.newAreas[k].t),
              const Mut('تأكد إنها مو مكررة باسم ثاني'),
              _row2('إضافة للقائمة', () => app.approveArea(k), 'رفض', () => app.rejectArea(k)),
            ]),
        ];
      case 'specs':
        final idx = [for (var k = 0; k < app.others.length; k++) k]..sort((a, b) => app.others[a].t.compareTo(app.others[b].t));
        return [
          if (idx.isEmpty) _empty('ماكو تخصصات جديدة 👌'),
          for (final k in idx)
            Box(children: [
              Text(app.others[k].name, style: const TextStyle(fontWeight: FontWeight.w700)),
              _since(app.others[k].t),
              Drop(
                label: 'القطاع المقترح',
                value: _otherSector[k] ?? app.others[k].sector,
                items: same(kSectors.keys),
                onChanged: (v) => setState(() => _otherSector[k] = v),
              ),
              _row2('إضافة للقائمة', () {
                app.approveOther(k, _otherSector.remove(k) ?? app.others[k].sector);
              }, 'رفض', () => app.rejectOther(k)),
            ]),
          if (app.custom.isNotEmpty) Mut('مضاف سابقاً: ${app.custom.values.expand((e) => e).join('، ')}'),
        ];
      case 'chats':
        final l = [...app.requests]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return [
          const Note('🛡️ فتح أي محادثة ينسجل باسمك بسجل الوصول، ويوصل إشعار للطرفين.', kind: NoteKind.lock),
          if (l.isEmpty) _empty('ماكو محادثات بعد'),
          for (final r in l)
            Press(
              onTap: () {
                app.hrOpenChat(r);
                openPage(context, HrChatView(reqId: r.id));
              },
              child: Item(color: Colors.white, children: [
                Text('${r.company} ↔ ${app.workers.where((w) => w.id == r.wid).firstOrNull?.name ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Mut('${r.spec} · ${r.msgs.length} رسالة · بدأت ${fmtDate(r.createdAt)}${r.warn > 0 ? ' · 🚫 ${r.warn} محاولة تبادل أرقام' : ''}'),
                stageChip(r),
              ]),
            ),
        ];
      case 'profiles':
        final ws = app.workers.where((w) => _q.isEmpty || w.name.contains(_q) || w.phone.contains(_q)).toList();
        final cs = app.companies.where((c) => _q.isEmpty || c.name.contains(_q)).toList();
        return [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم أو الرقم'),
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
          const Note('🛡️ فتح أي ملف ينسجل بسجل الوصول. تكدر تعدّل التقييم حتى بعد الاعتماد.', kind: NoteKind.lock),
          H3('👷 الموظفين (${ws.length})'),
          for (final w in ws)
            Press(
              onTap: () {
                app.hrOpenProfile(w.name);
                openPage(context, HrWorkerView(wid: w.id));
              },
              child: Item(color: Colors.white, children: [
                Row(children: [
                  Ava.of(w, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Mut('${w.specs.map((s) => s.spec).join('، ')} · ${w.gov}'),
                    ]),
                  ),
                  Text('${app.completeness(w).$1}%', style: const TextStyle(color: C.mut)),
                ]),
              ]),
            ),
          H3('🏢 الشركات (${cs.length})'),
          for (final c in cs)
            Item(children: [
              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Mut('${c.sector} · ${c.gov} · المسؤول: ${c.contact} · ${c.verified ? '✅ موثّقة' : '⏳ غير موثّقة'}'),
              Mut('طلبات: ${app.requests.where((r) => r.company == c.name).length} · ما حضرت: ${c.noShows} · التزام ${app.coScore(c.name).toStringAsFixed(1)}/5'),
            ]),
        ];
      case 'bank':
        final r = app.reviewBanks();
        return [
          const Note('🤖 فحص آلي: كل سؤال بيه جواب صح واحد، وخيارات مو مكررة، ومحور واضح. بعد ربط السيرفر الذكاء الاصطناعي يراجع صحة المحتوى نفسه ويقترح أسئلة جديدة، والموارد البشرية تعتمدها.'),
          for (final (spec, n, issues) in r)
            Item(children: [
              Row(children: [
                Expanded(child: Text(spec, style: const TextStyle(fontWeight: FontWeight.w700))),
                Pill('$n سؤال', kind: issues.isEmpty ? PillKind.ok : PillKind.warn),
              ]),
              if (issues.isEmpty) const Mut('✓ ما بيه ملاحظات') else for (final i in issues) Mut('⚠️ $i'),
            ]),
          Mut('التخصصات اللي ما عندها بنك خاص (${kSectors.values.expand((e) => e).length - kQB.length} تخصص) تاخذ أسئلة عامة لحد ما ينبني بنكها.'),
        ];
      case 'alerts':
        return [
          if (app.alerts.isEmpty) _empty('ماكو تنبيهات 👌'),
          for (final a in app.alerts) Item(children: [Text('${fmtDateTime(a.t)} · ${a.m}')]),
        ];
      case 'stats':
        return [
          Box(title: '📊 إحصائيات', children: [
            Row(children: [
              _stat('${app.workers.length}', 'باحث عن عمل'),
              _stat('${app.companies.length}', 'شركة'),
              _stat('${app.requests.length}', 'طلب مقابلة'),
              _stat('${app.requests.where((r) => r.stage == 'hired').length}', 'توظيف'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _stat('${app.requests.where((r) => r.stage == 'expired').length}', 'طلب انتهى'),
              _stat('${app.tickets.where((t) => t.open).length}', 'دعم بدون رد'),
              _stat('${app.workers.expand((w) => w.ratings).length}', 'تقييم'),
              _stat('${app.companies.fold<int>(0, (n, c) => n + c.noShows)}', 'عدم حضور'),
            ]),
          ]),
          Box(title: '🔐 سجل وصول الموارد البشرية', children: [
            const Mut('منو فتح أي محادثة أو ملف، ومتى.'),
            if (app.access.isEmpty) const Mut('ماكو وصول مسجّل بعد.'),
            for (final l in app.access.take(60)) _logLine(l),
          ]),
          Box(title: '📜 سجل العمليات', children: [for (final l in app.logs.take(60)) _logLine(l)]),
        ];
      case 'team':
        final hrs = app.accounts.where((a) => a.role == 'hr').toList();
        final ph = _c('new_hr_phone'), nm = _c('new_hr_name');
        return [
          const Note('🔐 كل حسابات الموارد البشرية تدخل بتحقق بخطوتين، وكل واحد يشوف الأقسام اللي تسمحها صلاحيته بس.', kind: NoteKind.lock),
          for (final a in hrs)
            Item(children: [
              Text(a.hrName, style: const TextStyle(fontWeight: FontWeight.w700)),
              Mut('📱 ${a.phone}'),
              if (a.phone == app.session)
                Pill(kHrRoles[a.hrRole] ?? '')
              else
                Drop(label: 'الصلاحية', value: a.hrRole, items: [for (final e in kHrRoles.entries) (e.key, e.value)], onChanged: (v) => app.setHrRole(a, v)),
            ]),
          Box(title: '➕ إضافة موظف موارد بشرية', children: [
            TextField(controller: nm, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 8),
            TextField(controller: ph, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '07XXXXXXXXX')),
            Drop(label: 'الصلاحية', value: _newRole, items: [for (final e in kHrRoles.entries) (e.key, e.value)], onChanged: (v) => setState(() => _newRole = v)),
            WideButton('إضافة', onTap: () {
              final err = app.addHr(ph.text, nm.text, _newRole);
              if (err != null) return toast(context, '⚠️ $err');
              ph.clear();
              nm.clear();
              toast(context, '✓ انضاف. كلمة المرور المؤقتة 123456');
            }),
          ]),
        ];
    }
    return const [];
  }

  Widget _logLine(LogEntry l) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        child: Text('${fmtDateTime(l.t)} · ${l.m}', style: const TextStyle(fontSize: 13, color: C.mut)),
      );

  Widget _stat(String n, String l) => Expanded(child: Column(children: [Big(n), Mut(l)]));

  Widget _ticket(Ticket t) {
    final overdue = t.open && now() - t.t > kDay;
    final ctl = _c('t_${t.id}');
    return Box(color: overdue ? C.warnBg : null, children: [
      Row(children: [
        Expanded(child: Text(t.who, style: const TextStyle(fontWeight: FontWeight.w700))),
        t.open
            ? Pill(overdue ? '⏰ تجاوز 24 ساعة' : '⏳ بانتظار الرد', kind: overdue ? PillKind.bad : PillKind.warn)
            : const Pill('✓ انرد عليها', kind: PillKind.ok),
      ]),
      _since(t.t),
      Text(t.text),
      if (!t.open) ...[
        const SizedBox(height: 6),
        Mut('الرد (${t.replyBy} · ${fmtDateTime(t.replyT!)}): ${t.reply}'),
      ] else ...[
        const SizedBox(height: 8),
        TextField(controller: ctl, maxLines: 2, decoration: const InputDecoration(labelText: 'الرد (يوصل إشعار للمستخدم)')),
        WideButton('إرسال الرد', onTap: () {
          if (ctl.text.trim().length < 2) return toast(context, 'اكتب الرد');
          app.replyTicket(t, ctl.text);
          _drop('t_${t.id}');
          toast(context, '✓ وصل الرد');
        }),
      ],
    ]);
  }

  /// رفض مستند ويه سبب يوصل للموظف
  Future<void> _reject(Worker w, Doc d) async {
    final reason = await rejectReason(context, d.title);
    if (reason == null) return;
    app.verifyDoc(w, d, false, reason);
    if (mounted) toast(context, 'تم الرفض، ووصل السبب للموظف');
  }

  Widget _examItem(Worker w, int i) {
    final s = w.specs[i];
    final score = _c('s_${w.id}_$i', '${s.aiScore ?? 0}');
    final note = _c('n_${w.id}_$i');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _since(s.since),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Mut('${kTrans[w.transport] ?? ''} ${w.age} سنة · ${s.spec} · ${s.years} سنة خبرة · ${app.docCount(w)} شهادة · ${w.area.isNotEmpty ? w.area : w.qadha}'),
            Mut('الامتحان: ${s.examScore}% · المحاولة ${s.attempts.length}${s.avgSec > 0 ? ' · معدل ${s.avgSec} ث للسؤال' : ''}'),
          ]),
        ),
        Column(children: [Big('${s.aiScore}'), const Mut('تقييم AI')]),
      ]),
      Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.infoBg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🤖 تحليل الذكاء الاصطناعي', style: TextStyle(fontWeight: FontWeight.w800, color: C.info)),
          if (s.strong.isNotEmpty) Text('💪 قوي بـ: ${s.strong.join('، ')}'),
          if (s.weak.isNotEmpty) Text('⚠️ ضعيف بـ: ${s.weak.join('، ')}'),
          if (s.aiNote.isNotEmpty) Text(s.aiNote, style: const TextStyle(color: C.info)),
        ]),
      ),
      Row(children: [
        SizedBox(width: 90, child: TextField(controller: score, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الدرجة'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة للعامل (اختياري)'))),
      ]),
      WideButton('اعتماد التقييم', onTap: () {
        app.approve(w, i, int.tryParse(score.text) ?? (s.aiScore ?? 0), note.text);
        _drop('s_${w.id}_$i');
        _drop('n_${w.id}_$i');
        toast(context, '✓ تم الاعتماد ووصل إشعار للعامل');
      }),
    ]);
  }

  Widget _langItem(Worker w, int i) {
    final l = w.langs[i];
    final score = _c('l_${w.id}_$i', '${l.score ?? 0}');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _since(l.since),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Mut('${l.lang} · المستوى اللي كتبه: ${l.level}'),
          ]),
        ),
        Column(children: [Big('${l.score}'), const Mut('تقييم AI')]),
      ]),
      Row(children: [
        SizedBox(width: 90, child: TextField(controller: score, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الدرجة'))),
        const SizedBox(width: 8),
        Expanded(child: WideButton('اعتماد', onTap: () {
          app.approveLang(w, i, int.tryParse(score.text) ?? (l.score ?? 0));
          _drop('l_${w.id}_$i');
        })),
      ]),
    ]);
  }
}

/// نافذة سبب الرفض
Future<String?> rejectReason(BuildContext context, String title) async {
  final ctl = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('رفض: $title'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 6, children: [
          for (final r in ['الصورة غير واضحة', 'الاسم غير مطابق', 'المستند ناقص', 'يبين معدّل'])
            ActionChip(label: Text(r), onPressed: () => ctl.text = r),
        ]),
        const SizedBox(height: 8),
        TextField(controller: ctl, decoration: const InputDecoration(labelText: 'سبب الرفض (يوصل للموظف)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('رفض')),
      ],
    ),
  );
  ctl.dispose();
  return reason;
}

// ───────────── عرض محادثة كاملة للموارد البشرية ─────────────
class HrChatView extends StatelessWidget {
  final String reqId;
  const HrChatView({super.key, required this.reqId});
  @override
  Widget build(BuildContext context) {
    final r = app.requests.where((x) => x.id == reqId).firstOrNull;
    if (r == null) return const Scaffold();
    final w = app.workers.where((x) => x.id == r.wid).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('💬 ${r.company} ↔ ${w?.shortName ?? '—'}')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(14), children: [
          Box(children: [
            Mut('${r.spec} · ${r.hours}'),
            stageChip(r),
            if (r.warn > 0) Pill('🚫 ${r.warn} محاولة تبادل معلومات تواصل انحجبت', kind: PillKind.bad),
            if (r.noShow) const Pill('🚩 المرشح بلّغ إن الشركة ما حضرت', kind: PillKind.bad),
            const Note('🔐 انسجل فتحك لهاي المحادثة بسجل الوصول، ووصل إشعار للطرفين.', kind: NoteKind.lock),
          ]),
          Box(title: 'الرسائل (${r.msgs.length})', children: [
            if (r.msgs.isEmpty) const Mut('ماكو رسائل.'),
            for (final m in r.msgs)
              Align(
                alignment: m.from == 'co' ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: m.from == 'co' ? C.soft : const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.from == 'co' ? '🏢 ${r.company}' : '👷 ${w?.name ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(m.text),
                    Text(fmtDateTime(m.t), style: const TextStyle(fontSize: 11, color: C.mut)),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

// ───────────── ملف موظف كامل للموارد البشرية (ويه تعديل التقييم) ─────────────
class HrWorkerView extends StatefulWidget {
  final String wid;
  const HrWorkerView({super.key, required this.wid});
  @override
  State<HrWorkerView> createState() => _HrWorkerViewState();
}

class _HrWorkerViewState extends State<HrWorkerView> {
  Future<void> _edit(Worker w, int i) async {
    final s = w.specs[i];
    final sc = TextEditingController(text: '${s.finalScore ?? s.aiScore ?? 0}');
    final nt = TextEditingController(text: s.hrNote);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل تقييم ${s.spec}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Mut('الحالية: ${s.finalScore ?? '—'} · تقييم AI: ${s.aiScore ?? '—'}'),
          const SizedBox(height: 8),
          TextField(controller: sc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الدرجة الجديدة')),
          const SizedBox(height: 8),
          TextField(controller: nt, decoration: const InputDecoration(labelText: 'سبب أو ملاحظة')),
          const Mut('التعديل ينسجل بسجل الوصول، ويوصل إشعار للموظف.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) {
      app.hrEditScore(w, i, int.tryParse(sc.text) ?? (s.finalScore ?? 0), nt.text);
      if (mounted) toast(context, '✓ انعدّل التقييم');
    }
    sc.dispose();
    nt.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final w = app.workers.where((x) => x.id == widget.wid).firstOrNull;
          if (w == null) return const Scaffold();
          final reqs = app.requests.where((r) => r.wid == w.id).toList();
          return Scaffold(
            appBar: AppBar(title: Text('🗂️ ${w.name}')),
            body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(14), children: [
                Box(children: [
                  Row(children: [
                    Ava.of(w, size: 64),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(w.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Mut('📱 ${w.phone} · ${w.gender} · ${w.age} سنة · ${w.transport}'),
                        Mut('📍 ${app.place(w)}'),
                      ]),
                    ),
                  ]),
                  Wrap(children: badges(w)),
                  Mut('اكتمال الملف ${app.completeness(w).$1}% · ⭐ ${w.points} نقطة · سجّل ${fmtDate(w.createdAt)} · آخر تحديث ${fmtDate(w.lastUpdate)}'),
                  if (w.about.isNotEmpty) ...[const SizedBox(height: 6), Text(w.about)],
                ]),
                Box(title: '🛠️ التخصصات والتقييم', children: [
                  for (var i = 0; i < w.specs.length; i++)
                    Item(children: [
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(w.specs[i].spec, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Mut('${w.specs[i].years} سنة · امتحان ${w.specs[i].examScore ?? '—'}% · AI ${w.specs[i].aiScore ?? '—'} · ${w.specs[i].status == 'reviewed' ? 'معتمد' : w.specs[i].status == 'pending' ? 'ينتظر' : 'ما امتحن'}'),
                            if (w.specs[i].aiNote.isNotEmpty) Mut('🤖 ${w.specs[i].aiNote}'),
                            if (w.specs[i].hrNote.isNotEmpty) Mut('🧑‍💼 ${w.specs[i].hrNote}'),
                          ]),
                        ),
                        if (w.specs[i].finalScore != null) Big('${w.specs[i].finalScore}'),
                      ]),
                      if (w.specs[i].status != 'new')
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(onPressed: () => _edit(w, i), icon: const Icon(Icons.edit), label: const Text('تعديل التقييم')),
                        ),
                    ]),
                ]),
                Box(title: '📎 المستندات', children: [
                  for (final d in [w.degree, w.union, ...w.certs].whereType<Doc>()) DocTile(label: '📎', doc: d),
                  if (w.degree == null && w.union == null && w.certs.isEmpty) const Mut('ما رفع مستندات.'),
                ]),
                Box(title: '⭐ تقييمات الشركات', children: [
                  if (w.ratings.isEmpty) const Mut('ماكو تقييمات بعد.'),
                  for (final r in w.ratings)
                    Item(children: [
                      Row(children: [Stars(r.stars.toDouble()), Mut('  ${r.company} · ${r.kind == 'd30' ? 'بعد 30 يوم' : 'بعد المقابلة'} · ${fmtDate(r.t)}')]),
                      if (r.note.isNotEmpty) Text(r.note),
                    ]),
                ]),
                Box(title: '🎥 المقابلات (${reqs.length})', children: [
                  for (final r in reqs)
                    Press(
                      onTap: () {
                        app.hrOpenChat(r);
                        openPage(context, HrChatView(reqId: r.id));
                      },
                      child: Item(color: Colors.white, children: [
                        Text('${r.company} · ${r.spec}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Row(children: [stageChip(r), const Spacer(), Mut('${r.msgs.length} رسالة')]),
                      ]),
                    ),
                ]),
              ]),
            ),
          );
        },
      );
}
