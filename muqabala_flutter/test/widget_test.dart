import 'package:flutter_test/flutter_test.dart';
import 'package:muqabala/data/store.dart';

void main() {
  test('الكلمات المفتاحية تطلع من النص بدون أرقام', () {
    final kw = app.extractKW('أشتغل بالطاقة الشمسية وتأسيس البيوت 07701234567');
    expect(kw, contains('طاقة'));
    expect(kw.any((k) => k.contains('0')), isFalse);
  });

  test('كشف محاولات تبادل الأرقام', () {
    expect(app.hasContact('هذا رقمي ٠٧٧٠١٢٣٤٥٦٧'), isTrue);
    expect(app.hasContact('أكدر أشتغل شفتات ليلية'), isFalse);
  });
}
