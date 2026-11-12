// صفحة الموظف: صفحتي، التعلّم والنقاط، المجتمع، والسيرة الذاتية
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/constants.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import 'exam.dart';
import 'interview.dart';
import 'register.dart';

class WorkerHome extends StatefulWidget {
  const WorkerHome({super.key});
  @override
  State<WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends State<WorkerHome> {
  int _tab = 0;

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final w = app.me;
    if (w == null) return const SizedBox.shrink();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('🏠 صفحتي')),
            ButtonSegment(value: 1, label: Text('📚 تعلّم')),
            ButtonSegment(value: 2, label: Text('💬 المجتمع')),
          ],
          selected: {_tab},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
      ),
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: switch (_tab) {
              1 => _learn(w),
              2 => const CommunityView(),
              _ => _home(w),
            },
          ),
        ),
      ),
    ]);
  }

  // ───────────── صفحتي ─────────────
  Widget _home(Worker w) {
    final reqs = app.requests.where((r) => r.wid == w.id).toList();
    final examDone = w.specs.any((s) => s.status != 'new');
    final docs = <(String, Doc)>[
      if (w.degree != null) ('🎓 الشهادة الدراسية', w.degree!),
      if (w.union != null) ('🪪 هوية النقابة', w.union!),
      for (final c in w.certs) ('📜 شهادة إضافية', c),
    ];
    final (pct, next) = app.completeness(w);
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
      if (pct < 100)
        Box(children: [
          Row(children: [
            const Expanded(child: Text('📋 اكتمال ملفك', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text('$pct%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: pct >= 70 ? C.ok : C.warn)),
          ]),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v, minHeight: 10, borderRadius: BorderRadius.circular(9),
              color: pct >= 70 ? C.ok : C.amber, backgroundColor: C.soft),
          ),
          if (next != null) ...[
            const SizedBox(height: 8),
            Text('💡 الخطوة الجاية: $next'),
            const Mut('الملفات المكتملة تطلع أول ببحث الشركات.'),
          ],
        ]),
      if (app.stale(w))
        Box(color: C.warnBg, children: [
          const Text('⏰ صار أكثر من 3 أشهر ما حدّثت معلوماتك.', style: TextStyle(fontWeight: FontWeight.w700)),
          const Text('حدّثها حتى تبقى بأعلى بحث الشركات.'),
          WideButton('تحديث معلوماتي', onTap: () => _open(RegisterScreen(edit: app.draftFrom(w)))),
        ]),
      Box(children: [
        Row(children: [
          Ava.of(w, size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أهلاً ${w.firstName} 👋', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Wrap(children: badges(w)),
              if (w.stars != null)
                Row(children: [Stars(w.stars!), Mut('  ${w.stars!.toStringAsFixed(1)} · تقييم ${w.ratings.length} شركة')]),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Mut('${w.gender} · ${w.age} سنة · ${kTrans[w.transport] ?? ''} ${w.transport}'),
        Mut('📍 ${app.place(w)}'),
        if (w.photo != null && w.hidePhoto) const Mut('🙈 صورتك مخفية عن الشركات'),
        if (w.selfie != null && !w.idVerified) const Mut('🤳 صورتك الحية تنتظر تحقق الموارد البشرية'),
      ]),
      if (reqs.isNotEmpty)
        Box(title: '📩 طلبات مقابلة', children: [
          for (final r in reqs)
            Item(children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${r.company}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                coBadge(r.company),
              ]),
              Text('تطلب مقابلة لتخصص ${r.spec}'),
              Mut(r.hours),
              if (app.daysLeft(r) != null)
                Mut('⌛ ${r.stage == 'sent' ? 'رد' : 'اختار موعد'} خلال ${app.daysLeft(r)} يوم، وإلا ينتهي الطلب تلقائياً'),
              Row(children: [
                stageChip(r),
                const Spacer(),
                FilledButton(onPressed: () => _open(InterviewScreen(reqId: r.id)), child: const Text('فتح')),
              ]),
            ]),
        ]),
      Box(title: 'تخصصاتي', children: [
        for (var i = 0; i < w.specs.length; i++) _specItem(w, i),
        const Note('🤖 الذكاء الاصطناعي يقيّمك أولاً، وبعدها تراجع الموارد البشرية التقييم. تظهر لك درجتك بعد المراجعة.'),
      ]),
      if (w.langs.isNotEmpty)
        Box(title: '🌐 لغاتي', children: [
          for (var i = 0; i < w.langs.length; i++) _langItem(w, i, examDone),
          const Mut('اختبار اللغة بسيط ويجي بعد امتحان مهنتك، ونتيجته تنضاف للـCV.'),
        ]),
      Box(title: '📎 مستنداتي', children: [
        if (docs.isEmpty) const Mut('ما رفعت مستندات بعد.'),
        for (final (k, doc) in docs) DocTile(label: k, doc: doc),
        if (w.union == null) const Mut('💡 ارفع هوية نقابتك (اختياري) حتى تاخذ علامة «✅ موثّق» وتزيد ثقة الشركات بيك.'),
      ]),
      Box(title: '✍️ عنّي', children: [
        if (w.about.isEmpty)
          const Mut('ما كتبت شي عن نفسك بعد. اكتب براحتك من «تعديل معلوماتي».')
        else ...[
          Text(w.about),
          const SizedBox(height: 8),
          Wrap(children: [for (final k in w.keywords) _kw(k)]),
          const Mut('🤖 هاي الكلمات المفتاحية طلعها الذكاء الاصطناعي من كلامك، وتنضاف للـCV وتبحث بيها الشركات.'),
        ],
      ]),
      Row(children: [
        Expanded(child: WideButton('📄 سيرتي الذاتية', onTap: () => _open(const CvScreen()))),
        const SizedBox(width: 8),
        Expanded(child: WideButton('✏️ تعديل معلوماتي', secondary: true, onTap: () => _open(RegisterScreen(edit: app.draftFrom(w))))),
      ]),
      const SizedBox(height: 20),
    ]);
  }

  Widget _specItem(Worker w, int i) {
    final s = w.specs[i];
    Widget status;
    Widget? action;
    if (s.status == 'new') {
      status = const Pill('لم يُمتحن بعد', kind: PillKind.warn);
      action = FilledButton(onPressed: () => _open(ExamScreen(session: app.startExam(i))), child: const Text('ابدأ الامتحان'));
    } else if (s.status == 'pending') {
      status = const Pill('قيد مراجعة الموارد البشرية', kind: PillKind.warn);
    } else {
      status = Pill('معتمد · ${app.level(s.finalScore ?? 0)}', kind: PillKind.ok);
      final (ok, why) = app.canRetake(s);
      action = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OutlinedButton(onPressed: ok ? () => _open(ExamScreen(session: app.startExam(i))) : null, child: const Text('إعادة الامتحان')),
        if (!ok) Mut(why),
      ]);
    }
    return Item(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.spec, style: const TextStyle(fontWeight: FontWeight.w700)),
            Mut('${s.sector} · ${s.years} سنة خبرة'),
            status,
          ]),
        ),
        if (s.status == 'reviewed') Big('${s.finalScore}'),
      ]),
      if (s.status == 'reviewed' && s.strong.isNotEmpty) Mut('💪 نقاط قوتك: ${s.strong.join('، ')}'),
      if (s.status == 'reviewed' && s.weak.isNotEmpty) Note('💡 ملاحظة تطوير: راجع ${s.weak.join('، ')}'),
      if (s.hrNote.isNotEmpty) Mut('ملاحظة الموارد البشرية: ${s.hrNote}'),
      if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action),
    ]);
  }

  Widget _langItem(Worker w, int i, bool examDone) {
    final l = w.langs[i];
    Widget st;
    Widget? act;
    if (!kLangQ.containsKey(l.lang)) {
      st = const Pill('تقييم ذاتي');
    } else if (l.status == 'pending') {
      st = const Pill('قيد مراجعة الموارد البشرية', kind: PillKind.warn);
    } else if (l.status == 'reviewed') {
      st = Pill('معتمد · ${l.score}/100', kind: PillKind.ok);
    } else {
      st = const Pill('لم يُختبر بعد', kind: PillKind.warn);
      act = examDone
          ? FilledButton(onPressed: () => _open(ExamScreen(session: app.startLang(i))), child: const Text('ابدأ اختبار اللغة'))
          : const Mut('🔒 ينفتح بعد ما تخلص امتحان مهنتك');
    }
    return Item(children: [
      Text('${l.lang} · ${l.level}', style: const TextStyle(fontWeight: FontWeight.w700)),
      st,
      if (act != null) Padding(padding: const EdgeInsets.only(top: 6), child: act),
    ]);
  }

  // ───────────── التعلّم والنقاط ─────────────
  Widget _learn(Worker w) {
    final wk = w.weekDone == app.weekId && !app.ignoreCooldown;
    final mo = w.courseDone == app.monthId && !app.ignoreCooldown;
    final c = kCourses[app.monthId % kCourses.length];
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
      Box(children: [
        const Center(child: Mut('نقاطي')),
        Center(child: Text('⭐ ${w.points}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: C.warn))),
        Center(
          child: app.active(w)
              ? const Pill('🔥 نشِط: تطلع أعلى ببحث الشركات', kind: PillKind.warn)
              : Pill('باقي ${50 - w.points % 50} نقطة وتاخذ شارة 🔥 نشِط'),
        ),
        const Center(child: Mut('كل ما تتعلّم وتشارك، ترتفع نقاطك ويرتفع ترتيبك ببحث الشركات.')),
      ]),
      Box(title: '📝 أسئلة الأسبوع', children: [
        const Mut('5 أسئلة قصيرة بتخصصك · دقيقتين · كل جواب صح = 5 نقاط، والإكمال = 10 نقاط'),
        if (wk)
          const Note('✅ خلصت أسئلة هذا الأسبوع. الأسئلة الجديدة تنفتح الأسبوع الجاي.')
        else
          WideButton('ابدأ أسئلة الأسبوع', onTap: () => _open(ExamScreen(session: app.startQuiz('week')))),
      ]),
      Box(title: '🎓 كورس الشهر', children: [
        Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final b in c.body) Text('• $b'),
        const Mut('بعد الدرس سؤالين بسيطين · الإكمال = 20 نقطة'),
        if (mo)
          const Note('✅ خلصت كورس هذا الشهر.')
        else
          WideButton('خلصت الدرس، ابدأ الاختبار', secondary: true, onTap: () => _open(ExamScreen(session: app.startQuiz('course')))),
      ]),
      if (app.ignoreCooldown) const Center(child: Mut('🧪 وضع التجربة: تكدر تعيد الأسئلة والكورس.')),
    ]);
  }
}

