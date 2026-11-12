// شاشات الشركة: معلومات الشركة والتوثيق، والبحث عن موظفين
import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import 'interview.dart';
import 'worker_home.dart' show keywordChip;

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});
  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  String _sector = kSectors.keys.first;
  String _gov = 'بغداد';
  String? _idFront, _idBack, _selfie;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  Widget _idRow(String label, String? file, ValueChanged<String> onPicked) => Item(children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          const Pill('إلزامي', kind: PillKind.bad),
        ]),
        if (file != null) Row(children: [Expanded(child: Text('📄 $file')), const Pill('✓ انرفعت', kind: PillKind.ok)]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.photo_camera),
            label: Text(file == null ? 'تصوير البطاقة' : 'تغيير'),
            onPressed: () async {
              final f = await shootDocument();
              if (f != null && mounted) setState(() => onPicked(f));
            },
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(14), children: [
      Box(title: '🏢 معلومات الشركة', children: [
        const Mut('مرة وحدة بس، وبعدها تكدر تبحث عن موظفين'),
        const SizedBox(height: 10),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الشركة / صاحب العمل', hintText: 'مثال: شركة النور للمقاولات')),
        Drop(label: 'مجال العمل', value: _sector, items: same(kSectors.keys), onChanged: (v) => setState(() => _sector = v)),
        Drop(label: 'المحافظة', value: _gov, items: same(app.geo.keys), onChanged: (v) => setState(() => _gov = v)),
        const SizedBox(height: 10),
        TextField(controller: _contact, decoration: const InputDecoration(labelText: 'اسم الشخص المسؤول', hintText: 'مثال: م. أحمد علي')),
        const H3('🛡️ توثيق الشركة'),
        const Note('حتى يثق بيك الباحثين عن عمل، صوّر مستمسكاتك الأصلية (مو نسخة مصورة)، وخذ صورة حية من الكاميرا. الموارد البشرية تراجعها، وبعد التوثيق تنحذف الصور.', kind: NoteKind.lock),
        _idRow('🪪 البطاقة الوطنية الموحدة: الوجه', _idFront, (f) => _idFront = f),
        _idRow('🪪 البطاقة الوطنية الموحدة: الظهر', _idBack, (f) => _idBack = f),
        Item(color: C.lockBg, children: [
          const Row(children: [
            Expanded(child: Text('🤳 صورة حية للشخص المسؤول', style: TextStyle(fontWeight: FontWeight.w700))),
            Pill('إلزامي', kind: PillKind.bad),
          ]),
          const Mut('تنأخذ هسه من الكاميرا الأمامية، مو من الاستوديو، حتى نتأكد إنه نفس صاحب المستمسك.'),
          if (_selfie != null)
            Row(children: [Ava(photo: _selfie, size: 64), const SizedBox(width: 10), const Pill('✓ انأخذت الصورة الحية', kind: PillKind.ok)])
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.camera_front),
                label: const Text('افتح الكاميرا وخذ سيلفي'),
                onPressed: () async {
                  final s = await takeSelfie();
                  if (s != null && mounted) setState(() => _selfie = s);
                },
              ),
            ),
        ]),
        WideButton('حفظ وإرسال للتوثيق', onTap: () {
          final err = app.saveCompany(
              name: _name.text, sector: _sector, gov: _gov, contact: _contact.text,
              idFront: _idFront, idBack: _idBack, selfie: _selfie);
          toast(context, err ?? '✓ انرسلت للتوثيق، وتگدر تبحث من هسه');
        }),
      ]),
    ]);
  }
}

class CompanyHome extends StatefulWidget {
  const CompanyHome({super.key});
  @override
  State<CompanyHome> createState() => _CompanyHomeState();
}

class _CompanyHomeState extends State<CompanyHome> {
  final q = SearchQuery(spec: 'كهربائي تأسيس منازل');
  late final _hours = TextEditingController(text: q.hours);
  final _kw = TextEditingController();
  bool _searched = false;

