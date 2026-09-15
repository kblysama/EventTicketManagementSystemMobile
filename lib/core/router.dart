import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/session.dart';
import '../features/auth/screens.dart';
import '../features/discovery/screens.dart';
import '../features/orders/screens.dart';
import '../features/tickets/screens.dart';
import '../features/organizer/screens.dart';
import '../features/admin/screens.dart';
import '../features/check_in/screens.dart';
import 'models.dart';
import 'widgets.dart';
import 'theme.dart';

String? passwordResetLocation(Uri uri) {
  if (uri.scheme != 'yerin' || uri.host != 'reset-password') return null;
  final token = uri.queryParameters['token'],
      email = uri.queryParameters['email'];
  if (token == null || token.isEmpty || email == null || email.isEmpty) {
    return null;
  }
  return Uri(
    path: '/reset-password',
    queryParameters: {'token': token, 'email': email},
  ).toString();
}

String? routeRedirect({
  required String path,
  required bool loading,
  required bool failed,
  required AppUser? user,
}) {
  if (path == '/reset-password' || path == '/forgot-password') return null;
  if (loading || failed) return path == '/splash' ? null : '/splash';
  if (path == '/' || path == '/splash') return user?.home ?? '/login';
  if (path == '/login' || path == '/register') {
    return user?.home;
  }
  final private = path.startsWith('/organizer') ||
      path.startsWith('/admin') ||
      path.startsWith('/check-in') ||
      path.startsWith('/orders') ||
      path.startsWith('/tickets') ||
      path == '/account' ||
      path.endsWith('/checkout');
  if (private && user == null) return '/login';
  if ((path.startsWith('/organizer') || path.startsWith('/check-in')) &&
      user?.role != Role.organizer) {
    return user?.home ?? '/login';
  }
  if (path.startsWith('/admin') && user?.role != Role.admin) {
    return user?.home ?? '/login';
  }
  if ((path == '/orders' ||
          path.startsWith('/tickets') ||
          path.endsWith('/checkout')) &&
      user != null &&
      user.role != Role.attendee) {
    return user.home;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, next) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      return routeRedirect(
        path: state.uri.path,
        loading: session.isLoading,
        failed: session.hasError,
        user: session.asData?.value,
      );
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: detailBar(context, 'Sayfa bulunamadı'),
      body: PageBody(
        children: [
          const EmptyState(
            'Bu bağlantı artık geçerli değil.',
            'Ana sayfadan devam edebilirsin.',
          ),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Ana sayfaya dön'),
          ),
        ],
      ),
    ),
    routes: [
      GoRoute(path: '/', builder: (_, state) => const SplashScreen()),
      GoRoute(path: '/splash', builder: (_, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, state) => const AuthScreen()),
      GoRoute(
        path: '/register',
        builder: (_, state) => const AuthScreen(mode: 'register'),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, state) => const AuthScreen(mode: 'forgot'),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => AuthScreen(
          mode: 'reset',
          token: state.uri.queryParameters['token'] ?? '',
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/discover',
            builder: (_, state) => const DiscoveryScreen(),
          ),
          GoRoute(
            path: '/tickets',
            builder: (_, state) => const TicketsScreen(),
          ),
          GoRoute(path: '/orders', builder: (_, state) => const OrdersScreen()),
          GoRoute(
            path: '/account',
            builder: (_, state) => const AccountScreen(),
          ),
          GoRoute(
            path: '/organizer',
            builder: (_, state) => const OrganizerEventsScreen(),
          ),
          GoRoute(
            path: '/check-in',
            builder: (_, state) => const CheckInSelectionScreen(),
          ),
          GoRoute(
            path: '/admin/events',
            builder: (_, state) => const AdminEventsScreen(),
          ),
          GoRoute(
            path: '/admin/orders',
            builder: (_, state) => const AdminOrdersScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/events/:slug',
        builder: (_, s) => EventDetailScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/events/:slug/checkout',
        builder: (_, s) => CheckoutScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/tickets/:code',
        builder: (_, s) => TicketDetailScreen(code: s.pathParameters['code']!),
      ),
      GoRoute(
        path: '/orders/:id/success',
        builder: (_, s) => OrderDetailScreen(
          id: int.tryParse(s.pathParameters['id']!) ?? 0,
          success: true,
        ),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, s) =>
            OrderDetailScreen(id: int.tryParse(s.pathParameters['id']!) ?? 0),
      ),
      GoRoute(
        path: '/organizer/new',
        builder: (_, s) => const EventFormScreen(),
      ),
      GoRoute(
        path: '/organizer/:slug',
        builder: (_, s) =>
            OrganizerEventScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/organizer/:slug/edit',
        builder: (_, s) => EventFormScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/organizer/:slug/sales',
        builder: (_, s) => SalesScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/check-in/:slug',
        builder: (_, s) => CheckInScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/admin/events/:slug',
        builder: (_, s) => AdminEventScreen(slug: s.pathParameters['slug']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(sessionProvider).asData?.value?.role ?? Role.attendee;
    final tabs = switch (role) {
      Role.attendee => [
          ('/discover', 'Keşfet', Icons.explore_outlined),
          ('/tickets', 'Biletlerim', Icons.confirmation_number_outlined),
          ('/orders', 'Siparişlerim', Icons.receipt_long_outlined),
          ('/account', 'Hesabım', Icons.person_outline),
        ],
      Role.organizer => [
          ('/organizer', 'Etkinliklerim', Icons.event_outlined),
          ('/check-in', 'Check-in', Icons.qr_code_scanner),
          ('/account', 'Hesabım', Icons.person_outline),
        ],
      Role.admin => [
          ('/admin/events', 'Etkinlikler', Icons.event_outlined),
          ('/admin/orders', 'Siparişler', Icons.receipt_long_outlined),
          ('/account', 'Hesabım', Icons.person_outline),
        ],
    };
    var selected = tabs.indexWhere(
      (t) => path == t.$1 || path.startsWith('${t.$1}/'),
    );
    if (selected < 0) selected = 0;
    return Scaffold(
      backgroundColor: YerinColors.background,
      appBar: AppBar(
        title: const Brand(),
      ),
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FloatingPillNav(
          selectedIndex: selected,
          destinations: [
            for (final tab in tabs)
              PillDestination(label: tab.$2, icon: tab.$3),
          ],
          onSelect: (i) => context.go(tabs[i].$1),
        ),
      ),
    );
  }
}

class PillDestination {
  const PillDestination({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class FloatingPillNav extends StatelessWidget {
  const FloatingPillNav({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
  });
  final int selectedIndex;
  final List<PillDestination> destinations;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: YerinColors.ink,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: YerinColors.ink.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _PillNavItem(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  const _PillNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  final PillDestination destination;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final fg = selected ? YerinColors.ink : YerinColors.slate;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? YerinColors.mint : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, size: 22, color: fg),
              const SizedBox(height: 4),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