Widget _kw(String k, {bool hit = false}) => Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: hit ? C.warnBg : const Color(0xFFEEF2F7), borderRadius: BorderRadius.circular(8)),
      child: Text('#$k', style: TextStyle(fontSize: 13, color: hit ? C.warn : const Color(0xFF334155), fontWeight: hit ? FontWeight.w700 : FontWeight.w400)),
    );

Widget keywordChip(String k, {bool hit = false}) => _kw(k, hit: hit);

// ───────────── المجتمع ─────────────
class CommunityView extends StatefulWidget {
  const CommunityView({super.key});
  @override
  State<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<CommunityView> {
  final _post = TextEditingController();
  final Map<String, TextEditingController> _cm = {};

  @override
  void dispose() {
    _post.dispose();
    for (final c in _cm.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _name(String wid) {
    final w = app.workers.where((x) => x.id == wid).firstOrNull;
    return w?.shortName ?? '—';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final me = app.me;
    if (me == null) return const SizedBox.shrink();
    final posts = app.posts.where((p) => !p.hidden).toList()..sort((a, b) => b.t.compareTo(a.t));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
      Box(title: '💬 مجتمع «مقابلة»', children: [
        const Mut('شارك نصيحة أو سؤال بمهنتك. نشر وتعليق بس، ماكو رسائل خاصة.'),
        const SizedBox(height: 8),
        TextField(controller: _post, maxLines: 3, decoration: const InputDecoration(hintText: 'شنو تريد تشارك؟')),
        WideButton('نشر (+2 ⭐)', onTap: () {
          final err = app.addPost(_post.text);
          if (err != null) return toast(context, err);
          _post.clear();
          toast(context, '✓ انتشر المنشور (+2 ⭐)');
        }),
        const Note('🔒 ممنوع نشر الأرقام والروابط والعناوين وحسابات التواصل. النظام يحجبها تلقائياً.', kind: NoteKind.lock),
      ]),
      if (posts.isEmpty) const Box(children: [Mut('ماكو منشورات بعد. كن أول واحد!')]),
      for (final p in posts) _postCard(p, me),
    ]);
  }

  Widget _postCard(Post p, Worker me) {
    final a = app.workers.where((x) => x.id == p.wid).firstOrNull;
    final c = _cm.putIfAbsent(p.id, () => TextEditingController());
    return Box(children: [
      Row(children: [
        if (a != null) Ava.of(a, size: 36, forCompany: true),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_name(p.wid), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${a != null && a.specs.isNotEmpty ? a.specs.first.spec : ''} · ${fmtDate(p.t)}', style: const TextStyle(fontSize: 12, color: C.mut)),
        ]),
      ]),
      const SizedBox(height: 8),
      Text(p.text),
      for (final cm in p.comments)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(10)),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${_name(cm.wid)}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: cm.text),
          ])),
        ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: c, decoration: const InputDecoration(hintText: 'اكتب تعليق…', isDense: true))),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: () {
            final err = app.addComment(p, c.text);
            if (err != null) return toast(context, err);
            c.clear();
          },
          child: const Text('تعليق'),
        ),
      ]),
      if (p.wid != me.id)
        TextButton.icon(
          onPressed: () {
            app.reportPost(p);
            toast(context, '✓ وصل البلاغ للإدارة');
          },
          icon: const Text('🚩'),
          label: const Text('إبلاغ'),
        ),
    ]);
  }
}

