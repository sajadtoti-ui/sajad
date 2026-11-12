// عناصر واجهة مشتركة بين كل الشاشات
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/characters.dart';
import '../data/models.dart';
import '../data/store.dart';

class C {
  static const pri = Color(0xFF0F766E);
  static const pri2 = Color(0xFF115E59);
  static const soft = Color(0xFFE6F4F2);
  static const amber = Color(0xFFF59E0B);
  static const ink = Color(0xFF14212B);
  static const mut = Color(0xFF5F6F7A);
  static const line = Color(0xFFE3E8EC);
  static const bg = Color(0xFFF4F6F8);
  static const ok = Color(0xFF15803D);
  static const okBg = Color(0xFFDCFCE7);
  static const warn = Color(0xFFB45309);
  static const warnBg = Color(0xFFFEF3C7);
  static const bad = Color(0xFFB91C1C);
  static const badBg = Color(0xFFFEE2E2);
  static const infoBg = Color(0xFFF0F7FF);
  static const info = Color(0xFF1E3A8A);
  static const lockBg = Color(0xFFF6F2FF);
  static const lock = Color(0xFF4C1D95);
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

enum PillKind { normal, ok, warn, bad }

class Pill extends StatelessWidget {
  final String text;
  final PillKind kind;
  const Pill(this.text, {super.key, this.kind = PillKind.normal});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      PillKind.ok => (C.okBg, C.ok),
      PillKind.warn => (C.warnBg, C.warn),
      PillKind.bad => (C.badBg, C.bad),
      PillKind.normal => (C.soft, C.pri2),
    };
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

PillKind docKind(String s) =>
    s == 'verified' ? PillKind.ok : s == 'rejected' ? PillKind.bad : PillKind.warn;
String docLabel(String s) =>
    s == 'verified' ? '✅ موثّقة' : s == 'rejected' ? 'مرفوضة' : '⏳ قيد المراجعة';

/// انتقال ناعم بين الشاشات: تلاشي ويه انزلاق خفيف
class SoftTransitions extends PageTransitionsBuilder {
  const SoftTransitions();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }
}

/// العنصر يظهر بتلاشي وصعود بسيط أول ما ينرسم
class FadeIn extends StatelessWidget {
  final Widget child;
  final int ms;
  const FadeIn({super.key, required this.child, this.ms = 380});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: c),
        ),
        child: child,
      );
}

/// يصغر شوية وقت الضغط حتى يحس المستخدم إن الزر استجاب
class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Press({super.key, required this.child, this.onTap});
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      );
}

void openPage(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));

/// صورة المساعد (غنى أو يمان) بدائرة
class AssistantFace extends StatelessWidget {
  final String who;
  final double size;
  const AssistantFace(this.who, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: ClipOval(child: SvgPicture.string(assistantSvg(who), fit: BoxFit.cover)),
      );
}

/// نجوم التقييم للعرض
class Stars extends StatelessWidget {
  final double value;
  final double size;
  const Stars(this.value, {super.key, this.size = 16});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(value >= i ? Icons.star_rounded : value >= i - .5 ? Icons.star_half_rounded : Icons.star_outline_rounded,
              color: C.amber, size: size),
      ]);
}

/// اختيار عدد النجوم
class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const StarPicker({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(value >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                  key: ValueKey(value >= i), color: C.amber, size: 34),
            ),
          ),
      ]);
}

/// بطاقة بيضاء بإطار
class Box extends StatelessWidget {
  final List<Widget> children;
  final String? title;
  final Color? color;
  const Box({super.key, required this.children, this.title, this.color});
  @override
  Widget build(BuildContext context) => FadeIn(child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          border: Border.all(color: C.line),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(title!, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ),
          ...children,
        ]),
      ));
}

/// عنصر داخل بطاقة
class Item extends StatelessWidget {
  final List<Widget> children;
  final Color? color;
  const Item({super.key, required this.children, this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: C.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

enum NoteKind { info, lock, warn }

class Note extends StatelessWidget {
  final String text;
  final NoteKind kind;
  const Note(this.text, {super.key, this.kind = NoteKind.info});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      NoteKind.info => (C.infoBg, C.info),
      NoteKind.lock => (C.lockBg, C.lock),
      NoteKind.warn => (C.warnBg, const Color(0xFF7C2D12)),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 14)),
    );
  }
}

class Mut extends StatelessWidget {
  final String text;
  const Mut(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: C.mut, fontSize: 14));
}

class H3 extends StatelessWidget {
  final String text;
  const H3(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

class Big extends StatelessWidget {
  final String text;
  final Color color;
  const Big(this.text, {super.key, this.color = C.pri2});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color));
}

