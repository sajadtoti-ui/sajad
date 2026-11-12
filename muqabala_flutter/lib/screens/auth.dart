// تسجيل الدخول وإنشاء حساب (باحث عن عمل أو شركة)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/logo.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import 'more.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signup = false;
  String _role = '';
  bool _otpSent = false, _verified = false, _agree = false;
  String _channel = 'واتساب';
  int _wait = 0; // ثواني لحد ما ينفتح «أعد الإرسال»
  Timer? _timer;
  final _code2fa = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _otp = TextEditingController();

  @override
  void dispose() {
    for (final c in [_phone, _pass, _pass2, _otp, _code2fa]) {
      c.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _reset(bool signup) => setState(() {
        _signup = signup;
        _role = '';
        _otpSent = _verified = _agree = false;
        _timer?.cancel();
        _wait = 0;
        _phone.clear();
        _pass.clear();
        _pass2.clear();
        _otp.clear();
      });

  void _login() {
    final err = app.login(_phone.text, _pass.text);
    if (err != null) toast(context, err);
  }

  void _sendOtp([String? channel]) {
    final p = _phone.text.trim().replaceAll(' ', '');
    if (!RegExp(r'^07\d{9}$').hasMatch(p)) {
      return toast(context, 'الرقم لازم يبدأ بـ 07 ويكون 11 رقم، مثل 07701234567');
    }
    if (app.phoneTaken(p)) return toast(context, 'هذا الرقم عنده حساب من قبل. ارجع لشاشة الدخول وسجّل دخول');
    if (channel != null) _channel = channel;
    _timer?.cancel();
    setState(() {
      _otpSent = true;
      _wait = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
    toast(context, '📱 انرسل الرمز على $_channel (للتجربة: 1234)');
  }

  void _verify() {
    if (_otp.text.trim() != '1234') return toast(context, 'الرمز غلط. تأكد من آخر رسالة وصلتك، أو اطلب رمز جديد');
    setState(() => _verified = true);
    toast(context, '✓ تم تأكيد الرقم');
  }

  void _create() {
    if (_role.isEmpty) return toast(context, 'اختار نوع الحساب: باحث عن عمل لو شركة');
    if (!_agree) return toast(context, 'لازم توافق على شروط الاستخدام وسياسة الخصوصية');
    if (!_verified) return toast(context, 'أكّد رقم الهاتف أولاً');
    if (_pass.text.length < 6) return toast(context, 'كلمة المرور لازم 6 أحرف أو أكثر');
    if (_pass.text != _pass2.text) return toast(context, 'كلمتا المرور غير متطابقتين');
    app.signup(_phone.text.trim(), _pass.text, _role);
  }

  Widget _roleCard(String role, String title, String sub) {
    final sel = _role == role;
    return InkWell(
      onTap: () => setState(() => _role = role),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? C.soft : Colors.white,
          border: Border.all(color: sel ? C.pri : const Color(0xFFCFD8DE), width: sel ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Mut(sub),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (app.pending2fa != null) return _twoFactor();
    return ListView(padding: const EdgeInsets.all(14), children: [
      const SizedBox(height: 4),
      Center(child: SvgPicture.string(kLogoFull, width: 220)),
      const Center(
        child: Text('مقـــابـلـــة', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: C.pri)),
      ),
      const SizedBox(height: 10),
      if (!_signup) ..._loginView() else ..._signupView(),
    ]);
  }

  List<Widget> _loginView() => [
        Box(title: '👋 أهلاً بك في «مقابلة»', children: [
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '07XXXXXXXXX')),
          const SizedBox(height: 10),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
          WideButton('دخول', onTap: _login),
          WideButton('ما عندي حساب، أريد أسجّل', secondary: true, onTap: () => _reset(true)),
        ]),
        Box(title: '🧪 حسابات للتجربة', children: const [
          Mut('كلمة المرور لكل الحسابات: 123456'),
          SizedBox(height: 6),
          Text('👷 موظف: 07701111111'),
          Text('🏢 شركة: 07900000000'),
          Text('🧑‍💼 موارد بشرية (مدير): 07000000000'),
          Text('🧑‍💼 موارد بشرية (مراجع): 07000000001'),
          Text('🧑‍💼 موارد بشرية (دعم): 07000000002'),
          Mut('رمز التحقق بخطوتين للموارد البشرية: 4321'),
        ]),
        Center(
          child: TextButton(
            onPressed: () async {
              await app.resetAll();
              if (mounted) toast(context, '✓ رجعت البيانات التجريبية');
            },
            child: const Text('إعادة البيانات التجريبية'),
          ),
        ),
      ];

  /// الخطوة الثانية لدخول الموارد البشرية
  Widget _twoFactor() => ListView(padding: const EdgeInsets.all(14), children: [
        const SizedBox(height: 20),
        Box(title: '🔐 تحقق بخطوتين', children: [
          const Mut('حسابات الموارد البشرية محمية بخطوتين. انرسل رمز على واتساب الرقم المسجّل.'),
          const SizedBox(height: 10),
          TextField(controller: _code2fa, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: 'الرمز (للتجربة: 4321)')),
          WideButton('دخول', onTap: () {
            final err = app.verify2fa(_code2fa.text);
            if (err != null) toast(context, err);
            _code2fa.clear();
          }),
          WideButton('رجوع', secondary: true, onTap: app.cancel2fa),
        ]),
      ]);

  List<Widget> _signupView() => [
        Box(title: '🆕 حساب جديد', children: [
          const Mut('نوع الحساب ينحدد من البداية، وكل نوع يشوف شاشته بس.'),
          _roleCard('worker', '👷 باحث عن عمل', 'أسجّل معلوماتي وأمتحن وتوصلني طلبات مقابلة'),
          _roleCard('company', '🏢 شركة / صاحب عمل', 'أبحث عن موظفين وأرسل طلبات مقابلة'),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            enabled: !_verified,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '07XXXXXXXXX'),
          ),
          if (!_otpSent) WideButton('إرسال رمز التحقق على واتساب', secondary: true, onTap: () => _sendOtp('واتساب')),
          if (_otpSent && !_verified) ...[
            const SizedBox(height: 10),
            Mut('انرسل الرمز على $_channel إلى ${_phone.text.trim()}'),
            const SizedBox(height: 6),
            TextField(controller: _otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رمز التحقق')),
            WideButton('تأكيد الرمز', secondary: true, onTap: _verify),
            const SizedBox(height: 6),
            if (_wait > 0)
              Center(child: Mut('ما وصلك؟ تكدر تطلب رمز جديد بعد $_wait ثانية'))
            else ...[
              const Center(child: Mut('ما وصلك الرمز؟ اختار طريقة ثانية:')),
              Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
                ActionChip(avatar: const Icon(Icons.chat, size: 18), label: const Text('واتساب مرة ثانية'), onPressed: () => _sendOtp('واتساب')),
                ActionChip(avatar: const Icon(Icons.sms, size: 18), label: const Text('رسالة SMS'), onPressed: () => _sendOtp('رسالة SMS')),
                ActionChip(avatar: const Icon(Icons.call, size: 18), label: const Text('مكالمة صوتية'), onPressed: () => _sendOtp('مكالمة صوتية')),
              ]),
            ],
          ],
          if (_verified) const Padding(padding: EdgeInsets.only(top: 6), child: Pill('✓ الرقم مؤكد', kind: PillKind.ok)),
          const SizedBox(height: 10),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور (6 أحرف أو أكثر)')),
          const SizedBox(height: 10),
          TextField(controller: _pass2, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            title: const Text('أوافق على شروط الاستخدام وسياسة الخصوصية'),
            subtitle: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () => openPage(context, const PrivacyScreen()),
                child: const Text('اقرأها هنا'),
              ),
            ),
          ),
          WideButton('إنشاء الحساب', onTap: _create),
          WideButton('عندي حساب، رجوع للدخول', secondary: true, onTap: () => _reset(false)),
          const Note('🔒 كلمة المرور تنحفظ مشفّرة، والحساب يتقفل مؤقتاً بعد 5 محاولات فاشلة.', kind: NoteKind.lock),
        ]),
      ];
}
