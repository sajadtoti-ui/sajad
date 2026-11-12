// المساعد الذكي: غنى (تظهر للمسجلين الذكور) ويمان (يظهر للمسجلات الإناث)،
// والشركة تختار مساعدها وتغيّره من الإعدادات.
import 'package:flutter/material.dart';

import '../data/characters.dart';
import '../data/faq.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import 'more.dart';

class _Line {
  final bool me;
  final String text;
  final bool human; // زر «كلّم شخص»
  _Line(this.me, this.text, {this.human = false});
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Line> _lines = [];
  bool _typing = false;

  String get who => app.assistant.isEmpty ? 'ghina' : app.assistant;
  String get role => app.acct?.role ?? 'worker';

  @override
  void initState() {
    super.initState();
    final first = app.myName.split(' ').first;
    _lines.add(_Line(false,
        'هلا ${first.isEmpty ? '' : first} 👋 آني ${assistantName(who)}، مساعدتك بمقابلة. اسألني أي شي عن ${role == 'company' ? 'البحث والتوثيق والمقابلات' : 'التسجيل والامتحان والمقابلات'}، أو اختار سؤال من تحت.'));
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String q) async {
    final t = q.trim();
    if (t.isEmpty) return;
    _ctl.clear();
    setState(() {
      _lines.add(_Line(true, t));
      _typing = true;
    });
    _down();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final f = findFaq(t, role);
    setState(() {
      _typing = false;
      if (f != null) {
        _lines.add(_Line(false, f.a));
        _lines.add(_Line(false, 'إذا ما جاوبت سؤالك، تكدر تكلّم شخص من فريقنا.', human: true));
      } else {
        _lines.add(_Line(false,
            'ما فهمت سؤالك زين 🙏 جرّب تكتبه بطريقة ثانية، أو كلّم شخص من فريق مقابلة ويرد عليك خلال 24 ساعة.',
            human: true));
      }
    });
    _down();
  }

  void _down() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final sugg = kFaq.where((f) => f.role == 'all' || f.role == role).map((f) => f.q).toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Hero(tag: 'assistant', child: AssistantFace(who, size: 40)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(assistantName(who), style: const TextStyle(fontWeight: FontWeight.w800)),
            const Text('مساعدة مقابلة · تجاوب فوراً', style: TextStyle(fontSize: 12, color: C.mut)),
          ]),
        ]),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(controller: _scroll, padding: const EdgeInsets.all(14), children: [
              for (final l in _lines) _bubble(l),
              if (_typing)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${assistantName(who)} تكتب…', style: const TextStyle(color: C.mut)),
                  ),
                ),
            ]),
          ),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
              for (final q in sugg)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ActionChip(label: Text(q), onPressed: () => _ask(q)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _ask,
                  decoration: InputDecoration(hintText: 'اكتب سؤالك لـ${assistantName(who)}…', isDense: true),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: () => _ask(_ctl.text), icon: const Icon(Icons.send)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(_Line l) => FadeIn(
        ms: 260,
        child: Align(
          alignment: l.me ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (!l.me) ...[AssistantFace(who, size: 28), const SizedBox(width: 6)],
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: l.me ? C.pri : Colors.white,
                  border: l.me ? null : Border.all(color: C.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.text, style: TextStyle(color: l.me ? Colors.white : C.ink, height: 1.5)),
                  if (l.human)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.support_agent),
                        label: const Text('كلّم شخص'),
                        onPressed: () => openPage(context, const SupportScreen()),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      );
}

/// اختيار مساعد الشركة (أول مرة، ومن الإعدادات)
Future<void> chooseAssistant(BuildContext context) async {
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('اختاروا مساعد شركتكم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Mut('تكدرون تغيّرونه بأي وقت من الإعدادات'),
          const SizedBox(height: 12),
          Row(children: [
            for (final w in ['ghina', 'yaman'])
              Expanded(
                child: Press(
                  onTap: () => Navigator.pop(ctx, w),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: app.assistant == w ? C.soft : Colors.white,
                      border: Border.all(color: app.assistant == w ? C.pri : C.line, width: app.assistant == w ? 2 : 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(children: [
                      AssistantFace(w, size: 90),
                      const SizedBox(height: 8),
                      Text(assistantName(w), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    ),
  );
  if (picked != null) app.setAssistant(picked);
}

/// زر المساعد العائم
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});
  @override
  Widget build(BuildContext context) {
    final who = app.assistant;
    return FloatingActionButton.extended(
      heroTag: null,
      backgroundColor: Colors.white,
      foregroundColor: C.pri2,
      onPressed: () async {
        if (who.isEmpty) {
          await chooseAssistant(context);
          if (app.assistant.isEmpty || !context.mounted) return;
        }
        openPage(context, const AssistantScreen());
      },
      icon: Hero(tag: 'assistant', child: AssistantFace(who.isEmpty ? 'ghina' : who, size: 34)),
      label: Text(who.isEmpty ? 'اختار مساعدك' : 'اسأل ${assistantName(who)}', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
