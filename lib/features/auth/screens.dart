import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'session.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Center(child: Brand(width: 160)),
            const Text(
              'Güzel anlarda yerin var.',
              style: TextStyle(color: YerinColors.muted),
            ),
            const Spacer(),
            if (session.hasError)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Notice(
                      'Oturum doğrulanamadı. Bağlantını kontrol et.',
                      error: true,
                    ),
                    FilledButton(
                      onPressed: () => ref.invalidate(sessionProvider),
                      child: const Text('Tekrar dene'),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).clear(),
                      child: const Text('Misafir olarak devam et'),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(
                width: 130,
                child: LinearProgressIndicator(
                  color: YerinColors.mint,
                  backgroundColor: YerinColors.border,
                ),
              ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.mode = 'login',
    this.token = '',
    this.email = '',
  });
  final String mode, token, email;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, obscure = true;
  ApiFailure? error;
  String? message;
  @override
  void initState() {
    super.initState();
    email.text = widget.email;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    final session = ref.read(sessionProvider.notifier);
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      if (widget.mode == 'forgot') {
        final result = await ref.read(apiProvider).post(
          '/auth/forgot-password',
          {'email': email.text.trim()},
        );
        if (mounted) {
          setState(
            () => message = result['message']?.toString() ??
                'Sıfırlama bağlantısı gönderildi.',
          );
        }
      } else if (widget.mode == 'reset') {
        await ref.read(apiProvider).post('/auth/reset-password', {
          'token': widget.token,
          'email': email.text.trim(),
          'password': password.text,
          'password_confirmation': confirmation.text,
        });
        await session.clear();
        if (mounted) {
          context.go('/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Şifren güncellendi. Giriş yapabilirsin.'),
            ),
          );
        }
      } else {
        await ref.read(sessionProvider.notifier).authenticate(widget.mode, {
          'email': email.text.trim(),
          'password': password.text,
          if (widget.mode == 'register') ...{
            'name': name.text.trim(),
            'password_confirmation': confirmation.text,
          },
        });
        if (mounted) {
          context.go(
            ref.read(sessionProvider).asData?.value?.home ?? '/discover',
          );
        }
      }
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = const ApiFailure('İşlem tamamlanamadı. Tekrar dene.'),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.mode == 'register',
        forgot = widget.mode == 'forgot',
        reset = widget.mode == 'reset';
    final title = register
        ? 'Güzel anılar bir\nhesapla başlar.'
        : forgot
            ? 'Şifreni mi unuttun?'
            : reset
                ? 'Hesabına yeniden kavuş.'
                : 'Tekrar hoş geldin.';
    return Scaffold(
      appBar: AppBar(
        title: const Brand(),
        leading: widget.mode != 'login'
            ? BackButton(onPressed: () => context.go('/login'))
            : null,
      ),
      body: PageBody(
        children: [
          if (register || forgot) ...[
            const BrandPoster(),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 40),
          Heading(
            title,
            subtitle: forgot
                ? 'Kayıtlı e-posta adresine şifre sıfırlama bağlantısı göndereceğiz.'
                : reset
                    ? 'Yeni bir şifre belirleyerek yolculuğuna devam et.'
                    : 'Güzel bir plana kaldığın yerden devam et.',
          ),
          if (reset) ...[const BrandPoster(), const SizedBox(height: 24)],
          Form(
            key: form,
            child: Column(
              children: [
                if (register)
                  LabeledField(
                    'Ad soyad',
                    controller: name,
                    validator: requiredText,
                    errorText: error?.fields['name'],
                  ),
                LabeledField(
                  'E-posta',
                  controller: email,
                  validator: emailValidator,
                  keyboardType: TextInputType.emailAddress,
                  errorText: error?.fields['email'],
                ),
                if (!forgot)
                  LabeledField(
                    reset ? 'Yeni şifre' : 'Şifre',
                    controller: password,
                    obscureText: obscure,
                    validator: (v) =>
                        requiredText(v) ??
                        ((register || reset) && v!.length < 8
                            ? 'En az 8 karakter kullan.'
                            : null),
                    errorText: error?.fields['password'],
                    suffixIcon: IconButton(
                      tooltip: obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                if (register || reset)
                  LabeledField(
                    'Şifre tekrarı',
                    controller: confirmation,
                    obscureText: obscure,
                    validator: (v) => v != password.text
                        ? 'Şifreler eşleşmiyor.'
                        : requiredText(v),
                  ),
                if (!register && !forgot && !reset)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Şifremi unuttum'),
                    ),
                  ),
                if (error != null) Notice(error!.message, error: true),
                if (message != null) Notice(message!),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Lütfen bekle…'
                        : register
                            ? 'Hesap oluştur'
                            : forgot
                                ? 'Sıfırlama bağlantısı gönder'
                                : reset
                                    ? 'Şifreyi kaydet'
                                    : 'Giriş yap',
                  ),
                ),
                const SizedBox(height: 12),
                if (register)
                  const Text(
                    'Katılımcı hesabı. Etkinlikleri keşfet, biletlerini yönet.',
                    style: TextStyle(fontSize: 12, color: YerinColors.muted),
                  ),
                if (!forgot && !reset)
                  TextButton(
                    onPressed: () =>
                        context.go(register ? '/login' : '/register'),
                    child: Text(
                      register
                          ? 'Hesabın var mı? Giriş yap'
                          : 'Henüz hesabın yok mu? Kayıt ol',
                    ),
                  ),
                if (!register && !forgot && !reset)
                  TextButton(
                    onPressed: () => context.go('/discover'),
                    child: const Text('Etkinlikleri keşfet'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).asData?.value;
    if (user == null) {
      return PageBody(
        children: [
          const Heading('Hesabım'),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Giriş yap'),
          ),
        ],
      );
    }
    return PageBody(
      children: [
        const Heading('Hesabım', subtitle: 'Yerin’deki yolculuğun burada.'),
        Surface(
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: YerinColors.ink,
                foregroundColor: YerinColors.mint,
                child: Text(
                  user.name
                      .split(' ')
                      .where((s) => s.isNotEmpty)
                      .take(2)
                      .map((s) => s[0])
                      .join(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(user.email, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    StatusBadge(switch (user.role.name) {
                      'admin' => 'Yönetici',
                      'organizer' => 'Organizatör',
                      _ => 'Katılımcı',
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (user.role.name == 'attendee') ...[
          ListTile(
            leading: const Icon(Icons.confirmation_number_outlined),
            title: const Text('Biletlerim'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/tickets'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Siparişlerim'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/orders'),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              await ref.read(sessionProvider.notifier).logout();
            } catch (_) {
              /* Local session is cleared even when the server is unreachable. */
            }
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Çıkış yap'),
        ),
      ],
    );
  }
}
