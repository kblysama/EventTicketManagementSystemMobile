import 'config.dart';

typedef Json = Map<String, dynamic>;

Json object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Json> objects(dynamic value) =>
    value is List ? value.map(object).toList() : [];
int integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String string(dynamic value) => value?.toString() ?? '';
DateTime? date(dynamic value) => DateTime.tryParse(string(value))?.toLocal();

enum Role { attendee, organizer, admin }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
  factory AppUser.fromJson(Json j) => AppUser(
        id: integer(j['id']),
        name: string(j['name']),
        email: string(j['email']),
        role: Role.values.firstWhere(
          (r) => r.name == j['role'],
          orElse: () => Role.attendee,
        ),
      );
  final int id;
  final String name, email;
  final Role role;
  String get firstName => name.split(' ').first;
  String get home => switch (role) {
        Role.attendee => '/discover',
        Role.organizer => '/organizer',
        Role.admin => '/admin/events',
      };
}

class TicketType {
  TicketType.fromJson(Json j)
      : id = integer(j['id']),
        name = string(j['name']),
        description = string(j['description']),
        price = integer(j['price']),
        capacity = integer(j['capacity']),
        remaining = integer(j['remaining'] ?? j['capacity']),
        sold = integer(j['sold']),
        saleStatus = string(j['sale_status']);
  final int id, price, capacity, remaining, sold;
  final String name, description, saleStatus;
  bool get canBuy => saleStatus == 'on_sale' && remaining > 0;
}

class Event {
  Event.fromJson(Json j)
      : id = integer(j['id']),
        slug = string(j['slug']),
        title = string(j['title']),
        description = string(j['description']),
        venue = string(j['venue']),
        city = string(j['city']),
        category = string(j['category']),
        categoryLabel = string(j['category_label']),
        categoryId = integer(
          j['event_category_id'] ?? object(j['event_category'])['id'],
        ),
        startsAt = date(j['starts_at']),
        endsAt = date(j['ends_at']),
        status = string(j['status']),
        coverUrl = AppConfig.resolveMediaUrl(string(j['cover_url'])),
        startingPrice =
            j['starting_price'] == null ? null : integer(j['starting_price']),
        sold = integer(j['sold']),
        capacity = integer(j['capacity']),
        checkedIn = integer(j['checked_in']),
        revenue = integer(j['revenue'] ?? j['total_sales']),
        organizerName = string(object(j['organizer'])['name']),
        organizerEmail = string(object(j['organizer'])['email']),
        ticketTypes =
            objects(j['ticket_types']).map(TicketType.fromJson).toList();
  final int id, categoryId, sold, capacity, checkedIn, revenue;
  final int? startingPrice;
  final String slug,
      title,
      description,
      venue,
      city,
      category,
      categoryLabel,
      status,
      coverUrl,
      organizerName,
      organizerEmail;
  final DateTime? startsAt, endsAt;
  final List<TicketType> ticketTypes;
  bool get published => status == 'published';
}

class Ticket {
  Ticket.fromJson(Json j)
      : code = string(j['code']),
        status = string(j['status']),
        buyerName = string(j['buyer_name']),
        typeName = j['ticket_type'] is Map
            ? string(j['ticket_type']['name'])
            : string(j['ticket_type']),
        orderNumber = string(j['order_number']),
        event = Event.fromJson(object(j['event'])),
        checkedInAt = date(j['checked_in_at']);
  final String code, status, buyerName, typeName, orderNumber;
  final Event event;
  final DateTime? checkedInAt;
  bool get used => status == 'used';
  bool isPast(DateTime now) => event.endsAt?.isBefore(now) ?? false;
}

/// One checkout produces many ticket codes; the list shows one card per purchase.
class TicketPurchase {
  TicketPurchase(List<Ticket> tickets)
      : tickets = List.unmodifiable(
          List<Ticket>.from(tickets)
            ..sort((a, b) => a.code.compareTo(b.code)),
        ) {
    assert(this.tickets.isNotEmpty);
  }
  final List<Ticket> tickets;
  Ticket get primary => tickets.first;
  String get orderNumber => primary.orderNumber;
  Event get event => primary.event;
  String get typeName => primary.typeName;
  int get quantity => tickets.length;
  int get usedCount => tickets.where((t) => t.used).length;
  bool get allUsed => usedCount == quantity;
  bool isPast(DateTime now) => primary.isPast(now);

  static List<TicketPurchase> group(Iterable<Ticket> tickets) {
    final map = <String, List<Ticket>>{};
    for (final ticket in tickets) {
      final key =
          ticket.orderNumber.isEmpty ? ticket.code : ticket.orderNumber;
      map.putIfAbsent(key, () => []).add(ticket);
    }
    final groups = map.values.map(TicketPurchase.new).toList()
      ..sort((a, b) {
        final aStart = a.event.startsAt;
        final bStart = b.event.startsAt;
        if (aStart != null && bStart != null) {
          final byStart = aStart.compareTo(bStart);
          if (byStart != 0) return byStart;
        }
        return a.orderNumber.compareTo(b.orderNumber);
      });
    return groups;
  }
}

class Order {
  Order.fromJson(Json j)
      : id = integer(j['id']),
        number = string(j['number']),
        buyerName = string(j['buyer_name']),
        buyerEmail = string(j['buyer_email']),
        quantity = integer(j['quantity']),
        unitPrice = integer(j['unit_price']),
        total = integer(j['total']),
        status = string(j['status']),
        createdAt = date(j['created_at']),
        event = Event.fromJson(object(j['event'])),
        typeName = string(object(j['ticket_type'])['name']),
        ticketCodes =
            objects(j['tickets']).map((t) => string(t['code'])).toList();
  final int id, quantity, unitPrice, total;
  final String number, buyerName, buyerEmail, status, typeName;
  final DateTime? createdAt;
  final Event event;
  final List<String> ticketCodes;
}

class Category {
  Category.fromJson(Json j)
      : id = integer(j['id']),
        slug = string(j['slug']),
        name = string(j['name']);
  final int id;
  final String slug, name;
}
