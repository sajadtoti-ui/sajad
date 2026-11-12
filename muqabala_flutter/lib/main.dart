// تطبيق «مقابلة»: يربط الباحثين عن عمل بالشركات في العراق
// النسخة 0.6 — تحويل النموذج الأولي إلى Flutter
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/logo.dart';
import 'data/store.dart';
import 'screens/auth.dart';
import 'screens/company.dart';
import 'screens/hr.dart';
import 'screens/splash.dart';
import 'screens/worker_home.dart';
import 'screens/register.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const MuqabalaApp());
}

class MuqabalaApp extends StatelessWidget {
  const MuqabalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: C.pri, primary: C.pri),
      scaffoldBackgroundColor: C.bg,
    );
    return MaterialApp(
      title: 'مقابلة',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(
        textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: const SplashGate(),
    );
  }
}

/// يعرض حركة اللوكو أول مرة، وبعدها الشاشة الرئيسية
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _done
            ? const RootScreen()
            : SplashScreen(onDone: () => setState(() => _done = true)),
      );
}

/// يختار الشاشة حسب نوع الحساب
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final a = app.acct;
        Widget body;
        String who = '';
        if (a == null) {
          body = const AuthScreen();
        } else if (a.role == 'worker') {
          final w = app.me;
          body = w == null ? const RegisterScreen() : const WorkerHome();
          who = '👷 ${w?.name ?? 'باحث عن عمل جديد'}';
        } else if (a.role == 'company') {
          final c = app.comp;
          body = c == null ? const CompanyProfileScreen() : const CompanyHome();
          who = '🏢 ${c?.name ?? 'شركة جديدة'}';
        } else {
          body = const HrScreen();
          who = '🧑‍💼 الموارد البشرية';
        }
        return Scaffold(
          appBar: AppBar(
            backgroundColor: C.pri,
            foregroundColor: Colors.white,
            titleSpacing: 12,
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: SvgPicture.string(kLogoFull, width: 38, height: 27),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('مقابلة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  if (who.isNotEmpty)
                    Text(who, style: const TextStyle(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            actions: [
              if (a != null)
                IconButton(tooltip: 'خروج', icon: const Icon(Icons.logout), onPressed: app.logout),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: body),
            ),
          ),
        );
      },
    );
  }
}
