import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router.dart';
import 'core/realtime.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  runApp(const ProviderScope(child: YerinApp()));
}

class YerinApp extends ConsumerStatefulWidget {
  const YerinApp({super.key});
  @override
  ConsumerState<YerinApp> createState() => _YerinAppState();
}

class _YerinAppState extends ConsumerState<YerinApp> {
  StreamSubscription<Uri>? links;
  @override
  void initState() {
    super.initState();
    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null && mounted) openLink(uri);
    });
    links = appLinks.uriLinkStream.listen(openLink);
  }

  void openLink(Uri uri) {
    final target = passwordResetLocation(uri);
    if (mounted && target != null) ref.read(routerProvider).go(target);
  }

  @override
  void dispose() {
    links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeProvider);
    return MaterialApp.router(
      title: 'Yerin',
      debugShowCheckedModeBanner: false,
      theme: yerinTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
