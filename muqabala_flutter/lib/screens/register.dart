// تسجيل الموظف أو تعديل معلوماته
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  final WorkerDraft? edit;
  const RegisterScreen({super.key, this.edit});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final WorkerDraft d = widget.edit ?? WorkerDraft();
  late final _name = TextEditingController(text: d.name);
  late final _age = TextEditingController(text: d.age);
  late final _about = TextEditingController(text: d.about);
  late final _qOther = TextEditingController(text: d.qadhaOther);
  late final _aOther = TextEditingController(text: d.areaOther);
  late final _deg = TextEditingController(text: d.degree?.title ?? '');
  late final _union = TextEditingController(text: d.union?.title ?? '');
  final _cert = TextEditingController();
  final _years = TextEditingController(text: '0');
  final _otherSpec = TextEditingController();
  String _sector = kSectors.keys.first;
  String _spec = '';
  String _lang = kLangs.first, _level = kLevels.first;
  String? _certFile, _certPath;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    if (d.edit) return;
    // نرجّع المعلومات اللي كتبها قبل إذا طلع من التطبيق أو صار خطأ
    app.loadRegDraft().then((old) {
      if (old == null || !mounted) return;
      super.setState(() {
        d
          ..name = old.name
          ..gender = old.gender
          ..age = old.age
          ..transport = old.transport
          ..gov = old.gov
          ..qadha = old.qadha
          ..qadhaOther = old.qadhaOther
          ..area = old.area
          ..areaOther = old.areaOther
          ..degree = old.degree
          ..union = old.union
          ..certs = old.certs
          ..langs = old.langs
          ..specs = old.specs
          ..photo = old.photo
          ..selfie = old.selfie
          ..hidePhoto = old.hidePhoto
          ..about = old.about;
        _name.text = d.name;
        _age.text = d.age;
        _about.text = d.about;
        _qOther.text = d.qadhaOther;
        _aOther.text = d.areaOther;
        _deg.text = d.degree?.title ?? '';
        _union.text = d.union?.title ?? '';
      });
      if (d.name.isNotEmpty || d.specs.isNotEmpty) toast(context, '↩️ رجّعنا المعلومات اللي كتبتها قبل، كمّل من وين ما وقفت');
    });
    for (final c in [_name, _age, _about, _qOther, _aOther]) {
      c.addListener(_persist);
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persist();
  }

  /// حفظ المسودة بعد نص ثانية من آخر تغيير
  void _persist() {
    if (d.edit) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      d
        ..name = _name.text
        ..age = _age.text.trim()
        ..about = _about.text
        ..qadhaOther = _qOther.text
        ..areaOther = _aOther.text;
      app.saveRegDraft(d);
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (!d.edit && app.me == null) {
      d
        ..name = _name.text
        ..age = _age.text.trim()
        ..about = _about.text;
      app.saveRegDraft(d);
    }
    for (final c in [_name, _age, _about, _qOther, _aOther, _deg, _union, _cert, _years, _otherSpec]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSpec() {
    var v = _spec;
    var other = false;
    if (v == '__o') {
      v = _otherSpec.text.trim();
      other = true;
      if (v.length < 3) return toast(context, 'اكتب اسم التخصص');
    }
    if (v.isEmpty) return toast(context, 'اختر تخصص');
    if (d.specs.any((s) => s.spec == v)) return toast(context, 'التخصص مضاف مسبقاً');
    final y = (int.tryParse(_years.text) ?? 0).clamp(0, 50);
    setState(() {
      d.specs.add(Spec(spec: v, sector: other ? 'أخرى (قيد المراجعة)' : app.sectorOf(v), years: y, other: other));
      _spec = '';
      _otherSpec.clear();
      _years.text = '0';
    });
  }

  Future<void> _pickDoc(String kind) async {
    final (name, path, err) = await pickDocument();
    if (!mounted) return;
    if (err != null) return toast(context, err);
    if (name == null) return;
    setState(() {
      if (kind == 'degree') {
        d.degree = Doc(title: _deg.text.trim().isEmpty ? 'الشهادة الدراسية' : _deg.text.trim(), file: name, path: path);
      } else if (kind == 'union') {
        d.union = Doc(title: _union.text.trim().isEmpty ? 'هوية النقابة' : _union.text.trim(), file: name, path: path);
      } else {
        _certFile = name;
        _certPath = path;
      }
    });
    if (kind != 'extra') toast(context, '✓ انرفع الملف، ينتظر مراجعة الموارد البشرية');
  }

  void _addCert() {
    final t = _cert.text.trim();
    if (t.length < 3) return toast(context, 'اكتب اسم الشهادة');
    if (_certFile == null) return toast(context, 'ارفع صورة الشهادة أو PDF');
    setState(() {
      d.certs.add(Doc(title: t, file: _certFile, path: _certPath));
      _certFile = null;
      _certPath = null;
      _cert.clear();
    });
  }

  void _submit() {
    d
      ..name = _name.text
      ..age = _age.text.trim()
      ..about = _about.text
      ..qadhaOther = _qOther.text
      ..areaOther = _aOther.text;
    if (d.degree != null && _deg.text.trim().isNotEmpty) d.degree!.title = _deg.text.trim();
    if (d.union != null && _union.text.trim().isNotEmpty) d.union!.title = _union.text.trim();
    final err = app.validateDraft(d);
    if (err != null) return toast(context, '⚠️ $err · معلوماتك محفوظة، صحّح هاي النقطة بس');
    app.saveDraft(d);
    toast(context, d.edit ? '✓ انحفظت التعديلات' : '✓ تمت الفلترة بنجاح. ابدأ امتحان تخصصك');
    if (d.edit) Navigator.of(context).pop();
  }

  Widget _fileRow(Doc? doc, VoidCallback onRemove) => doc?.file == null
      ? const SizedBox.shrink()
      : Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCFD8DE)), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            DocThumb(doc: doc!, size: 44),
            const SizedBox(width: 8),
            Expanded(child: Text(doc.file ?? '', overflow: TextOverflow.ellipsis)),
            Pill(docLabel(doc.status), kind: docKind(doc.status)),
            IconButton(icon: const Icon(Icons.close, color: C.bad), onPressed: onRemove),
          ]),
        );

  Widget _upload(String label, VoidCallback onTap, {IconData icon = Icons.upload_file}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: FilledButton.tonalIcon(onPressed: onTap, icon: Icon(icon), label: Text(label)),
      );

  @override
  Widget build(BuildContext context) {
    final geo = app.geo;
    final qs = geo[d.gov]!.keys.toList();
    if (d.qadha != '__o' && !qs.contains(d.qadha)) d.qadha = qs.first;
    final areas = d.qadha == '__o' ? <String>[] : geo[d.gov]![d.qadha]!.keys.toList();
    if (d.area != '__o' && !areas.contains(d.area)) d.area = '';
    final needDeg = d.specs.where((s) => kDegreeSectors.contains(s.sector)).firstOrNull;
    final sectors = app.allSectors;

    final list = ListView(padding: const EdgeInsets.all(14), children: [
      Box(title: d.edit ? 'تعديل معلوماتي' : 'تسجيل جديد', children: [
        // ── الصورة الحية للتحقق ──
        if (!d.edit)
          Item(color: C.lockBg, children: [
            const Row(children: [
              Expanded(child: Text('🤳 التحقق من الهوية: صورة حية', style: TextStyle(fontWeight: FontWeight.w700))),
              Pill('إلزامي', kind: PillKind.bad),
            ]),
            const Mut('سيلفي ينأخذ هسه من الكاميرا الأمامية، مو صورة من الاستوديو. يتأكد إنك شخص حقيقي، وينحذف بعد التحقق.'),
            if (d.selfie != null)
              Row(children: [
                Ava(photo: d.selfie, size: 64),
                const SizedBox(width: 10),
                const Pill('✓ انأخذت الصورة الحية', kind: PillKind.ok),
              ])
            else
              _upload('افتح الكاميرا وخذ سيلفي', () async {
                final s = await takeSelfie();
                if (!mounted) return;
                if (s != null) {
                  setState(() => d.selfie = s);
                } else {
                  showLastError(context);
                }
              }, icon: Icons.camera_front),
          ]),
        // ── صورة الملف ──
        const SizedBox(height: 8),
        Row(children: [
          Ava(photo: d.photo, gender: d.gender, size: 70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _upload(d.photo == null ? 'رفع صورتك' : 'تغيير الصورة', () async {
                final p = await pickPhoto();
                if (!mounted) return;
                if (p != null) {
                  setState(() => d.photo = p);
                } else {
                  showLastError(context);
                }
              }, icon: Icons.photo_camera),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('إخفاء صورتي عن الشركات'),
                value: d.hidePhoto,
                onChanged: (v) => setState(() => d.hidePhoto = v),
              ),
            ]),
          ),
        ]),
        const Mut('الصورة اختيارية، وما تظهر لأي شركة إلا بعد ما تقبل المقابلة الأولية.'),
        const SizedBox(height: 10),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم الكامل', hintText: 'مثال: علي حسين جاسم')),
        Row(children: [
          Expanded(child: Drop(label: 'الجنس', value: d.gender, items: same(['ذكر', 'أنثى']), onChanged: (v) => setState(() => d.gender = v))),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(controller: _age, keyboardType: TextInputType.number, maxLength: 2, decoration: const InputDecoration(labelText: 'العمر (رقم بس)', hintText: 'مثال: 28', counterText: '')),
            ),
          ),
        ]),
        Drop(label: 'هل عندك وسيلة نقل؟', value: d.transport, items: [for (final e in kTrans.entries) (e.key, '${e.value} ${e.key}')], onChanged: (v) => setState(() => d.transport = v)),

        // ── العنوان ──
        const H3('📍 العنوان'),
        Drop(label: 'المحافظة', value: d.gov, items: same(geo.keys), onChanged: (v) => setState(() {
              d.gov = v;
              d.qadha = '';
              d.area = '';
            })),
        Drop(label: 'القضاء / الناحية', value: d.qadha, items: [...same(qs), ('__o', '➕ أخرى')], onChanged: (v) => setState(() {
              d.qadha = v;
              d.area = '';
            })),
        if (d.qadha == '__o')
          Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: _qOther, decoration: const InputDecoration(labelText: 'اكتب اسم القضاء أو الناحية'))),
        Drop(label: 'المنطقة (اختياري)', value: d.area, items: [('', 'بدون تحديد'), ...same(areas), ('__o', '➕ أخرى (منطقتي مو موجودة)')], onChanged: (v) => setState(() => d.area = v)),
        if (d.area == '__o')
          Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: _aOther, decoration: const InputDecoration(labelText: 'اكتب اسم منطقتك'))),
        if (d.qadha == '__o' || d.area == '__o') const Note('🤖 الذكاء الاصطناعي يتأكد إنها مو مكررة باسم ثاني، وبعدها تنضاف للقائمة.'),
        const Note('🔒 العنوان التفصيلي ما يظهر للشركات. يشوفون المنطقة بس.', kind: NoteKind.lock),

        // ── التخصصات ──
        const H3('🛠️ التخصصات (تكدر تختار أكثر من تخصص)'),
        if (d.specs.isEmpty) const Mut('ما أضفت تخصص بعد'),
        for (var i = 0; i < d.specs.length; i++)
          Item(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.specs[i].spec, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Mut('${d.specs[i].sector} · ${d.specs[i].years} سنة'),
                ]),
              ),
              IconButton(icon: const Icon(Icons.close, color: C.bad), onPressed: () => setState(() => d.specs.removeAt(i))),
            ]),
          ]),
        Item(color: const Color(0xFFFAFBFC), children: [
          Drop(label: 'القطاع', value: _sector, items: same(sectors.keys), onChanged: (v) => setState(() {
                _sector = v;
                _spec = '';
              })),
          Drop(label: 'التخصص الدقيق', value: _spec, items: [...same(sectors[_sector] ?? []), ('__o', '➕ أخرى (تخصصي مو موجود)')], onChanged: (v) => setState(() => _spec = v)),
          if (_spec == '__o')
            Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: _otherSpec, decoration: const InputDecoration(labelText: 'اكتب تخصصك الدقيق'))),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextField(controller: _years, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنوات الخبرة بهذا التخصص')),
          ),
          WideButton('+ إضافة التخصص', secondary: true, onTap: _addSpec),
        ]),

        // ── المستندات ──
        const H3('📎 المستندات'),
        const Note('🔒 صورة أو PDF، الحد الأقصى 5 ميغا. تنحفظ مشفّرة، والشركة ما تشوفها إلا بعد ما تقبل المقابلة.', kind: NoteKind.lock),
        Item(children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('🎓 الشهادة الدراسية  ', style: TextStyle(fontWeight: FontWeight.w700)),
            needDeg != null ? Pill('إلزامية لتخصص ${needDeg.spec}', kind: PillKind.bad) : const Pill('اختيارية لتخصصك'),
          ]),
          const SizedBox(height: 6),
          TextField(controller: _deg, decoration: const InputDecoration(hintText: 'مثال: بكالوريوس هندسة كهرباء')),
          _fileRow(d.degree, () => setState(() => d.degree = null)),
          _upload(d.degree?.file == null ? 'رفع الشهادة' : 'تغيير الملف', () => _pickDoc('degree')),
        ]),
        Item(children: [
          const Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('🪪 هوية النقابة  ', style: TextStyle(fontWeight: FontWeight.w700)),
            Pill('اختيارية'),
          ]),
          const Mut('مثل نقابة المهندسين أو الصيادلة أو المعلمين. إذا رفعتها وراجعتها الموارد البشرية تطلع لك علامة «✅ موثّق».'),
          const SizedBox(height: 6),
          TextField(controller: _union, decoration: const InputDecoration(hintText: 'مثال: هوية نقابة المهندسين العراقيين')),
          _fileRow(d.union, () => setState(() => d.union = null)),
          _upload(d.union?.file == null ? 'رفع الهوية' : 'تغيير الملف', () => _pickDoc('union')),
        ]),
        Item(children: [
          const Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('📜 شهادات إضافية  ', style: TextStyle(fontWeight: FontWeight.w700)),
            Pill('اختيارية'),
          ]),
          const Mut('كورسات، شهادات سلامة، دورات… تكدر ترفع أكثر من وحدة.'),
          for (var i = 0; i < d.certs.length; i++) _fileRow(Doc(title: d.certs[i].title, file: '${d.certs[i].title} · ${d.certs[i].file ?? ''}', path: d.certs[i].path, status: d.certs[i].status), () => setState(() => d.certs.removeAt(i))),
          const SizedBox(height: 6),
          TextField(controller: _cert, decoration: const InputDecoration(hintText: 'اسم الشهادة، مثال: HAZWOPER 40')),
          Row(children: [
            Expanded(child: _upload(_certFile == null ? 'اختيار الملف' : '✓ $_certFile', () => _pickDoc('extra'))),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(top: 6), child: OutlinedButton(onPressed: _addCert, child: const Text('+ إضافة'))),
          ]),
        ]),

        // ── اللغات ──
        const H3('🌐 اللغات (اختياري – تنضاف للـCV)'),
        Wrap(children: [
          for (var i = 0; i < d.langs.length; i++)
            InputChip(
              label: Text('${d.langs[i].lang} · ${d.langs[i].level}'),
              onDeleted: () => setState(() => d.langs.removeAt(i)),
            ),
        ]),
        Row(children: [
          Expanded(child: Drop(label: 'اللغة', value: _lang, items: same(kLangs), onChanged: (v) => setState(() => _lang = v))),
          const SizedBox(width: 8),
          Expanded(child: Drop(label: 'المستوى', value: _level, items: same(kLevels), onChanged: (v) => setState(() => _level = v))),
        ]),
        WideButton('إضافة اللغة', secondary: true, onTap: () {
          if (d.langs.any((x) => x.lang == _lang)) return toast(context, 'اللغة مضافة');
          setState(() => d.langs.add(Lang(lang: _lang, level: _level)));
        }),
        const Mut('📝 إذا ضفت لغة، تاخذ اختبار بسيط بيها بعد امتحان مهنتك.'),

        // ── عرّف بنفسك ──
        const H3('✍️ عرّف بنفسك'),
        TextField(controller: _about, maxLines: 4, decoration: const InputDecoration(hintText: 'اكتب براحتك عن نفسك وشغلك، بدون أي قيود…')),
        const Note('🤖 الذكاء الاصطناعي يحوّل كلامك لكلمات مفتاحية تنضاف داخل الـCV وتبحث بيها الشركات. اسمك ورقمك ما ينرسلون ويه النص.'),
        WideButton(d.edit ? 'حفظ التعديلات' : 'إرسال وفلترة المعلومات', onTap: _submit),
      ]),
    ]);

    if (!d.edit) return list;
    return Scaffold(appBar: AppBar(title: const Text('تعديل معلوماتي')), body: SafeArea(child: list));
  }
}
