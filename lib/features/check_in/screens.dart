import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class CheckInSelectionScreen extends ConsumerWidget {
  const CheckInSelectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
        value: ref.watch(jsonProvider('/organizer/events')),
        onRetry: () => ref.invalidate(jsonProvider('/organizer/events')),
        data: (j) {
          final events = objects(j['data']).map(Event.fromJson).toList();
          return PageBody(
            children: [
              const Heading(
                'Hangi etkinlikte buluşuyoruz?',
                subtitle: 'Biletleri doğrulamak için etkinliğini seç.',
              ),
              if (events.isEmpty)
                const EmptyState(
                  'Etkinlik bulunamadı.',
                  'Etkinlik oluşturduğunda burada görünecek.',
                ),
              for (final e in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EventCover(e, height: 175),
                        const SizedBox(height: 16),
                        StatusBadge(dateLabel(e.startsAt, time: false)),
                        const SizedBox(height: 12),
                        Text(
                          e.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        EventFacts(e),
                        const Divider(height: 28),
                        DetailRow('Giriş', '${e.checkedIn} / ${e.sold}'),
                        DetailRow(
                          'Kişi bekleniyor',
                          '${(e.sold - e.checkedIn).clamp(0, e.sold)}',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push('/check-in/${e.slug}'),
                          child: const Text('Biletleri doğrula →'),
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

/// Holds a scan until the operator explicitly starts the next verification.
/// This avoids parallel requests and repeated QR frames, including timeouts.
class ScanGate {
  bool locked = false;
  bool acquire(String code) {
    if (locked || code.trim().isEmpty) return false;
    locked = true;
    return true;
  }

  void reset() => locked = false;
}

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<CheckInScreen> createState() => _CheckInState();
}

class _CheckInState extends ConsumerState<CheckInScreen>
    with WidgetsBindingObserver {
  final code = TextEditingController();
  final scanner = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final gate = ScanGate();
  bool busy = false, cameraReady = false;
  String? cameraError, error;
  Json? result;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => startCamera());
  }

  Future<void> startCamera() async {
    if (!mounted || gate.locked) return;
    try {
      await scanner.start();
      if (mounted) {
        setState(() {
          cameraReady = true;
          cameraError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          cameraReady = false;
          cameraError =
              'Kamera açılamadı. Ayarlardan kamera iznini kontrol et veya bilet kodunu elle gir.';
        });
      }
    }
  }

  Future<void> stopCamera() async {
    try {
      await scanner.stop();
    } catch (_) {
      /* The camera may not be initialized after permission denial. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(startCamera());
    } else {
      unawaited(stopCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    code.dispose();
    unawaited(scanner.dispose());
    super.dispose();
  }

  Future<void> verify(String raw) async {
    final value = raw.trim();
    if (!gate.acquire(value)) return;
    final refreshData = ref.read(dataRevisionProvider.notifier).refresh;
    setState(() {
      busy = true;
      error = null;
      result = null;
      code.text = value;
    });
    unawaited(stopCamera());
    try {
      final j = await ref.read(apiProvider).post(
        '/organizer/events/${Uri.encodeComponent(widget.slug)}/check-in',
        {'code': value},
      );
      refreshData();
      if (mounted) setState(() => result = j);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiFailure && e.status == 409
              ? 'Bu bilet daha önce kullanıldı. Tekrar giriş yapılamaz.'
              : e is ApiFailure && e.uncertain
                  ? 'Sonuç alınamadı. Bilet doğrulanmış olabilir. Bağlantıyı kontrol edip aynı kodu tekrar doğrulayarak durumunu öğren.'
                  : '$e',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void next() {
    gate.reset();
    setState(() {
      result = null;
      error = null;
      code.clear();
    });
    unawaited(startCamera());
  }

  @override
  Widget build(BuildContext context) {
    final e = ref
        .watch(
          jsonProvider('/organizer/events/${Uri.encodeComponent(widget.slug)}'),
        )
        .asData
        ?.value;
    final ticket = object(result?['ticket'] ?? result?['data']);
    final type = ticket['ticket_type'] is Map
        ? string(ticket['ticket_type']['name'])
        : string(ticket['ticket_type']);
    return Scaffold(
      appBar: detailBar(context, 'Check-in'),
      body: PageBody(
        children: [
          Heading(
            'Kodu okut. Güzel an başlasın.',
            eyebrow: string(object(e?['data'])['title']).toUpperCase(),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: scanner,
                    onDetect: (capture) {
                      if (capture.barcodes.isNotEmpty) {
                        final value = capture.barcodes.first.rawValue;
                        if (value != null) unawaited(verify(value));
                      }
                    },
                    errorBuilder: (context, exception) => const ColoredBox(
                      color: YerinColors.ink,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Kamera kullanılamıyor. Bilet kodunu aşağıdan elle girebilirsin.',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        border: Border.all(color: YerinColors.mint, width: 3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (gate.locked)
                    const ColoredBox(
                      color: Color(0x88040F0F),
                      child: Center(
                        child: Icon(
                          Icons.pause_circle_outline,
                          color: YerinColors.mint,
                          size: 56,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'QR kodunu çerçevenin içine yerleştir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: YerinColors.muted),
          ),
          if (cameraError != null) Notice(cameraError!),
          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('veya'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          LabeledField(
            'Bilet kodu',
            controller: code,
            suffixIcon: IconButton(
              tooltip: 'Kodu temizle',
              onPressed: busy ? null : code.clear,
              icon: const Icon(Icons.cancel_outlined),
            ),
          ),
          FilledButton(
            onPressed: busy || gate.locked ? null : () => verify(code.text),
            child: Text(busy ? 'Doğrulanıyor…' : 'Doğrula'),
          ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Surface(
                color: YerinColors.mint,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Giriş onaylandı',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            [
                              string(ticket['buyer_name']),
                              type,
                            ].where((v) => v.isNotEmpty).join(' · '),
                          ),
                          Text(dateLabel(date(ticket['checked_in_at']))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (error != null) Notice(error!, error: true),
          if (gate.locked && !busy)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                onPressed: next,
                child: const Text('Yeni bilet doğrula'),
              ),
            ),
        ],
      ),
    );
  }
}
