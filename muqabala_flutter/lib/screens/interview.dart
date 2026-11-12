// طلب المقابلة ومراحله، مشترك بين الشركة والموظف:
// طلب → تحديد موعد → مقابلة فيديو → مقابلة حضورية → توظيف
import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

/// يختار تاريخ ووقت، ويرجع الوقت بالملي ثانية
Future<int?> pickDateTime(BuildContext context) async {
  final d = await showDatePicker(
    context: context,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 60)),
    initialDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute).millisecondsSinceEpoch;
}

class InterviewScreen extends StatefulWidget {
  final String reqId;
  const InterviewScreen({super.key, required this.reqId});
  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  final _chat = TextEditingController();
  final _place = TextEditingController();
  final List<int?> _slots = [null, null, null];
  int? _inAt;

  @override
  void dispose() {
    _chat.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final r = app.requests.where((x) => x.id == widget.reqId).firstOrNull;
        final a = app.acct;
        if (r == null || a == null) return const Scaffold();
        final isCo = a.role == 'company';
        final w = app.workerById(r.wid);
        final idx = kStages.indexWhere((x) => x.$1 == r.stage);
        final chatOpen = !['sent', 'declined', 'rejected'].contains(r.stage);
        return Scaffold(
          appBar: AppBar(title: Text(isCo ? '👷 ${w.shortName}' : '🏢 ${r.company}')),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(14), children: [
              Box(children: [
                if (!isCo) coBadge(r.company),
                Mut('${r.spec} · ${r.hours}'),
                const SizedBox(height: 8),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  for (var i = 0; i < kStages.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: idx >= 0 && i <= idx ? C.pri : C.soft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${i + 1} ${kStages[i].$2}',
                          style: TextStyle(fontSize: 12, color: idx >= 0 && i <= idx ? Colors.white : C.pri2)),
                    ),
                ]),
                const SizedBox(height: 10),
                ..._actions(r, isCo),
              ]),
              if (isCo && chatOpen) _docsCard(w),
              if (chatOpen) _chatCard(r, isCo),
            ]),
          ),
        );
      },
    );
  }

  List<Widget> _actions(Req r, bool isCo) {
    switch (r.stage) {
      case 'sent':
        if (isCo) return const [Mut('بانتظار رد المرشح على الطلب.')];
        return [
          Row(children: [
            Expanded(child: WideButton('قبول المقابلة', onTap: () => app.answerReq(r, true))),
            const SizedBox(width: 8),
            Expanded(child: WideButton('اعتذار', danger: true, onTap: () => app.answerReq(r, false))),
          ]),
        ];
      case 'schedule':
        if (r.slots.isEmpty) {
          if (!isCo) return const [Mut('الشركة راح تقترح مواعيد لمقابلة الفيديو، وأنت تختار اللي يناسبك.')];
          return [
            const Text('اقترح 3 مواعيد لمقابلة الفيديو:', style: TextStyle(fontWeight: FontWeight.w700)),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(_slots[i] == null ? 'موعد ${i + 1}' : fmtDateTime(_slots[i]!)),
                  onPressed: () async {
                    final t = await pickDateTime(context);
                    if (t != null && mounted) setState(() => _slots[i] = t);
                  },
                ),
              ),
            WideButton('إرسال المواعيد للمرشح', onTap: () {
              final t = _slots.whereType<int>().toList();
              if (t.isEmpty) return toast(context, 'حدد موعد واحد على الأقل');
              app.proposeSlots(r, t);
              toast(context, '✓ وصلت المواعيد للمرشح');
            }),
          ];
        }
        if (isCo) {
          return [
            const Mut('بانتظار المرشح يختار موعد من:'),
            for (final t in r.slots) Item(children: [Text('📅 ${fmtDateTime(t)}')]),
          ];
        }
        return [
          const Text('اختار الموعد اللي يناسبك:', style: TextStyle(fontWeight: FontWeight.w700)),
          for (var i = 0; i < r.slots.length; i++)
            WideButton('📅 ${fmtDateTime(r.slots[i])}', secondary: true, onTap: () {
              app.pickSlot(r, i);
              toast(context, '✓ تم تثبيت موعد مقابلة الفيديو');
            }),
        ];
      case 'video':
        return [
          Item(children: [Text('🎥 مقابلة فيديو: ${fmtDateTime(r.videoAt ?? now())}')]),
          WideButton('دخول غرفة المقابلة', onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => VideoRoom(req: r, isCo: isCo)))),
          if (isCo && r.videoDone) ...[
            const H3('نتيجة مقابلة الفيديو'),
            Row(children: [
              Expanded(child: WideButton('مناسب ← حضورية', onTap: () => app.videoResult(r, true))),
              const SizedBox(width: 8),
              Expanded(child: WideButton('غير مناسب', danger: true, onTap: () => app.videoResult(r, false))),
            ]),
          ],
        ];
      case 'inperson':
        if (r.inAt == null) {
          if (!isCo) return const [Mut('الشركة راح تحدد موعد ومكان المقابلة الحضورية.')];
          return [
            const Text('حدد المقابلة الحضورية:', style: TextStyle(fontWeight: FontWeight.w700)),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(_inAt == null ? 'الموعد' : fmtDateTime(_inAt!)),
                onPressed: () async {
                  final t = await pickDateTime(context);
                  if (t != null && mounted) setState(() => _inAt = t);
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: _place, decoration: const InputDecoration(labelText: 'المكان (عنوان الشركة)', hintText: 'مثال: بغداد – الكرادة – شارع 62 – مقر الشركة')),
            WideButton('إرسال للمرشح', onTap: () {
              final err = app.setInPerson(r, _inAt, _place.text);
              toast(context, err ?? '✓ وصل الموعد للمرشح');
            }),
          ];
        }
        return [
          Item(children: [Text('🤝 مقابلة حضورية: ${fmtDateTime(r.inAt!)}'), Text('📍 ${r.place}')]),
          if (!r.inOk)
            isCo
                ? const Mut('بانتظار تأكيد المرشح.')
                : WideButton('تأكيد الحضور', onTap: () {
                    app.confirmIn(r);
                    toast(context, '✓ تم تأكيد الحضور');
                  })
          else
            const Pill('✓ المرشح أكد الحضور', kind: PillKind.ok),
          if (!isCo) const Note('👥 تگدر تشارك موعد المقابلة ويه شخص تثق بيه قبل ما تروح.', kind: NoteKind.lock),
          if (isCo && r.inOk) ...[
            const H3('النتيجة النهائية'),
            Row(children: [
              Expanded(child: WideButton('✅ تم التوظيف', onTap: () => app.finalResult(r, true))),
              const SizedBox(width: 8),
              Expanded(child: WideButton('غير مناسب', danger: true, onTap: () => app.finalResult(r, false))),
            ]),
          ],
        ];
      case 'hired':
        return const [Note('🎉 مبروك! تم التوظيف عبر «مقابلة». بعدين نضيف تقييم الطرفين ومتابعة أول 30 يوم.')];
      default:
        return const [Mut('انتهى هذا الطلب.')];
    }
  }

  Widget _docsCard(Worker w) => Box(title: '📎 مستندات المرشح', children: [
        Row(children: [
          Ava.of(w, size: 64, forCompany: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Mut('ظهرت الصورة والاسم الكامل بعد قبول المقابلة'),
            ]),
          ),
        ]),
        Wrap(children: badges(w)),
        for (final d in [w.degree, w.union, ...w.certs].whereType<Doc>())
          Item(children: [
            Row(children: [
              Expanded(child: Text('📄 ${d.title}')),
              Pill(docLabel(d.status), kind: docKind(d.status)),
            ]),
          ]),
        if (w.degree == null && w.union == null && w.certs.isEmpty) const Mut('ما رفع مستندات.'),
      ]);

  Widget _chatCard(Req r, bool isCo) => Box(title: '💬 المحادثة', children: [
        if (r.msgs.isEmpty) const Mut('ماكو رسائل بعد.'),
        for (final m in r.msgs)
          Align(
            alignment: (m.from == 'co') == isCo ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (m.from == 'co') == isCo ? C.soft : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.text),
                Text(fmtDateTime(m.t), style: const TextStyle(fontSize: 11, color: C.mut)),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _chat, decoration: const InputDecoration(hintText: 'اكتب رسالة…', isDense: true))),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () {
              final err = app.sendMsg(r, _chat.text, isCo);
              if (err != null) {
                toast(context, err);
              } else {
                _chat.clear();
              }
            },
            child: const Text('إرسال'),
          ),
        ]),
        const Note('🔒 ممنوع تبادل الأرقام أو الإيميلات أو الروابط أو حسابات التواصل. النظام يحجبها تلقائياً.', kind: NoteKind.lock),
      ]);
}

/// غرفة مقابلة الفيديو (عرض توضيحي). بالنسخة الحقيقية: مكالمة مشفّرة داخل التطبيق.
class VideoRoom extends StatelessWidget {
  final Req req;
  final bool isCo;
  const VideoRoom({super.key, required this.req, required this.isCo});
  @override
  Widget build(BuildContext context) {
    final w = app.workerById(req.wid);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text('🔴 مقابلة فيديو · ${req.spec}', style: const TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text('${isCo ? '👷' : '🏢'}  ${isCo ? w.firstName : req.company}',
                    style: const TextStyle(color: Colors.white, fontSize: 22)),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 120,
                height: 90,
                decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('أنت', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.mic)),
              const SizedBox(width: 12),
              IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.videocam)),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.bad),
                onPressed: () {
                  app.endCall(req);
                  Navigator.pop(context);
                },
                child: const Text('إنهاء'),
              ),
            ]),
            const Note('ℹ️ هذا عرض توضيحي. بالنسخة الحقيقية تكون مكالمة فيديو مشفّرة داخل التطبيق، بدون ما يظهر رقم أي طرف.'),
          ]),
        ),
      ),
    );
  }
}
