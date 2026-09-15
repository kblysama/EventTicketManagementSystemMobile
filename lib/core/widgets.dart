import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';

class Brand extends StatelessWidget {
  const Brand({super.key, this.width = 88});
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Yerin',
        image: true,
        child: SizedBox(
          width: width,
          height: width * .42,
          child: ClipRect(
            child: OverflowBox(
              maxHeight: width,
              child: Image.asset(
                'assets/images/yerin-logo.png',
                width: width,
                height: width,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.padding = 24});
  final List<Widget> children;
  final double padding;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child:
                ListView(padding: EdgeInsets.all(padding), children: children),
          ),
        ),
      );
}

/// Brand artwork built with widgets; event artwork always comes from its API.
class BrandPoster extends StatelessWidget {
  const BrandPoster({super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 190 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
          color: YerinColors.ink,
          padding: const EdgeInsets.all(22),
          child: Stack(
            children: [
              Positioned(
                right: -85,
                top: -12,
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: YerinColors.slate, width: 26),
                  ),
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAHA ÇOK AN. DAHA ÇOK HİKÂYE.',
                    style: TextStyle(
                      fontSize: 8,
                      color: YerinColors.slate,
                      letterSpacing: 1.3,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Hayatın\niçinde.\nTam yerinde.',
                    style: TextStyle(
                      fontSize: 25,
                      height: 1.05,
                      color: YerinColors.mint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.subtitle, this.eyebrow});
  final String title;
  final String? subtitle, eyebrow;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  eyebrow!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(letterSpacing: 2, color: YerinColors.muted),
                ),
              ),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  subtitle!,
                  style: const TextStyle(color: YerinColors.muted),
                ),
              ),
          ],
        ),
      );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = 16,
  });
  final Widget child;
  final Color color;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: YerinColors.border),
        ),
        child: child,
      );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Semantics(
          liveRegion: true,
          child: Surface(
            color: error ? const Color(0xFFFFECE8) : YerinColors.cyan,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(error ? Icons.info_outline : Icons.info_outline, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(text)),
              ],
            ),
          ),
        ),
      );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key, this.active = true});
  final String text;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? YerinColors.mint : YerinColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
}

class EventCover extends StatelessWidget {
  const EventCover(this.event, {super.key, this.height = 200});
  final Event event;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: event.coverUrl.isEmpty
              ? _fallback(context)
              : Image.network(
                  event.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => _fallback(context),
                ),
        ),
      );
  Widget _fallback(BuildContext context) => Container(
        color: YerinColors.ink,
        padding: const EdgeInsets.all(22),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: YerinColors.slate, width: 28),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                event.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
}

class EventFacts extends StatelessWidget {
  const EventFacts(this.event, {super.key});
  final Event event;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel(event.startsAt),
            style: const TextStyle(color: YerinColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            [event.venue, event.city].where((s) => s.isNotEmpty).join(', '),
            style: const TextStyle(color: YerinColors.muted),
          ),
        ],
      );
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.bold = false});
  final String label, value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  Text(label, style: const TextStyle(color: YerinColors.muted)),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}

class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
  });
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => value.when(
        skipLoadingOnRefresh: true,
        data: data,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 16),
                Text(
                  e is ApiFailure ? e.message : 'Veriler yüklenemedi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: onRetry, child: const Text('Tekrar dene')),
              ],
            ),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.title, this.message, {super.key});
  final String title, message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              size: 40,
              color: YerinColors.muted,
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: YerinColors.muted),
            ),
          ],
        ),
      );
}

AppBar detailBar(BuildContext context, String title) => AppBar(
      leading: IconButton(
        tooltip: 'Geri',
        icon: const Icon(Icons.arrow_back_ios_new, size: 19),
        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      actions: const [
        Padding(padding: EdgeInsets.only(right: 24), child: Brand(width: 65)),
      ],
    );

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Bu alan zorunludur.' : null;
String? emailValidator(String? value) =>
    requiredText(value) ??
    (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
        ? 'Geçerli bir e-posta adresi gir.'
        : null);

class LabeledField extends StatelessWidget {
  const LabeledField(
    this.label, {
    super.key,
    required this.controller,
    this.validator,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffixIcon,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final Widget? suffixIcon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: YerinColors.muted,
              ),
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: controller,
              validator: validator,
              keyboardType: keyboardType,
              obscureText: obscureText,
              maxLines: maxLines,
              decoration: InputDecoration(
                errorText: errorText,
                suffixIcon: suffixIcon,
              ),
              textInputAction:
                  maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
            ),
          ],
        ),
      );
}