// ───────────── السيرة الذاتية ─────────────
class CvScreen extends StatelessWidget {
  const CvScreen({super.key});

  static String cvText(Worker w) {
    String ds(Doc x) => x.status == 'verified' ? ' ✓ موثّقة' : x.status == 'pending' ? ' (قيد التوثيق)' : '';
    final b = StringBuffer()
      ..writeln(w.name)
      ..writeln('${w.gender} · ${w.age} سنة · وسيلة النقل: ${w.transport}')
      ..writeln('📍 ${[w.gov, w.qadha, w.area].where((e) => e.isNotEmpty).join(' – ')}');
    if (w.about.isNotEmpty) b..writeln()..writeln('نبذة:')..writeln(w.about);
    if (w.keywords.isNotEmpty) b..writeln()..writeln('الكلمات المفتاحية:')..writeln(w.keywords.map((k) => '#$k').join('  '));
    b..writeln()..writeln('التخصصات:');
    for (final s in w.specs) {
      b.writeln('• ${s.spec} — ${s.years} سنة خبرة — ${s.status == 'reviewed' ? 'مستوى: ${app.level(s.finalScore ?? 0)} (${s.finalScore}/100، معتمد من «مقابلة»)' : 'قيد التقييم'}');
    }
    b..writeln()..writeln('الشهادات والمستندات:');
    final docs = [w.degree, w.union, ...w.certs].whereType<Doc>();
    if (docs.isEmpty) b.writeln('—');
    for (final d in docs) {
      b.writeln('• ${d.title}${ds(d)}');
    }
    if (w.langs.isNotEmpty) {
      b..writeln()..writeln('اللغات:');
      for (final l in w.langs) {
        b.writeln('• ${l.lang} — ${l.level}${l.status == 'reviewed' ? ' (اختبار «مقابلة»: ${l.score}/100)' : ''}');
      }
    }
    if (w.stars != null) b..writeln()..writeln('⭐ تقييم الشركات بعد المقابلة: ${w.stars!.toStringAsFixed(1)}/5 (${w.ratings.length} تقييم)');
    if (app.active(w)) b..writeln()..writeln('🔥 عضو نشِط بالتعلّم والمجتمع (${w.points} نقطة)');
    b..writeln()..write('موثّق عبر تطبيق «مقابلة»');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final w = app.me;
    if (w == null) return const Scaffold();
    final t = cvText(w);
    return Scaffold(
      appBar: AppBar(title: const Text('📄 السيرة الذاتية')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(14), children: [
          Box(children: [
            Row(children: [
              Ava.of(w, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Wrap(children: badges(w)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFFAFBFC), border: Border.all(color: const Color(0xFFCFD8DE)), borderRadius: BorderRadius.circular(10)),
              child: SelectableText(t, style: const TextStyle(fontSize: 15, height: 1.6)),
            ),
            WideButton('نسخ النص', onTap: () async {
              await Clipboard.setData(ClipboardData(text: t));
              if (context.mounted) toast(context, '✓ تم النسخ');
            }),
          ]),
        ]),
      ),
    );
  }
}
