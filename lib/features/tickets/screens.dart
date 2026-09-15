import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});
  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  bool past = false;
  @override
  Widget build(BuildContext context) => AsyncView(
        value: ref.watch(jsonProvider('/tickets')),
        onRetry: () => ref.invalidate(jsonProvider('/tickets')),
        data: (json) {
          final tickets = objects(json['data']).map(Ticket.fromJson).toList();
          final purchases = TicketPurchase.group(tickets);
          final now = DateTime.now();
          final upcoming = purchases.where((p) => !p.isPast(now)).length;
          final filtered =
              purchases.where((p) => p.isPast(now) == past).toList();
          return PageBody(
            children: [
              const Heading(
                'Biletlerin burada.',
                subtitle: 'Katılacağın etkinlikler, tek yerde.',
              ),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text('Yaklaşan ($upcoming)'),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Geçmiş (${purchases.length - upcoming})'),
                  ),
                ],
                selected: {past},
                onSelectionChanged: (s) => setState(() => past = s.first),
              ),
              const SizedBox(height: 24),
              if (filtered.isEmpty)
                const EmptyState(
                  'Burada henüz bilet yok.',
                  'Yeni bir buluşma için etkinlikleri keşfet.',
                ),
              ...filtered.map(
                (purchase) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EventCover(purchase.event, height: 180),
                        const SizedBox(height: 16),
                        StatusBadge(
                          purchase.allUsed
                              ? 'Kullanıldı'
                              : purchase.usedCount == 0
                                  ? 'Kullanılmadı'
                                  : '${purchase.usedCount}/${purchase.quantity} kullanıldı',
                          active: !purchase.allUsed,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          purchase.event.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        EventFacts(purchase.event),
                        const SizedBox(height: 8),
                        Text(
                          purchase.quantity == 1
                              ? purchase.typeName
                              : '${purchase.typeName} · ${purchase.quantity} bilet',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push(
                            '/tickets/${Uri.encodeComponent(purchase.primary.code)}',
                          ),
                          child: Text(
                            purchase.quantity == 1
                                ? 'Bileti aç'
                                : 'Biletleri aç',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class TicketDetailScreen extends ConsumerWidget {
  const TicketDetailScreen({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: detailBar(context, 'Biletin'),
        body: AsyncView(
          value: ref.watch(jsonProvider('/tickets')),
          onRetry: () => ref.invalidate(jsonProvider('/tickets')),
          data: (json) {
            final tickets =
                objects(json['data']).map(Ticket.fromJson).toList();
            final own = tickets.where((t) => t.code == code).toList();
            if (own.isEmpty) {
              return AsyncView(
                value: ref.watch(ticketProvider(code)),
                onRetry: () => ref.invalidate(ticketProvider(code)),
                data: (ticket) => _TicketPassList(
                  tickets: [ticket],
                  focusCode: code,
                ),
              );
            }
            final purchase = TicketPurchase.group(tickets).firstWhere(
              (p) => p.tickets.any((t) => t.code == code),
            );
            return _TicketPassList(
              tickets: purchase.tickets,
              focusCode: code,
            );
          },
        ),
      );
}

class _TicketPassList extends StatelessWidget {
  const _TicketPassList({required this.tickets, required this.focusCode});
  final List<Ticket> tickets;
  final String focusCode;
  @override
  Widget build(BuildContext context) {
    final multi = tickets.length > 1;
    final focusIndex = tickets.indexWhere((t) => t.code == focusCode);
    return PageBody(
      children: [
        Heading(
          multi ? 'Satın aldığın biletler.' : 'İçeriye bir kod uzaklık.',
          subtitle: multi
              ? 'Aşağı kaydırarak ${tickets.length} biletin hepsini gör.'
              : null,
        ),
        for (final entry in tickets.indexed) ...[
          if (multi)
            Padding(
              padding: EdgeInsets.only(bottom: 12, top: entry.$1 == 0 ? 0 : 8),
              child: Text(
                '${entry.$1 + 1}. bilet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          _TicketPassCard(
            ticket: entry.$2,
            highlighted: multi && entry.$1 == focusIndex,
          ),
          if (entry.$1 < tickets.length - 1) const SizedBox(height: 20),
        ],
        const SizedBox(height: 16),
        const Notice('Girişte QR kodunu görevliye göster.'),
      ],
    );
  }
}

class _TicketPassCard extends StatelessWidget {
  const _TicketPassCard({required this.ticket, this.highlighted = false});
  final Ticket ticket;
  final bool highlighted;
  @override
  Widget build(BuildContext context) => Surface(
        color: YerinColors.mint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'YERİN / DİJİTAL BİLET',
                    style: TextStyle(fontSize: 11, letterSpacing: 2),
                  ),
                ),
                if (highlighted)
                  Text(
                    'Seçilen',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: YerinColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            EventCover(ticket.event, height: 150),
            const SizedBox(height: 16),
            StatusBadge(
              ticket.used ? 'Kullanıldı' : 'Kullanılmadı',
              active: !ticket.used,
            ),
            const SizedBox(height: 12),
            Text(
              ticket.event.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            EventFacts(ticket.event),
            DetailRow('Bilet tipi', ticket.typeName),
            DetailRow('Katılımcı', ticket.buyerName),
            if (ticket.checkedInAt != null)
              DetailRow('Giriş zamanı', dateLabel(ticket.checkedInAt)),
            const Divider(),
            Center(
              child: Semantics(
                label: 'Giriş biletinin QR kodu: ${ticket.code}',
                child: QrImageView(
                  data: ticket.code,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SelectableText(
                ticket.code,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
