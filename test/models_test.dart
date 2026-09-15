import 'package:flutter_test/flutter_test.dart';
import 'package:yerin_mobile/core/config.dart';
import 'package:yerin_mobile/core/models.dart';

void main() {
  test('cover URLs on localhost are rewritten to the API host', () {
    final event = Event.fromJson({
      'cover_url': 'http://127.0.0.1:8000/storage/covers/demo.webp',
    });
    final api = Uri.parse(AppConfig.apiUrl);
    expect(
      event.coverUrl,
      'http://${api.host}:${api.port}/storage/covers/demo.webp',
    );
    expect(
      AppConfig.resolveMediaUrl('https://cdn.example/cover.webp'),
      'https://cdn.example/cover.webp',
    );
  });
  test('tickets from the same purchase collapse into one list card', () {
    Ticket ticket(String code) => Ticket.fromJson({
          'code': code,
          'status': 'unused',
          'order_number': 'YRN-100',
          'ticket_type': 'Genel',
          'event': {
            'title': 'Ağrı Dağı',
            'ends_at': '2026-10-24T23:00:00+03:00',
            'starts_at': '2026-10-24T20:00:00+03:00',
          },
        });
    final groups = TicketPurchase.group([
      ticket('A'),
      ticket('C'),
      ticket('B'),
      Ticket.fromJson({
        'code': 'SOLO',
        'status': 'unused',
        'order_number': 'YRN-101',
        'ticket_type': 'Genel',
        'event': {'title': 'Yoga', 'ends_at': '2026-11-01T12:00:00+03:00'},
      }),
    ]);
    expect(groups, hasLength(2));
    expect(groups.first.quantity, 3);
    expect(groups.first.tickets.map((t) => t.code), ['A', 'B', 'C']);
    expect(groups.last.quantity, 1);
  });
  test('API integer TL and routing identifiers preserve their meaning', () {
    final order = Order.fromJson({
      'id': 42,
      'number': 'YRN-ABC',
      'total': 1500,
      'quantity': 2,
      'event': {'slug': 'kiyida-caz'},
      'tickets': [
        {'code': 'CODE-A'},
        {'code': 'CODE-B'},
      ],
    });
    expect(order.id, 42);
    expect(order.total, 1500);
    expect(order.event.slug, 'kiyida-caz');
    expect(order.ticketCodes, ['CODE-A', 'CODE-B']);
  });
  test('used tickets remain upcoming until event ends', () {
    final ticket = Ticket.fromJson({
      'code': 'QR-A',
      'status': 'used',
      'event': {'ends_at': '2026-10-24T23:00:00+03:00'},
    });
    expect(ticket.used, true);
    expect(ticket.isPast(DateTime.utc(2026, 10, 23)), false);
    expect(ticket.isPast(DateTime.utc(2026, 10, 25)), true);
  });
  test('paused or exhausted ticket types cannot be purchased', () {
    expect(
      TicketType.fromJson({'sale_status': 'paused', 'remaining': 5}).canBuy,
      false,
    );
    expect(
      TicketType.fromJson({'sale_status': 'on_sale', 'remaining': 0}).canBuy,
      false,
    );
    expect(
      TicketType.fromJson({'sale_status': 'on_sale', 'remaining': 1}).canBuy,
      true,
    );
  });
}
