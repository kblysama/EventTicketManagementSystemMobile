import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerin_mobile/features/auth/session.dart';
import 'package:yerin_mobile/main.dart';

void main() {
  testWidgets('app initializes an anonymous session and shows login', (tester) async {
    await initializeDateFormatting('tr_TR');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.llfbandit.app_links/messages'), (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.llfbandit.app_links/events'), (call) async => null);
    await tester.pumpWidget(ProviderScope(overrides: [tokenStoreProvider.overrideWithValue(TokenStore(readToken: () async => null, writeToken: (_) async {}, deleteToken: () async {}))], child: const YerinApp()));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar hoş geldin.'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
