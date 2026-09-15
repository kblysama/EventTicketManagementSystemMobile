import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yerin_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android/iOS starts and renders login and discovery', (tester) async {
    await app.main();
    for (var i = 0; i < 80 && find.text('Tekrar hoş geldin.').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Tekrar hoş geldin.'), findsOneWidget);
    final discover = find.text('Etkinlikleri keşfet');
    await tester.ensureVisible(discover);
    await tester.tap(discover);
    for (var i = 0; i < 80 && find.text('Bugün nerede\nolmak istersin?').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Bugün nerede\nolmak istersin?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
