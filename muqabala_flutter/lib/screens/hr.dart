// لوحة الموارد البشرية: كل المراجعات والتوثيق بمكان واحد
import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

class HrScreen extends StatefulWidget {
  const HrScreen({super.key});
  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen> {
  final Map<String, TextEditingController> _ctl = {};
  final Map<int, String> _otherSector = {};

  TextEditingController _c(String key, [String init = '']) =>
      _ctl.putIfAbsent(key, () => TextEditingController(text: init));

  /// يشيل الحقل بعد ما يختفي من الشاشة
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

  Widget _row2(String a, VoidCallback onA, String b, VoidCallback onB) => Row(children: [
        Expanded(child: WideButton(a, onTap: onA)),
        const SizedBox(width: 8),
        Expanded(child: WideButton(b, danger: true, onTap: onB)),
      ]);

  Widget _img(String? b64, String label) => Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 84, height: 84, child: Ava(photo: b64, size: 84))),
        Mut(label),
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final pend = <(Worker, int)>[
      for (final w in app.workers)
        for (var i = 0; i < w.specs.length; i++)
          if (w.specs[i].status == 'pending') (w, i),
    ];
    final selfies = app.workers.where((w) => w.selfie != null && !w.idVerified).toList();
    final cos = app.companies.where((c) => !c.verified && c.selfie != null).toList();
    final docs = <(Worker, String, Doc)>[
      for (final w in app.workers) ...[
        if (w.degree?.status == 'pending') (w, '🎓 شهادة دراسية', w.degree!),
        if (w.union?.status == 'pending') (w, '🪪 هوية نقابة', w.union!),
        for (final c in w.certs)
          if (c.status == 'pending') (w, '📜 شهادة إضافية', c),
      ],
    ];
    final langs = <(Worker, int)>[
      for (final w in app.workers)
        for (var i = 0; i < w.langs.length; i++)
          if (w.langs[i].status == 'pending') (w, i),
    ];
    final reported = app.posts.where((p) => p.hidden).toList();

    return ListView(padding: const EdgeInsets.all(14), children: [
      Box(title: '🧑‍💼 قائمة المراجعة (${pend.length})', children: [
        const Mut('الذكاء الاصطناعي قيّم هؤلاء. راجع التقييم واعتمده أو عدّله، مو شرط بنفس اللحظة.'),
        if (pend.isEmpty) const Mut('ماكو طلبات بانتظار المراجعة 👌'),
        for (final (w, i) in pend) _examItem(w, i),
      ]),
      Box(title: '🏢 توثيق الشركات (${cos.length})', children: [
        if (cos.isEmpty) const Mut('ماكو شركات تنتظر 👌'),
        for (final c in cos)
          Item(children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Mut('${c.sector} · ${c.gov} · المسؤول: ${c.contact}'),
            const SizedBox(height: 8),
            Row(children: [
              _img(c.selfie, 'الصورة الحية'),
              const SizedBox(width: 10),
              if (c.idFront != null) Column(children: [DocThumb(doc: Doc(title: 'البطاقة: الوجه', path: c.idFront), size: 84), const Mut('وجه البطاقة')]),
              const SizedBox(width: 10),
              if (c.idBack != null) Column(children: [DocThumb(doc: Doc(title: 'البطاقة: الظهر', path: c.idBack), size: 84), const Mut('ظهر البطاقة')]),
            ]),
            const Mut('اضغط على أي صورة حتى تكبّرها، وقارن الوجه بصورة البطاقة والاسم بالمسؤول.'),
            _row2('✅ توثيق الشركة', () => app.verifyCo(c, true), 'رفض', () => app.verifyCo(c, false)),
          ]),
        const Mut('🗑️ صور البطاقة والصورة الحية تنحذف بعد التوثيق.'),
      ]),
      Box(title: '🤳 التحقق من هوية الموظفين (${selfies.length})', children: [
        if (selfies.isEmpty) const Mut('ماكو صور حية تنتظر 👌'),
        for (final w in selfies)
          Item(children: [
            Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              _img(w.selfie, 'الصورة الحية'),
              const SizedBox(width: 10),
              if (w.photo != null) _img(w.photo, 'صورة الملف'),
            ]),
            _row2('✅ شخص حقيقي، احذف الصورة', () => app.verifyId(w, true), 'رفض', () => app.verifyId(w, false)),
          ]),
        const Mut('🗑️ الصورة الحية تنحذف من السيرفر مباشرة بعد التحقق.'),
      ]),
      Box(title: '📎 مستندات بانتظار التوثيق (${docs.length})', children: [
        if (docs.isEmpty) const Mut('ماكو مستندات تنتظر 👌'),
        for (final (w, k, d) in docs)
          DocTile(label: '${w.name} · $k', doc: d, actions: [
            const Mut('افتح المستند وتأكد إن الاسم مطابق، والجهة والتخصص صحيحين، وما بيه تعديل أو قص.'),
            _row2('✅ توثيق', () => app.verifyDoc(w, d, true), 'رفض', () => _reject(w, d)),
          ]),
        const Mut('توثيق هوية النقابة يعطي العامل علامة «✅ موثّق». بالنسخة الحقيقية صور الهويات تنحذف بعد التحقق.'),
      ]),
      Box(title: '🌐 اختبارات اللغة (${langs.length})', children: [
        if (langs.isEmpty) const Mut('ماكو اختبارات لغة تنتظر 👌'),
        for (final (w, i) in langs) _langItem(w, i),
      ]),
      Box(title: '📍 مناطق جديدة اقترحها الذكاء الاصطناعي (${app.newAreas.length})', children: [
        if (app.newAreas.isEmpty) const Mut('ماكو مناطق جديدة.'),
        for (var k = 0; k < app.newAreas.length; k++)
          Item(children: [
            Text([app.newAreas[k].gov, app.newAreas[k].qadha, if (app.newAreas[k].area.isNotEmpty) app.newAreas[k].area].join(' ← '),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const Mut('تأكد إنها مو مكررة باسم ثاني'),
            _row2('إضافة للقائمة', () => app.approveArea(k), 'رفض', () => app.rejectArea(k)),
          ]),
      ]),
      Box(title: '🤖 تخصصات جديدة اقترحها الذكاء الاصطناعي (${app.others.length})', children: [
        if (app.others.isEmpty) const Mut('ماكو تخصصات جديدة.'),
        for (var k = 0; k < app.others.length; k++)
          Item(children: [
            Text(app.others[k].name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
      ]),
      if (reported.isNotEmpty)
        Box(title: '🚩 منشورات عليها بلاغات (${reported.length})', children: [
          for (final p in reported)
            Item(children: [
              Text(p.text),
              _row2('إرجاع المنشور', () => app.modPost(p, true), 'حذف', () => app.modPost(p, false)),
            ]),
        ]),
      if (app.alerts.isNotEmpty)
        Box(title: '🚨 تنبيهات أمنية', children: [for (final a in app.alerts) Item(children: [Text('${fmtDate(a.t)} · ${a.m}')])]),
      Box(title: '📊 إحصائيات', children: [
        Row(children: [
          _stat('${app.workers.length}', 'باحث عن عمل'),
          _stat('${app.companies.length}', 'شركة'),
          _stat('${app.requests.length}', 'طلب مقابلة'),
          _stat('${app.requests.where((r) => r.stage == 'hired').length}', 'توظيف'),
        ]),
      ]),
      Box(title: '📜 سجل العمليات', children: [
        for (final l in app.logs.take(40))
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
            child: Text('${fmtDateTime(l.t)} · ${l.m}', style: const TextStyle(fontSize: 13, color: C.mut)),
          ),
      ]),
      SwitchListTile(
        title: const Text('🧪 وضع التجربة: إعادة الامتحان بدون انتظار 14 يوم'),
        value: app.ignoreCooldown,
        onChanged: (v) {
          app.ignoreCooldown = v;
          app.changed();
        },
      ),
      const SizedBox(height: 20),
    ]);
  }

  /// رفض مستند ويه سبب يوصل للموظف
  Future<void> _reject(Worker w, Doc d) async {
    final ctl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('رفض: ${d.title}'),
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
    if (reason == null) return;
    app.verifyDoc(w, d, false, reason);
    if (mounted) toast(context, 'تم الرفض، ووصل السبب للموظف');
  }

  Widget _stat(String n, String l) => Expanded(child: Column(children: [Big(n), Mut(l)]));

  Widget _examItem(Worker w, int i) {
    final s = w.specs[i];
    final score = _c('s_${w.id}_$i', '${s.aiScore ?? 0}');
    final note = _c('n_${w.id}_$i');
    return Item(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Mut('${kTrans[w.transport] ?? ''} ${w.age} سنة · ${s.spec} · ${s.years} سنة خبرة · ${app.docCount(w)} شهادة · ${w.area.isNotEmpty ? w.area : w.qadha}'),
            Mut('الامتحان: ${s.examScore}%${s.weak.isNotEmpty ? ' · ضعف بـ: ${s.weak.join('، ')}' : ''}'),
          ]),
        ),
        Column(children: [Big('${s.aiScore}'), const Mut('تقييم AI')]),
      ]),
      const SizedBox(height: 8),
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
    return Item(children: [
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