/// صورة الشخص: تظهر الصورة، أو 🔒 للشركة قبل قبول المقابلة
class Ava extends StatelessWidget {
  final String? photo;
  final String gender;
  final double size;
  final bool locked;
  const Ava({super.key, this.photo, this.gender = 'ذكر', this.size = 44, this.locked = false});
  factory Ava.of(Worker w, {double size = 44, bool locked = false, bool forCompany = false}) =>
      Ava(
        photo: (forCompany && w.hidePhoto) ? null : w.photo,
        gender: w.gender,
        size: size,
        locked: locked,
      );
  @override
  Widget build(BuildContext context) {
    final img = (!locked && photo != null) ? MemoryImage(base64Decode(photo!)) : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: C.soft,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: C.line, spreadRadius: 1)],
        image: img != null ? DecorationImage(image: img, fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: img != null
          ? null
          : Text(locked ? '🔒' : (gender == 'أنثى' ? '👩' : '👨'),
              style: TextStyle(fontSize: size * (locked ? .42 : .5))),
    );
  }
}

List<Widget> badges(Worker w) => [
      if (w.idVerified) const Pill('🤳 هوية متحقق منها', kind: PillKind.ok),
      if (w.union?.status == 'verified') const Pill('✅ موثّق نقابياً', kind: PillKind.ok),
      if (w.degree?.status == 'verified') const Pill('🎓 شهادة موثّقة', kind: PillKind.ok),
      if (app.active(w)) const Pill('🔥 نشِط', kind: PillKind.warn),
    ];

Widget coBadge(String name) {
  final c = app.companyByName(name);
  final b = (c?.verified ?? false)
      ? const Pill('✅ شركة موثّقة', kind: PillKind.ok)
      : const Pill('⏳ قيد التوثيق', kind: PillKind.warn);
  if ((c?.noShows ?? 0) == 0) return b;
  return Wrap(children: [b, Pill('⚠️ ما حضرت ${c!.noShows} مقابلة · التزام ${app.coScore(name).toStringAsFixed(1)}/5', kind: PillKind.bad)]);
}

Widget stageChip(Req r) {
  return switch (r.stage) {
    'schedule' => const Pill('📅 تحديد موعد الفيديو', kind: PillKind.warn),
    'video' => const Pill('🎥 مقابلة فيديو', kind: PillKind.warn),
    'inperson' => const Pill('🤝 مقابلة حضورية', kind: PillKind.warn),
    'hired' => const Pill('✅ تم التوظيف', kind: PillKind.ok),
    'rejected' => const Pill('غير مناسب', kind: PillKind.bad),
    'declined' => const Pill('اعتذر', kind: PillKind.bad),
    'expired' => const Pill('⌛ انتهى بدون رد', kind: PillKind.bad),
    _ => const Pill('⏳ بانتظار رد المرشح'),
  };
}

String fmtDate(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  const m = ['كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول',
    'تشرين الأول', 'تشرين الثاني', 'كانون الأول'];
  return '${d.day} ${m[d.month - 1]}';
}

String fmtDateTime(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '${fmtDate(t)} · $h:$mm ${d.hour < 12 ? 'ص' : 'م'}';
}

// ───────────── التقاط الصور والملفات ─────────────
final _picker = ImagePicker();

/// صورة حية من الكاميرا الأمامية (مو من الاستوديو)
/// رسالة خطأ واضحة بالعراقي بدل «حدث خطأ»
String lastError = '';
const kCamError = 'ما گدرنا نفتح الكاميرا. افتح إعدادات التلفون ← التطبيقات ← مقابلة ← الأذونات، واسمح بالكاميرا.';
const kFileError = 'ما گدرنا نفتح الملف. تأكد إنه صورة أو PDF، وجرّب تختاره مرة ثانية.';

Future<String?> takeSelfie() async {
  try {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 400,
      imageQuality: 70,
    );
    if (x == null) return null;
    return base64Encode(await x.readAsBytes());
  } catch (_) {
    lastError = kCamError;
    return null;
  }
}

/// صورة الملف الشخصي من الاستوديو
Future<String?> pickPhoto() async {
  try {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 320, imageQuality: 75);
    if (x == null) return null;
    return base64Encode(await x.readAsBytes());
  } catch (_) {
    lastError = 'ما گدرنا نفتح الصور. اسمح للتطبيق يوصل للصور من إعدادات التلفون.';
    return null;
  }
}

/// يعرض آخر خطأ صار (إذا موجود) ويصفّره
void showLastError(BuildContext context) {
  if (lastError.isEmpty) return;
  toast(context, '⚠️ $lastError');
  lastError = '';
}

/// يحفظ نسخة من الملف داخل مجلد التطبيق، ويرجع مكانها
Future<String> saveDocBytes(Uint8List bytes, String name) async {
  final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/docs');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final safe = name.replaceAll(RegExp(r'[^\w\.\-؀-ۿ]'), '_');
  final f = File('${dir.path}/${now()}_$safe');
  await f.writeAsBytes(bytes);
  return f.path;
}

/// صورة مستمسك بالكاميرا الخلفية. يرجع (اسم الملف، مكانه)
Future<(String, String)?> shootDocument() async {
  try {
    final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
    if (x == null) return null;
    return (x.name, await saveDocBytes(await x.readAsBytes(), x.name));
  } catch (_) {
    lastError = kCamError;
    return null;
  }
}

