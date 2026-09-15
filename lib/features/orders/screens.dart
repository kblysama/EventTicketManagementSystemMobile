import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/session.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int? selectedId;
  int quantity = 1;
  bool busy = false, uncertain = false;
  String? error;
  Future<void> purchase(TicketType type) async {
    if (busy || uncertain) return;
    final refreshData = ref.read(dataRevisionProvider.notifier).refresh;
    final user = ref.read(sessionProvider).asData?.value;
    if (user == null) {
      context.go('/login');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final json = await ref.read(apiProvider).post('/orders', {
        'ticket_type_id': type.id,
        'quantity': quantity,
        'buyer_name': user.name,
        'buyer_email': user.email,
      });
      final order = Order.fromJson(object(json['data']));
      refreshData();
      if (mounted) context.go('/orders/${order.id}/success');
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          uncertain = e.uncertain;
          error = e.uncertain
              ? 'Siparişinin sonucu henüz doğrulanamadı. Tekrar satın almadan önce siparişlerini kontrol et.'
              : e.fields.values.isNotEmpty
                  ? e.fields.values.join('\n')
                  : e.message;
        });
      }
      refreshData();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: detailBar(context, 'Yerini ayır'),
        body: AsyncView(
          value: ref.watch(eventProvider(widget.slug)),
          onRetry: () => ref.invalidate(eventProvider(widget.slug)),
          data: (event) {
            final types = event.ticketTypes.where((t) => t.canBuy).toList();
            final selected =
                types.where((t) => t.id == selectedId).firstOrNull ??
                    types.firstOrNull;
            final maxQuantity =
                selected == null ? 0 : selected.remaining.clamp(0, 10);
            final validQuantity = quantity <= maxQuantity;
            return PageBody(
              children: [
                const Heading('Bu akşamda\nsenin de yerin var.'),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EventCover(event, height: 130),
                      const SizedBox(height: 12),
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      EventFacts(event),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (selected == null || !event.published)
                  const Notice('Bu etkinlik için satışta bilet bulunmuyor.')
                else ...[
                  DropdownButtonFormField<int>(
                    initialValue: selected.id,
                    key: ValueKey(selected.id),
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Bilet tipi'),
                    items: types
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text('${t.name} · ${money(t.price)}'),
                          ),
                        )
                        .toList(),
                    onChanged: busy || uncertain
                        ? null
                        : (id) => setState(() {
                              selectedId = id;
                              quantity = 1;
                            }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text('Adet')),
                      IconButton(
                        tooltip: 'Adedi azalt',
                        onPressed: !busy && !uncertain && quantity > 1
                            ? () => setState(() => quantity--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$quantity'),
                      IconButton(
                        tooltip: 'Adedi artır',
                        onPressed: !busy && !uncertain && quantity < maxQuantity
                            ? () => setState(() => quantity++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (!validQuantity)
                    const Notice(
                      'Kalan bilet sayısı değişti. Adedi azalt.',
                      error: true,
                    ),
                  const SizedBox(height: 20),
                  Surface(
                    child: Column(
                      children: [
                        DetailRow(
                          '${selected.name} × $quantity',
                          money(selected.price * quantity),
                        ),
                        const DetailRow('İşlem ücreti', '₺0'),
                        const Divider(),
                        DetailRow(
                          'Toplam',
                          money(selected.price * quantity),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const Notice(
                    'Bu bir demo satın alma işlemidir. Gerçek bir ödeme alınmayacaktır.',
                  ),
                  if (error != null) Notice(error!, error: true),
                  FilledButton(
                    onPressed: busy || uncertain || !validQuantity
                        ? null
                        : () => purchase(selected),
                    child: Text(
                      busy ? 'Sipariş oluşturuluyor…' : 'Satın almayı onayla',
                    ),
                  ),
                  if (uncertain)
                    OutlinedButton(
                      onPressed: () => context.go('/orders'),
                      child: const Text('Siparişlerimi kontrol et'),
                    ),
                ],
              ],
            );
          },
        ),
      );
}

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
        value: ref.watch(jsonProvider('/orders')),
        onRetry: () => ref.invalidate(jsonProvider('/orders')),
        data: (j) {
          final orders = objects(j['data']).map(Order.fromJson).toList();
          return PageBody(
            children: [
              const Heading(
                'Siparişlerin.',
                subtitle: 'Planladığın güzel anların özeti.',
              ),
              if (orders.isEmpty)
                const EmptyState(
                  'İlk planın seni bekliyor.',
                  'Keşfet’ten bir etkinlik seçerek yerini ayır.',
                ),
              ...orders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${order.number}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const StatusBadge('Tamamlandı'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          order.event.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        DetailRow(
                          dateLabel(order.createdAt, time: false),
                          '${order.quantity} bilet',
                        ),
                        Text(
                          money(order.total),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push('/orders/${order.id}'),
                          child: const Text('Detayları gör'),
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

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id, this.success = false});
  final int id;
  final bool success;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: detailBar(context, success ? 'Yerin hazır' : 'Sipariş detayı'),
        body: AsyncView(
          value: ref.watch(orderProvider(id)),
          onRetry: () => ref.invalidate(orderProvider(id)),
          data: (order) {
            final user = ref.watch(sessionProvider).asData?.value;
            return PageBody(
              children: [
                if (success) ...[
                  const Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: YerinColors.mint,
                      child:
                          Icon(Icons.check, size: 36, color: YerinColors.ink),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Heading(
                    'Yerin hazır${user == null ? '' : ', ${user.firstName}'}.',
                    subtitle:
                        '${order.event.title} için biletin seni bekliyor.',
                  ),
                ],
                if (!success) Heading('#${order.number}'),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge('Tamamlandı · Demo'),
                ),
                const SizedBox(height: 20),
                EventCover(order.event, height: 170),
                const SizedBox(height: 16),
                Text(
                  order.event.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                EventFacts(order.event),
                const SizedBox(height: 24),
                Surface(
                  child: Column(
                    children: [
                      DetailRow('Sipariş no', '#${order.number}'),
                      DetailRow(
                        '${order.typeName} × ${order.quantity}',
                        money(order.total),
                      ),
                      const DetailRow('İşlem ücreti', '₺0'),
                      const Divider(),
                      DetailRow('Toplam', money(order.total), bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Surface(
                  child: Column(
                    children: [
                      DetailRow('Sipariş tarihi', dateLabel(order.createdAt)),
                      DetailRow('Katılımcı', order.buyerName),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (user?.role == Role.attendee)
                  FilledButton(
                    onPressed: order.ticketCodes.isEmpty
                        ? null
                        : () => context.push(
                              '/tickets/${Uri.encodeComponent(order.ticketCodes.first)}',
                            ),
                    child: Text(
                      order.ticketCodes.length <= 1
                          ? 'Biletimi göster'
                          : 'Biletlerimi göster (${order.ticketCodes.length})',
                    ),
                  ),
                if (success)
                  OutlinedButton(
                    onPressed: () => context.go('/orders/$id'),
                    child: const Text('Sipariş detayına git'),
                  ),
              ],
            );
          },
        ),
      );
}
