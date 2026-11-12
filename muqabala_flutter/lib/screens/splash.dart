// شاشة البداية: الفقاعتين يتقاربن (تقريب وجهات النظر)، وتنزل البنايات والأشخاص، وبعدها الاسم
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/logo.dart';
import '../widgets/common.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4300));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));

  /// طبقة تنزلق من مكان وتظهر تدريجياً
  Widget _layer(String svg, Animation<double> t, Offset from) => AnimatedBuilder(
        animation: t,
        builder: (_, child) => Opacity(
          opacity: t.value.clamp(0.0, 1.0).toDouble(),
          child: FractionalTranslation(translation: from * (1 - t.value), child: child),
        ),
        child: SvgPicture.string(svg, fit: BoxFit.contain),
      );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width.clamp(0, 360).toDouble() * .86;
    final word = _iv(.62, .78);
    final tag = _iv(.72, .86);
    return GestureDetector(
      onTap: widget.onDone, // الضغط على الشاشة يتخطى الحركة
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: w,
              child: AspectRatio(
                aspectRatio: 392 / 280,
                child: Stack(fit: StackFit.expand, children: [
                  _layer(kLogoBubble1, _iv(0, .24), const Offset(-.3, -.06)),
                  _layer(kLogoBubble2, _iv(0, .24), const Offset(.3, .06)),
                  _layer(kLogoOverlap, _iv(.21, .3), Offset.zero),
                  _layer(kLogoBuildings, _iv(.25, .42, Curves.easeOutBack), const Offset(0, -.25)),
                  _layer(kLogoPeople, _iv(.42, .58, Curves.easeOutBack), const Offset(0, -.25)),
                ]),
              ),
            ),
            AnimatedBuilder(
              animation: word,
              builder: (_, child) => Opacity(
                opacity: word.value,
                child: Transform.translate(offset: Offset(0, 14 * (1 - word.value)), child: child),
              ),
              child: SizedBox(
                width: w,
                child: const FittedBox(
                  child: Text('مقـــابـلـــة',
                      style: TextStyle(fontSize: 60, fontWeight: FontWeight.w800, color: C.pri)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            FadeTransition(
              opacity: tag,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('تقريب وجهات النظر بين الباحث عن عمل والشركات',
                    textAlign: TextAlign.center, style: TextStyle(color: C.mut, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
