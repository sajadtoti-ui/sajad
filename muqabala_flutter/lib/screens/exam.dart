// الامتحانات: امتحان المهنة واختبار اللغة (بوقت لكل سؤال)، وأسئلة الأسبوع والكورس (بدون وقت)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/constants.dart';
import '../data/store.dart';
import '../widgets/common.dart';

class ExamScreen extends StatefulWidget {
  final ExamSession session;
  const ExamScreen({super.key, required this.session});
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  ExamSession get e => widget.session;
  bool get timed => e.kind == 'spec' || e.kind == 'lang';
  int _left = 30;
  Timer? _timer;
  int? _feedback; // للأسئلة الأسبوعية: الخيار اللي اختاره
  int _gain = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (timed) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _left = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) _answer(-1); // انتهى الوقت = جواب غلط
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _answer(int j) {
    if (_finished) return;
    final q = e.qs[e.k];
    final ok = j >= 0 && q.opts[j].$2;
    if (!timed) {
      if (_feedback != null) return;
      setState(() => _feedback = j);
      e.answers.add((q.topic, ok));
      return;
    }
    e.answers.add((q.topic, ok));
    e.secs.add(30 - _left);
    if (j < 0) e.timeouts++;
    e.k++;
    if (e.done) {
      _finish();
    } else {
      setState(_startTimer);
    }
  }

  void _next() {
    setState(() {
      _feedback = null;
      e.k++;
    });
    if (e.done) _finish();
  }

  void _finish() {
    _timer?.cancel();
    _gain = app.finishExam(e);
    setState(() => _finished = true);
  }

  String get _title {
    final w = app.me!;
    return switch (e.kind) {
      'spec' => w.specs[e.index].spec,
      'lang' => '🌐 اختبار اللغة ${w.langs[e.index].lang}',
      'week' => '📝 أسئلة الأسبوع',
      _ => '🎓 اختبار الكورس',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _finished || !timed,
      child: Scaffold(
        appBar: AppBar(title: Text(_title), automaticallyImplyLeading: _finished || !timed),
        body: SafeArea(child: _finished ? _doneView() : _questionView()),
      ),
    );
  }

  Widget _doneView() {
    final w = app.me!;
    if (!timed) {
      return ListView(padding: const EdgeInsets.all(14), children: [
        Box(children: [
          const Center(child: Text('🎉 أحسنت!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          Center(child: Text('جاوبت صح على ${e.correct} من ${e.qs.length}')),
          Center(child: Big('+$_gain ⭐', color: C.warn)),
          WideButton('رجوع', onTap: () => Navigator.pop(context)),
        ]),
      ]);
    }
    // بعد امتحان المهنة: إذا عنده لغة بيها اختبار، نعرض الخطوة الجاية
    final nextLang = e.kind == 'spec'
        ? w.langs.indexWhere((l) => kLangQ.containsKey(l.lang) && l.status == 'new')
        : -1;
    return ListView(padding: const EdgeInsets.all(14), children: [
      Box(title: '✅ خلص الاختبار', children: [
        Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const Note('🤖 الذكاء الاصطناعي حلّل إجاباتك حسب كل محور (نقاط القوة والضعف والوقت) وأرسل التقييم للموارد البشرية. يوصلك إشعار لما تعتمد درجتك.'),
        const Note('🔒 الذكاء الاصطناعي استلم إجاباتك بس، بدون اسمك أو رقمك.', kind: NoteKind.lock),
        if (nextLang >= 0)
          Item(children: [
            Text('🌐 الخطوة الجاية: اختبار اللغة ${w.langs[nextLang].lang}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Mut('5 أسئلة بسيطة، تاخذ دقيقتين.'),
            WideButton('ابدأ اختبار اللغة', onTap: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ExamScreen(session: app.startLang(nextLang))));
            }),
          ]),
        WideButton('رجوع لصفحتي', secondary: nextLang >= 0, onTap: () => Navigator.pop(context)),
      ]),
    ]);
  }

  Widget _questionView() {
    final q = e.qs[e.k];
    final label = e.kind == 'lang'
        ? const Pill('🌐 أسئلة لغة')
        : e.kind == 'spec'
            ? (e.generic
                ? const Pill('🤖 أسئلة عامة لحد ما ينبني بنك تخصصك', kind: PillKind.warn)
                : Pill('📚 بنك أسئلة خاص بـ$_title', kind: PillKind.ok))
            : const SizedBox.shrink();
    return ListView(padding: const EdgeInsets.all(14), children: [
      Box(children: [
        Row(children: [
          Expanded(child: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (timed) Text('⏱️ $_left ث', style: const TextStyle(fontWeight: FontWeight.w800, color: C.warn)),
        ]),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(end: e.k / e.qs.length),
          duration: const Duration(milliseconds: 350),
          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, borderRadius: BorderRadius.circular(9)),
        ),
        if (timed) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(value: _left / 30, minHeight: 3, color: _left <= 10 ? C.bad : C.amber, backgroundColor: C.line),
        ],
        const SizedBox(height: 6),
        label,
        Mut('سؤال ${e.k + 1} من ${e.qs.length}${q.topic.isNotEmpty ? ' · ${q.topic}' : ''}'),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(a), child: c),
          ),
          child: Text(q.q, key: ValueKey(e.k), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        if (q.img != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: C.line), borderRadius: BorderRadius.circular(12)),
            child: SvgPicture.string(q.img!, height: 170),
          ),
        for (var j = 0; j < q.opts.length; j++) _option(j, q.opts[j]),
        if (!timed && _feedback != null) WideButton(e.k + 1 < e.qs.length ? 'السؤال الجاي' : 'النتيجة', onTap: _next),
        if (e.generic) const Note('ℹ️ بالنسخة الحقيقية، الذكاء الاصطناعي يولّد أسئلة خاصة بتخصصك.'),
        if (timed) const Mut('🛡️ وقت محدد لكل سؤال، والأسئلة والخيارات تتغير بكل محاولة.'),
      ]),
    ]);
  }

  Widget _option(int j, (String, bool) o) {
    Color border = const Color(0xFFCFD8DE);
    Color? bg;
    if (_feedback != null) {
      if (o.$2) {
        border = C.ok;
        bg = C.okBg;
      } else if (j == _feedback) {
        border = C.bad;
        bg = C.badBg;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Press(
        onTap: () => _answer(j),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg ?? Colors.white, border: Border.all(color: border, width: _feedback != null && bg != null ? 2 : 1), borderRadius: BorderRadius.circular(10)),
          child: Text(o.$1, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
