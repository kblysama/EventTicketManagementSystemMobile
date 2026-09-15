import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../organizer/screens.dart';

class AdminEventsScreen extends ConsumerStatefulWidget {
  const AdminEventsScreen({super.key});
  @override
  ConsumerState<AdminEventsScreen> createState() => _AdminEventsState();
}

class _AdminEventsState extends ConsumerState<AdminEventsScreen> {
  String status = '';
  @override
  Widget build(BuildContext context) {
    final path = '/admin/events${status.isEmpty ? '' : '?status=$status'}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Heading(
                'Şehrin bütün buluşmaları.',
                eyebrow: 'YERİN / YÖNETİM',
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in {
                    '': 'Tümü',
                    'published': 'Yayında',
                    'draft': 'Taslak',
                  }.entries)
                    ChoiceChip(
                      label: Text(option.value),
                      selected: status == option.key,
                      onSelected: (_) => setState(() => status = option.key),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: ref.watch(jsonProvider(path)),
            onRetry: () => ref.invalidate(jsonProvider(path)),
            data: (j) {
              final events = objects(j['data']).map(Event.fromJson).toList();
              return PageBody(
                children: [
                  if (events.isEmpty)
                    const EmptyState(
                      'Etkinlik bulunamadı.',
                      'Seçilen durum için etkinlik yok.',
                    ),
                  for (final e in events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EventSummary(e),
                            const SizedBox(height: 12),
                            Text(e.organizerName),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  context.push('/admin/events/${e.slug}'),
                              child: const Text('Yönetim detayını gör →'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends ConsumerState<AdminOrdersScreen> {
  int? eventId;
  @override
  Widget build(BuildContext context) {
    final path = '/admin/orders${eventId == null ? '' : '?event_id=$eventId'}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Heading('Her sipariş, yeni bir plan.', eyebrow: 'YÖNETİM'),
              AsyncView(
                value: ref.watch(jsonProvider('/admin/events')),
                onRetry: () => ref.invalidate(jsonProvider('/admin/events')),
                data: (j) {
                  final events =
                      objects(j['data']).map(Event.fromJson).toList();
                  return DropdownButtonFormField<int>(
                    initialValue:
                        events.any((e) => e.id == eventId) ? eventId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Etkinliğe göre filtrele',
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Tüm etkinlikler'),
                      ),
                      ...events.map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.title, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (id) => setState(() => eventId = id),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: ref.watch(jsonProvider(path)),
            onRetry: () => ref.invalidate(jsonProvider(path)),
            data: (j) {
              final orders = objects(j['data']).map(Order.fromJson).toList();
              final summary = object(j['summary']);
              final total = integer(
                summary['revenue'] ??
                    summary['total_sales'] ??
                    orders.fold<int>(0, (sum, o) => sum + o.total),
              );
              final quantity = integer(
                summary['sold'] ??
                    orders.fold<int>(0, (sum, o) => sum + o.quantity),
              );
              return PageBody(
                children: [
                  Metric(
                    'SATIŞ TOPLAMI',
                    money(total),
                    subtitle:
                        '$quantity bilet · ${integer(summary['orders'] ?? orders.length)} sipariş',
                    mint: true,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tüm siparişler',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (orders.isEmpty)
                    const EmptyState(
                      'Henüz sipariş yok.',
                      'Satışlar burada görünecek.',
                    ),
                  for (final o in orders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Text(
                                  '#${o.number}',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                StatusBadge(
                                  o.status == 'completed'
                                      ? 'Tamamlandı'
                                      : o.status,
                                  active: o.status == 'completed',
                                ),
                              ],
                            ),
                            const Divider(height: 28),
                            Text(
                              o.buyerName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${o.event.title} · ${o.quantity} ${o.typeName}',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              dateLabel(o.createdAt),
                              style: const TextStyle(color: YerinColors.muted),
                            ),
                            const Divider(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    money(o.total),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      context.push('/orders/${o.id}'),
                                  child: const Text('Detay →'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class AdminEventScreen extends ConsumerWidget {
  const AdminEventScreen({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = '/admin/events/${Uri.encodeComponent(slug)}';
    return Scaffold(
      appBar: detailBar(context, 'Yönetim detayı'),
      body: AsyncView(
        value: ref.watch(jsonProvider(path)),
        onRetry: () => ref.invalidate(jsonProvider(path)),
        data: (j) {
          final e = Event.fromJson(object(j['data']));
          return PageBody(
            children: [
              EventSummary(e),
              const SizedBox(height: 24),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORGANİZATÖR',
                      style: TextStyle(
                        letterSpacing: 2,
                        color: YerinColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      e.organizerName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(e.organizerEmail),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow('Başlangıç', dateLabel(e.startsAt)),
                    DetailRow('Bitiş', dateLabel(e.endsAt)),
                    const Divider(),
                    DetailRow('Konum', '${e.venue}, ${e.city}'),
                    const Divider(),
                    for (final t in e.ticketTypes)
                      DetailRow(
                        t.name,
                        '${money(t.price)} · Kapasite ${t.capacity}',
                      ),
                    if (e.ticketTypes.isEmpty)
                      const Text('Henüz bilet tipi yok.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Notice('Bu, salt okunur yönetim görünümüdür.'),
            ],
          );
        },
      ),
    );
  }
}
