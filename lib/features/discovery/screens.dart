import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/session.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  String category = '', city = '', query = '';
  Timer? debounce;
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => city = prefs.getString('discovery_city') ?? '');
      }
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = Uri(
      path: '/events',
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        if (city.isNotEmpty) 'city': city,
        if (category.isNotEmpty) 'category': category,
      },
    ).toString();
    final value = ref.watch(jsonProvider(path));
    final categories = objects(
      ref.watch(jsonProvider('/event-categories')).asData?.value['data'],
    ).map(Category.fromJson).toList();
    final citiesResult =
        ref.watch(jsonProvider('/event-cities')).asData?.value['data'];
    final cities = citiesResult is List
        ? citiesResult
            .map((v) => v is Map ? string(v['name'] ?? v['city']) : string(v))
            .where((v) => v.isNotEmpty)
            .toSet()
        : <String>{};
    return AsyncView(
      value: value,
      onRetry: () => ref.invalidate(jsonProvider(path)),
      data: (json) {
        final events = objects(json['data']).map(Event.fromJson).toList();
        final choices = {...cities, if (city.isNotEmpty) city};
        return RefreshIndicator(
          onRefresh: () async {
            ref.read(dataRevisionProvider.notifier).refresh();
            await ref.read(jsonProvider(path).future);
          },
          child: PageBody(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: DropdownButton<String>(
                  value: city,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Tüm şehirler'),
                    ),
                    ...choices.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: (v) async {
                    setState(() => city = v ?? '');
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('discovery_city', city);
                  },
                ),
              ),
              const Heading('Bugün nerede\nolmak istersin?'),
              TextField(
                controller: search,
                decoration: const InputDecoration(
                  hintText: 'Etkinlik veya mekân ara',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) setState(() => query = v.trim());
                  });
                },
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Senin için'),
                      selected: category.isEmpty,
                      onSelected: (_) => setState(() => category = ''),
                    ),
                    ...categories.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: category == c.slug,
                          onSelected: (_) => setState(() => category = c.slug),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Kaçırmak istemezsin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (events.isEmpty)
                const EmptyState(
                  'Burada henüz bir plan yok.',
                  'Başka bir kategori veya şehir seçmeyi dene.',
                ),
              ...events.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/events/${event.slug}'),
                    child: Surface(
                      padding: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EventCover(event),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (event.categoryLabel.isNotEmpty)
                                  Text(
                                    event.categoryLabel.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.4,
                                      color: YerinColors.muted,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  event.title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                EventFacts(event),
                                const SizedBox(height: 16),
                                Text(
                                  event.startingPrice == null
                                      ? 'Biletler yakında'
                                      : money(event.startingPrice!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: detailBar(context, 'Etkinlik'),
        body: AsyncView(
          value: ref.watch(eventProvider(slug)),
          onRetry: () => ref.invalidate(eventProvider(slug)),
          data: (event) => PageBody(
            children: [
              EventCover(event, height: 260),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(event.categoryLabel),
              ),
              const SizedBox(height: 16),
              Heading(
                event.title,
                subtitle: event.organizerName.isEmpty
                    ? null
                    : '${event.organizerName} tarafından.',
              ),
              Surface(child: EventFacts(event)),
              const SizedBox(height: 24),
              Text(event.description),
              const SizedBox(height: 32),
              Surface(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.startingPrice == null
                            ? 'Biletler yakında'
                            : money(event.startingPrice!),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: event.published &&
                                event.ticketTypes.any((t) => t.canBuy)
                            ? () {
                                if (ref.read(sessionProvider).asData?.value ==
                                    null) {
                                  context.push('/login');
                                } else {
                                  context.push('/events/$slug/checkout');
                                }
                              }
                            : null,
                        child: Text(
                          event.ticketTypes.any((t) => t.canBuy)
                              ? 'Yerini ayır'
                              : 'Satışa kapalı',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
