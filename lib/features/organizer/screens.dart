import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/realtime.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'ticket_type_form.dart';
export 'event_form.dart';

String organizerPath(String slug) =>
    '/organizer/events/${Uri.encodeComponent(slug)}';

class Metric extends StatelessWidget {
  const Metric(
    this.label,
    this.value, {
    super.key,
    this.subtitle,
    this.mint = false,
  });
  final String label, value;
  final String? subtitle;
  final bool mint;
  @override
  Widget build(BuildContext context) => Surface(
        color: mint ? YerinColors.mint : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: YerinColors.muted)),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              subtitle ?? ' ',
              style: const TextStyle(color: YerinColors.muted),
            ),
          ],
        ),
      );
}

class EventSummary extends StatelessWidget {
  const EventSummary(this.event, {super.key});
  final Event event;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventCover(event, height: 180),
          const SizedBox(height: 16),
          StatusBadge(
            event.published ? 'Yayında' : 'Taslak',
            active: event.published,
          ),
          const SizedBox(height: 12),
          Text(event.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          EventFacts(event),
        ],
      );
}

class OrganizerEventsScreen extends ConsumerWidget {
  const OrganizerEventsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
        value: ref.watch(jsonProvider('/organizer/events')),
        onRetry: () => ref.invalidate(jsonProvider('/organizer/events')),
        data: (j) {
          final events = objects(j['data']).map(Event.fromJson).toList();
          return PageBody(
            children: [
              const Heading(
                'Sen kur. Şehir buluşsun.',
                eyebrow: 'ETKİNLİKLERİM',
                subtitle: 'İyi deneyimler, iyi bir hazırlıkla başlar.',
              ),
              Text('${events.length} etkinlik'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/organizer/new'),
                icon: const Icon(Icons.add),
                label: const Text('Yeni etkinlik'),
              ),
              const SizedBox(height: 16),
              if (events.isEmpty)
                const EmptyState(
                  'İlk buluşmanı tasarla.',
                  'Yeni etkinlik oluşturarak başlayabilirsin.',
                ),
              for (final e in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Surface(
                    child: Column(
                      children: [
                        EventSummary(e),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Metric(
                                'Satılan bilet',
                                '${e.sold} / ${e.capacity}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Metric(
                                'Toplam satış',
                                money(e.revenue),
                                subtitle: 'Simüle satış tutarı',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push('/organizer/${e.slug}'),
                          child: const Text('Etkinliği yönet ↗'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class OrganizerEventScreen extends ConsumerStatefulWidget {
  const OrganizerEventScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<OrganizerEventScreen> createState() => _OrganizerEventState();
}

class _OrganizerEventState extends ConsumerState<OrganizerEventScreen> {
  bool deleting = false;
  String? error;
  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etkinlik silinsin mi?'),
        content: const Text(
          'Bu etkinlik ve etkinliğe bağlı tüm siparişler ile biletler kalıcı olarak silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Etkinliği sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      deleting = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).delete(organizerPath(widget.slug));
      if (mounted) ref.read(dataRevisionProvider.notifier).refresh();
      if (mounted) context.go('/organizer');
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = organizerPath(widget.slug);
    return Scaffold(
      appBar: detailBar(context, 'Etkinlik yönetimi'),
      body: AsyncView(
        value: ref.watch(jsonProvider(path)),
        onRetry: () => ref.invalidate(jsonProvider(path)),
        data: (j) {
          final e = Event.fromJson(object(j['data']));
          return PageBody(
            children: [
              EventSummary(e),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Metric('Bilet', '${e.sold}', subtitle: 'Toplam satış'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Metric(
                      'Check-in',
                      '${e.checkedIn}',
                      subtitle: 'Giriş yapılan',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/check-in/${e.slug}'),
                child: const Text('Check-in başlat'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.push('/organizer/${e.slug}/sales'),
                child: const Text('Satış özetini gör'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.push('/organizer/${e.slug}/edit'),
                child: const Text('Etkinliği düzenle'),
              ),
              const SizedBox(height: 24),
              Text(
                'Bilet tipleri',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (e.ticketTypes.isEmpty)
                const Notice('Satışa başlamak için bir bilet tipi ekle.'),
              for (final t in e.ticketTypes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        DetailRow(
                          'Fiyat / Kapasite',
                          '${money(t.price)} / ${t.capacity}',
                        ),
                        DetailRow(
                          'Satış durumu',
                          t.saleStatus == 'on_sale' ? 'Satışta' : 'Durduruldu',
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              showTicketTypeForm(context, e.slug, t),
                          child: const Text('Bilet tipini düzenle'),
                        ),
                      ],
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => showTicketTypeForm(context, e.slug, null),
                icon: const Icon(Icons.add),
                label: const Text('Bilet tipi ekle'),
              ),
              if (error != null) Notice(error!, error: true),
              const SizedBox(height: 16),
              TextButton(
                onPressed: deleting ? null : remove,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(deleting ? 'Siliniyor…' : 'Etkinliği sil'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = '${organizerPath(slug)}/sales';
    return Scaffold(
      appBar: detailBar(context, 'Organizer Paneli'),
      body: AsyncView(
        value: ref.watch(jsonProvider(path)),
        onRetry: () => ref.invalidate(jsonProvider(path)),
        data: (j) {
          final d = object(j['data']);
          final sold = integer(d['sold']);
          final checked = integer(d['checked_in']);
          final ratio = sold == 0 ? 0.0 : (checked / sold).clamp(0.0, 1.0);
          return PageBody(
            children: [
              const Heading('Satış özeti', subtitle: 'Buluşmanın sayıları.'),
              Metric(
                'TOPLAM SATIŞ',
                money(integer(d['revenue'] ?? d['total_sales'])),
                subtitle: string(object(d['event'])['title'] ?? d['title']),
                mint: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Metric('Satılan bilet', '$sold', mint: true),
                  Metric('Check-in', '$checked', mint: true),
                ],
              ),
              const SizedBox(height: 16),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bilet dağılımı',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final t in objects(d['ticket_types'])) ...[
                      const SizedBox(height: 16),
                      DetailRow(
                        string(t['name']),
                        '${integer(t['sold'])} / ${integer(t['capacity'])}',
                      ),
                      LinearProgressIndicator(
                        value: integer(t['capacity']) == 0
                            ? 0
                            : (integer(t['sold']) / integer(t['capacity']))
                                .clamp(0.0, 1.0),
                        minHeight: 10,
                        color: YerinColors.slate,
                        backgroundColor: YerinColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      Text('${integer(t['remaining'])} kişiye daha yer var.'),
                    ],
                    if (objects(d['ticket_types']).isEmpty)
                      const Text('Henüz bilet tipi eklenmedi.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Giriş oranı',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (ref.watch(realtimeProvider) == LiveStatus.live)
                      const StatusBadge('Canlı veriler'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: ratio,
                                  strokeWidth: 10,
                                  color: YerinColors.slate,
                                  backgroundColor: YerinColors.background,
                                ),
                              ),
                              Text('%${(ratio * 100).round()}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Text(
                            '$sold biletin $checked tanesi doğrulandı.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
