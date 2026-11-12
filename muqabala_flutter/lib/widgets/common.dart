// عناصر واجهة مشتركة بين كل الشاشات
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

/// بطاقة بيضاء بإطار
class Box extends StatelessWidget {
  final List<Widget> children;
  final String? title;
  final Color? color;
  const Box({super.key, required this.children, this.title, this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          border: Border.all(color: C.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(title!, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ),
          ...children,
        ]),
      );
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
  return (c?.verified ?? false)
      ? const Pill('✅ شركة موثّقة', kind: PillKind.ok)
      : const Pill('⏳ قيد التوثيق', kind: PillKind.warn);
}

Widget stageChip(Req r) {
  return switch (r.stage) {
    'schedule' => const Pill('📅 تحديد موعد الفيديو', kind: PillKind.warn),
    'video' => const Pill('🎥 مقابلة فيديو', kind: PillKind.warn),
    'inperson' => const Pill('🤝 مقابلة حضورية', kind: PillKind.warn),
    'hired' => const Pill('✅ تم التوظيف', kind: PillKind.ok),
    'rejected' => const Pill('غير مناسب', kind: PillKind.bad),
    'declined' => const Pill('اعتذر', kind: PillKind.bad),
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
Future<String?> takeSelfie() async {
  final x = await _picker.pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 400,
    imageQuality: 70,
  );
  if (x == null) return null;
  return base64Encode(await x.readAsBytes());
}

/// صورة الملف الشخصي من الاستوديو
Future<String?> pickPhoto() async {
  final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 320, imageQuality: 75);
  if (x == null) return null;
  return base64Encode(await x.readAsBytes());
}

/// صورة مستمسك بالكاميرا الخلفية، يرجع اسم الملف
Future<String?> shootDocument() async {
  final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1400, imageQuality: 80);
  return x?.name;
}

/// مستند (صورة أو PDF) بحد أقصى 5 ميغا. يرجع (اسم الملف، رسالة خطأ)
Future<(String?, String?)> pickDocument() async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
  );
  if (r == null || r.files.isEmpty) return (null, null);
  final f = r.files.single;
  if (f.size > 5 * 1024 * 1024) return (null, '⚠️ الملف أكبر من 5 ميغا');
  return (f.name, null);
}

/// زر بعرض كامل
class WideButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool secondary;
  final bool danger;
  const WideButton(this.text, {super.key, this.onTap, this.secondary = false, this.danger = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          width: double.infinity,
          child: secondary
              ? OutlinedButton(onPressed: onTap, child: Text(text))
              : FilledButton(
                  style: danger ? FilledButton.styleFrom(backgroundColor: C.badBg, foregroundColor: C.bad) : null,
                  onPressed: onTap,
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
