// شاشات مساعدة: الإشعارات، الإعدادات، سياسة الخصوصية والشروط، والدعم «كلّم شخص»
import 'package:flutter/material.dart';

import '../data/characters.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import 'assistant.dart';
import 'interview.dart';

// ───────────── الإشعارات ─────────────
class NotifScreen extends StatefulWidget {
  const NotifScreen({super.key});
  @override
  State<NotifScreen> createState() => _NotifScreenState();
}

class _NotifScreenState extends State<NotifScreen> {
  late final Set<int> _unreadAtOpen = {for (final n in app.myNotifs.where((n) => !n.read)) n.t};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => app.readAll());
  }

  @override
  Widget build(BuildContext context) {
    final list = app.myNotifs;
    return Scaffold(
      appBar: AppBar(title: const Text('🔔 الإشعارات')),
      body: SafeArea(
        child: list.isEmpty
            ? const Center(child: Mut('ماكو إشعارات بعد'))
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = list[i];
                  final isNew = _unreadAtOpen.contains(n.t);
                  final canOpen = n.reqId != null && app.requests.any((r) => r.id == n.reqId);
                  return FadeIn(
                    ms: 200 + i * 40,
                    child: Press(
                      onTap: canOpen ? () => openPage(context, InterviewScreen(reqId: n.reqId!)) : null,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isNew ? C.soft : Colors.white,
                          border: Border.all(color: isNew ? C.pri : C.line),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.text, style: TextStyle(fontWeight: isNew ? FontWeight.w700 : FontWeight.w400)),
                              Text(fmtDateTime(n.t), style: const TextStyle(fontSize: 12, color: C.mut)),
                            ]),
                          ),
                          if (canOpen) const Icon(Icons.chevron_left, color: C.mut),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// جرس الإشعارات بالشريط العلوي ويه عدد غير المقروءة
class NotifBell extends StatelessWidget {
  const NotifBell({super.key});
  @override
  Widget build(BuildContext context) {
    final n = app.unread;
    return IconButton(
      tooltip: 'الإشعارات',
      onPressed: () => openPage(context, const NotifScreen()),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

// ───────────── الإعدادات ─────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _delete(BuildContext context) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('حذف الحساب نهائياً'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('راح تنحذف كل معلوماتك ومستنداتك ومقابلاتك ومحادثاتك، وما تكدر ترجعها.'),
            const SizedBox(height: 10),
            const Text('حتى تأكد، اكتب كلمة: حذف', style: TextStyle(fontWeight: FontWeight.w700)),
            TextField(controller: ctl, onChanged: (_) => set(() {})),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.bad),
              onPressed: ctl.text.trim() == 'حذف' ? () => Navigator.pop(ctx, true) : null,
              child: const Text('احذف حسابي'),
            ),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (ok != true || !context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    app.deleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final a = app.acct;
        if (a == null) return const Scaffold();
        final isCo = a.role == 'company';
        return Scaffold(
          appBar: AppBar(title: const Text('⚙️ الإعدادات')),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(14), children: [
              Box(title: 'حسابي', children: [
                Text(app.myName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Mut('📱 ${a.phone}'),
              ]),
              if (isCo && app.comp != null)
                Box(title: '🤖 مساعد الشركة', children: [
                  Row(children: [
                    AssistantFace(app.assistant.isEmpty ? 'ghina' : app.assistant, size: 54),
                    const SizedBox(width: 12),
                    Expanded(child: Text(app.assistant.isEmpty ? 'لسه ما اخترتوا مساعد' : 'المساعد الحالي: ${assistantName(app.assistant)}')),
                  ]),
                  WideButton('🔄 غيّر المساعد', secondary: true, onTap: () => chooseAssistant(context)),
                ]),
              Box(title: 'المساعدة', children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.support_agent),
                  title: const Text('كلّم شخص من فريق مقابلة'),
                  subtitle: const Text('نرد خلال 24 ساعة'),
                  onTap: () => openPage(context, const SupportScreen()),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('سياسة الخصوصية وشروط الاستخدام'),
                  onTap: () => openPage(context, const PrivacyScreen()),
                ),
              ]),
              if (a.role != 'hr')
                Box(title: 'منطقة الخطر', children: [
                  const Mut('حذف الحساب يمسح كل بياناتك من التطبيق نهائياً.'),
                  WideButton('🗑️ احذف حسابي وبياناتي', danger: true, onTap: () => _delete(context)),
                ]),
            ]),
          ),
        );
      },
    );
  }
}

