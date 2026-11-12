// تسجيل الدخول وإنشاء حساب (باحث عن عمل أو شركة)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/logo.dart';
import '../data/store.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signup = false;
  String _role = '';
  bool _otpSent = false, _verified = false;
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _otp = TextEditingController();

  @override
  void dispose() {
    for (final c in [_phone, _pass, _pass2, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  void _reset(bool signup) => setState(() {
        _signup = signup;
        _role = '';
        _otpSent = _verified = false;
        _phone.clear();
        _pass.clear();
        _pass2.clear();
        _otp.clear();
      });

  void _login() {
    final err = app.login(_phone.text, _pass.text);
    if (err != null) toast(context, err);
  }

  void _sendOtp() {
    final p = _phone.text.trim();
    if (!RegExp(r'^07\d{9}$').hasMatch(p)) {
      return toast(context, 'اكتب رقم عراقي صحيح يبدأ بـ 07 ومن 11 رقم');
    }
    if (app.phoneTaken(p)) return toast(context, 'هذا الرقم عنده حساب، سجّل دخول');
    setState(() => _otpSent = true);
    toast(context, '📱 تم إرسال الرمز (للتجربة: 1234)');
  }

  void _verify() {
    if (_otp.text.trim() != '1234') return toast(context, 'الرمز غير صحيح');
    setState(() => _verified = true);
    toast(context, '✓ تم تأكيد الرقم');
  }

  void _create() {
    if (_role.isEmpty) return toast(context, 'اختار نوع الحساب: باحث عن عمل لو شركة');
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
          Text('🧑‍💼 موارد بشرية: 07000000000'),
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
          if (!_otpSent) WideButton('إرسال رمز التحقق', secondary: true, onTap: _sendOtp),
          if (_otpSent && !_verified) ...[
            const SizedBox(height: 10),
            TextField(controller: _otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رمز التحقق')),
            WideButton('تأكيد الرمز', secondary: true, onTap: _verify),
          ],
          if (_verified) const Padding(padding: EdgeInsets.only(top: 6), child: Pill('✓ الرقم مؤكد', kind: PillKind.ok)),
          const SizedBox(height: 10),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور (6 أحرف أو أكثر)')),
          const SizedBox(height: 10),
          TextField(controller: _pass2, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
          WideButton('إنشاء الحساب', onTap: _create),
          WideButton('عندي حساب، رجوع للدخول', secondary: true, onTap: () => _reset(false)),
          const Note('🔒 كلمة المرور تنحفظ مشفّرة، والحساب يتقفل مؤقتاً بعد 5 محاولات فاشلة.', kind: NoteKind.lock),
        ]),
      ];
}