  @override
  void dispose() {
    _hours.dispose();
    _kw.dispose();
    super.dispose();
  }

  void _open(String reqId) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => InterviewScreen(reqId: reqId)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = app.comp;
    if (c == null) return const SizedBox.shrink();
    final mine = app.requests.where((r) => r.company == c.name).toList();
    final geo = app.geo;
    final qs = geo[q.gov]!.keys.toList();
    if (q.qadha.isNotEmpty && !qs.contains(q.qadha)) q.qadha = '';
    final areas = q.qadha.isEmpty ? <String>[] : geo[q.gov]![q.qadha]!.keys.toList();
    if (q.area.isNotEmpty && !areas.contains(q.area)) q.area = '';
    final allSpecs = [for (final e in app.allSectors.entries) ...e.value];

    return ListView(padding: const EdgeInsets.all(14), children: [
      if (mine.isNotEmpty)
        Box(title: '🎥 مقابلاتي (${mine.length})', children: [
          for (final r in mine)
            Item(children: [
              Text('${app.workerById(r.wid).shortName} · ${r.spec}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Row(children: [stageChip(r), const Spacer(), FilledButton(onPressed: () => _open(r.id), child: const Text('فتح'))]),
            ]),
        ]),
      Box(title: '🏢 نشر وظيفة والبحث عن موظف', children: [
        Mut('${c.name} · ${c.sector}'),
        coBadge(c.name),
        if (!c.verified)
          const Note('⏳ الموارد البشرية تراجع مستمسكاتك. الباحثين عن عمل يشوفون إن شركتك «قيد التوثيق» لحد ما تخلص المراجعة.'),
        Drop(label: 'التخصص المطلوب', value: q.spec, items: same(allSpecs), onChanged: (v) => setState(() => q.spec = v)),
        Row(children: [
          Expanded(child: Drop(label: 'الجنس المطلوب', value: q.gender, items: const [('', 'ما يفرق'), ('ذكر', 'ذكر'), ('أنثى', 'أنثى')], onChanged: (v) => setState(() => q.gender = v))),
          const SizedBox(width: 8),
          Expanded(child: Drop(label: 'الخبرة المطلوبة', value: q.exp, items: [for (final e in kExp) (e.$1, e.$2)], onChanged: (v) => setState(() => q.exp = v))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _hours, decoration: const InputDecoration(labelText: 'ساعات العمل')),
        const SizedBox(height: 10),
        TextField(controller: _kw, decoration: const InputDecoration(labelText: 'كلمة مفتاحية (اختياري)', hintText: 'مثال: طاقة شمسية، إكسل، بيركنز')),
        Drop(label: 'وسيلة نقل (اختياري)', value: q.trans, items: const [('', 'لا يهم'), ('any', 'عنده وسيلة نقل (دراجة أو سيارة)'), ('سيارة', 'عنده سيارة'), ('دراجة', 'عنده دراجة')], onChanged: (v) => setState(() => q.trans = v)),
        Drop(label: 'لغة مطلوبة (اختياري)', value: q.lang, items: [('', 'لا يهم'), ...same(kLangs)], onChanged: (v) => setState(() => q.lang = v)),
        const H3('📍 وين تريد تبحث؟'),
        const Mut('اختار المحافظة بس، وإذا تريد تتخصص أكثر اختار القضاء والمنطقة (اختياري).'),
        Drop(label: 'المحافظة', value: q.gov, items: same(geo.keys), onChanged: (v) => setState(() {
              q.gov = v;
              q.qadha = '';
              q.area = '';
            })),
        Drop(label: 'القضاء (اختياري)', value: q.qadha, items: [('', 'كل المحافظة'), ...same(qs)], onChanged: (v) => setState(() {
              q.qadha = v;
              q.area = '';
            })),
        if (q.qadha.isNotEmpty)
          Drop(label: 'المنطقة (اختياري)', value: q.area, items: [('', 'كل القضاء'), ...same(areas)], onChanged: (v) => setState(() => q.area = v)),
        if (q.area.isNotEmpty) ...[
          Drop(label: 'النطاق', value: q.radius ? 'r' : 'a', items: const [('a', 'نفس المنطقة بس'), ('r', 'ضمن مسافة بالكيلومترات')], onChanged: (v) => setState(() => q.radius = v == 'r')),
          if (q.radius)
            Row(children: [
              Expanded(child: Slider(value: q.km, min: 1, max: 50, divisions: 49, label: '${q.km.round()} كم', onChanged: (v) => setState(() => q.km = v))),
              Text('${q.km.round()} كم'),
            ]),
        ],
        WideButton('🔎 ابحث عن مرشحين', onTap: () => setState(() {
              q.hours = _hours.text;
              q.kw = _kw.text.trim();
              _searched = true;
            })),
      ]),
      if (_searched) _results(c),
    ]);
  }

  Widget _results(Company c) {
    final list = app.search(q);
    final kws = q.kw.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    return Box(title: 'المرشحين (${list.length})', children: [
      if (list.isEmpty) const Mut('ماكو مرشحين بهذه الشروط. جرّب توسّع النطاق أو تغيّر الخبرة أو الجنس.'),
      for (final h in list) _hit(h, c, kws),
      const Note('🔒 ما يتبادل الطرفين أي رقم أو حساب. الصورة والشهادات تظهر بعد ما يقبل المرشح المقابلة الأولية، والعنوان التفصيلي ما يظهر أبداً.', kind: NoteKind.lock),
    ]);
  }

  Widget _hit(SearchHit h, Company c, List<String> kws) {
    final w = h.w, s = h.s, rev = s.status == 'reviewed';
    final req = app.findReq(w.id, c.name, q.spec);
    return Item(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Ava.of(w, size: 46, locked: true),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${w.shortName}  ${w.gender == 'أنثى' ? '♀' : '♂'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Mut('📍 ${[w.area, w.qadha].where((e) => e.isNotEmpty).join('، ')}${h.d < 9999 ? ' · ${h.d.toStringAsFixed(1)} كم' : ''}'),
            Mut('${kTrans[w.transport] ?? ''} ${w.transport == 'لا يوجد' ? 'بدون وسيلة نقل' : w.transport} · ${w.age} سنة · ${s.years} سنة خبرة · ${app.docCount(w)} شهادة'
                '${w.langs.isNotEmpty ? ' · ${w.langs.map((l) => l.lang + (l.status == 'reviewed' ? ' (${l.score})' : '')).join('، ')}' : ''}'),
            Wrap(children: [
              ...badges(w),
              rev
                  ? const Pill('معتمد من الموارد البشرية', kind: PillKind.ok)
                  : const Pill('⏳ التقييم قيد مراجعة الموارد البشرية', kind: PillKind.warn),
            ]),
            if (w.keywords.isNotEmpty)
              Wrap(children: [
                for (final k in w.keywords.take(6)) keywordChip(k, hit: kws.any((x) => k.contains(x) || x.contains(k))),
              ]),
          ]),
        ),
        Column(children: [
          if (rev) ...[Big('${s.finalScore}'), Mut(app.level(s.finalScore ?? 0))] else const Mut('الدرجة\nبعد المراجعة'),
        ]),
      ]),
      const SizedBox(height: 6),
      if (req != null)
        Row(children: [stageChip(req), const Spacer(), FilledButton(onPressed: () => _open(req.id), child: const Text('فتح'))])
      else
        FilledButton(
          onPressed: () {
            q.hours = _hours.text;
            app.sendReq(w, q);
            toast(context, '✓ وصل الطلب للمرشح');
          },
          child: const Text('طلب مقابلة'),
        ),
    ]);
  }
}
