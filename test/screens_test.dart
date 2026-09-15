import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerin_mobile/core/api.dart';
import 'package:yerin_mobile/core/models.dart';
import 'package:yerin_mobile/core/theme.dart';
import 'package:yerin_mobile/core/widgets.dart';
import 'package:yerin_mobile/features/auth/screens.dart';
import 'package:yerin_mobile/features/auth/session.dart';
import 'package:yerin_mobile/features/discovery/screens.dart';
import 'package:yerin_mobile/features/orders/screens.dart';
import 'package:yerin_mobile/features/tickets/screens.dart';
import 'package:yerin_mobile/features/organizer/screens.dart';
import 'package:yerin_mobile/features/organizer/ticket_type_form.dart';
import 'package:yerin_mobile/features/admin/screens.dart';
import 'package:yerin_mobile/features/check_in/screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

final demoType = <String, dynamic>{
  'id': 1,
  'name': 'Genel Giriş',
  'price': 750,
  'capacity': 200,
  'remaining': 80,
  'sold': 120,
  'sale_status': 'on_sale',
};
final demoEvent = <String, dynamic>{
  'id': 1,
  'slug': 'kiyida-caz',
  'title': 'Kıyıda Caz',
  'description':
      'Müziğe, sahneye, yeni deneyimlere. Kendine bir an ayır. Yerin hazır.',
  'venue': 'Beykoz Kundura',
  'city': 'İstanbul',
  'starts_at': '2026-10-24T20:00:00+03:00',
  'ends_at': '2026-10-24T23:00:00+03:00',
  'status': 'published',
  'category': 'music',
  'category_label': 'Canlı Müzik',
  'event_category_id': 1,
  'starting_price': 750,
  'sold': 120,
  'capacity': 200,
  'revenue': 90000,
  'checked_in': 48,
  'organizer': {'id': 2, 'name': 'Kundura Sahne', 'email': 'sahne@example.com'},
  'ticket_types': [demoType],
};
final demoTicket = <String, dynamic>{
  'code': 'YRN-261024-A7K2',
  'status': 'unused',
  'buyer_name': 'Deniz Yılmaz',
  'ticket_type': 'Genel Giriş',
  'event': demoEvent,
  'order_number': 'YRN-1042',
};
final demoOrder = <String, dynamic>{
  'id': 42,
  'number': 'YRN-1042',
  'buyer_name': 'Deniz Yılmaz',
  'buyer_email': 'deniz@example.com',
  'quantity': 1,
  'unit_price': 750,
  'total': 750,
  'status': 'completed',
  'created_at': '2026-09-18T14:32:00+03:00',
  'event': demoEvent,
  'ticket_type': demoType,
  'tickets': [demoTicket],
};

class FixtureApi extends ApiClient {
  @override
  Future<Json> get(String path, {Map<String, dynamic>? query}) async {
    final p = Uri.parse(path).path;
    if (p == '/event-categories') {
      return {
        'data': [
          {'id': 1, 'slug': 'music', 'name': 'Müzik'},
        ],
      };
    }
    if (p == '/event-cities') {
      return {
        'data': ['İstanbul'],
      };
    }
    if (p.endsWith('/sales')) {
      return {
        'data': {
          'event': demoEvent,
          'sold': 120,
          'checked_in': 48,
          'revenue': 90000,
          'ticket_types': [demoType],
        },
      };
    }
    if (p == '/events' || p == '/organizer/events' || p == '/admin/events') {
      return {
        'data': [demoEvent],
      };
    }
    if (p == '/orders' || p == '/admin/orders') {
      return {
        'data': [demoOrder],
        'meta': {'total_sales': 750, 'sold_tickets': 1, 'orders_count': 1},
      };
    }
    if (p.startsWith('/orders/')) return {'data': demoOrder};
    if (p == '/tickets') {
      return {
        'data': [demoTicket],
      };
    }
    if (p.startsWith('/tickets/')) return {'data': demoTicket};
    return {'data': demoEvent};
  }
}

class FixtureSession extends Session {
  @override
  Future<AppUser?> build() async => const AppUser(
        id: 1,
        name: 'Deniz Yılmaz',
        email: 'deniz@example.com',
        role: Role.attendee,
      );
}

Widget framed(Widget child) => Scaffold(
      appBar: AppBar(title: const Brand()),
      body: child,
    );
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    final fonts = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    SharedPreferences.setMockInitialValues({});
  });
  final screens = <String, Widget>{
    '02-login': const AuthScreen(),
    '03-register': const AuthScreen(mode: 'register'),
    '04-forgot': const AuthScreen(mode: 'forgot'),
    '05-reset': const AuthScreen(
      mode: 'reset',
      token: 'test',
      email: 'deniz@example.com',
    ),
    '06-account': framed(const AccountScreen()),
    '07-discover': framed(const DiscoveryScreen()),
    '08-event': const EventDetailScreen(slug: 'kiyida-caz'),
    '09-checkout': const CheckoutScreen(slug: 'kiyida-caz'),
    '10-success': const OrderDetailScreen(id: 42, success: true),
    '11-tickets': framed(const TicketsScreen()),
    '12-ticket': const TicketDetailScreen(code: 'YRN-261024-A7K2'),
    '13-orders': framed(const OrdersScreen()),
    '14-order': const OrderDetailScreen(id: 42),
    '15-organizer': framed(const OrganizerEventsScreen()),
    '16-form': const EventFormScreen(slug: 'kiyida-caz'),
    '17-manage': const OrganizerEventScreen(slug: 'kiyida-caz'),
    '18-sales': const SalesScreen(slug: 'kiyida-caz'),
    '19-checkin-selection': framed(const CheckInSelectionScreen()),
    '21-admin-events': framed(const AdminEventsScreen()),
    '22-admin-orders': framed(const AdminOrdersScreen()),
    '23-admin-event': const AdminEventScreen(slug: 'kiyida-caz'),
  };
  for (final entry in screens.entries) {
    for (final largeText in [false, true]) {
      testWidgets(
        '${entry.key} ${largeText ? 'small screen large text' : 'reference viewport'} renders without overflow',
        (tester) async {
          tester.view.physicalSize = Size(largeText ? 320 : 390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                apiProvider.overrideWithValue(FixtureApi()),
                sessionProvider.overrideWith(FixtureSession.new),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: yerinTheme(),
                locale: const Locale('tr', 'TR'),
                supportedLocales: const [Locale('tr', 'TR')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(largeText ? 1.6 : 1),
                  ),
                  child: child!,
                ),
                home: entry.value,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (!largeText) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/${entry.key}.png'),
            );
          }
        },
      );
    }
  }
  test('check-in gate blocks duplicate frames until explicit reset', () {
    final gate = ScanGate();
    expect(gate.acquire(''), false);
    expect(gate.acquire('QR-A'), true);
    expect(gate.acquire('QR-B'), false);
    gate.reset();
    expect(gate.acquire('QR-B'), true);
  });
  test('ticket price and capacity require valid integer TL and quantities', () {
    expect(nonNegativeInteger('750'), null);
    expect(nonNegativeInteger('7.5'), isNotNull);
    expect(nonNegativeInteger('-1'), isNotNull);
    expect(positiveInteger('0'), isNotNull);
  });
}