/// مستند (صورة أو PDF) بحد أقصى 5 ميغا. يرجع (اسم الملف، مكانه، رسالة خطأ)
Future<(String?, String?, String?)> pickDocument() async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (files.isEmpty) return (null, null, null);
    final f = files.first;
    final size = await f.length() ?? 0;
    if (size > 5 * 1024 * 1024) {
      return (null, null, '⚠️ الملف حجمه ${(size / 1048576).toStringAsFixed(1)} ميغا، والحد 5 ميغا. صوّره بدقة أقل أو اضغط الـPDF وجرّب مرة ثانية.');
    }
    final bytes = await f.readAsBytes();
    return (f.name, await saveDocBytes(bytes, f.name), null);
  } catch (_) {
    return (null, null, '⚠️ $kFileError');
  }
}

/// يفتح المستند: الصورة بتكبير وتصغير، والـPDF بعارض داخل التطبيق
void openDoc(BuildContext context, Doc d) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => DocViewer(doc: d)));
}

class DocViewer extends StatelessWidget {
  final Doc doc;
  const DocViewer({super.key, required this.doc});
  @override
  Widget build(BuildContext context) {
    final p = doc.path;
    final exists = p != null && File(p).existsSync();
    Widget body;
    if (!exists) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('📄 هذا مستند تجريبي بدون ملف حقيقي.\nالمستندات اللي ترفعها من التطبيق تنفتح هنا.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: C.mut)),
        ),
      );
    } else if (doc.isPdf) {
      body = PdfViewer.file(p);
    } else {
      body = InteractiveViewer(minScale: 1, maxScale: 6, child: Center(child: Image.file(File(p))));
    }
    return Scaffold(
      backgroundColor: exists && !doc.isPdf ? Colors.black : null,
      appBar: AppBar(title: Text(doc.title, overflow: TextOverflow.ellipsis)),
      body: SafeArea(child: body),
    );
  }
}

/// صورة مصغرة للمستند، تنفتح بالضغط
class DocThumb extends StatelessWidget {
  final Doc doc;
  final double size;
  const DocThumb({super.key, required this.doc, this.size = 64});
  @override
  Widget build(BuildContext context) {
    final p = doc.path;
    final img = p != null && !doc.isPdf && File(p).existsSync();
    return InkWell(
      onTap: () => openDoc(context, doc),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: C.soft,
          border: Border.all(color: C.line),
          borderRadius: BorderRadius.circular(10),
          image: img ? DecorationImage(image: FileImage(File(p)), fit: BoxFit.cover) : null,
        ),
        alignment: Alignment.center,
        child: img ? null : Text(doc.isPdf ? 'PDF' : '📄', style: const TextStyle(fontWeight: FontWeight.w800, color: C.pri2)),
      ),
    );
  }
}

/// سطر مستند: صورة مصغرة + الاسم + الحالة + زر عرض
class DocTile extends StatelessWidget {
  final String label;
  final Doc doc;
  final List<Widget> actions;
  const DocTile({super.key, required this.label, required this.doc, this.actions = const []});
  @override
  Widget build(BuildContext context) => Item(children: [
        Row(children: [
          DocThumb(doc: doc, size: 56),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 13, color: C.mut)),
              Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Pill(docLabel(doc.status), kind: docKind(doc.status)),
            ]),
          ),
          TextButton(onPressed: () => openDoc(context, doc), child: const Text('👁️ عرض')),
        ]),
        if (doc.status == 'rejected' && doc.note.isNotEmpty) Mut('سبب الرفض: ${doc.note}'),
        ...actions,
      ]);
}

/// زر بعرض كامل
class WideButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool secondary;
  final bool danger;
  const WideButton(this.text, {super.key, this.onTap, this.secondary = false, this.danger = false});
  VoidCallback? get _tap => onTap == null
      ? null
      : () {
          HapticFeedback.lightImpact();
          onTap!();
        };
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          width: double.infinity,
          child: secondary
              ? OutlinedButton(onPressed: _tap, child: Text(text))
              : FilledButton(
                  style: danger ? FilledButton.styleFrom(backgroundColor: C.badBg, foregroundColor: C.bad) : null,
                  onPressed: _tap,
                  child: Text(text),
                ),
        ),
      );
}

/// قائمة منسدلة بسيطة
class Drop extends StatelessWidget {
  final String label;
  final String value;
  final List<(String, String)> items; // (القيمة، النص)
  final ValueChanged<String> onChanged;
  const Drop({super.key, required this.label, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final v = items.any((e) => e.$1 == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label|${items.map((e) => e.$1).join(',')}|$v'),
        // ignore: deprecated_member_use
        value: v,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final (val, txt) in items) DropdownMenuItem(value: val, child: Text(txt))],
        onChanged: (x) => onChanged(x ?? ''),
      ),
    );
  }
}

List<(String, String)> same(Iterable<String> xs) => [for (final x in xs) (x, x)];