// ───────────── سياسة الخصوصية وشروط الاستخدام ─────────────
const List<(String, List<String>)> kPolicy = [
  ('شنو نجمع', [
    'رقم الهاتف وكلمة المرور (مشفّرة).',
    'معلوماتك المهنية: الاسم، الجنس، العمر، المنطقة، التخصص، الخبرة، الشهادات، اللغات، ونص «عرّف بنفسك».',
    'صورة حية للتحقق من الهوية، وتنحذف مباشرة بعد التحقق.',
    'للشركات: صور البطاقة الوطنية وصورة حية للمسؤول، وتنحذف بعد التوثيق.',
  ]),
  ('منو يشوف معلوماتك', [
    'رقمك ما يطلع لأي شركة أو مستخدم أبداً.',
    'الشركة تشوف اسمك المختصر ومنطقتك ودرجتك. الصورة والمستندات تظهر بس بعد ما تقبل المقابلة.',
    'العنوان التفصيلي ما يظهر لأحد.',
    'الذكاء الاصطناعي يستلم إجابات الامتحان ونص «عرّف بنفسك» بدون اسمك أو رقمك.',
  ]),
  ('المحادثات والمراجعة', [
    'المحادثات بين الشركات والمرشحين قابلة للمراجعة من إدارة مقابلة لحمايتك ومنع الاحتيال.',
    'كل مرة يفتح موظف من الإدارة محادثة أو ملف، ينسجل اسمه والوقت، ويوصلك إشعار.',
    'ممنوع تبادل الأرقام أو الحسابات أو الروابط، والنظام يحجبها تلقائياً.',
  ]),
  ('حقوقك', [
    'تكدر تعدّل معلوماتك بأي وقت.',
    'تكدر تحذف حسابك وكل بياناتك من الإعدادات، والحذف نهائي.',
    'تكدر تكلّم فريق مقابلة من «كلّم شخص» ونرد خلال 24 ساعة.',
  ]),
  ('شروط الاستخدام', [
    'التسجيل للأعمار 18 سنة وفوق.',
    'لازم تكون المعلومات والمستندات حقيقية وتخصك. المستند المزور يسبب حذف الحساب.',
    'ماكو أي وظيفة حقيقية تطلب منك فلوس. إذا أحد طلب فلوس، بلّغنا فوراً.',
    'الشركة اللي ما تحضر مقابلة حددتها ينزل تقييم التزامها.',
    'ماكو إعلانات داخل التطبيق.',
  ]),
];

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الخصوصية وشروط الاستخدام')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(14), children: [
            for (final (h, items) in kPolicy)
              Box(title: h, children: [
                for (final t in items)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• $t', style: const TextStyle(height: 1.5))),
              ]),
            const Center(child: Mut('آخر تحديث: تشرين الثاني 2026')),
            const SizedBox(height: 20),
          ]),
        ),
      );
}

// ───────────── الدعم «كلّم شخص» ─────────────
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final mine = app.myTickets;
          return Scaffold(
            appBar: AppBar(title: const Text('🆘 كلّم شخص')),
            body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(14), children: [
                Box(title: 'اكتب مشكلتك أو سؤالك', children: [
                  const Mut('يوصل لفريق الموارد البشرية بمقابلة، ونرد خلال 24 ساعة ويوصلك إشعار.'),
                  const SizedBox(height: 8),
                  TextField(controller: _ctl, maxLines: 4, decoration: const InputDecoration(hintText: 'مثال: رفعت شهادتي من يومين وبعدها قيد المراجعة…')),
                  WideButton('إرسال', onTap: () {
                    final err = app.sendTicket(_ctl.text);
                    if (err != null) return toast(context, '⚠️ $err');
                    _ctl.clear();
                    FocusScope.of(context).unfocus();
                    toast(context, '✓ وصلت رسالتك، نرد خلال 24 ساعة');
                  }),
                ]),
                if (mine.isNotEmpty)
                  Box(title: 'رسائلي', children: [
                    for (final t in mine)
                      Item(children: [
                        Text(t.text),
                        Mut(fmtDateTime(t.t)),
                        const SizedBox(height: 6),
                        if (t.open)
                          const Pill('⏳ بانتظار الرد', kind: PillKind.warn)
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(10)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('رد فريق مقابلة:', style: TextStyle(fontWeight: FontWeight.w700, color: C.pri2)),
                              Text(t.reply),
                              Mut(fmtDateTime(t.replyT!)),
                            ]),
                          ),
                      ]),
                  ]),
              ]),
            ),
          );
        },
      );
}
