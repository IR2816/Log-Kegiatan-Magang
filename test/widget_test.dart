import 'package:flutter_test/flutter_test.dart';

import 'package:log_kegiatan_magang/app.dart';

void main() {
  testWidgets('menampilkan keadaan awal yang kosong', (tester) async {
    await tester.pumpWidget(const InternshipLogApp());
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Isi data magang dulu'), findsOneWidget);
    expect(find.text('Isi profil'), findsAtLeastNWidgets(1));
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('bisa berpindah ke halaman aktivitas', (tester) async {
    await tester.pumpWidget(const InternshipLogApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('Aktivitas'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Aktivitas Magang'), findsOneWidget);
    expect(find.text('Tambah aktivitas'), findsAtLeastNWidgets(1));
  });
}
